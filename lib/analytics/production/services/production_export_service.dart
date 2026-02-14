// lib/analytics/production/services/production_export_service.dart
//
// Plattformübergreifender Export-Service für Produktionsdaten.
// Nutzt die gleichen Platform-Helper wie der Roundwood-Export.

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'production_pdf_service.dart';
import 'production_csv_service.dart';

// Conditional imports für Web vs. Mobile
// Verwendet die gleichen Helper-Dateien wie beim Warehouse/Roundwood-Export
import '../../../warehouse/services/warehouse_export_helper_stub.dart'
if (dart.library.html) '../../../warehouse/services/warehouse_export_helper_web.dart'
if (dart.library.io) '../../../warehouse/services/warehouse_export_helper_mobile.dart';

class ProductionExportService {
  static String _getFileName(String type) {
    return 'Produktionsliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.$type';
  }

  /// CSV Export - funktioniert auf Web und Mobile
  static Future<void> exportCsv(List<Map<String, dynamic>> batches) async {
    final csvBytes = await ProductionCsvService.generateCsv(batches);
    final fileName = _getFileName('csv');

    await saveAndShareFile(
      bytes: csvBytes,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// PDF Export - funktioniert auf Web und Mobile
  static Future<void> exportPdf(
      List<Map<String, dynamic>> batches, {
        bool includeAnalytics = false,
        Map<String, dynamic>? activeFilters,
      }) async {
    final pdfBytes = await ProductionPdfService.generateBatchList(
      batches,
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