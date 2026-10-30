"""Caso de prueba CP-01: compara el modelo preentrenado y el ajustado sobre el
mismo conjunto de prueba (hipótesis del numeral 2.3, resultados del 4.4.2).

Calcula todas las métricas del informe, en dos niveles:

* Objeto: matriz de confusión con «fondo», precisión, recall, F1, AP@0,5,
  AP@0,5:0,95 e IoU medio.
* Imagen: exactitud, precisión, recall, F1, especificidad y AUC-ROC por clase.

Y la F1 según el umbral de confianza, para justificar el umbral de la app.
Guarda tablas (Markdown y CSV), un JSON y gráficas PNG en --out.

Uso (conjunto de prueba de Pasto, el que va al informe):
    python scripts/evaluate.py --test-dir datasets/raw/eyesight-pasto-prueba \
        --tuned runs/eyesight/yolov8n_ajustado/weights/best.pt --out results/pasto

Uso (partición de prueba del conjunto unido):
    python scripts/evaluate.py --data datasets/eyesight/eyesight.yaml \
        --tuned runs/eyesight/yolov8n_ajustado/weights/best.pt --out results/publico
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import yaml  # noqa: E402

from eyesight_ml.classes import COCO_IDS, COMMON_CLASSES, EYESIGHT_CLASSES, NEW_CLASSES  # noqa: E402
from eyesight_ml.dataset import build_mapping, read_source_names  # noqa: E402
from eyesight_ml.evaluation import (  # noqa: E402
    best_threshold,
    confusion_matrix,
    f1_by_threshold,
    image_level,
    image_scores,
    macro,
    mean_iou,
    roc_curve,
)
from eyesight_ml.metrics import (  # noqa: E402
    GroundTruth,
    Prediction,
    average_precision,
    mean_ap,
    paired_bootstrap,
    per_class_ap,
    precision_recall_f1,
)

COCO_TO_NAME = {v: k for k, v in COCO_IDS.items()}


def load_ground_truth(
    test_images: Path, mapping: dict[int, int] | None = None
) -> tuple[list[Path], list[GroundTruth]]:
    """Imágenes y cajas reales. [mapping] traduce los índices de una
    exportación de Roboflow (que ordena las clases a su manera) a los de
    EyeSight AI; sin él se asumen los mismos índices."""
    labels_dir = test_images.parent / "labels"
    images = sorted(p for p in test_images.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png"})
    gts: list[GroundTruth] = []
    for img in images:
        label = labels_dir / f"{img.stem}.txt"
        if not label.exists():
            continue
        for line in label.read_text(encoding="utf-8").splitlines():
            parts = line.split()
            if len(parts) != 5:
                continue
            c, x, y, w, h = int(parts[0]), *map(float, parts[1:])
            if mapping is not None:
                if c not in mapping:
                    continue
                c = mapping[c]
            gts.append(GroundTruth(img.name, EYESIGHT_CLASSES[c], (x - w / 2, y - h / 2, x + w / 2, y + h / 2)))
    return images, gts


def predict(model_path: str, images: list[Path], imgsz: int, coco: bool) -> list[Prediction]:
    from ultralytics import YOLO

    model = YOLO(model_path)
    preds: list[Prediction] = []
    for img in images:
        result = model.predict(str(img), imgsz=imgsz, conf=0.001, verbose=False)[0]
        for box, cls, score in zip(
            result.boxes.xyxyn.tolist(), result.boxes.cls.tolist(), result.boxes.conf.tolist()
        ):
            idx = int(cls)
            name = COCO_TO_NAME.get(idx) if coco else EYESIGHT_CLASSES[idx]
            if name is None:
                continue
            preds.append(Prediction(img.name, name, float(score), tuple(box)))
    return preds


def table(gts, preds, classes, conf) -> list[dict]:
    ap = per_class_ap(gts, preds, classes)
    rows = []
    for c in classes:
        g_c = [g for g in gts if g.label == c]
        p_c = [x for x in preds if x.label == c]
        p, r, f1 = precision_recall_f1(g_c, p_c, conf)
        ap_range = [average_precision(g_c, p_c, t / 100) for t in range(50, 100, 5)]
        rows.append(
            {
                "clase": c,
                "precision": p,
                "recall": r,
                "f1": f1,
                "ap50": ap[c],
                "ap50_95": macro(ap_range),
                "iou_medio": mean_iou(g_c, p_c, conf),
            }
        )
    return rows


def image_table(images, gts, preds, classes, conf) -> list[dict]:
    rows = []
    for c in classes:
        m = image_level(images, gts, preds, c, conf)
        rows.append(
            {
                "clase": c,
                "tp": m.tp,
                "tn": m.tn,
                "fp": m.fp,
                "fn": m.fn,
                "exactitud": m.accuracy,
                "precision": m.precision,
                "recall": m.recall,
                "f1": m.f1,
                "especificidad": m.specificity,
                "auc_roc": m.auc,
            }
        )
    return rows


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    keys = list(rows[0].keys())
    lines = [",".join(keys)]
    for r in rows:
        lines.append(",".join("" if r[k] is None else str(r[k]) for k in keys))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_matrix(path: Path, m: dict[str, dict[str, int]]) -> None:
    labels = list(m.keys())
    lines = ["real \\ predicho," + ",".join(labels)]
    for r in labels:
        lines.append(r + "," + ",".join(str(m[r][c]) for c in labels))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def plots(out: Path, name: str, matrix, roc_data, thresholds) -> None:
    """Gráficas para el informe; se omiten si no está matplotlib."""
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib no está instalado: se omiten las gráficas")
        return
    labels = list(matrix.keys())
    values = [[matrix[r][c] for c in labels] for r in labels]
    fig, ax = plt.subplots(figsize=(8, 7))
    ax.imshow(values, cmap="Blues")
    ax.set_xticks(range(len(labels)), labels, rotation=45, ha="right")
    ax.set_yticks(range(len(labels)), labels)
    for i, row in enumerate(values):
        for j, v in enumerate(row):
            if v:
                ax.text(j, i, str(v), ha="center", va="center", fontsize=8)
    ax.set_xlabel("Predicho")
    ax.set_ylabel("Real")
    ax.set_title(f"Matriz de confusión ({name}, nivel objeto)")
    fig.tight_layout()
    fig.savefig(out / f"matriz_confusion_{name}.png", dpi=160)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(6, 6))
    for label, (pts, auc) in roc_data.items():
        if auc == auc:  # sin NaN
            ax.plot([p[0] for p in pts], [p[1] for p in pts], label=f"{label} (AUC {auc:.2f})")
    ax.plot([0, 1], [0, 1], linestyle="--", color="gray")
    ax.set_xlabel("Tasa de falsos positivos")
    ax.set_ylabel("Tasa de verdaderos positivos (recall)")
    ax.set_title(f"Curvas ROC por clase ({name}, nivel imagen)")
    ax.legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(out / f"roc_{name}.png", dpi=160)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7, 4))
    xs = [p.threshold for p in thresholds]
    ax.plot(xs, [p.precision for p in thresholds], label="Precisión")
    ax.plot(xs, [p.recall for p in thresholds], label="Recall")
    ax.plot(xs, [p.f1 for p in thresholds], label="F1", linewidth=2.5)
    ax.set_xlabel("Umbral de confianza")
    ax.set_ylim(0, 1)
    ax.set_title(f"Precisión, recall y F1 según el umbral ({name})")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out / f"f1_umbral_{name}.png", dpi=160)
    plt.close(fig)


def full_report(out: Path, name: str, images, gts, preds, classes, conf) -> dict:
    """Todas las métricas de un modelo; guarda sus tablas y gráficas."""
    names = [p.name for p in images]
    obj = table(gts, preds, classes, conf)
    img = image_table(names, gts, preds, classes, conf)
    matrix = confusion_matrix(gts, preds, classes, conf)
    thresholds = f1_by_threshold(gts, [p for p in preds if p.label in classes])
    best = best_threshold(thresholds)
    roc_data = {}
    for c in classes:
        y, s = image_scores(names, gts, preds, c)
        roc_data[c] = (roc_curve(y, s), next(r["auc_roc"] for r in img if r["clase"] == c))
    write_csv(out / f"objeto_{name}.csv", obj)
    write_csv(out / f"imagen_{name}.csv", img)
    write_matrix(out / f"matriz_confusion_{name}.csv", matrix)
    write_csv(
        out / f"f1_umbral_{name}.csv",
        [{"umbral": p.threshold, "precision": p.precision, "recall": p.recall, "f1": p.f1} for p in thresholds],
    )
    plots(out, name, matrix, roc_data, thresholds)
    return {
        "objeto": obj,
        "imagen": img,
        "matriz_confusion": matrix,
        "mejor_umbral": {"umbral": best.threshold, "precision": best.precision, "recall": best.recall, "f1": best.f1},
        "macro_imagen": {
            k: macro([r[k] for r in img]) for k in ("exactitud", "precision", "recall", "f1", "especificidad", "auc_roc")
        },
        "macro_objeto": {k: macro([r[k] for r in obj]) for k in ("precision", "recall", "f1", "ap50", "ap50_95", "iou_medio")},
    }


def fmt(v: float) -> str:
    return "—" if v is None or (isinstance(v, float) and math.isnan(v)) else f"{v:.3f}".replace(".", ",")



def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, help="eyesight.yaml del conjunto unido (usa su partición test)")
    parser.add_argument(
        "--test-dir",
        type=Path,
        help="exportación YOLOv8 de Roboflow del conjunto de prueba de Pasto (se usan todas sus particiones)",
    )
    parser.add_argument("--base", default="yolov8n.pt", help="modelo preentrenado COCO")
    parser.add_argument("--tuned", required=True, help="best.pt o el .tflite exportado")
    parser.add_argument("--imgsz", type=int, default=320)
    parser.add_argument("--conf", type=float, default=0.5, help="umbral de la aplicación")
    parser.add_argument("--bootstrap", type=int, default=1000)
    parser.add_argument("--out", type=Path, default=Path("results"))
    args = parser.parse_args()

    if args.test_dir is not None:
        mapping = build_mapping(read_source_names(args.test_dir / "data.yaml"))
        # Todo el proyecto de prueba es el examen: se leen todas sus
        # particiones, porque Roboflow puede marcarlas como train o valid.
        images, gts = [], []
        for split in ("train", "valid", "val", "test"):
            folder = args.test_dir / split / "images"
            if folder.is_dir():
                split_images, split_gts = load_ground_truth(folder, mapping)
                images += split_images
                gts += split_gts
        if not images:
            raise SystemExit(f"No encontré imágenes en {args.test_dir}")
    elif args.data is not None:
        data = yaml.safe_load(args.data.read_text(encoding="utf-8"))
        images, gts = load_ground_truth(Path(data["path"]) / data["test"])
        if not images:
            raise SystemExit("La partición de prueba del conjunto unido está vacía")
    else:
        raise SystemExit("Indique --test-dir (prueba de Pasto) o --data (conjunto unido)")
    print(f"Imágenes de prueba: {len(images)}; cajas reales: {len(gts)}")

    base = predict(args.base, images, args.imgsz, coco=True)
    tuned = predict(args.tuned, images, args.imgsz, coco=False)

    common_gts = [g for g in gts if g.label in COMMON_CLASSES]
    base_rows = table(common_gts, base, COMMON_CLASSES, args.conf)
    tuned_rows = table(gts, tuned, EYESIGHT_CLASSES, args.conf)
    boot = paired_bootstrap(
        common_gts,
        base,
        [p for p in tuned if p.label in COMMON_CLASSES],
        COMMON_CLASSES,
        iterations=args.bootstrap,
    )

    args.out.mkdir(parents=True, exist_ok=True)
    report_base = full_report(args.out, "preentrenado", images, common_gts, base, COMMON_CLASSES, args.conf)
    report_tuned = full_report(args.out, "ajustado", images, gts, tuned, EYESIGHT_CLASSES, args.conf)

    summary = {
        "imagenes": len(images),
        "map50_comunes_preentrenado": mean_ap({r["clase"]: r["ap50"] for r in base_rows}),
        "map50_comunes_ajustado": mean_ap(
            {r["clase"]: r["ap50"] for r in tuned_rows if r["clase"] in COMMON_CLASSES}
        ),
        "map50_nuevas_ajustado": mean_ap(
            {r["clase"]: r["ap50"] for r in tuned_rows if r["clase"] in NEW_CLASSES}
        ),
        "diferencia": boot.difference,
        "ic95": [boot.ci_low, boot.ci_high],
        "p_valor": boot.p_value,
        "rechaza_h0": boot.rejects_h0,
        "umbral_recomendado": report_tuned["mejor_umbral"],
    }
    (args.out / "cp01_resultados.json").write_text(
        json.dumps(
            {"resumen": summary, "preentrenado": report_base, "ajustado": report_tuned},
            indent=2,
            ensure_ascii=False,
            default=float,
        ),
        encoding="utf-8",
    )

    lines = [
        "## Nivel objeto (detección)",
        "",
        "| Modelo | Clase | Precisión | Recall | F1 | AP@0,5 | AP@0,5:0,95 | IoU medio |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for label, rep in (("Preentrenado", report_base), ("Ajustado", report_tuned)):
        for r in rep["objeto"]:
            lines.append(
                f"| {label} | {r['clase']} | {fmt(r['precision'])} | {fmt(r['recall'])} | {fmt(r['f1'])} "
                f"| {fmt(r['ap50'])} | {fmt(r['ap50_95'])} | {fmt(r['iou_medio'])} |"
            )
    lines += [
        "",
        "## Nivel imagen (clasificación: ¿la imagen contiene la clase?)",
        "",
        "| Modelo | Clase | TP | TN | FP | FN | Exactitud | Precisión | Recall | F1 | Especificidad | AUC-ROC |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for label, rep in (("Preentrenado", report_base), ("Ajustado", report_tuned)):
        for r in rep["imagen"]:
            lines.append(
                f"| {label} | {r['clase']} | {r['tp']} | {r['tn']} | {r['fp']} | {r['fn']} | {fmt(r['exactitud'])} "
                f"| {fmt(r['precision'])} | {fmt(r['recall'])} | {fmt(r['f1'])} | {fmt(r['especificidad'])} | {fmt(r['auc_roc'])} |"
            )
    best = report_tuned["mejor_umbral"]
    lines += [
        "",
        f"Umbral con mayor F1 (modelo ajustado, entre 0,30 y 0,90): {fmt(best['umbral'])} "
        f"(precisión {fmt(best['precision'])}, recall {fmt(best['recall'])}, F1 {fmt(best['f1'])})",
        "",
        "## Hipótesis (numeral 2.3)",
        "",
        "",
        f"Diferencia de mAP@0,5 en clases comunes (ajustado − preentrenado): {fmt(boot.difference)}",
        f"IC 95 %: [{fmt(boot.ci_low)}; {fmt(boot.ci_high)}], valor p unilateral: {fmt(boot.p_value)}",
        "Decisión: " + ("se rechaza H0" if boot.rejects_h0 else "no se rechaza H0"),
    ]
    (args.out / "cp01_tabla.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
