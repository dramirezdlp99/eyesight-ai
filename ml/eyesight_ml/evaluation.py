"""Evaluación completa del modelo en dos niveles (numeral 4.4.2).

El modelo es de **detección de objetos**: clasifica (qué obstáculo es) y
localiza (dónde está, con una caja). Por eso se evalúa en dos niveles:

1. **Objeto (detección).** Cada caja cuenta. Una predicción es acierto (TP)
   si su caja se superpone a una caja real de la misma clase con IoU ≥ 0,5.
   Aquí no existen los verdaderos negativos (habría infinitos «no
   obstáculos» en cada imagen), así que se usan la matriz de confusión con
   la clase «fondo», precisión, recall, F1, AP/mAP y el IoU medio.
2. **Imagen (clasificación).** Para cada clase: «¿la imagen contiene un
   poste?». Ahí sí hay TP, TN, FP y FN, y se pueden calcular exactitud
   (accuracy), precisión, recall, F1, especificidad y AUC-ROC.

Además, la F1 según el umbral de confianza justifica el umbral que usa la
aplicación (equilibrio entre precisión y recall).
"""

from __future__ import annotations

from dataclasses import dataclass

from .metrics import GroundTruth, Prediction, iou, precision_recall_f1

BACKGROUND = "fondo"


# --------------------------------------------------------- Nivel objeto


def confusion_matrix(
    gts: list[GroundTruth],
    preds: list[Prediction],
    classes: list[str],
    conf_threshold: float,
    iou_threshold: float = 0.5,
) -> dict[str, dict[str, int]]:
    """Matriz real × predicho con la fila y la columna «fondo».

    En cada imagen, las predicciones (de mayor a menor confianza) se emparejan
    con la caja real de mayor IoU, sin importar la clase, para ver también
    las confusiones entre clases (por ejemplo poste ↔ bolardo).

    * ``m[real][predicho]``: caja real emparejada.
    * ``m[real]["fondo"]``: caja real sin detectar (falso negativo).
    * ``m["fondo"][predicho]``: detección sin caja real (falso positivo).
    """
    labels = [*classes, BACKGROUND]
    m = {r: {c: 0 for c in labels} for r in labels}
    by_image_gt: dict[str, list[GroundTruth]] = {}
    for g in gts:
        if g.label in classes:
            by_image_gt.setdefault(g.image, []).append(g)
    by_image_pred: dict[str, list[Prediction]] = {}
    for p in preds:
        if p.label in classes and p.score >= conf_threshold:
            by_image_pred.setdefault(p.image, []).append(p)
    for image in set(by_image_gt) | set(by_image_pred):
        truths = by_image_gt.get(image, [])
        used = [False] * len(truths)
        for p in sorted(by_image_pred.get(image, []), key=lambda x: -x.score):
            best, best_iou = -1, iou_threshold
            for i, g in enumerate(truths):
                if used[i]:
                    continue
                v = iou(p.box, g.box)
                if v >= best_iou:
                    best, best_iou = i, v
            if best >= 0:
                used[best] = True
                m[truths[best].label][p.label] += 1
            else:
                m[BACKGROUND][p.label] += 1
        for i, g in enumerate(truths):
            if not used[i]:
                m[g.label][BACKGROUND] += 1
    return m


def mean_iou(
    gts: list[GroundTruth],
    preds: list[Prediction],
    conf_threshold: float,
    iou_threshold: float = 0.5,
) -> float:
    """IoU medio de los aciertos: calidad de la localización (la parte de
    regresión del modelo). NaN si no hay aciertos."""
    values: list[float] = []
    by_image: dict[str, list[GroundTruth]] = {}
    for g in gts:
        by_image.setdefault(g.image, []).append(g)
    used = {k: [False] * len(v) for k, v in by_image.items()}
    for p in sorted((p for p in preds if p.score >= conf_threshold), key=lambda x: -x.score):
        truths = by_image.get(p.image, [])
        best, best_iou = -1, iou_threshold
        for i, g in enumerate(truths):
            if used[p.image][i] or g.label != p.label:
                continue
            v = iou(p.box, g.box)
            if v >= best_iou:
                best, best_iou = i, v
        if best >= 0:
            used[p.image][best] = True
            values.append(best_iou)
    return sum(values) / len(values) if values else float("nan")


@dataclass(frozen=True)
class ThresholdPoint:
    threshold: float
    precision: float
    recall: float
    f1: float


def f1_by_threshold(
    gts: list[GroundTruth],
    preds: list[Prediction],
    thresholds: list[float] | None = None,
) -> list[ThresholdPoint]:
    """Precisión, recall y F1 (todas las clases juntas) para cada umbral."""
    ts = thresholds or [round(0.05 * k, 2) for k in range(2, 19)]  # 0,10 … 0,90
    points = []
    for t in ts:
        p, r, f1 = precision_recall_f1(gts, preds, t)
        points.append(ThresholdPoint(t, p, r, f1))
    return points


