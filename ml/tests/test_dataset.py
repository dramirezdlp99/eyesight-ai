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
