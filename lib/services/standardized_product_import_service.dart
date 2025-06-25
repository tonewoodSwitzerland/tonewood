import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class StandardizedProductImportService {
  static Future<void> showImportDialog(BuildContext context, VoidCallback onComplete) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Standardprodukte importieren'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wählen Sie eine CSV-Datei mit Standardprodukten aus.\n\n'
                    'Die Datei sollte folgende Spalten enthalten:\n'
                    '• Artikelnummer (4-stellig)\n'
                    '• Produkt\n'
                    '• Instrument\n'
                    '• Teile\n'
                    '• Maße (x\', x+, x\'\', y\', y+, y\'\', z, z2)\n'
                    '• Dickeklasse\n'
                    '• Volumen (optional)',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Achtung: Bestehende Produkte mit gleicher Artikelnummer werden überschrieben!',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                // Starte den Import direkt mit dem Root-Context
                await _importFromFile(context, onComplete, dialogContext);
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Datei auswählen'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _importFromFile(BuildContext context, VoidCallback onComplete, [BuildContext? dialogContext]) async {
    try {
      print('StandardizedProductImport: Starte Dateiauswahl...');

      // Schließe den Dialog erst NACH der Dateiauswahl
      if (dialogContext != null && Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }

      // Datei auswählen
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      print('StandardizedProductImport: Dateiauswahl abgeschlossen. Result: ${result != null}');

      if (result == null || result.files.isEmpty) {
        print('StandardizedProductImport: Keine Datei ausgewählt');
        return;
      }

      print('StandardizedProductImport: Datei ausgewählt: ${result.files.first.name}');
      print('StandardizedProductImport: Dateigröße: ${result.files.first.size} bytes');

      // Zeige Ladeindikator mit neuem Context
      if (!context.mounted) {
        print('StandardizedProductImport: Context nicht mehr gemounted!');
        return;
      }

      print('StandardizedProductImport: Zeige Ladeindikator...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext loadingContext) {
          return WillPopScope(
            onWillPop: () async => false,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Importiere Produkte...'),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      // Lese Dateiinhalt
      String csvContent;
      if (kIsWeb) {
        print('StandardizedProductImport: Web-Plattform erkannt');
        // Web: Verwende bytes
        final bytes = result.files.first.bytes;
        if (bytes == null) {
          throw Exception('Konnte Datei nicht lesen');
        }
        // Versuche verschiedene Encodings
        try {
          csvContent = utf8.decode(bytes);
        } catch (e) {
          print('StandardizedProductImport: UTF-8 Dekodierung fehlgeschlagen, versuche Latin1');
          csvContent = latin1.decode(bytes);
        }
        print('StandardizedProductImport: CSV-Inhalt gelesen (${csvContent.length} Zeichen)');
      } else {
        print('StandardizedProductImport: Mobile Plattform erkannt');
        // Mobile: Lese Datei
        final path = result.files.first.path;
        print('StandardizedProductImport: Dateipfad: $path');

        if (path == null) {
          throw Exception('Dateipfad ist null');
        }

        final file = File(path);
        print('StandardizedProductImport: File exists: ${await file.exists()}');

        // Versuche verschiedene Encodings
        try {
          csvContent = await file.readAsString(encoding: utf8);
        } catch (e) {
          print('StandardizedProductImport: UTF-8 Dekodierung fehlgeschlagen, versuche Latin1');
          csvContent = await file.readAsString(encoding: latin1);
        }
        print('StandardizedProductImport: CSV-Inhalt gelesen (${csvContent.length} Zeichen)');
      }

      // Entferne BOM falls vorhanden
      if (csvContent.startsWith('\uFEFF')) {
        print('StandardizedProductImport: BOM gefunden und entfernt');
        csvContent = csvContent.substring(1);
      }

      print('StandardizedProductImport: Erste 200 Zeichen: ${csvContent.substring(0, csvContent.length > 200 ? 200 : csvContent.length)}');

      // Parse CSV mit angepassten Einstellungen für deutsche CSV-Dateien
      print('StandardizedProductImport: Parse CSV...');
      final List<List<dynamic>> rows = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        textEndDelimiter: '"',
        eol: '\r\n',  // oder '\n' oder '\r' - je nach Datei
      ).convert(csvContent);
      print('StandardizedProductImport: CSV geparst. Anzahl Zeilen: ${rows.length}');

      if (rows.isEmpty) {
        throw Exception('CSV-Datei ist leer');
      }

      // Bereinige die Daten von Zeilenumbrüchen in Zellen
      final cleanedRows = <List<dynamic>>[];
      for (var row in rows) {
        if (row.isNotEmpty && row[0] != null && row[0].toString().trim().isNotEmpty) {
          // Bereinige jede Zelle von Zeilenumbrüchen
          final cleanedRow = row.map((cell) {
            if (cell == null) return cell;
            return cell.toString().replaceAll('\r', '').replaceAll('\n', ' ').trim();
          }).toList();
          cleanedRows.add(cleanedRow);
        }
      }

      print('StandardizedProductImport: Bereinigte Zeilen: ${cleanedRows.length}');

      if (cleanedRows.isNotEmpty) {
        print('StandardizedProductImport: Erste Zeile (Header): ${cleanedRows[0]}');
      }
      if (cleanedRows.length > 1) {
        print('StandardizedProductImport: Zweite Zeile (Daten): ${cleanedRows[1]}');
      }

      // Verarbeite Daten
      print('StandardizedProductImport: Verarbeite Import-Daten...');
      final importResults = await _processImportData(cleanedRows);

      print('StandardizedProductImport: Import abgeschlossen. Importiert: ${importResults.imported}, Aktualisiert: ${importResults.updated}, Fehler: ${importResults.errors}');

      // Schließe Ladeindikator
      if (context.mounted) {
        print('StandardizedProductImport: Schließe Ladeindikator...');
        Navigator.pop(context);
      }

      // Zeige Ergebnis
      if (context.mounted) {
        print('StandardizedProductImport: Zeige Ergebnis-Dialog...');
        _showImportResult(context, importResults, onComplete);
      }

    } catch (e, stackTrace) {
      print('StandardizedProductImport: FEHLER: $e');
      print('StandardizedProductImport: Stack trace: $stackTrace');

      // Schließe Ladeindikator falls noch offen
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Zeige Fehler
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Import: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<ImportResult> _processImportData(List<List<dynamic>> rows) async {
    int imported = 0;
    int updated = 0;
    int errors = 0;
    List<String> errorMessages = [];

    print('StandardizedProductImport._processImportData: Starte mit ${rows.length} Zeilen');

    // Überspringe Header-Zeile
    for (int i = 1; i < rows.length; i++) {
      try {
        final row = rows[i];
        print('StandardizedProductImport._processImportData: Verarbeite Zeile $i: $row');

        // Validiere Zeilenlänge
        if (row.length < 13) {
          throw Exception('Zeile hat nur ${row.length} Spalten (mindestens 13 erforderlich)');
        }

        // Parse Daten aus CSV
        final articleNumber = row[0]?.toString().trim() ?? '';
        print('StandardizedProductImport._processImportData: Artikelnummer: $articleNumber');

        if (articleNumber.isEmpty) {
          print('StandardizedProductImport._processImportData: Überspringe leere Zeile');
          continue;
        }

        if (articleNumber.length != 4 || !RegExp(r'^\d{4}$').hasMatch(articleNumber)) {
          throw Exception('Artikelnummer "$articleNumber" muss 4-stellig und numerisch sein');
        }

        final productName = row[1]?.toString().trim() ?? '';
        final instrument = row[2]?.toString().trim() ?? '';
        final parts = _parseIntOrDefault(row[3], 1);

        print('StandardizedProductImport._processImportData: Produkt: $productName, Instrument: $instrument, Teile: $parts');

        // Dimensionen
        final lengthStandard = _parseDoubleOrDefault(row[4], 0) ?? 0;
        final lengthAddition = _parseDoubleOrDefault(row[5], 0) ?? 0;
        final lengthWithAddition = _parseDoubleOrDefault(row[6], lengthStandard + lengthAddition) ?? (lengthStandard + lengthAddition);

        final widthStandard = _parseDoubleOrDefault(row[7], 0) ?? 0;
        final widthAddition = _parseDoubleOrDefault(row[8], 0) ?? 0;
        final widthWithAddition = _parseDoubleOrDefault(row[9], widthStandard + widthAddition) ?? (widthStandard + widthAddition);

        final thicknessValue = _parseDoubleOrDefault(row[10], 0) ?? 0;
        final thicknessValue2 = row.length > 11 && row[11] != null && row[11].toString().trim().isNotEmpty
            ? _parseDoubleOrDefault(row[11], null)
            : null;

        final thicknessClass = row.length > 12 ? _parseIntOrDefault(row[12], 1) : 1;

        // Volumen berechnen oder aus CSV lesen
        double mm3Standard, mm3WithAddition, dm3Standard, dm3WithAddition;

        if (row.length >= 17) {
          // Volumen aus CSV
          mm3Standard = _parseDoubleOrDefault(row[15], 0) ?? 0;
          mm3WithAddition = _parseDoubleOrDefault(row[16], 0) ?? 0;
          dm3Standard = row.length > 17 ? (_parseDoubleOrDefault(row[17], 0) ?? mm3Standard / 1000000) : mm3Standard / 1000000;
          dm3WithAddition = row.length > 18 ? (_parseDoubleOrDefault(row[18], 0) ?? mm3WithAddition / 1000000) : mm3WithAddition / 1000000;
        } else {
          // Volumen berechnen
          mm3Standard = lengthStandard * widthStandard * thicknessValue * parts;
          mm3WithAddition = lengthWithAddition * widthWithAddition * thicknessValue * parts;
          dm3Standard = mm3Standard / 1000000;
          dm3WithAddition = mm3WithAddition / 1000000;
        }

        // Maßtext generieren
        String measurementStandard, measurementWithAddition;
        if (row.length >= 15 && row[13] != null && row[13].toString().trim().isNotEmpty) {
          measurementStandard = row[13].toString().trim();
          measurementWithAddition = row[14]?.toString().trim() ?? measurementStandard;
        } else {
          measurementStandard = '$parts# ${lengthStandard.toStringAsFixed(0)}×${widthStandard.toStringAsFixed(0)}×$thicknessValue';
          measurementWithAddition = '$parts# ${lengthWithAddition.toStringAsFixed(0)}×${widthWithAddition.toStringAsFixed(0)}×$thicknessValue';
        }

        // Erstelle Produkt-Objekt
        final productData = {
          'articleNumber': articleNumber,
          'productName': productName,
          'instrument': instrument,
          'parts': parts,
          'dimensions': {
            'length': {
              'standard': lengthStandard,
              'addition': lengthAddition,
              'withAddition': lengthWithAddition,
            },
            'width': {
              'standard': widthStandard,
              'addition': widthAddition,
              'withAddition': widthWithAddition,
            },
            'thickness': {
              'value': thicknessValue,
              if (thicknessValue2 != null) 'value2': thicknessValue2,
            },
          },
          'thicknessClass': thicknessClass,
          'measurementText': {
            'standard': measurementStandard,
            'withAddition': measurementWithAddition,
          },
          'volume': {
            'mm3_standard': mm3Standard,
            'mm3_withAddition': mm3WithAddition,
            'dm3_standard': dm3Standard,
            'dm3_withAddition': dm3WithAddition,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Prüfe ob Produkt bereits existiert
        final existingDocs = await FirebaseFirestore.instance
            .collection('standardized_products')
            .where('articleNumber', isEqualTo: articleNumber)
            .get();

        if (existingDocs.docs.isNotEmpty) {
          // Update existierendes Produkt
          await FirebaseFirestore.instance
              .collection('standardized_products')
              .doc(existingDocs.docs.first.id)
              .update(productData);
          updated++;
        } else {
          // Erstelle neues Produkt
          productData['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance
              .collection('standardized_products')
              .add(productData);
          imported++;
        }

      } catch (e) {
        errors++;
        errorMessages.add('Zeile ${i + 1}: $e');

        // Stoppe nach 10 Fehlern
        if (errorMessages.length >= 10) {
          errorMessages.add('... und weitere Fehler');
          break;
        }
      }
    }

    return ImportResult(
      imported: imported,
      updated: updated,
      errors: errors,
      errorMessages: errorMessages,
    );
  }

  static double? _parseDoubleOrDefault(dynamic value, double? defaultValue) {
    if (value == null || value.toString().trim().isEmpty) {
      return defaultValue;
    }

    // Bereinige den String
    String str = value.toString().trim();

    // Entferne Tausendertrennzeichen (Punkte in deutschen Zahlen)
    str = str.replaceAll('.', '');

    // Ersetze Komma durch Punkt als Dezimaltrennzeichen
    str = str.replaceAll(',', '.');

    // Entferne alle nicht-numerischen Zeichen außer Punkt und Minus
    str = str.replaceAll(RegExp(r'[^\d.-]'), '');

    return double.tryParse(str) ?? defaultValue;
  }

  static int _parseIntOrDefault(dynamic value, int defaultValue) {
    if (value == null || value.toString().trim().isEmpty) {
      return defaultValue;
    }
    final str = value.toString().trim();
    return int.tryParse(str) ?? defaultValue;
  }

  static void _showImportResult(BuildContext context, ImportResult result, VoidCallback onComplete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import abgeschlossen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Neue Produkte importiert: ${result.imported}'),
                Text('Bestehende Produkte aktualisiert: ${result.updated}'),
                if (result.errors > 0) ...[
                  Text(
                    'Fehler: ${result.errors}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  if (result.errorMessages.isNotEmpty) ...[
                    const Text(
                      'Fehlermeldungen:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...result.errorMessages.map((msg) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $msg',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onComplete();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class ImportResult {
  final int imported;
  final int updated;
  final int errors;
  final List<String> errorMessages;

  ImportResult({
    required this.imported,
    required this.updated,
    required this.errors,
    required this.errorMessages,
  });
}