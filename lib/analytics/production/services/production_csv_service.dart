// lib/analytics/production/services/production_csv_service.dart
//
// CSV-Export für die neue flache production_batches Collection.
// Ersetzt den alten CSV-Service der auf dem verschachtelten production-Modell basierte.

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';

class ProductionCsvService {
  /// Generiert eine CSV-Datei aus production_batches Dokumenten.
  ///
  /// [batches] ist eine Liste von Maps, wie sie von
  /// ProductionBatchService.getBatchesForYear() oder ähnlichen Methoden
  /// zurückgegeben wird.
  static Future<Uint8List> generateCsv(List<Map<String, dynamic>> batches) async {
    // Sortiere nach Datum (neueste zuerst)
    batches.sort((a, b) {
      final dateA = _extractDate(a);
      final dateB = _extractDate(b);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    final List<List<dynamic>> csvData = [
      // Header
      [
        'Datum',
        'Produktions-Nr.',
        'Instrument',
        'Bauteil',
        'Produkt',
        'Holzart',
        'Qualität',
        'Menge',
        'Einheit',
        'Preis CHF',
        'Wert CHF',
        'Mondholz',
        'Haselfichte',
        'Therm. behandelt',
        'FSC-100',
        'Stamm-Nr.',
        'Stamm-Jahr',
      ],
      // Daten
      ...batches.map((batch) {
        final date = _extractDate(batch);
        final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
        final price = (batch['price_CHF'] as num?)?.toDouble() ?? 0.0;
        final value = (batch['value'] as num?)?.toDouble() ?? (quantity * price);

        // Produktionsnummer zusammenbauen
        final barcode = batch['barcode'] ?? '';
        final batchNumber = (batch['batch_number'] ?? 0).toString().padLeft(4, '0');
        final productionNumber = barcode.isNotEmpty ? '$barcode.$batchNumber' : batchNumber;

        return [
          date != null ? DateFormat('dd.MM.yyyy').format(date) : '',
          productionNumber,
          batch['instrument_name'] ?? '',
          batch['part_name'] ?? '',
          batch['product_name'] ?? '',
          batch['wood_name'] ?? '',
          batch['quality_name'] ?? '',
          quantity,
          batch['unit'] ?? 'Stk',
          price.toStringAsFixed(2),
          value.toStringAsFixed(2),
          (batch['moonwood'] == true) ? 'Ja' : 'Nein',
          (batch['haselfichte'] == true) ? 'Ja' : 'Nein',
          (batch['thermally_treated'] == true) ? 'Ja' : 'Nein',
          (batch['FSC_100'] == true) ? 'Ja' : 'Nein',
          batch['roundwood_internal_number'] ?? '',
          batch['roundwood_year']?.toString() ?? '',
        ];
      }),
    ];

    // Konvertiere in CSV-String mit Semikolon (Excel-Kompatibilität)
    final csvString = const ListToCsvConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
      textEndDelimiter: '"',
    ).convert(csvData);

    // BOM für Excel + CSV Daten
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)];
    return Uint8List.fromList(bytes);
  }

  /// Extrahiert ein DateTime aus verschiedenen möglichen Datumsformaten
  static DateTime? _extractDate(Map<String, dynamic> batch) {
    final dateField = batch['stock_entry_date'];
    if (dateField == null) return null;
    if (dateField is DateTime) return dateField;
    // Firestore Timestamp
    if (dateField is dynamic && dateField.toDate != null) {
      try {
        return (dateField).toDate();
      } catch (_) {}
    }
    return null;
  }
}