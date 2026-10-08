import json

import pytest

from eyesight_ml.manifest import install_model, sha256_file


def test_instala_modelo_etiquetas_y_manifiesto(tmp_path):
    model = tmp_path / "best_int8.tflite"
    model.write_bytes(b"modelo de prueba")
    assets = tmp_path / "assets" / "models"
    manifest = install_model(
        model, ["person", "pole"], assets, name="x", quantization="int8", source="prueba"
    )
    assert (assets / "eyesight_yolov8n.tflite").read_bytes() == b"modelo de prueba"
    assert (assets / "labels.txt").read_text() == "person\npole\n"
    saved = json.loads((assets / "model_manifest.json").read_text(encoding="utf-8"))
    assert saved == manifest
    assert saved["sha256"] == sha256_file(assets / "eyesight_yolov8n.tflite")
    assert len(saved["sha256"]) == 64
    assert saved["input_size"] == 320


def test_rechaza_etiquetas_vacias(tmp_path):
    model = tmp_path / "m.tflite"
    model.write_bytes(b"x")
    with pytest.raises(ValueError):
        install_model(model, [], tmp_path, name="x", quantization="int8", source="")


def test_manifiesto_de_la_app_es_valido():
    from pathlib import Path

    assets = Path(__file__).resolve().parents[2] / "assets" / "models"
    manifest = json.loads((assets / "model_manifest.json").read_text(encoding="utf-8"))
    assert manifest["sha256"] == sha256_file(assets / manifest["file"])
    labels = (assets / manifest["labels"]).read_text(encoding="utf-8").split()
    assert labels[0] == "person"
