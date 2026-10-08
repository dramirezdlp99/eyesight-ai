import math

from eyesight_ml.metrics import (
    GroundTruth,
    Prediction,
    average_precision,
    iou,
    mean_ap,
    paired_bootstrap,
    per_class_ap,
    precision_recall_f1,
)

BOX = (0.1, 0.1, 0.3, 0.3)
OTHER = (0.6, 0.6, 0.8, 0.8)


def test_iou():
    assert iou(BOX, BOX) == 1.0
    assert iou(BOX, OTHER) == 0.0
    assert math.isclose(iou((0, 0, 1, 1), (0.5, 0, 1.5, 1)), 1 / 3)


def test_ap_perfecto_y_sin_predicciones():
    gts = [GroundTruth("a", "pole", BOX), GroundTruth("b", "pole", OTHER)]
    preds = [Prediction("a", "pole", 0.9, BOX), Prediction("b", "pole", 0.8, OTHER)]
    assert math.isclose(average_precision(gts, preds), 1.0)
    assert average_precision(gts, []) == 0.0
    assert math.isnan(average_precision([], preds))


def test_ap_con_falso_positivo_de_mayor_puntaje():
    gts = [GroundTruth("a", "pole", BOX)]
    preds = [Prediction("a", "pole", 0.9, OTHER), Prediction("a", "pole", 0.5, BOX)]
    # Precisión 0,5 a recall 1: AP = 0,5 en los 101 puntos.
    assert math.isclose(average_precision(gts, preds), 0.5)


def test_ap_con_recall_parcial():
    gts = [GroundTruth("a", "pole", BOX), GroundTruth("b", "pole", OTHER)]
    preds = [Prediction("a", "pole", 0.9, BOX)]
    # Precisión 1 hasta recall 0,5: 51 de los 101 puntos.
    assert math.isclose(average_precision(gts, preds), 51 / 101)


def test_una_caja_real_no_cuenta_dos_veces():
    gts = [GroundTruth("a", "pole", BOX)]
    preds = [Prediction("a", "pole", 0.9, BOX), Prediction("a", "pole", 0.8, BOX)]
    p, r, f1 = precision_recall_f1(gts, preds, conf_threshold=0.5)
    assert (p, r) == (0.5, 1.0)
    assert math.isclose(f1, 2 / 3)


def test_umbral_de_confianza():
    gts = [GroundTruth("a", "pole", BOX)]
    preds = [Prediction("a", "pole", 0.3, BOX)]
    assert precision_recall_f1(gts, preds, conf_threshold=0.5) == (0.0, 0.0, 0.0)


def test_map_ignora_clases_sin_cajas_reales():
    gts = [GroundTruth("a", "pole", BOX)]
    preds = [Prediction("a", "pole", 0.9, BOX)]
    ap = per_class_ap(gts, preds, ["pole", "car"])
    assert math.isnan(ap["car"])
    assert mean_ap(ap) == 1.0


def test_bootstrap_detecta_un_modelo_claramente_mejor():
    gts, base, tuned = [], [], []
    for i in range(30):
        img = f"img{i}"
        gts.append(GroundTruth(img, "person", BOX))
        tuned.append(Prediction(img, "person", 0.9, BOX))
        base.append(Prediction(img, "person", 0.9, OTHER if i % 2 else BOX))
    result = paired_bootstrap(gts, base, tuned, ["person"], iterations=200)
    assert result.difference > 0.3
    assert result.ci_low > 0
    assert result.p_value < 0.05
    assert result.rejects_h0


def test_bootstrap_no_rechaza_con_modelos_iguales():
    gts = [GroundTruth(f"i{i}", "car", BOX) for i in range(20)]
    preds = [Prediction(f"i{i}", "car", 0.9, BOX) for i in range(20)]
    result = paired_bootstrap(gts, preds, preds, ["car"], iterations=100)
    assert result.difference == 0
    assert not result.rejects_h0
