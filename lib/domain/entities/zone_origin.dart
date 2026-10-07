/// Origen del registro de una zona de riesgo (RF10 y RF11).
enum ZoneOrigin {
  automatic('automático'),
  manual('manual');

  const ZoneOrigin(this.spanishName);

  final String spanishName;

  static ZoneOrigin? fromName(String? name) {
    for (final value in ZoneOrigin.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}
