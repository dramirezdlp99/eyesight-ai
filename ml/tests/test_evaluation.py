import math
import random

from eyesight_ml.evaluation import (
    BACKGROUND,
    BinaryMetrics,
    auc_roc,
    best_threshold,
    confusion_matrix,
    f1_by_threshold,
    image_level,
    macro,
    mean_iou,
    roc_curve,
)
from eyesight_ml.metrics import GroundTruth, Prediction

BOX = (0.1, 0.1, 0.5, 0.5)
SHIFTED = (0.15, 0.1, 0.55, 0.5)  # IoU ≈ 0,78 con BOX
FAR = (0.6, 0.6, 0.9, 0.9)


def test_matriz_de_confusion_con_fondo():
    gts = [
        GroundTruth("a", "pole", BOX),
        GroundTruth("b", "bollard", BOX),
        GroundTruth("c", "pothole", BOX),
    ]
    preds = [
        Prediction("a", "pole", 0.9, SHIFTED),  # acierto
        Prediction("b", "pole", 0.8, BOX),  # confunde bolardo con poste
        Prediction("a", "step", 0.7, FAR),  # falso positivo
        Prediction("c", "pothole", 0.2, BOX),  # bajo el umbral: no cuenta
    ]
    m = confusion_matrix(gts, preds, ["pole", "bollard", "step", "pothole"], 0.5)
    assert m["pole"]["pole"] == 1
    assert m["bollard"]["pole"] == 1
    assert m[BACKGROUND]["step"] == 1
    assert m["pothole"][BACKGROUND] == 1
    total = sum(sum(row.values()) for row in m.values())
    assert total == 4


def test_iou_medio_de_los_aciertos():
    gts = [GroundTruth("a", "pole", BOX)]
    preds = [Prediction("a", "pole", 0.9, SHIFTED)]
    assert math.isclose(mean_iou(gts, preds, 0.5), 0.14 / 0.18, rel_tol=1e-9)
    assert math.isnan(mean_iou(gts, [], 0.5))


def test_auc_coincide_con_el_conteo_de_pares():
    rng = random.Random(3)
    y = [rng.randint(0, 1) for _ in range(60)]
    s = [round(rng.random(), 1) for _ in range(60)]  # con empates
    pos = [v for t, v in zip(y, s) if t]
    neg = [v for t, v in zip(y, s) if not t]
    pairs = sum(1.0 if p > n else 0.5 if p == n else 0.0 for p in pos for n in neg)
    assert math.isclose(auc_roc(y, s), pairs / (len(pos) * len(neg)), rel_tol=1e-12)


def test_auc_casos_extremos():
    assert auc_roc([1, 1, 0, 0], [0.9, 0.8, 0.2, 0.1]) == 1.0
    assert auc_roc([1, 1, 0, 0], [0.1, 0.2, 0.8, 0.9]) == 0.0
    assert math.isnan(auc_roc([1, 1], [0.5, 0.6]))


def test_curva_roc_de_0_a_1():
    pts = roc_curve([1, 0, 1, 0], [0.9, 0.8, 0.7, 0.1])
    assert pts[0] == (0.0, 0.0)
    assert pts[-1] == (1.0, 1.0)
    assert all(a[0] <= b[0] and a[1] <= b[1] for a, b in zip(pts, pts[1:]))


def test_nivel_imagen_con_verdaderos_negativos():
    images = ["a", "b", "c", "d"]
    gts = [GroundTruth("a", "pole", BOX), GroundTruth("b", "pole", BOX)]
    preds = [
        Prediction("a", "pole", 0.9, BOX),
        Prediction("c", "pole", 0.7, BOX),
        Prediction("b", "pole", 0.3, BOX),
    ]
    m = image_level(images, gts, preds, "pole", 0.5)
    assert (m.tp, m.tn, m.fp, m.fn) == (1, 1, 1, 1)
    assert m.accuracy == 0.5
    assert m.precision == 0.5
    assert m.recall == 0.5
    assert m.specificity == 0.5
    assert m.f1 == 0.5
    assert 0 <= m.auc <= 1


def test_metricas_binarias_sin_casos():
    m = BinaryMetrics(0, 0, 0, 0, float("nan"))
    assert math.isnan(m.accuracy)
    assert m.precision == 0.0 and m.recall == 0.0 and m.f1 == 0.0


def test_f1_por_umbral_y_mejor_umbral():
    gts = [GroundTruth(str(i), "pole", BOX) for i in range(10)]
    preds = [Prediction(str(i), "pole", 0.35 + 0.05 * i, BOX) for i in range(10)]
    preds += [Prediction("x", "pole", 0.4, BOX)]  # falso positivo de baja confianza
    points = f1_by_threshold(gts, preds)
    assert points[0].threshold == 0.1 and points[-1].threshold == 0.9
    best = best_threshold(points)
    assert 0.30 <= best.threshold <= 0.90
    assert best.f1 == max(p.f1 for p in points if 0.30 <= p.threshold <= 0.90)


def test_promedio_ignora_nan():
    assert macro([0.5, float("nan"), 1.0]) == 0.75
    assert math.isnan(macro([float("nan")]))
