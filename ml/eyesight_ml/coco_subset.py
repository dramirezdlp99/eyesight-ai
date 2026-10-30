"""Subconjunto de COCO para no olvidar las clases comunes.

Las fotos de Pasto casi no tienen bicicletas, camiones, buses ni perros. Si el
modelo se ajusta sin ejemplos de esas clases, las «olvida» aunque el modelo
base de COCO las conociera (olvido catastrófico). Este módulo elige imágenes
de la validación de COCO 2017 (licencia CC BY 4.0 de las anotaciones) que
tengan esas clases y las convierte al formato YOLO con los índices de
EyeSight AI.

Funciones puras (sin red) para que las pruebas corran sin descargar nada; el
script ``scripts/fetch_coco_subset.py`` descarga y escribe los archivos.
"""

from __future__ import annotations

import random
from collections import defaultdict

from .classes import class_id

# Categorías de COCO (id del JSON de anotaciones) → clase de EyeSight AI.
COCO_CATEGORY_TO_EYESIGHT: dict[int, str] = {
    1: "person",
    2: "bicycle",
    3: "car",
    4: "motorcycle",
    6: "bus",
    8: "truck",
    18: "dog",
}

# Clases que faltan en Pasto: se buscan imágenes que las contengan.
WANTED_DEFAULT: tuple[str, ...] = ("bicycle", "truck", "bus", "dog")

# Cajas más pequeñas que esta fracción del área de la imagen no se usan:
# objetos diminutos al fondo, que la app no anuncia.
MIN_AREA_FRACTION = 0.002


def select_images(
    annotations: list[dict],
    images: dict[int, dict],
    wanted: tuple[str, ...] = WANTED_DEFAULT,
    per_class: int = 150,
    seed: int = 0,
) -> list[int]:
    """Ids de imágenes con al menos una caja útil de cada clase buscada,
    hasta ``per_class`` por clase, en orden determinista."""
    by_class: dict[str, set[int]] = defaultdict(set)
    for ann in annotations:
        name = COCO_CATEGORY_TO_EYESIGHT.get(ann.get("category_id"))
        if name not in wanted or ann.get("iscrowd"):
            continue
        info = images.get(ann.get("image_id"))
        if info is None or not _big_enough(ann["bbox"], info):
            continue
        by_class[name].add(ann["image_id"])
    rng = random.Random(seed)
    chosen: list[int] = []
    seen: set[int] = set()
    for name in wanted:
        ids = sorted(by_class.get(name, set()))
        rng.shuffle(ids)
        count = 0
        for image_id in ids:
            if count >= per_class:
                break
            if image_id not in seen:
                seen.add(image_id)
                chosen.append(image_id)
            count += 1
    return chosen


def yolo_lines(annotations: list[dict], info: dict) -> list[str]:
    """Líneas YOLO (clase cx cy w h normalizados) de una imagen, solo con
    las clases de EyeSight AI y sin cajas diminutas ni grupos (iscrowd)."""
    width, height = float(info["width"]), float(info["height"])
    lines: list[str] = []
    for ann in annotations:
        name = COCO_CATEGORY_TO_EYESIGHT.get(ann.get("category_id"))
        if name is None or ann.get("iscrowd") or not _big_enough(ann["bbox"], info):
            continue
        x, y, w, h = (float(v) for v in ann["bbox"])
        cx = min(max((x + w / 2) / width, 0.0), 1.0)
        cy = min(max((y + h / 2) / height, 0.0), 1.0)
        nw = min(w / width, 1.0)
        nh = min(h / height, 1.0)
        lines.append(f"{class_id(name)} {cx:.6f} {cy:.6f} {nw:.6f} {nh:.6f}")
    return lines


def _big_enough(bbox: list[float], info: dict) -> bool:
    w, h = float(bbox[2]), float(bbox[3])
    area = float(info["width"]) * float(info["height"])
    return area > 0 and w > 0 and h > 0 and (w * h) / area >= MIN_AREA_FRACTION
