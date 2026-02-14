// lib/analytics/roundwood/services/roundwood_export_service.dart

import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/roundwood_models.dart';
import 'roundwood_pdf_service.dart';
import 'roundwood_csv_service.dart';

// Conditional imports für Web vs. Mobile
// WICHTIG: Du brauchst die gleichen 3 Helper-Dateien wie beim Warehouse-Export.
// Falls sie im selben Projekt unter warehouse/services/ liegen, importiere von dort:
import '../../../warehouse/services/warehouse_export_helper_stub.dart'
if (dart.library.html) '../../../warehouse/services/warehouse_export_helper_web.dart'
if (dart.library.io) '../../../warehouse/services/warehouse_export_helper_mobile.dart';

class RoundwoodExportService {
  static String _getFileName(String type) {
    return 'Rundholzliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.$type';
  }

  /// CSV Export - funktioniert auf Web und Mobile
  static Future<void> exportCsv(List<RoundwoodItem> items) async {
    items.sort((a, b) => a.internalNumber.compareTo(b.internalNumber));

    final csvBytes = await RoundwoodCsvService.generateCsv(items);
    final fileName = _getFileName('csv');

    await saveAndShareFile(
      bytes: csvBytes,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// PDF Export - funktioniert auf Web und Mobile
  static Future<void> exportPdf(
      List<RoundwoodItem> items, {
        bool includeAnalytics = false,
        Map<String, dynamic>? activeFilters,
      }) async {
    items.sort((a, b) => a.internalNumber.compareTo(b.internalNumber));

    final pdfBytes = await RoundwoodPdfService.generatePdf(
      items,
      includeAnalytics: includeAnalytics,
      activeFilters: activeFilters,
    );
    final fileName = _getFileName('pdf');

    await saveAndShareFile(
      bytes: Uint8List.fromList(pdfBytes),
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }
}