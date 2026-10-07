/// Fuentes de video admitidas (RF19, patrón Strategy del numeral 3.12.5).
enum VideoSourceKind {
  /// Cámara trasera del teléfono, a la altura del pecho.
  phone('cámara del teléfono'),

  /// Cámara USB UVC montada en gafas y conectada por OTG.
  usb('cámara USB');

  const VideoSourceKind(this.spanishName);

  final String spanishName;

  static VideoSourceKind? fromName(String? name) {
    for (final value in VideoSourceKind.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}
