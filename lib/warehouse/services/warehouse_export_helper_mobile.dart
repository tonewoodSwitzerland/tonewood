// lib/warehouse/services/warehouse_export_helper_mobile.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/Desktop: Speichert temporär und öffnet Share-Dialog
Future<void> saveAndShareFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: fileName,
  );

  // Aufräumen nach 1 Minute
  Future.delayed(const Duration(minutes: 1), () {
    if (file.existsSync()) file.delete();
  });
}