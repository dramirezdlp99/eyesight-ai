"""Ajuste fino de YOLOv8n a partir de los pesos preentrenados en COCO.

Uso (en Google Colab con GPU):
    python scripts/train.py --data datasets/eyesight/eyesight.yaml --epochs 100
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    from ultralytics import YOLO

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--model", default="yolov8n.pt")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--imgsz", type=int, default=320)
    parser.add_argument("--batch", type=int, default=32)
    parser.add_argument("--patience", type=int, default=20)
    parser.add_argument("--project", default="runs/eyesight")
    parser.add_argument("--name", default="yolov8n_ajustado")
    args = parser.parse_args()

    model = YOLO(args.model)  # pesos preentrenados (aprendizaje por transferencia)
    model.train(
        data=str(args.data),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        patience=args.patience,
        project=args.project,
        name=args.name,
        seed=7,
        deterministic=True,
        plots=True,
    )
    metrics = model.val(data=str(args.data), split="test", imgsz=args.imgsz)
    print(f"mAP@0,5 en prueba (todas las clases): {metrics.box.map50:.4f}")


if __name__ == "__main__":
    main()
