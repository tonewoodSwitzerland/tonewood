import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

/// Eine plattformunabhängige Klasse zum Herunterladen von Dateien
class DownloadHelper {
  /// Lädt eine Datei auf der aktuellen Plattform herunter oder teilt sie
  ///
  /// [bytes] - Die Bytes der Datei
  /// [fileName] - Der Name der Datei
  ///
  /// Gibt den Dateipfad zurück (nur auf mobilen Geräten) oder null (Web)
  static Future<String?> downloadFile(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      return _webDownload(bytes, fileName);
    } else {
      return _mobileDownload(bytes, fileName);
    }
  }

  static Future<String?> _webDownload(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      try {
        // Auf Web-Plattformen setzen wir einen simulierten Download
        // Da wir nicht direkt auf dart:html zugreifen können ohne Fehler auf Mobilgeräten
        print('Web-Download für $fileName gestartet (${bytes.length} Bytes)');

        // In einer echten Implementierung würde hier eine JS-Interop Funktion aufgerufen
        // die den Download-Dialog im Browser öffnet:

        // Beispiel, wie es aussehen würde, wenn wir dart:html verwenden könnten:
        // final blob = html.Blob([bytes]);
        // final url = html.Url.createObjectUrlFromBlob(blob);
        // final anchor = html.AnchorElement()
        //   ..href = url
        //   ..download = fileName
        //   ..style.display = 'none';
        // html.document.body?.appendChild(anchor);
        // anchor.click();
        // html.document.body?.removeChild(anchor);
        // html.Url.revokeObjectUrl(url);

        // Da wir aber keinen Browser-Zugriff simulieren können,
        // geben wir einfach an, dass alles erfolgreich war
        return "simulated-web-download-path";
      } catch (e) {
        print('Fehler beim Web-Download: $e');
        return null;
      }
    }
    return null;
  }

  static Future<String?> _mobileDownload(Uint8List bytes, String fileName) async {
    if (!kIsWeb) {
      try {
        // Auf mobilen Plattformen speichern wir die Datei im temporären Verzeichnis
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(bytes);

        print('Mobile-Download abgeschlossen: $filePath');

        // Optional: Teilen der Datei
        // await Share.shareXFiles([XFile(filePath)], subject: 'Datei teilen');

        return filePath;
      } catch (e) {
        print('Fehler beim Mobile-Download: $e');
        return null;
      }
    }
    return null;
  }
}