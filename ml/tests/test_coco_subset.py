from eyesight_ml.classes import class_id
from eyesight_ml.coco_subset import select_images, yolo_lines

IMAGES = {
    1: {"id": 1, "width": 640, "height": 480},
    2: {"id": 2, "width": 640, "height": 480},
    3: {"id": 3, "width": 640, "height": 480},
}
ANNS = [
    {"image_id": 1, "category_id": 2, "bbox": [100, 100, 80, 60], "iscrowd": 0},  # bicicleta
    {"image_id": 1, "category_id": 1, "bbox": [300, 50, 60, 200], "iscrowd": 0},  # persona
    {"image_id": 1, "category_id": 10, "bbox": [0, 0, 50, 50], "iscrowd": 0},  # semáforo: fuera
    {"image_id": 2, "category_id": 18, "bbox": [10, 10, 200, 150], "iscrowd": 0},  # perro
    {"image_id": 3, "category_id": 8, "bbox": [5, 5, 4, 4], "iscrowd": 0},  # camión diminuto
    {"image_id": 3, "category_id": 6, "bbox": [0, 0, 300, 200], "iscrowd": 1},  # bus en grupo
]


def test_elige_solo_imagenes_con_clases_buscadas_y_utiles():
    chosen = select_images(ANNS, IMAGES, per_class=10)
    assert sorted(chosen) == [1, 2]


def test_respeta_el_limite_por_clase_y_es_determinista():
    many = [
        {"image_id": i, "category_id": 18, "bbox": [0, 0, 100, 100], "iscrowd": 0}
        for i in range(1, 4)
    ]
    imgs = {i: {"id": i, "width": 640, "height": 480} for i in range(1, 4)}
    a = select_images(many, imgs, per_class=2, seed=1)
    b = select_images(many, imgs, per_class=2, seed=1)
    assert a == b
    assert len(a) == 2


def test_convierte_a_yolo_con_los_indices_de_eyesight():
    lines = yolo_lines([a for a in ANNS if a["image_id"] == 1], IMAGES[1])
    assert len(lines) == 2  # el semáforo se descarta
    c, cx, cy, w, h = lines[0].split()
    assert int(c) == class_id("bicycle")
    assert abs(float(cx) - 140 / 640) < 1e-6
    assert abs(float(cy) - 130 / 480) < 1e-6
    assert abs(float(w) - 80 / 640) < 1e-6
    assert abs(float(h) - 60 / 480) < 1e-6
    assert lines[1].startswith(f"{class_id('person')} ")


def test_descarta_grupos_y_cajas_diminutas():
    lines = yolo_lines([a for a in ANNS if a["image_id"] == 3], IMAGES[3])
    assert lines == []
