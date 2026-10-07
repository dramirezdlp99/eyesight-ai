import '../entities/app_settings.dart';

/// Puerto de la configuración (RF18).
abstract interface class ISettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);

  Future<void> clear();
}
