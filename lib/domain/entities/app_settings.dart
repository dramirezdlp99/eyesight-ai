import '../../core/config/app_constants.dart';
import 'user_profile.dart';
import 'video_source_kind.dart';

/// Configuración de la herramienta (RF18, RF19 y diagrama de clases).
class AppSettings {
  const AppSettings({
    this.profile,
    this.speechRate = AppConstants.defaultSpeechRate,
    this.volume = AppConstants.defaultVolume,
    this.alertRadiusM = AppConstants.defaultAlertRadiusM,
    this.confidenceThreshold = AppConstants.defaultConfidenceThreshold,
    this.videoSource = VideoSourceKind.phone,
    this.vibration = true,
    this.autoZones = true,
  });

  /// Reconstruye los ajustes desde Hive. Cualquier valor ausente o fuera de
  /// rango se reemplaza por su valor por defecto, para que un dato dañado
  /// nunca deje la herramienta sin funcionar (RNF05).
  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    const d = AppSettings();
    final profileRaw = map['profile'];
    final sourceRaw = map['videoSource'];
    return AppSettings(
      profile: UserProfile.fromName(profileRaw is String ? profileRaw : null),
      speechRate: _inRange(
        map['speechRate'],
        AppConstants.minSpeechRate,
        AppConstants.maxSpeechRate,
        d.speechRate,
      ),
      volume: _inRange(map['volume'], 0, 1, d.volume),
      alertRadiusM: _inRange(
        map['alertRadiusM'],
        AppConstants.minAlertRadiusM,
        AppConstants.maxAlertRadiusM,
        d.alertRadiusM,
      ),
      confidenceThreshold: _inRange(
        map['confidenceThreshold'],
        AppConstants.minConfidenceThreshold,
        AppConstants.maxConfidenceThreshold,
        d.confidenceThreshold,
      ),
      videoSource:
          VideoSourceKind.fromName(sourceRaw is String ? sourceRaw : null) ??
              d.videoSource,
      vibration: map['vibration'] is bool ? map['vibration'] as bool : true,
      autoZones: map['autoZones'] is bool ? map['autoZones'] as bool : true,
    );
  }

  /// Perfil elegido; `null` mientras no se ha elegido ninguno (HU01, CA1).
  final UserProfile? profile;

  /// Velocidad de la voz como multiplicador (1,0 = normal).
  final double speechRate;
  final double volume;
  final double alertRadiusM;
  final double confidenceThreshold;
  final VideoSourceKind videoSource;
  final bool vibration;
  final bool autoZones;

  AppSettings copyWith({
    UserProfile? profile,
    bool clearProfile = false,
    double? speechRate,
    double? volume,
    double? alertRadiusM,
    double? confidenceThreshold,
    VideoSourceKind? videoSource,
    bool? vibration,
    bool? autoZones,
  }) =>
      AppSettings(
        profile: clearProfile ? null : (profile ?? this.profile),
        speechRate: speechRate ?? this.speechRate,
        volume: volume ?? this.volume,
        alertRadiusM: alertRadiusM ?? this.alertRadiusM,
        confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
        videoSource: videoSource ?? this.videoSource,
        vibration: vibration ?? this.vibration,
        autoZones: autoZones ?? this.autoZones,
      );

  /// Restablece los valores por defecto conservando el perfil (HU13, CA4).
  AppSettings resetKeepingProfile() => AppSettings(profile: profile);

  Map<String, Object?> toMap() => {
        'profile': profile?.name,
        'speechRate': speechRate,
        'volume': volume,
        'alertRadiusM': alertRadiusM,
        'confidenceThreshold': confidenceThreshold,
        'videoSource': videoSource.name,
        'vibration': vibration,
        'autoZones': autoZones,
      };

  static double _inRange(Object? value, double min, double max, double def) {
    if (value is num) {
      final v = value.toDouble();
      if (!v.isNaN && v >= min && v <= max) {
        return v;
      }
    }
    return def;
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.profile == profile &&
      other.speechRate == speechRate &&
      other.volume == volume &&
      other.alertRadiusM == alertRadiusM &&
      other.confidenceThreshold == confidenceThreshold &&
      other.videoSource == videoSource &&
      other.vibration == vibration &&
      other.autoZones == autoZones;

  @override
  int get hashCode => Object.hash(
        profile,
        speechRate,
        volume,
        alertRadiusM,
        confidenceThreshold,
        videoSource,
        vibration,
        autoZones,
      );
}
