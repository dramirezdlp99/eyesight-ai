/// Parámetros de funcionamiento de EyeSight AI.
///
/// Cada valor proviene de un requerimiento o de un criterio de aceptación del
/// informe (capítulo 4). Se centralizan aquí para que las pruebas y el código
/// usen exactamente los mismos números.
abstract final class AppConstants {
  // ---------------------------------------------------------------- Modelo
  /// Tamaño de entrada del modelo YOLOv8n (numeral 2.5.2): 320 × 320 píxeles.
  static const int modelInputSize = 320;

  /// IoU usado por la supresión de no máximos (numeral 4.2.3).
  static const double nmsIouThreshold = 0.45;

  /// Máximo de detecciones conservadas por cuadro tras la NMS.
  static const int maxDetectionsPerFrame = 20;

  /// Frecuencia objetivo de análisis: 5 a 10 cuadros por segundo (RNF03).
  static const int minFps = 5;
  static const int maxFps = 10;

  /// Intervalo mínimo entre cuadros analizados (100 ms = 10 fps como máximo).
  static const Duration minFrameInterval = Duration(milliseconds: 100);

  // ---------------------------------------------------- Detección y alertas
  /// Cuadros consecutivos para confirmar una detección (HU03, CA1).
  static const int stabilityWindow = 3;

  /// Tiempo mínimo antes de repetir el mismo obstáculo (HU03, CA2).
  static const Duration repeatSameObstacleAfter = Duration(seconds: 4);

  /// Pausa de la voz con el comando «silencio» (HU09, CA2).
  static const Duration muteDuration = Duration(seconds: 10);

  /// Meta de latencia de inferencia (RNF01) y de captura a alerta (RNF02).
  static const int inferenceLatencyGoalMs = 100;
  static const int captureToAlertGoalMs = 500;

  // ----------------------------------------------------- Franja de trayectoria
  /// Franja central e inferior de la imagen que representa la trayectoria
  /// del usuario (numeral 2.5.8 y wireframe de la HU03).
  static const double pathBandLeft = 0.28;
  static const double pathBandRight = 0.72;
  static const double pathBandTop = 0.42;

  /// Umbrales de cercanía relativa (numeral 2.5.8). Se evalúan sobre el borde
  /// inferior de la caja (contacto con el suelo) y sobre su altura relativa.
  static const double nearBottom = 0.85;
  static const double nearHeight = 0.50;
  static const double mediumBottom = 0.65;
  static const double mediumHeight = 0.25;

  // ------------------------------------------------------- Zonas de riesgo
  /// Radio de alerta por defecto (HU08, CA1) y rango permitido (HU11, HU13).
  static const double defaultAlertRadiusM = 20;
  static const double minAlertRadiusM = 5;
  static const double maxAlertRadiusM = 100;

  /// Distancia para agrupar detecciones del mismo tipo (HU06, CA2).
  static const double zoneMergeDistanceM = 10;

  /// Precisión GPS mínima para registrar una zona (HU06, CA1).
  static const double maxAccuracyToRegisterM = 20;

  /// Precisión GPS mínima para emitir alertas preventivas (HU08, CA4).
  static const double maxAccuracyToWarnM = 30;

  /// Histéresis de repetición de la alerta preventiva (HU08, CA2).
  static const double zoneRearmExtraM = 10;
  static const Duration zoneRepeatAfter = Duration(seconds: 60);

  /// Consulta periódica de la posición (HU08, tareas técnicas).
  static const Duration positionPollInterval = Duration(seconds: 3);

  /// Tiempo para responder el tipo de zona manual (HU07, CA3).
  static const Duration manualZoneAnswerTimeout = Duration(seconds: 8);

  /// Pulsación prolongada para marcar una zona (HU07, CA1).
  static const Duration markZoneLongPress = Duration(seconds: 2);

  /// Longitud máxima de la nota de una zona (HU11, CA2).
  static const int maxNoteLength = 100;

  // ------------------------------------------------------------ Historial
  /// Retención automática del historial (HU12, CA4).
  static const Duration historyRetention = Duration(days: 90);

  // ------------------------------------------------------------ Ajustes
  /// Umbral de confianza por defecto y rango permitido (HU13, CA2).
  static const double defaultConfidenceThreshold = 0.50;
  static const double minConfidenceThreshold = 0.30;
  static const double maxConfidenceThreshold = 0.90;

  /// Velocidad de la voz como multiplicador (1,0x = normal).
  static const double defaultSpeechRate = 1.0;
  static const double minSpeechRate = 0.5;
  static const double maxSpeechRate = 2.0;

  static const double defaultVolume = 1.0;

  // ------------------------------------------------------------ Seguridad
  /// PIN del acompañante: 4 a 6 dígitos (RF02).
  static const int minPinLength = 4;
  static const int maxPinLength = 6;

  /// Bloqueo tras intentos fallidos (RNF10).
  static const int maxPinAttempts = 5;
  static const Duration pinLockDuration = Duration(seconds: 60);

  /// Iteraciones de PBKDF2-HMAC-SHA256 para el resumen del PIN.
  static const int pinHashIterations = 120000;

  /// Bytes de la sal aleatoria del PIN.
  static const int pinSaltLength = 16;

  // --------------------------------------------------------- Tolerancia a fallos
  /// Conmutación a la cámara del teléfono si la USB falla (RNF05).
  static const Duration cameraFallbackTimeout = Duration(seconds: 3);

  /// Inicio del escáner (HU02, CA1).
  static const Duration scannerStartGoal = Duration(seconds: 3);

  /// Fallos seguidos del modelo antes de avisar por voz (RNF16).
  static const int detectionFailuresToWarn = 3;

  // ------------------------------------------------------------ Escáner
  /// Ventana de escucha de cada comando de voz (HU09).
  static const Duration commandListenWindow = Duration(seconds: 8);

  /// Intervalo mínimo entre intentos de registrar la misma clase como zona
  /// (evita consultar el repositorio en cada cuadro).
  static const Duration zoneRegistrationThrottle = Duration(seconds: 5);

  /// Antigüedad máxima de la última posición GPS para usarla en el
  /// historial y en el registro automático de zonas.
  static const Duration positionMaxAge = Duration(seconds: 10);
}
