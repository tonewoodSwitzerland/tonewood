// lib/analytics/production/services/production_export_service.dart
//
// Plattformübergreifender Export-Service für Produktionsdaten.
// Nutzt die gleichen Platform-Helper wie der Roundwood-Export.

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // Volumen-Daten laden bevor CSV gebaut wird
    final enrichedBatches = await _enrichBatchesWithVolume(batches);

    final csvBytes = await ProductionCsvService.generateCsv(enrichedBatches);
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
    // Volumen-Daten laden bevor PDF gebaut wird
    final enrichedBatches = await _enrichBatchesWithVolume(batches);

    final pdfBytes = await ProductionPdfService.generateBatchList(
      enrichedBatches,
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

  // ============================================================
  // Volumen aus standardized_products laden
  // ============================================================

  /// Lädt für alle Batches das Volumen aus der standardized_products Collection.
  /// Gruppiert die Abfragen nach articleNumber um doppelte Firestore-Reads zu vermeiden.
  static Future<List<Map<String, dynamic>>> _enrichBatchesWithVolume(
      List<Map<String, dynamic>> batches,
      ) async {
    // Sammle alle einzigartigen articleNumbers
    final Set<String> uniqueArticleNumbers = {};

    for (final batch in batches) {
      final instrumentCode = batch['instrument_code'] as String? ?? '';
      final partCode = batch['part_code'] as String? ?? '';
      if (instrumentCode.isNotEmpty && partCode.isNotEmpty) {
        uniqueArticleNumbers.add(instrumentCode + partCode);
      }
    }

    if (uniqueArticleNumbers.isEmpty) return batches;

    // Lade alle Volumen in Batches von 10 (Firestore whereIn Limit)
    final Map<String, double> volumeCache = {};

    final articleNumberList = uniqueArticleNumbers.toList();
    for (int i = 0; i < articleNumberList.length; i += 10) {
      final chunk = articleNumberList.sublist(
        i,
        i + 10 > articleNumberList.length ? articleNumberList.length : i + 10,
      );

      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('standardized_products')
            .where('articleNumber', whereIn: chunk)
            .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final articleNumber = data['articleNumber'] as String? ?? '';

          final mm3Volume = data['volume']?['mm3_withAddition'];
          final dm3Volume = data['volume']?['dm3_withAddition'];

          if (mm3Volume != null && (mm3Volume as num) > 0) {
            // mm³ → m³
            volumeCache[articleNumber] = mm3Volume.toDouble() / 1000000000.0;
          } else if (dm3Volume != null && (dm3Volume as num) > 0) {
            // dm³ → m³
            volumeCache[articleNumber] = dm3Volume.toDouble() / 1000.0;
          }
        }
      } catch (e) {
        print('Fehler beim Laden der Volumen-Daten: $e');
      }
    }

    // Batches mit Volumen anreichern
    return batches.map((batch) {
      final instrumentCode = batch['instrument_code'] as String? ?? '';
      final partCode = batch['part_code'] as String? ?? '';
      final articleNumber = instrumentCode + partCode;

      final volume = volumeCache[articleNumber];

      if (volume != null) {
        return {
          ...batch,
          '_volume_m3': volume,
        };
      }
      return batch;
    }).toList();
  }
}