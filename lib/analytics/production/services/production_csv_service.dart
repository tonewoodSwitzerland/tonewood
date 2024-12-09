import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/production_models.dart';

class ProductionCsvService {
  static Future<List<int>> generateCsv(List<ProductionItem> items) async {
    final List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Barcode',
      'Datum',
      'Instrument',
      'Bauteil',
      'Holzart',
      'Qualität',
      'Menge',
      'Einheit',
      'Preis CHF',
      'Wert CHF',
      'Mondholz',
      'Haselfichte',
      'Thermisch behandelt'
    ]);

    // Data rows
    for (var item in items) {
      rows.add([
        item.barcode,
        _formatDate(item.created_at),
        '${item.instrument_name} (${item.instrument_code})',
        '${item.part_name} (${item.part_code})',
        '${item.wood_name} (${item.wood_code})',
        '${item.quality_name} (${item.quality_code})',
        item.quantity,
        item.unit,
        item.price_CHF.toStringAsFixed(2),
        (item.quantity * item.price_CHF).toStringAsFixed(2),
        item.moonwood ? 'Ja' : 'Nein',
        item.haselfichte ? 'Ja' : 'Nein',
        item.thermally_treated ? 'Ja' : 'Nein',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    return utf8.encode(csvData);
  }

  static String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}