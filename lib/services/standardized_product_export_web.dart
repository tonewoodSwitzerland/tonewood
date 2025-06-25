import 'dart:html' as html;
import 'dart:convert';

// Web-spezifische Implementierung für den Datei-Download
void downloadFileForWeb(String content, String fileName) {
  // Erstelle Blob mit UTF-8 BOM für Excel-Kompatibilität
  final bytes = utf8.encode('\uFEFF$content'); // BOM + Inhalt
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');

  // Erstelle Download-Link
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  // Füge Link zum DOM hinzu, klicke und entferne wieder
  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);

  // Räume URL auf
  html.Url.revokeObjectUrl(url);
}