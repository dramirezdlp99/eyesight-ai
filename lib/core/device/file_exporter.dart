import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Entrega un archivo generado por la app al investigador (HU15, CA3).
abstract interface class IFileExporter {
  /// Guarda [contents] como [fileName] y abre el menú de compartir del
  /// teléfono. Devuelve la ruta del archivo.
  Future<String> export(String fileName, String contents);

  /// Abre el menú de compartir con [text] (por ejemplo, para WhatsApp).
  Future<void> shareText(String text, {String? subject});
}

/// Guarda el archivo en la carpeta temporal privada de la app y abre el
/// menú de compartir de Android. Nada se envía sin que el investigador
/// elija el destino.
class ShareFileExporter implements IFileExporter {
  const ShareFileExporter();

  @override
  Future<String> export(String fileName, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(contents, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: fileName,
    );
    return file.path;
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}
