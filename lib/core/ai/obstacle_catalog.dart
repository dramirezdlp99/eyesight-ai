/// Categoría de un obstáculo para decidir alertas y registro de zonas.
enum ObstacleKind {
  /// Se desplaza (persona, vehículo, bicicleta): alerta, pero no crea zona.
  mobile,

  /// Fijo y peligroso (hueco, escalón, poste, bolardo, obra): alerta y crea
  /// zona de riesgo automática (HU06, CA1).
  fixedHazard,

  /// Fijo de menor riesgo (banca, hidrante, cono): alerta sin crear zona.
  fixed,
}

/// Información de una clase que la herramienta considera obstáculo.
class ObstacleInfo {
  const ObstacleInfo(this.spanishName, this.kind);

  final String spanishName;
  final ObstacleKind kind;

  bool get createsZone => kind == ObstacleKind.fixedHazard;
}

/// Catálogo de clases de obstáculos (delimitación del numeral 1.8).
///
/// Incluye las clases útiles del conjunto COCO del modelo preentrenado y las
/// clases nuevas del conjunto de datos ampliado. Las clases que no aparecen
/// aquí (por ejemplo «pizza» o «televisor») se descartan.
abstract final class ObstacleCatalog {
  static const Map<String, ObstacleInfo> _entries = {
    // ---- Clases COCO comunes a ambos modelos (hipótesis, numeral 2.3)
    'person': ObstacleInfo('Persona', ObstacleKind.mobile),
    'bicycle': ObstacleInfo('Bicicleta', ObstacleKind.mobile),
    'car': ObstacleInfo('Automóvil', ObstacleKind.mobile),
    'motorcycle': ObstacleInfo('Motocicleta', ObstacleKind.mobile),
    'bus': ObstacleInfo('Bus', ObstacleKind.mobile),
    'truck': ObstacleInfo('Camión', ObstacleKind.mobile),
    'dog': ObstacleInfo('Perro', ObstacleKind.mobile),
    // ---- Otras clases COCO presentes en el espacio público
    'traffic light': ObstacleInfo('Semáforo', ObstacleKind.fixed),
    'fire hydrant': ObstacleInfo('Hidrante', ObstacleKind.fixed),
    'stop sign': ObstacleInfo('Señal de pare', ObstacleKind.fixed),
    'parking meter': ObstacleInfo('Parquímetro', ObstacleKind.fixed),
    'bench': ObstacleInfo('Banca', ObstacleKind.fixed),
    'chair': ObstacleInfo('Silla', ObstacleKind.fixed),
    'potted plant': ObstacleInfo('Matera', ObstacleKind.fixed),
    // ---- Clases nuevas del conjunto de datos ampliado (numeral 3.13.2)
    'pole': ObstacleInfo('Poste', ObstacleKind.fixedHazard),
    'bollard': ObstacleInfo('Bolardo', ObstacleKind.fixedHazard),
    'traffic cone': ObstacleInfo('Cono', ObstacleKind.fixed),
    'step': ObstacleInfo('Escalón', ObstacleKind.fixedHazard),
    'pothole': ObstacleInfo('Hueco', ObstacleKind.fixedHazard),
    'construction': ObstacleInfo('Obra', ObstacleKind.fixedHazard),
    // ---- Tipo genérico para zonas manuales (HU07)
    'other': ObstacleInfo('Riesgo', ObstacleKind.fixedHazard),
  };

  /// Tipos que el usuario puede dictar al marcar una zona (HU07, CA2).
  static const List<String> manualZoneTypes = [
    'pothole',
    'step',
    'construction',
    'other',
  ];

  /// Normaliza la etiqueta del modelo: minúsculas y guiones como espacios
  /// (`traffic_cone` y `traffic-cone` equivalen a `traffic cone`).
  static String normalize(String label) =>
      label.trim().toLowerCase().replaceAll(RegExp(r'[_\-]+'), ' ');

  static ObstacleInfo? lookup(String label) => _entries[normalize(label)];

  static bool isObstacle(String label) => lookup(label) != null;

  static bool createsZone(String label) => lookup(label)?.createsZone ?? false;

  /// Nombre en español para la voz; si la clase no está en el catálogo se
  /// devuelve la etiqueta original.
  static String spanishName(String label) =>
      lookup(label)?.spanishName ?? label;

  /// Todas las claves del catálogo (para filtros del historial).
  static Iterable<String> get keys => _entries.keys;
}
