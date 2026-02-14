// lib/warehouse/services/warehouse_export_helper_stub.dart

import 'dart:typed_data';

/// Stub - wird nie direkt verwendet, nur als Fallback für conditional import
Future<void> saveAndShareFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Plattform nicht unterstützt');
}