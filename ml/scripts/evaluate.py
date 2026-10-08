"""Caso de prueba CP-01: compara el modelo preentrenado y el ajustado sobre el
mismo conjunto de prueba (hipótesis del numeral 2.3, resultados del 4.4.2).

Uso:
    python scripts/evaluate.py --data datasets/eyesight/eyesight.yaml \
        --tuned runs/eyesight/yolov8n_ajustado/weights/best.pt --out results
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
from eyesight_ml.metrics import (  # noqa: E402
    GroundTruth,
    Prediction,
    mean_ap,
    paired_bootstrap,
    per_class_ap,
    precision_recall_f1,
)

COCO_TO_NAME = {v: k for k, v in COCO_IDS.items()}


def load_ground_truth(test_images: Path) -> tuple[list[Path], list[GroundTruth]]:
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
        p, r, f1 = precision_recall_f1(
            [g for g in gts if g.label == c], [x for x in preds if x.label == c], conf
        )
        rows.append({"clase": c, "precision": p, "recall": r, "f1": f1, "ap50": ap[c]})
    return rows


def fmt(v: float) -> str:
    return "—" if v is None or (isinstance(v, float) and math.isnan(v)) else f"{v:.3f}".replace(".", ",")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--base", default="yolov8n.pt", help="modelo preentrenado COCO")
    parser.add_argument("--tuned", required=True, help="best.pt o el .tflite exportado")
    parser.add_argument("--imgsz", type=int, default=320)
    parser.add_argument("--conf", type=float, default=0.5, help="umbral de la aplicación")
    parser.add_argument("--bootstrap", type=int, default=1000)
    parser.add_argument("--out", type=Path, default=Path("results"))
    args = parser.parse_args()

    data = yaml.safe_load(args.data.read_text(encoding="utf-8"))
    test_images = Path(data["path"]) / data["test"]
    images, gts = load_ground_truth(test_images)
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
    }
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "cp01_resultados.json").write_text(
        json.dumps({"resumen": summary, "preentrenado": base_rows, "ajustado": tuned_rows}, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    lines = ["| Modelo | Clase | Precisión | Recall | F1 | mAP@0,5 |", "|---|---|---|---|---|---|"]
    for label, rows in (("Preentrenado", base_rows), ("Ajustado", tuned_rows)):
        for r in rows:
            lines.append(
                f"| {label} | {r['clase']} | {fmt(r['precision'])} | {fmt(r['recall'])} | {fmt(r['f1'])} | {fmt(r['ap50'])} |"
            )
    lines += [
        "",
        f"Diferencia de mAP@0,5 en clases comunes (ajustado − preentrenado): {fmt(boot.difference)}",
        f"IC 95 %: [{fmt(boot.ci_low)}; {fmt(boot.ci_high)}], valor p unilateral: {fmt(boot.p_value)}",
        "Decisión: " + ("se rechaza H0" if boot.rejects_h0 else "no se rechaza H0"),
    ]
    (args.out / "cp01_tabla.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
