import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import '../models/roundwood_models.dart';

class RoundwoodCsvService {
  static Future<Uint8List> generateCsv(List<RoundwoodItem> items) async {
    // Erstelle die CSV-Daten mit allen relevanten Feldern
    List<List<dynamic>> csvData = [
      // Header
      [
        'Nr.',
        'Orig. Nr.',
        'Holzart',
        'Qualität',
        'Vol (m³)',
        'Farbe',
        'Schlagdatum',
        'Herkunft',
        'Zweck',
        'Mondholz',
        'Bemerkungen',
        'Erfassungsdatum',
      ],
      // Daten
      ...items.map((item) => [
        item.internalNumber,
        item.originalNumber ?? '',
        item.woodName,
        item.qualityName,
        item.volume.toStringAsFixed(2),
        item.color ?? '',
        item.cuttingDate != null
            ? DateFormat('dd.MM.yy').format(item.cuttingDate!)
            : '',
        item.origin ?? '',
        item.purpose ?? '',
        item.isMoonwood ? 'Ja' : 'Nein',
        item.remarks ?? '',
        DateFormat('dd.MM.yy').format(item.timestamp),
      ]),
    ];

    // Konvertiere in CSV-String
    final csvString = const ListToCsvConverter(
      fieldDelimiter: ';',  // Semikolon für bessere Excel-Kompatibilität
      textDelimiter: '"',
      textEndDelimiter: '"',
    ).convert(csvData);

    // BOM für Excel + CSV Daten
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)];
    return Uint8List.fromList(bytes);
  }
}