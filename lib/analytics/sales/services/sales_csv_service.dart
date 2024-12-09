import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesCsvService {
  static Future<List<int>> generateSalesList(List<Map<String, dynamic>> sales) async {
    // CSV Header
    final csvData = [
      [
        'Datum',
        'Belegnummer',
        'Kunde',
        'Artikel',
        'Qualität',
        'Menge',
        'Einheit',
        'Einzelpreis',
        'Rabatt %',
        'Rabatt CHF',
        'Total',
      ].join(';'),
    ];

    // Daten hinzufügen
    for (final sale in sales) {
      final customer = sale['customer'] as Map<String, dynamic>;
      final items = (sale['items'] as List).cast<Map<String, dynamic>>();
      final metadata = sale['metadata'] as Map<String, dynamic>;
      final timestamp = (metadata['timestamp'] as Timestamp).toDate();

      for (final item in items) {
        final row = [
          DateFormat('dd.MM.yyyy').format(timestamp),
          sale['receipt_number'] ?? '-',
          customer['company'],
          item['product_name'],
          item['quality_name'],
          item['quantity'].toString(),
          item['unit'],
          item['price_per_unit'].toStringAsFixed(2),
          (item['discount']?['percentage'] ?? 0).toString(),
          (item['discount_amount'] ?? 0).toStringAsFixed(2),
          item['total'].toStringAsFixed(2),
        ].join(';');

        csvData.add(row);
      }
    }

    // Füge BOM für Excel hinzu
    final List<int> bom = [0xEF, 0xBB, 0xBF];
    final csvString = csvData.join('\n');

    return bom + utf8.encode(csvString);
  }
}