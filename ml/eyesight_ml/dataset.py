"""Unión de conjuntos de datos en formato YOLO con reasignación de clases.

Cada fuente (por ejemplo, una exportación de Roboflow Universe en formato
"YOLOv8") trae su propio data.yaml con nombres de clase. Este módulo traduce
esos nombres a las clases de EyeSight AI, descarta las demás y arma un único
conjunto con particiones de entrenamiento, validación y prueba.
"""

from __future__ import annotations

import hashlib
import shutil
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .classes import EYESIGHT_CLASSES, class_id, to_eyesight

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SPLITS = ("train", "val", "test")
# Nombres de carpetas usados por distintas exportaciones.
SPLIT_ALIASES = {"train": "train", "valid": "val", "val": "val", "test": "test"}


@dataclass
class MergeReport:
    images: dict[str, int] = field(default_factory=lambda: {s: 0 for s in SPLITS})
    boxes_per_class: dict[str, int] = field(
        default_factory=lambda: {c: 0 for c in EYESIGHT_CLASSES}
    )
    dropped_boxes: int = 0
    skipped_images: int = 0


def read_source_names(data_yaml: Path) -> list[str]:
    """Nombres de clase de una fuente (lista o diccionario id → nombre)."""
    data = yaml.safe_load(data_yaml.read_text(encoding="utf-8"))
    names = data.get("names")
    if isinstance(names, dict):
        return [str(names[k]) for k in sorted(names, key=int)]
    if isinstance(names, list):
        return [str(n) for n in names]
    raise ValueError(f"{data_yaml}: no tiene la clave 'names'")


def build_mapping(source_names: list[str]) -> dict[int, int]:
    """Índice de la fuente → índice de EyeSight AI (solo clases conocidas)."""
    mapping: dict[int, int] = {}
    for i, name in enumerate(source_names):
        target = to_eyesight(name)
        if target is not None:
            mapping[i] = class_id(target)
    return mapping


def remap_label_text(text: str, mapping: dict[int, int]) -> tuple[list[str], int]:
    """Reescribe un archivo de etiquetas YOLO. Devuelve las líneas válidas y
    cuántas cajas se descartaron. Las coordenadas deben estar entre 0 y 1."""
    lines: list[str] = []
    dropped = 0
    for raw in text.splitlines():
        parts = raw.split()
        if not parts:
            continue
        if len(parts) != 5:
            # Polígonos de segmentación u otros formatos: se descartan.
            dropped += 1
            continue
        try:
            src = int(float(parts[0]))
            coords = [float(v) for v in parts[1:]]
        except ValueError:
            dropped += 1
            continue
        if src not in mapping or any(v < 0 or v > 1 for v in coords) or coords[2] <= 0 or coords[3] <= 0:
            dropped += 1
            continue
        lines.append(f"{mapping[src]} " + " ".join(f"{v:.6f}" for v in coords))
    return lines, dropped


def split_for(key: str, val_ratio: float = 0.15, test_ratio: float = 0.15) -> str:
    """Partición determinista a partir de un hash del nombre del archivo."""
    h = int(hashlib.sha256(key.encode("utf-8")).hexdigest()[:8], 16) / 0xFFFFFFFF
    if h < test_ratio:
        return "test"
    if h < test_ratio + val_ratio:
        return "val"
    return "train"


def _find_split_dirs(source: Path) -> list[tuple[str | None, Path]]:
    """Carpetas de imágenes de la fuente con su partición, si la declara."""
    found: list[tuple[str | None, Path]] = []
    for alias, split in SPLIT_ALIASES.items():
        images = source / alias / "images"
        if images.is_dir():
            found.append((split, images))
    if not found and (source / "images").is_dir():
        found.append((None, source / "images"))
    return found


def merge_sources(sources: list[Path], output: Path, keep_splits: bool = True) -> MergeReport:
    """Une las fuentes en `output` (formato YOLO) y escribe `eyesight.yaml`."""
    report = MergeReport()
    for split in SPLITS:
        (output / split / "images").mkdir(parents=True, exist_ok=True)
        (output / split / "labels").mkdir(parents=True, exist_ok=True)

    for source in sources:
        mapping = build_mapping(read_source_names(source / "data.yaml"))
        prefix = source.name.replace(" ", "_")
        for declared, images_dir in _find_split_dirs(source):
            labels_dir = images_dir.parent / "labels"
            for image in sorted(images_dir.iterdir()):
                if image.suffix.lower() not in IMAGE_EXTENSIONS:
                    continue
                label_file = labels_dir / f"{image.stem}.txt"
                text = label_file.read_text(encoding="utf-8") if label_file.exists() else ""
                lines, dropped = remap_label_text(text, mapping)
                report.dropped_boxes += dropped
                if not lines and text.strip():
                    # Solo tenía clases ajenas: no aporta al conjunto.
                    report.skipped_images += 1
                    continue
                name = f"{prefix}__{image.name}"
                split = declared if (keep_splits and declared) else split_for(name)
                shutil.copy2(image, output / split / "images" / name)
                (output / split / "labels" / f"{Path(name).stem}.txt").write_text(
                    "\n".join(lines) + ("\n" if lines else ""), encoding="utf-8"
                )
                report.images[split] += 1
                for line in lines:
                    report.boxes_per_class[EYESIGHT_CLASSES[int(line.split()[0])]] += 1

    write_data_yaml(output)
    return report


def write_data_yaml(output: Path) -> Path:
    data = {
        "path": str(output.resolve()),
        "train": "train/images",
        "val": "val/images",
        "test": "test/images",
        "names": {i: n for i, n in enumerate(EYESIGHT_CLASSES)},
    }
    target = output / "eyesight.yaml"
    target.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")
    return target