def best_threshold(points: list[ThresholdPoint], low: float = 0.30, high: float = 0.90) -> ThresholdPoint:
    """Umbral con mayor F1 dentro del rango que admite la aplicación (HU13);
    ante un empate, el menor (favorece el recall: un obstáculo sin avisar es
    el error más peligroso)."""
    allowed = [p for p in points if low <= p.threshold <= high] or points
    return max(allowed, key=lambda p: (round(p.f1, 9), -p.threshold))


# --------------------------------------------------------- Nivel imagen


@dataclass(frozen=True)
class BinaryMetrics:
    tp: int
    tn: int
    fp: int
    fn: int
    auc: float

    @property
    def total(self) -> int:
        return self.tp + self.tn + self.fp + self.fn

    @property
    def accuracy(self) -> float:
        return (self.tp + self.tn) / self.total if self.total else float("nan")

    @property
    def precision(self) -> float:
        return self.tp / (self.tp + self.fp) if self.tp + self.fp else 0.0

    @property
    def recall(self) -> float:
        return self.tp / (self.tp + self.fn) if self.tp + self.fn else 0.0

    @property
    def specificity(self) -> float:
        return self.tn / (self.tn + self.fp) if self.tn + self.fp else 0.0

    @property
    def f1(self) -> float:
        p, r = self.precision, self.recall
        return 2 * p * r / (p + r) if p + r else 0.0


def image_scores(
    images: list[str],
    gts: list[GroundTruth],
    preds: list[Prediction],
    label: str,
) -> tuple[list[int], list[float]]:
    """Para cada imagen: 1 si contiene la clase y la mayor confianza con la
    que el modelo la predijo (0 si no la predijo)."""
    present = {g.image for g in gts if g.label == label}
    best: dict[str, float] = {}
    for p in preds:
        if p.label == label and p.score > best.get(p.image, 0.0):
            best[p.image] = p.score
    return [1 if img in present else 0 for img in images], [best.get(img, 0.0) for img in images]


def auc_roc(y_true: list[int], scores: list[float]) -> float:
    """Área bajo la curva ROC por la estadística de Mann-Whitney (los empates
    cuentan medio). NaN si falta alguna de las dos clases."""
    pos = [s for y, s in zip(y_true, scores) if y == 1]
    neg = [s for y, s in zip(y_true, scores) if y == 0]
    if not pos or not neg:
        return float("nan")
    order = sorted(scores)
    rank_of: dict[float, float] = {}
    i = 0
    while i < len(order):
        j = i
        while j < len(order) and order[j] == order[i]:
            j += 1
        rank_of[order[i]] = (i + 1 + j) / 2  # rango medio de los empates
        i = j
    rank_sum = sum(rank_of[s] for s in pos)
    u = rank_sum - len(pos) * (len(pos) + 1) / 2
    return u / (len(pos) * len(neg))


def roc_curve(y_true: list[int], scores: list[float]) -> list[tuple[float, float]]:
    """Puntos (tasa de falsos positivos, tasa de verdaderos positivos) de la
    curva ROC, desde (0, 0) hasta (1, 1)."""
    pos = sum(y_true)
    neg = len(y_true) - pos
    if pos == 0 or neg == 0:
        return [(0.0, 0.0), (1.0, 1.0)]
    points = [(0.0, 0.0)]
    for t in sorted(set(scores), reverse=True):
        tp = sum(1 for y, s in zip(y_true, scores) if y == 1 and s >= t)
        fp = sum(1 for y, s in zip(y_true, scores) if y == 0 and s >= t)
        points.append((fp / neg, tp / pos))
    if points[-1] != (1.0, 1.0):
        points.append((1.0, 1.0))
    return points


def image_level(
    images: list[str],
    gts: list[GroundTruth],
    preds: list[Prediction],
    label: str,
    conf_threshold: float,
) -> BinaryMetrics:
    y, s = image_scores(images, gts, preds, label)
    tp = sum(1 for t, v in zip(y, s) if t == 1 and v >= conf_threshold)
    fn = sum(1 for t, v in zip(y, s) if t == 1 and v < conf_threshold)
    fp = sum(1 for t, v in zip(y, s) if t == 0 and v >= conf_threshold)
    tn = sum(1 for t, v in zip(y, s) if t == 0 and v < conf_threshold)
    return BinaryMetrics(tp, tn, fp, fn, auc_roc(y, s))


def macro(values: list[float]) -> float:
    """Promedio ignorando NaN."""
    clean = [v for v in values if v == v]
    return sum(clean) / len(clean) if clean else float("nan")
