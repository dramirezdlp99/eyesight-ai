import 'package:permission_handler/permission_handler.dart';

/// Permisos que usa la aplicación (numeral 4.1.7: permisos mínimos,
/// solicitados en el momento en que se necesitan).
enum AppPermission {
  camera('la cámara, para detectar obstáculos'),
  microphone('el micrófono, para los comandos de voz'),
  location('la ubicación, para recordar las zonas de riesgo');

  const AppPermission(this.reason);

  /// Explicación que se anuncia por voz antes de pedir el permiso (HU02 CA2).
  final String reason;
}

abstract interface class IPermissionGuard {
  Future<bool> isGranted(AppPermission permission);

  Future<bool> request(AppPermission permission);
}

class PermissionHandlerGuard implements IPermissionGuard {
  static Permission _map(AppPermission p) => switch (p) {
        AppPermission.camera => Permission.camera,
        AppPermission.microphone => Permission.microphone,
        AppPermission.location => Permission.locationWhenInUse,
      };

  @override
  Future<bool> isGranted(AppPermission permission) =>
      _map(permission).isGranted;

  @override
  Future<bool> request(AppPermission permission) async =>
      (await _map(permission).request()).isGranted;
}
