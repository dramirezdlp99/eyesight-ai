import 'package:get/get.dart';

import '../../core/device/file_exporter.dart';
import '../../core/device/permission_guard.dart';
import '../../core/security/input_validators.dart';
import '../../core/security/pin_guard.dart';
import '../../core/security/zone_backup.dart';
import '../../domain/repositories/i_audit_repository.dart';
import '../../domain/repositories/i_history_repository.dart';
import '../../domain/repositories/i_zone_repository.dart';
import '../../domain/usecases/zone_service.dart';
import '../routes/app_routes.dart';

/// Privacidad: datos guardados, permisos, cambio de PIN y borrado total
/// (HU14, RF02, RF20).
class PrivacyController extends GetxController {
  PrivacyController({
    required IZoneRepository zones,
    required IHistoryRepository history,
    required IAuditRepository audit,
    required IPermissionGuard permissions,
    required PinGuard pin,
    required Future<void> Function() wipe,
    required void Function(String route) navigate,
    required ZoneService zoneService,
    required IFileExporter exporter,
    ZoneBackup? backup,
  })  : _zoneService = zoneService,
        _exporter = exporter,
        _backup = backup ?? ZoneBackup(),
        _zones = zones,
        _history = history,
        _audit = audit,
        _permissions = permissions,
        _pin = pin,
        _wipe = wipe,
        _navigate = navigate;

  final IZoneRepository _zones;
  final IHistoryRepository _history;
  final IAuditRepository _audit;
  final IPermissionGuard _permissions;
  final PinGuard _pin;
  final Future<void> Function() _wipe;
  final void Function(String route) _navigate;
  final ZoneService _zoneService;
  final IFileExporter _exporter;
  final ZoneBackup _backup;

  /// Palabra que hay que escribir para borrar todo (HU14, CA2).
  static const String confirmWord = 'ELIMINAR';
  static const String encryption =
      'AES-256 en Hive; la clave vive en el Android Keystore';

  final RxInt zoneCount = 0.obs;
  final RxInt historyCount = 0.obs;
  final RxInt auditCount = 0.obs;
  final RxMap<AppPermission, bool> permissions = <AppPermission, bool>{}.obs;
  final RxBool busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// CA1: cantidad de datos guardados y estado de cada permiso.
  Future<void> load() async {
    zoneCount.value = await _zones.count();
    historyCount.value = await _history.count();
    auditCount.value = (await _audit.all()).length;
    final states = <AppPermission, bool>{};
    for (final p in AppPermission.values) {
      try {
        states[p] = await _permissions.isGranted(p);
      } on Object {
        states[p] = false;
      }
    }
    permissions.assignAll(states);
  }

  /// CA3: cambia el PIN. Devuelve `null` si se cambió o el mensaje de error.
  Future<String?> changePin(String current, String next, String repeat) async {
    final invalid = InputValidators.pin(next);
    if (invalid != null) {
      return invalid;
    }
    if (next != repeat) {
      return 'Los PIN nuevos no coinciden.';
    }
    final result = await _pin.changePin(current, next);
    return switch (result) {
      PinAccepted() => null,
      PinRejected(:final remainingAttempts) =>
        'PIN actual incorrecto. Quedan $remainingAttempts intentos.',
      PinLocked(:final remaining) =>
        'Demasiados intentos. Espere ${remaining.inSeconds} segundos.',
      PinNotSet() => 'No hay un PIN configurado.',
    };
  }

  /// Exporta las zonas cifradas con una contraseña y abre el menú de
  /// compartir. Devuelve `null` si se compartió o el motivo del error.
  Future<String?> exportZones(String password, String repeat) async {
    final invalid = ZoneBackup.validatePassword(password);
    if (invalid != null) {
      return invalid;
    }
    if (password != repeat) {
      return 'Las contraseñas no coinciden.';
    }
    final zones = await _zones.all();
    if (zones.isEmpty) {
      return 'Todavía no hay zonas para exportar.';
    }
    busy.value = true;
    try {
      final text = await _backup.seal(zones, password);
      await _exporter.shareText(text,
          subject: 'Zonas de riesgo de EyeSight AI');
      return null;
    } on Object catch (e) {
      return 'No se pudo exportar: $e';
    } finally {
      busy.value = false;
    }
  }

  /// Importa zonas desde el texto de una copia. Devuelve el mensaje para el
  /// acompañante y `true` si se importó.
  Future<(bool, String)> importZones(String text, String password) async {
    busy.value = true;
    try {
      final zones = await _backup.open(text, password);
      final added = await _zoneService.importZones(zones);
      await load();
      final skipped = zones.length - added;
      return (
        true,
        'Se importaron $added zonas'
            '${skipped > 0 ? '; $skipped ya existían o no eran válidas' : ''}.',
      );
    } on ZoneBackupException catch (e) {
      return (false, e.message);
    } finally {
      busy.value = false;
    }
  }

  /// CA2: con «ELIMINAR» borra zonas, historial, ajustes, PIN y clave de
  /// cifrado, y vuelve a la selección de perfil.
  Future<bool> wipeAll(String typed) async {
    if (typed.trim() != confirmWord || busy.value) {
      return false;
    }
    busy.value = true;
    try {
      await _wipe();
    } finally {
      busy.value = false;
    }
    _navigate(AppRoutes.profile);
    return true;
  }
}
