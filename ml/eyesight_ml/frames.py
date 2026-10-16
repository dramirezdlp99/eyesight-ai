"""Selección de cuadros de los videos grabados en Pasto.

Funciones puras (solo numpy) para que las pruebas corran sin OpenCV; el
script ``scripts/extract_frames.py`` las usa para leer y guardar los videos.
"""

from __future__ import annotations

import re
import unicodedata

import numpy as np


def frame_indices(fps: float, total_frames: int, every_s: float = 1.0) -> list[int]:
    """Índices de los cuadros a guardar: uno cada ``every_s`` segundos."""
    if fps <= 0 or total_frames <= 0:
        return []
    if every_s <= 0:
        raise ValueError("every_s debe ser mayor que cero")
    step = fps * every_s
    indices: list[int] = []
    t = 0.0
    while round(t) < total_frames:
        index = int(round(t))
        if not indices or index != indices[-1]:
            indices.append(index)
        t += step
    return indices


def to_gray(image: np.ndarray) -> np.ndarray:
    """Convierte una imagen BGR (como la entrega OpenCV) a escala de grises."""
    if image.ndim == 2:
        return image.astype(np.float64)
    b, g, r = image[..., 0], image[..., 1], image[..., 2]
    return 0.114 * b + 0.587 * g + 0.299 * r


def sharpness(gray: np.ndarray) -> float:
    """Varianza del laplaciano: valores bajos indican un cuadro movido."""
    g = gray.astype(np.float64)
    if g.shape[0] < 3 or g.shape[1] < 3:
        return 0.0
    lap = (
        g[:-2, 1:-1] + g[2:, 1:-1] + g[1:-1, :-2] + g[1:-1, 2:] - 4.0 * g[1:-1, 1:-1]
    )
    return float(lap.var())


def resized_dims(width: int, height: int, max_side: int = 1280) -> tuple[int, int]:
    """Dimensiones con el lado mayor en ``max_side`` (sin agrandar)."""
    side = max(width, height)
    if side <= max_side:
        return width, height
    scale = max_side / side
    return max(1, round(width * scale)), max(1, round(height * scale))


def slug(text: str) -> str:
    """Nombre de archivo seguro: sin tildes, espacios ni símbolos."""
    plain = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    plain = re.sub(r"[^a-zA-Z0-9]+", "-", plain).strip("-").lower()
    return plain or "video"


def frame_name(place: str, video: str, second: float) -> str:
    """``lugar_video_s00012.jpg``: el lugar ayuda a separar la prueba."""
    return f"{slug(place)}_{slug(video)}_s{int(second):05d}.jpg"
