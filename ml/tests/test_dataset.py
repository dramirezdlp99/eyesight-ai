from pathlib import Path

import yaml

from eyesight_ml.classes import class_id
from eyesight_ml.dataset import (
    build_mapping,
    merge_sources,
    read_source_names,
    remap_label_text,
    split_for,
)


def make_source(root: Path, name: str, names, files: dict[str, dict[str, str]]) -> Path:
    src = root / name
    src.mkdir()
    (src / "data.yaml").write_text(yaml.safe_dump({"names": names}), encoding="utf-8")
    for split, items in files.items():
        (src / split / "images").mkdir(parents=True)
        (src / split / "labels").mkdir(parents=True)
        for stem, label in items.items():
            (src / split / "images" / f"{stem}.jpg").write_bytes(b"jpg")
            if label is not None:
                (src / split / "labels" / f"{stem}.txt").write_text(label, encoding="utf-8")
    return src


def test_lee_nombres_en_lista_o_diccionario(tmp_path):
    a = tmp_path / "a.yaml"
    a.write_text(yaml.safe_dump({"names": ["pothole", "car"]}), encoding="utf-8")
    b = tmp_path / "b.yaml"
    b.write_text(yaml.safe_dump({"names": {1: "car", 0: "pothole"}}), encoding="utf-8")
    assert read_source_names(a) == ["pothole", "car"]
    assert read_source_names(b) == ["pothole", "car"]


def test_reasigna_ids_y_descarta_clases_ajenas_y_datos_invalidos():
    mapping = build_mapping(["Pothole", "pizza", "Cone"])
    assert mapping == {0: class_id("pothole"), 2: class_id("traffic_cone")}
    text = "\n".join(
        [
            "0 0.5 0.5 0.2 0.2",  # hueco: se conserva
            "1 0.5 0.5 0.2 0.2",  # pizza: se descarta
            "2 0.1 0.1 0.1 0.1",  # cono: se conserva
            "0 1.5 0.5 0.2 0.2",  # fuera de rango
            "0 0.1 0.2 0.3 0.4 0.5 0.6",  # polígono
            "x 0.1 0.2 0.3 0.4",  # basura
        ]
    )
    lines, dropped = remap_label_text(text, mapping)
    assert lines == [
        f"{class_id('pothole')} 0.500000 0.500000 0.200000 0.200000",
        f"{class_id('traffic_cone')} 0.100000 0.100000 0.100000 0.100000",
    ]
    assert dropped == 4


def test_particion_determinista():
    assert split_for("img_001.jpg") == split_for("img_001.jpg")
    splits = {split_for(f"img_{i}.jpg") for i in range(200)}
    assert splits == {"train", "val", "test"}


def test_une_fuentes_y_escribe_eyesight_yaml(tmp_path):
    s1 = make_source(
        tmp_path,
        "baches pasto",
        ["pothole"],
        {"train": {"a": "0 0.5 0.5 0.1 0.1"}, "valid": {"b": "0 0.4 0.4 0.1 0.1"}},
    )
    s2 = make_source(
        tmp_path,
        "calles",
        ["car", "pizza"],
        {"test": {"c": "0 0.5 0.5 0.3 0.3", "d": "1 0.5 0.5 0.3 0.3", "e": None}},
    )
    out = tmp_path / "eyesight"
    report = merge_sources([s1, s2], out)

    assert report.images == {"train": 1, "val": 1, "test": 2}
    assert report.skipped_images == 1  # "d" solo tenía pizza
    assert report.boxes_per_class["pothole"] == 2
    assert report.boxes_per_class["car"] == 1
    assert (out / "train" / "images" / "baches_pasto__a.jpg").exists()
    assert (out / "test" / "labels" / "calles__e.txt").read_text() == ""

    data = yaml.safe_load((out / "eyesight.yaml").read_text(encoding="utf-8"))
    assert data["names"][class_id("pothole")] == "pothole"
    assert data["test"] == "test/images"


def test_grupo_de_video_de_un_cuadro_de_roboflow():
    from eyesight_ml.dataset import frame_group

    assert frame_group("barrio_barrio-1_s00033_jpg.rf.abc123.jpg") == "barrio_barrio-1"
    assert frame_group("sector_sector-11_s00055.jpg") == "sector_sector-11"
    assert frame_group("000000000139.jpg") is None


def test_validacion_por_video_completo_y_al_menos_uno():
    from eyesight_ml.dataset import choose_val_groups

    groups = {f"barrio_barrio-{i}" for i in range(1, 18)}
    val = choose_val_groups(groups)
    assert len(val) == 3  # 15 % de 17, hacia arriba
    assert val == choose_val_groups(groups)  # determinista
    assert choose_val_groups({"solo_uno"}) == {"solo_uno"}
    assert choose_val_groups(set()) == set()


def test_union_con_particion_por_video(tmp_path):
    import yaml

    from eyesight_ml.dataset import merge_sources

    src = tmp_path / "pasto"
    (src / "train" / "images").mkdir(parents=True)
    (src / "train" / "labels").mkdir(parents=True)
    (src / "data.yaml").write_text(yaml.safe_dump({"names": ["pole"]}), encoding="utf-8")
    for video in range(1, 8):
        for second in range(3):
            stem = f"barrio_barrio-{video}_s{second:05d}_jpg.rf.x{second}"
            (src / "train" / "images" / f"{stem}.jpg").write_bytes(b"x")
            (src / "train" / "labels" / f"{stem}.txt").write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")
    out = tmp_path / "out"
    report = merge_sources([src], out, group_split=True)
    assert report.images["test"] == 0
    assert report.images["val"] == 6  # dos videos completos (15 % de 7, hacia arriba)
    val_videos = {p.name.split("_s0")[0] for p in (out / "val" / "images").iterdir()}
    train_videos = {p.name.split("_s0")[0] for p in (out / "train" / "images").iterdir()}
    assert len(val_videos) == 2 and not (val_videos & train_videos)
