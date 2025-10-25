import 'dart:html' as html;

/// Web-Implementierung für PDF-Download
void downloadFile(String url, String fileName) {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..setAttribute('target', '_blank')
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}