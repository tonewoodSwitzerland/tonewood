import 'dart:html' as html;
import 'dart:typed_data';

class DownloadHelper {
  static Future<String?> downloadFile(Uint8List bytes, String fileName) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return null; // Web gibt keinen Dateipfad zurück
  }
}
