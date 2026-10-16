import numpy as np
import pytest

from eyesight_ml.frames import (
    frame_indices,
    frame_name,
    resized_dims,
    sharpness,
    slug,
    to_gray,
)


def test_un_cuadro_por_segundo():
    assert frame_indices(30, 95) == [0, 30, 60, 90]


def test_respeta_fps_fraccionarios_sin_repetir():
    idx = frame_indices(29.97, 300, 1.0)
    assert idx[:3] == [0, 30, 60]
    assert len(idx) == len(set(idx))
    assert all(i < 300 for i in idx)


def test_cada_medio_segundo():
    assert frame_indices(10, 25, 0.5) == [0, 5, 10, 15, 20]


def test_video_vacio_o_invalido():
    assert frame_indices(0, 100) == []
    assert frame_indices(30, 0) == []
    with pytest.raises(ValueError):
        frame_indices(30, 100, 0)


def test_un_cuadro_movido_tiene_menos_nitidez():
    rng = np.random.default_rng(7)
    sharp = rng.integers(0, 255, size=(64, 64)).astype(np.float64)
    # Desenfoque: promedio de vecinos repetido.
    blurred = sharp.copy()
    for _ in range(4):
        blurred[1:-1, 1:-1] = (
            blurred[:-2, 1:-1] + blurred[2:, 1:-1] + blurred[1:-1, :-2] + blurred[1:-1, 2:]
        ) / 4
    assert sharpness(sharp) > 5 * sharpness(blurred)


def test_una_imagen_plana_no_tiene_bordes():
    assert sharpness(np.full((10, 10), 128.0)) == 0.0
    assert sharpness(np.zeros((2, 2))) == 0.0


def test_gris_desde_bgr():
    image = np.zeros((2, 2, 3), dtype=np.uint8)
    image[..., 2] = 255  # rojo en BGR
    assert to_gray(image)[0, 0] == pytest.approx(0.299 * 255)


def test_reduce_sin_agrandar():
    assert resized_dims(1920, 1080) == (1280, 720)
    assert resized_dims(1080, 1920) == (720, 1280)
    assert resized_dims(640, 480) == (640, 480)


def test_nombres_de_archivo_seguros():
    assert slug("Calle 18 – Parque Nariño") == "calle-18-parque-narino"
    assert slug("***") == "video"
    assert frame_name("Centro", "VID 001", 12.7) == "centro_vid-001_s00012.jpg"
