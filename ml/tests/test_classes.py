from eyesight_ml.classes import (
    COCO_IDS,
    COMMON_CLASSES,
    EYESIGHT_CLASSES,
    NEW_CLASSES,
    normalize_name,
    to_eyesight,
)


def test_trece_clases_siete_comunes_y_seis_nuevas():
    assert len(EYESIGHT_CLASSES) == 13
    assert COMMON_CLASSES == ["person", "bicycle", "car", "motorcycle", "bus", "truck", "dog"]
    assert NEW_CLASSES == ["pole", "bollard", "traffic_cone", "step", "pothole", "construction"]
    assert set(COCO_IDS) == set(COMMON_CLASSES)


def test_ids_coco_de_referencia():
    assert COCO_IDS["person"] == 0
    assert COCO_IDS["bus"] == 5
    assert COCO_IDS["truck"] == 7
    assert COCO_IDS["dog"] == 16


def test_sinonimos_de_roboflow():
    assert to_eyesight("Pothole") == "pothole"
    assert to_eyesight("Traffic-Cone") == "traffic_cone"
    assert to_eyesight("stairs") == "step"
    assert to_eyesight("Lamp_Post") == "pole"
    assert to_eyesight("motorbike") == "motorcycle"
    assert to_eyesight("pizza") is None


def test_normalizacion():
    assert normalize_name("  Traffic__Cone ") == "traffic cone"
