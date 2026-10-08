"""Métricas de detección y contraste de hipótesis (numerales 2.2.1 y 2.3).

Implementación propia y comprobada con pruebas, para calcular las mismas
métricas sobre el modelo preentrenado y el ajustado con idénticas reglas:

* IoU, precisión, recall y F1 con un umbral de confianza.
* AP@0,5 por clase con interpolación de 101 puntos (criterio COCO, el mismo
  que usa Ultralytics) y mAP@0,5 como su promedio.
* Bootstrap pareado por imágenes para la diferencia de mAP@0,5.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass

Box = tuple[float, float, float, float]  # x1, y1, x2, y2 (normalizadas)


@dataclass(frozen=True)
class GroundTruth:
    image: str
    label: str
    box: Box


@dataclass(frozen=True)
class Prediction:
    image: str
    label: str
    score: float
    box: Box


def iou(a: Box, b: Box) -> float:
    iw = min(a[2], b[2]) - max(a[0], b[0])
    ih = min(a[3], b[3]) - max(a[1], b[1])
    if iw <= 0 or ih <= 0:
        return 0.0
    inter = iw * ih
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0.0


def _match(
    gts: list[GroundTruth], preds: list[Prediction], iou_threshold: float
) -> tuple[list[tuple[float, bool]], int]:
    """Empareja predicciones (de mayor a menor puntaje) con cajas reales de la
    misma imagen; cada caja real se usa una sola vez. Devuelve (puntaje, es_TP)
    y el número de cajas reales."""
    by_image: dict[str, list[GroundTruth]] = {}
    for g in gts:
        by_image.setdefault(g.image, []).append(g)
    used: dict[str, list[bool]] = {k: [False] * len(v) for k, v in by_image.items()}
    results: list[tuple[float, bool]] = []
    for p in sorted(preds, key=lambda x: -x.score):
        candidates = by_image.get(p.image, [])
        best, best_iou = -1, iou_threshold
        for i, g in enumerate(candidates):
            if used[p.image][i]:
                continue
            v = iou(p.box, g.box)
            if v >= best_iou:
                best, best_iou = i, v
        if best >= 0:
            used[p.image][best] = True
            results.append((p.score, True))
        else:
            results.append((p.score, False))
    return results, len(gts)


def average_precision(
    gts: list[GroundTruth], preds: list[Prediction], iou_threshold: float = 0.5
) -> float:
    """AP de una sola clase con interpolación de 101 puntos. NaN si no hay
    cajas reales de la clase."""
    matches, n_gt = _match(gts, preds, iou_threshold)
    if n_gt == 0:
        return math.nan
    if not matches:
        return 0.0
    tp = fp = 0
    precisions: list[float] = []
    recalls: list[float] = []
    for _, is_tp in matches:
        if is_tp:
            tp += 1
        else:
            fp += 1
        precisions.append(tp / (tp + fp))
        recalls.append(tp / n_gt)
    # Envolvente de precisión (monótona decreciente).
    for i in range(len(precisions) - 2, -1, -1):
        precisions[i] = max(precisions[i], precisions[i + 1])
    total = 0.0
    for k in range(101):
        r = k / 100
        p = 0.0
        for rec, prec in zip(recalls, precisions):
            if rec >= r:
                p = prec
                break
        total += p
    return total / 101


def precision_recall_f1(
    gts: list[GroundTruth],
    preds: list[Prediction],
    conf_threshold: float,
    iou_threshold: float = 0.5,
) -> tuple[float, float, float]:
    kept = [p for p in preds if p.score >= conf_threshold]
    matches, n_gt = _match(gts, kept, iou_threshold)
    tp = sum(1 for _, ok in matches if ok)
    fp = len(matches) - tp
    precision = tp / (tp + fp) if tp + fp else 0.0
    recall = tp / n_gt if n_gt else 0.0
    f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
    return precision, recall, f1


def per_class_ap(
    gts: list[GroundTruth], preds: list[Prediction], classes: list[str]
) -> dict[str, float]:
    return {
        c: average_precision(
            [g for g in gts if g.label == c], [p for p in preds if p.label == c]
        )
        for c in classes
    }


def mean_ap(ap: dict[str, float]) -> float:
    values = [v for v in ap.values() if not math.isnan(v)]
    return sum(values) / len(values) if values else math.nan


@dataclass(frozen=True)
class BootstrapResult:
    difference: float
    ci_low: float
    ci_high: float
    p_value: float

    @property
    def rejects_h0(self) -> bool:
        """H0: el modelo ajustado no supera al preentrenado (α = 0,05)."""
        return self.p_value < 0.05


def paired_bootstrap(
    gts: list[GroundTruth],
    preds_base: list[Prediction],
    preds_tuned: list[Prediction],
    classes: list[str],
    iterations: int = 1000,
    seed: int = 7,
) -> BootstrapResult:
    """Diferencia de mAP@0,5 (ajustado − preentrenado) con intervalo de
    confianza del 95 % y valor p unilateral por remuestreo de imágenes."""
    images = sorted({g.image for g in gts} | {p.image for p in preds_base + preds_tuned})
    observed = mean_ap(per_class_ap(gts, preds_tuned, classes)) - mean_ap(
        per_class_ap(gts, preds_base, classes)
    )
    gt_by = _group(gts)
    base_by = _group(preds_base)
    tuned_by = _group(preds_tuned)
    rng = random.Random(seed)
    diffs: list[float] = []
    for _ in range(iterations):
        sample = [rng.choice(images) for _ in images]
        g_s: list[GroundTruth] = []
        b_s: list[Prediction] = []
        t_s: list[Prediction] = []
        for n, img in enumerate(sample):
            key = f"{img}#{n}"
            g_s += [GroundTruth(key, g.label, g.box) for g in gt_by.get(img, [])]
            b_s += [Prediction(key, p.label, p.score, p.box) for p in base_by.get(img, [])]
            t_s += [Prediction(key, p.label, p.score, p.box) for p in tuned_by.get(img, [])]
        d = mean_ap(per_class_ap(g_s, t_s, classes)) - mean_ap(per_class_ap(g_s, b_s, classes))
        if not math.isnan(d):
            diffs.append(d)
    diffs.sort()
    if not diffs:
        return BootstrapResult(observed, math.nan, math.nan, math.nan)
    low = diffs[int(0.025 * (len(diffs) - 1))]
    high = diffs[int(0.975 * (len(diffs) - 1))]
    p_value = sum(1 for d in diffs if d <= 0) / len(diffs)
    return BootstrapResult(observed, low, high, p_value)


def _group(items):
    out: dict[str, list] = {}
    for item in items:
        out.setdefault(item.image, []).append(item)
    return out
