// Stub implementation für nicht-Web Plattformen
void downloadFileForWeb(String content, String fileName) {
  // Diese Funktion wird auf mobilen Plattformen nie aufgerufen
  // da wir vorher kIsWeb prüfen
  throw UnsupportedError('Web download is not supported on this platform');
}