import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import '../models/roundwood_models.dart';

class RoundwoodCsvService {
  static Future<Uint8List> generateCsv(List<RoundwoodItem> items) async {
    // Sortiere nach interner Nummer
    items.sort((a, b) => a.internalNumber.compareTo(b.internalNumber));

    List<List<dynamic>> csvData = [
      // Header - AKTUALISIERT mit neuen Feldern
      [
        'Nr.',
        'Jahrgang', // NEU
        'Orig. Nr.',
        'Holzart',
        'Qualität',
        'Vol (m³)',
        'Spray-Farbe', // UMBENANNT
        'Plakette-Farbe', // NEU
        'Einschnittdatum',
        'Herkunft',
        'Verwendungszwecke', // VEREINFACHT
        'Andere Verwendung', // NEU
        'Mondholz',
        'FSC', // NEU
        'Bemerkungen',
        'Erfassungsdatum',
      ],
      // Daten
      ...items.map((item) => [
        item.internalNumber,
        item.year, // NEU
        item.originalNumber ?? '',
        item.woodName,
        item.qualityName,
        item.volume.toStringAsFixed(2),
        item.sprayColor ?? '', // UMBENANNT
        item.plaketteColor ?? '', // NEU
        item.cuttingDate != null
            ? DateFormat('dd.MM.yy').format(item.cuttingDate!)
            : '',
        item.origin ?? '',
        item.purposes.join(', '), // VEREINFACHT: direkte Liste
        item.otherPurpose ?? '', // NEU
        item.isMoonwood ? 'Ja' : 'Nein',
        item.isFSC ? 'Ja' : 'Nein', // NEU
        item.remarks ?? '',
        DateFormat('dd.MM.yy').format(item.timestamp),
      ]),
    ];

    // Konvertiere in CSV-String
    final csvString = const ListToCsvConverter(
      fieldDelimiter: ';', // Semikolon für bessere Excel-Kompatibilität
      textDelimiter: '"',
      textEndDelimiter: '"',
    ).convert(csvData);

    // BOM für Excel + CSV Daten
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)];
    return Uint8List.fromList(bytes);
  }
}