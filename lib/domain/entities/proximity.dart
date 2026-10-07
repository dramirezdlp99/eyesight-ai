/// Cercanía relativa de un obstáculo (numeral 2.5.8, RF05).
enum Proximity {
  near('cerca'),
  medium('a media distancia'),
  far('lejos');

  const Proximity(this.spoken);

  /// Texto que se usa en la alerta de voz (HU03, CA1).
  final String spoken;

  /// Menor valor = más urgente.
  int get urgency => index;

  /// `true` si esta cercanía es más urgente que [other].
  bool isCloserThan(Proximity other) => urgency < other.urgency;

  static Proximity? fromName(String? name) {
    for (final value in Proximity.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}
