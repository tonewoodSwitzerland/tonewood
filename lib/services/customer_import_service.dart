import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/customer.dart';
import 'icon_helper.dart';

class CustomerImportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Zeigt einen Dialog zum Importieren von Kundendaten aus CSV
  static Future<void> showImportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
             getAdaptiveIcon(iconName: 'upload_file',defaultIcon:Icons.upload_file, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Kundendaten importieren'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wählen Sie eine CSV-Datei zum Importieren von Kundendaten.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                       getAdaptiveIcon(iconName: 'info', defaultIcon:Icons.info, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'CSV-Format:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Trennzeichen: Komma (,) oder Semikolon (;)\n'
                        '• Textqualifizierer: Anführungszeichen (")\n'
                        '• Kodierung: UTF-8\n'
                        '• Erste Zeile: Spaltenüberschriften',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                       getAdaptiveIcon(iconName: 'warning',defaultIcon:Icons.warning, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Wichtige Hinweise:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Leere Zeilen werden übersprungen\n'
                        '• Bestehende Kunden werden nicht überschrieben\n'
                        '• Backup Ihrer Daten wird empfohlen',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _pickAndImportFile(context);
            },
            icon: getAdaptiveIcon(iconName: 'upload',defaultIcon:Icons.upload),
            label: const Text('CSV-Datei auswählen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Datei auswählen und importieren
  static Future<void> _pickAndImportFile(BuildContext context) async {
    try {
      print("test22");
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        print("test5");
        final file = result.files.first;

        if (kIsWeb) {
          await _importFromBytes(context, file.bytes!, file.name);
        } else {
          await _importFromFile(context, File(file.path!), file.name);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Fehler beim Dateizugriff: $e');
      }
    }
  }


  static Future<void> _importFromBytes(BuildContext context, Uint8List bytes, String fileName) async {
    try {
      final csvString = utf8.decode(bytes);
      await _processCsvData(context, csvString, fileName);
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Fehler beim Lesen der Datei: $e');
      }
    }
  }
  static Future<void> _importFromFile(BuildContext context, File file, String fileName) async {
    try {
      print("DEBUG: Start Import von $fileName");

      String csvString;
      try {
        csvString = await file.readAsString();
        print("DEBUG: Datei gelesen, Länge: ${csvString.length}");
      } catch (e) {
        throw e;
      }

      await _processCsvData(context, csvString, fileName);

    } catch (e) {
      print("DEBUG: Fehler beim Import: $e");
      if (context.mounted) {
        _showErrorDialog(context, 'Fehler beim Lesen der Datei: $e');
      }
    }
  }

  static Future<void> _processCsvData(BuildContext context, String csvString, String fileName) async {
    try {
      print('DEBUG: Starte CSV-Verarbeitung');

      if (csvString.trim().isEmpty) {
        _showErrorDialog(context, 'Die CSV-Datei ist leer.');
        return;
      }

      final List<List<String>> csvData = _parseCsv(csvString);

      if (csvData.isEmpty) {
        _showErrorDialog(context, 'Die CSV-Datei konnte nicht gelesen werden.');
        return;
      }

      final List<String> headers = csvData.first;
      final Map<String, int> columnMapping = _analyzeHeaders(headers);

      if (columnMapping.isEmpty) {
        _showErrorDialog(context, 'Keine erkannten Spalten gefunden.');
        return;
      }

      // Daten importieren
      final List<Customer> customers = [];
      int errorCount = 0;
      int skippedRows = 0;

      for (int i = 1; i < csvData.length; i++) {
        try {
          final customer = _parseCustomerFromRow(csvData[i], columnMapping);
          if (customer != null) {
            customers.add(customer);
          } else {
            skippedRows++;
          }
        } catch (e) {
          errorCount++;
          print('DEBUG: Fehler in Zeile ${i + 1}: $e');
        }
      }

      print('DEBUG: ${customers.length} Kunden gefunden');

      if (customers.isEmpty) {
        _showErrorDialog(context, 'Keine gültigen Kundendaten gefunden.');
        return;
      }

      // EINFACH DIREKT IMPORTIEREN - KEINE BESTÄTIGUNG
      print('DEBUG: Starte direkten Import...');
      await _saveCustomersToFirestore(context, customers);

    } catch (e) {
      print('DEBUG: Fehler in _processCsvData: $e');
      _showErrorDialog(context, 'Fehler beim Verarbeiten: $e');
    }
  }

  /// CSV-String parsen
  static List<List<String>> _parseCsv(String csvString) {
    try {
      final List<List<String>> result = [];
      final lines = csvString.split('\n');

      print('DEBUG: Anzahl Zeilen in CSV: ${lines.length}');

      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        String line = lines[lineIndex].trim();
        if (line.isEmpty) continue;

        // WICHTIG: Deine CSV verwendet Semikolon als Haupttrennzeichen
        final List<String> row = line.split(';').map((field) => field.trim()).toList();

        if (lineIndex < 5) { // Debug nur erste 5 Zeilen
          print('DEBUG: Zeile $lineIndex: "$line"');
          print('DEBUG: Parsed Row: $row');
        }

        if (row.isNotEmpty) {
          result.add(row);
        }
      }

      return result;
    } catch (e) {
      print('ERROR: CSV-Parser Fehler: $e');
      return [];
    }
  }

  /// Header-Analyse für Spalten-Mapping
  static Map<String, int> _analyzeHeaders(List<String> headers) {
    final Map<String, int> mapping = {};

    print('DEBUG: Analysiere Headers: $headers');

    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase().trim();
      print('DEBUG: Header $i: "$header"');

      // KORRIGIERT: Richtige Zuordnung nach deiner CSV-Struktur
      if (header == 'firma') {
        mapping['company'] = i;
      } else if (header == 'vorname, name') {
        // Das ist ein kombiniertes Feld - wir nehmen es als firstName
        mapping['firstName'] = i;
      } else if (header == 'zusatz') {
        mapping['addressSupplement'] = i;
      } else if (header == 'strasse + hausnummer') {
        mapping['street'] = i;
      } else if (header == 'bezirk/postfach etc') {
        mapping['districtPOBox'] = i;
      } else if (header == 'plz und ort') {
        mapping['zipCode'] = i; // Wird später getrennt
      } else if (header == 'land') {
        mapping['country'] = i;
      } else if (header == 'länderkürzel') {
        mapping['countryCode'] = i;
      } else if (header == 'e-mail') {
        mapping['email'] = i;
      } else if (header == 'telefon 1') {
        mapping['phone1'] = i;
      } else if (header == 'telefon 2') {
        mapping['phone2'] = i;
      } else if (header == 'mwst-nr / uid') {
        mapping['vatNumber'] = i;
      } else if (header == 'eori nr.') {
        mapping['eoriNumber'] = i;
      } else if (header == 'sprache') {
        mapping['language'] = i;
      } else if (header == 'weihnachtskarte') {
        mapping['wantsChristmasCard'] = i;
      } else if (header == 'notizen') {
        mapping['notes'] = i;
      }
      // Lieferadresse - KORRIGIERT
      else if (header == 'liefer-firma') {
        mapping['shippingCompany'] = i;
      } else if (header == 'liefer-vorname') {
        mapping['shippingFirstName'] = i;
      } else if (header == 'liefer-nachname') {
        mapping['shippingLastName'] = i;
      } else if (header == 'liefer-strasse') {
        mapping['shippingStreet'] = i;
      } else if (header == 'liefer-hausnummer') {
        mapping['shippingHouseNumber'] = i;
      } else if (header == 'liefer-plz') {
        mapping['shippingZipCode'] = i;
      } else if (header == 'liefer-ort') {
        mapping['shippingCity'] = i;
      } else if (header == 'liefer-land') {
        mapping['shippingCountry'] = i;
      } else if (header == 'liefer-länderkürzel') {
        mapping['shippingCountryCode'] = i;
      } else if (header == 'liefer-telefonnummer') {
        mapping['shippingPhone'] = i;
      } else if (header == 'liefer-email') {
        mapping['shippingEmail'] = i;
      }
    }

    print('DEBUG: Finale Spalten-Mappings: $mapping');
    return mapping;
  }

  /// Customer aus CSV-Zeile parsen
  /// Customer aus CSV-Zeile parsen
  /// Customer aus CSV-Zeile parsen
  /// Customer aus CSV-Zeile parsen
  static Customer? _parseCustomerFromRow(List<String> row, Map<String, int> mapping) {
    try {
      final getValue = (String field) {
        final index = mapping[field];
        if (index == null || index >= row.length) return null;
        final value = row[index].trim();
        return value.isEmpty ? null : value;
      };

      final company = getValue('company') ?? '';
      final firstNameRaw = getValue('firstName') ?? ''; // Das ist "Vorname, Name"
      final email = getValue('email') ?? '';

      // "Vorname, Name" Feld aufteilen
      String firstName = '';
      String lastName = '';
      if (firstNameRaw.isNotEmpty) {
        final parts = firstNameRaw.split(' ');
        if (parts.isNotEmpty) {
          firstName = parts[0];
          if (parts.length > 1) {
            lastName = parts.sublist(1).join(' ');
          }
        }
      }

      // PLZ und Ort trennen
      String zipCode = '';
      String city = '';
      final zipAndCity = getValue('zipCode') ?? '';
      if (zipAndCity.isNotEmpty) {
        final parts = zipAndCity.split(' ');
        if (parts.isNotEmpty) {
          zipCode = parts[0];
          if (parts.length > 1) {
            city = parts.sublist(1).join(' ');
          }
        }
      }

      // GEÄNDERT: Nur überspringen wenn ALLE wichtigen Felder leer sind
      if (company.isEmpty && firstName.isEmpty && lastName.isEmpty && email.isEmpty) {
        print('DEBUG: Zeile komplett leer - übersprungen');
        return null;
      }

      // GEÄNDERT: Auch Kunden ohne Email importieren
      // if (email.isEmpty) {
      //   print('DEBUG: Zeile ohne Email - aber trotzdem importieren');
      // }

      // Prüfen ob Lieferadresse verwendet wird
      final hasShippingAddress = getValue('shippingStreet')?.isNotEmpty == true ||
          getValue('shippingCity')?.isNotEmpty == true ||
          getValue('shippingCompany')?.isNotEmpty == true;

      print('DEBUG: Erstelle Customer - Company: "$company", FirstName: "$firstName", LastName: "$lastName", Email: "$email"');

      return Customer(
        id: '', // Wird von Firestore generiert
        name: company.isNotEmpty ? company : '$firstName $lastName'.trim(),
        company: company,
        firstName: firstName,
        lastName: lastName,
        addressSupplement: getValue('addressSupplement'),
        street: getValue('street') ?? '',
        houseNumber: '', // Ist in "Strasse + Hausnummer" kombiniert
        districtPOBox: getValue('districtPOBox'),
        zipCode: zipCode,
        city: city,
        country: getValue('country') ?? '',
        countryCode: getValue('countryCode'),
        email: email, // Auch wenn leer
        phone1: getValue('phone1'),
        phone2: getValue('phone2'),
        vatNumber: getValue('vatNumber'),
        eoriNumber: getValue('eoriNumber'),
        language: getValue('language') ?? 'DE',
        wantsChristmasCard: _parseBool(getValue('wantsChristmasCard')),
        notes: getValue('notes'),
        hasDifferentShippingAddress: hasShippingAddress,
        shippingCompany: getValue('shippingCompany'),
        shippingFirstName: getValue('shippingFirstName'),
        shippingLastName: getValue('shippingLastName'),
        shippingStreet: getValue('shippingStreet'),
        shippingHouseNumber: getValue('shippingHouseNumber'),
        shippingZipCode: getValue('shippingZipCode'),
        shippingCity: getValue('shippingCity'),
        shippingCountry: getValue('shippingCountry'),
        shippingCountryCode: getValue('shippingCountryCode'),
        shippingPhone: getValue('shippingPhone'),
        shippingEmail: getValue('shippingEmail'),
      );
    } catch (e) {
      debugPrint('Fehler beim Parsen der Zeile: $e');
      return null;
    }
  }

  /// Boolean-Werte parsen
  static bool _parseBool(String? value) {
    if (value == null) return false;
    final lower = value.toLowerCase();
    return lower == 'ja' || lower == 'yes' || lower == 'true' || lower == '1' || lower == 'wahr';
  }

  static Future<void> _saveCustomersToFirestore(BuildContext context, List<Customer> customers) async {
    try {
      print('DEBUG: Speichere ${customers.length} Kunden in Firestore');

      int savedCount = 0;

      for (int i = 0; i < customers.length; i++) {
        try {
          await _firestore.collection('customers').add(customers[i].toMap());
          savedCount++;

          if (savedCount % 50 == 0) {
            print('DEBUG: $savedCount von ${customers.length} gespeichert');
          }
        } catch (e) {
          print('FEHLER: Kunde ${i + 1} nicht gespeichert: $e');
        }
      }

      print('DEBUG: Import fertig - $savedCount Kunden gespeichert');
      _showSuccessDialog(context, savedCount);

    } catch (e) {
      print('DEBUG: Speicher-Fehler: $e');
      _showErrorDialog(context, 'Fehler beim Speichern: $e');
    }
  }


  /// Import-Bestätigung
  static Future<bool?> _showImportConfirmation(
      BuildContext context,
      int customerCount,
      int errorCount,
      String fileName,
      ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import-Bestätigung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datei: $fileName'),
            const SizedBox(height: 8),
            Text('Gefundene Kunden: $customerCount'),
            if (errorCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Fehlerhafte Zeilen: $errorCount',
                style: const TextStyle(color: Colors.orange),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Möchten Sie diese Kunden importieren?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
  }


  /// Dialog für teilweisen Erfolg
  static void _showPartialSuccessDialog(BuildContext context, int savedCount, int failedCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
             getAdaptiveIcon(iconName: 'warning',defaultIcon:Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Import teilweise erfolgreich'),
          ],
        ),
        content: Text(
          'Erfolgreich importiert: $savedCount Kunden\n'
              'Fehlgeschlagen: $failedCount Kunden\n\n'
              'Überprüfen Sie die Konsole für Details zu den fehlgeschlagenen Importen.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  /// Erfolgs-Dialog
  static void _showSuccessDialog(BuildContext context, int savedCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
             getAdaptiveIcon(iconName: 'check_circle',defaultIcon:Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            const Text('Import erfolgreich'),
          ],
        ),
        content: Text(
          '$savedCount Kunden wurden erfolgreich importiert.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Fehler-Dialog
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(iconName: 'error',defaultIcon:Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('Fehler'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}