"""Clases del modelo ajustado de EyeSight AI.

Las siete primeras son comunes con COCO y permiten contrastar la hipótesis del
numeral 2.3 (modelo preentrenado frente a modelo ajustado). Las seis últimas
son las clases nuevas de la delimitación (numeral 1.8).
"""

from __future__ import annotations

import re

# Orden definitivo de las clases del modelo ajustado (índice = id de YOLO).
EYESIGHT_CLASSES: list[str] = [
    "person",
    "bicycle",
    "car",
    "motorcycle",
    "bus",
    "truck",
    "dog",
    "pole",
    "bollard",
    "traffic_cone",
    "step",
    "pothole",
    "construction",
]

# Clases presentes en ambos modelos (hipótesis, numeral 2.3).
COMMON_CLASSES: list[str] = EYESIGHT_CLASSES[:7]

# Clases nuevas: se reportan de forma descriptiva.
NEW_CLASSES: list[str] = EYESIGHT_CLASSES[7:]

# Índices de las clases comunes en COCO (modelo preentrenado yolov8n.pt).
COCO_IDS: dict[str, int] = {
    "person": 0,
    "bicycle": 1,
    "car": 2,
    "motorcycle": 3,
    "bus": 5,
    "truck": 7,
    "dog": 16,
}

# Sinónimos frecuentes en los conjuntos de datos de Roboflow Universe.
SYNONYMS: dict[str, str] = {
    "person": "person",
    "people": "person",
    "pedestrian": "person",
    "human": "person",
    "bicycle": "bicycle",
    "bike": "bicycle",
    "car": "car",
    "vehicle": "car",
    "motorcycle": "motorcycle",
    "motorbike": "motorcycle",
    "moto": "motorcycle",
    "bus": "bus",
    "truck": "truck",
    "dog": "dog",
    "pole": "pole",
    "post": "pole",
    "lamp post": "pole",
    "light pole": "pole",
    "utility pole": "pole",
    "street light": "pole",
    "bollard": "bollard",
    "bollards": "bollard",
    "traffic cone": "traffic_cone",
    "cone": "traffic_cone",
    "cones": "traffic_cone",
    "step": "step",
    "steps": "step",
    "stair": "step",
    "stairs": "step",
    "staircase": "step",
    "curb": "step",
    "kerb": "step",
    "pothole": "pothole",
    "potholes": "pothole",
    "hole": "pothole",
    "construction": "construction",
    "roadwork": "construction",
    "road work": "construction",
    "barrier": "construction",
    "barricade": "construction",
}


def normalize_name(name: str) -> str:
    """Minúsculas, guiones y guiones bajos como espacios, espacios simples."""
    return re.sub(r"\s+", " ", re.sub(r"[_\-]+", " ", name.strip().lower())).strip()


def to_eyesight(name: str) -> str | None:
    """Clase de EyeSight AI para un nombre de otro conjunto, o None si se
    descarta."""
    return SYNONYMS.get(normalize_name(name))


def class_id(name: str) -> int:
    return EYESIGHT_CLASSES.index(name)
