import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
// Conditional import für Web
import 'package:universal_html/html.dart' as html;
import 'dart:convert';

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
// Erstelle Blob und URL
final blob = html.Blob([bytes]);
final url = html.Url.createObjectUrlFromBlob(blob);

// Erstelle unsichtbaren Download-Link
final anchor = html.AnchorElement()
..href = url
..download = fileName
..style.display = 'none';

// Füge zum DOM hinzu
html.document.body!.children.add(anchor);

// Klicke auf den Link
anchor.click();

// Entferne den Link wieder
html.document.body!.children.remove(anchor);

// Räume die URL auf
html.Url.revokeObjectUrl(url);

print('Web-Download für $fileName gestartet (${bytes.length} Bytes)');
return "Downloads-Ordner";
} catch (e) {
print('Fehler beim Web-Download: $e');
// Fallback: Öffne in neuem Tab
try {
final blob = html.Blob([bytes], 'application/pdf');
final url = html.Url.createObjectUrlFromBlob(blob);
html.window.open(url, '_blank');
return "Neues Browser-Fenster";
} catch (e2) {
print('Auch Fallback fehlgeschlagen: $e2');
return null;
}
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