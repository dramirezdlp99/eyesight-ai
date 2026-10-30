"""Descarga un subconjunto de COCO 2017 con bicicletas, camiones, buses y
perros, en el formato de una exportación YOLOv8 de Roboflow, para unirlo con
prepare_dataset.py. Así el modelo ajustado no olvida esas clases.

Uso (en Colab, desde la carpeta ml):
    python scripts/fetch_coco_subset.py --output datasets/raw/coco-comunes
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
import zipfile
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from eyesight_ml.classes import EYESIGHT_CLASSES  # noqa: E402
from eyesight_ml.coco_subset import select_images, yolo_lines  # noqa: E402
from eyesight_ml.dataset import split_for  # noqa: E402

ANNOTATIONS_URL = "http://images.cocodataset.org/annotations/annotations_trainval2017.zip"
MEMBER = "annotations/instances_val2017.json"


def load_annotations(cache: Path) -> dict:
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / "instances_val2017.json"
    if not target.exists():
        archive = cache / "annotations_trainval2017.zip"
        if not archive.exists():
            print("Descargando anotaciones de COCO (unos 250 MB)…")
            urllib.request.urlretrieve(ANNOTATIONS_URL, archive)
        with zipfile.ZipFile(archive) as z:
            target.write_bytes(z.read(MEMBER))
    return json.loads(target.read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("datasets/raw/coco-comunes"))
    parser.add_argument("--cache", type=Path, default=Path("datasets/coco-cache"))
    parser.add_argument("--per-class", type=int, default=150)
    args = parser.parse_args()

    coco = load_annotations(args.cache)
    images = {img["id"]: img for img in coco["images"]}
    per_image: dict[int, list[dict]] = defaultdict(list)
    for ann in coco["annotations"]:
        per_image[ann["image_id"]].append(ann)
    chosen = select_images(coco["annotations"], images, per_class=args.per_class)
    print(f"Imágenes elegidas: {len(chosen)}")

    # Partición 85/0/15. La validación queda solo con videos de Pasto, para que
    # la elección de la mejor época dependa de las clases nuevas y no del
    # rendimiento en COCO (en el experimento 2 la mejor «época» fue la 1). La
    # parte de prueba comprueba que el modelo no olvidó las clases comunes.
    counts = {"train": 0, "test": 0}
    folders = {"train": "train", "test": "test"}
    for folder in folders.values():
        (args.output / folder / "images").mkdir(parents=True, exist_ok=True)
        (args.output / folder / "labels").mkdir(parents=True, exist_ok=True)

    def save(image_id: int) -> str | None:
        info = images[image_id]
        lines = yolo_lines(per_image[image_id], info)
        if not lines:
            return None
        split = split_for(info["file_name"], val_ratio=0.0, test_ratio=0.15)
        folder = args.output / folders[split]
        image_path = folder / "images" / info["file_name"]
        if not image_path.exists():
            try:
                urllib.request.urlretrieve(info["coco_url"], image_path)
            except OSError as error:
                print(f"  No pude descargar {info['file_name']}: {error}")
                return None
        (folder / "labels" / f"{Path(info['file_name']).stem}.txt").write_text(
            "\n".join(lines) + "\n", encoding="utf-8"
        )
        return split

    with ThreadPoolExecutor(max_workers=16) as pool:
        for split in pool.map(save, chosen):
            if split:
                counts[split] += 1

    data = {"names": list(EYESIGHT_CLASSES), "nc": len(EYESIGHT_CLASSES)}
    (args.output / "data.yaml").write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
    (args.output / "LICENCIA.txt").write_text(
        "Imágenes y anotaciones de COCO 2017 (cocodataset.org). Anotaciones bajo "
        "CC BY 4.0; cada imagen conserva la licencia de Flickr indicada en COCO.\n",
        encoding="utf-8",
    )
    print(f"Guardadas por partición: {counts} en {args.output}")


if __name__ == "__main__":
    main()
