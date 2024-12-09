
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/roundwood_models.dart';
import 'roundwood_pdf_service.dart';
import 'roundwood_csv_service.dart';

class RoundwoodExportService {
  static String _getFileName(String type) {
    // Beispiel: "Rundholzliste_01.11.2023.pdf"
    return 'Rundholzliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.$type';
  }

  static Future<void> sharePdf(List<RoundwoodItem> items) async {
    try {
      items.sort((a, b) => a.internalNumber.compareTo(b.internalNumber));
      final pdfBytes = await RoundwoodPdfService.generatePdf(items);
      final fileName = _getFileName('pdf');  // Stelle sicher, dass dieser Name verwendet wird

      await Share.shareXFiles(
        [XFile.fromData(
          pdfBytes,
          name: fileName,  // Hier wird der Name explizit gesetzt
          mimeType: 'application/pdf',
        )],
        subject: 'Rundholzliste ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> shareCsv(List<RoundwoodItem> items) async {
    try {
      items.sort((a, b) => a.internalNumber.compareTo(b.internalNumber));
      final csvBytes = await RoundwoodCsvService.generateCsv(items);
      final fileName = _getFileName('csv');  // Stelle sicher, dass dieser Name verwendet wird

      await Share.shareXFiles(
        [XFile.fromData(
          csvBytes,
          name: fileName,  // Hier wird der Name explizit gesetzt
          mimeType: 'text/csv',
        )],
        subject: 'Rundholzliste ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      );
    } catch (e) {
      rethrow;
    }
  }
}
