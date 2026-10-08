import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/i_settings_repository.dart';

/// Ajustes de la herramienta en Hive cifrado (RF18).
class SettingsRepository implements ISettingsRepository {
  SettingsRepository(this._box);

  static const String key = 'app';

  final Box<dynamic> _box;

  @override
  Future<AppSettings> load() async {
    final raw = _box.get(key);
    return raw is Map ? AppSettings.fromMap(raw) : const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) => _box.put(key, settings.toMap());

  @override
  Future<void> clear() async {
    await _box.clear();
  }
}
