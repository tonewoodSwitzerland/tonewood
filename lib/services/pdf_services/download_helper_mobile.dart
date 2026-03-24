
// download_helper_mobile.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class DownloadHelper {
  static Future<String> downloadFile(Uint8List bytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
