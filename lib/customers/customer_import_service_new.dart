import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class CustomerImportData {
  final String? kundenId;
  final String firma;
  final String vornameName; // "Vorname, Name" aus Excel
  final String? zusatz;
  final String strasseHausnummer;
  final String? bezirkPostfach;
  final String plzOrt;
  final String land;
  final String? laenderkuerzel;
  final String? email;
  final String? telefon1;
  final String? telefon2;
  final String? vatNumber;
  final String? eoriNumber;
  final String? sprache;
  final String? weihnachtskarte;
  final String? notizen;

  // Lieferadresse
  final String? abweichendeLieferadresse;
  final String? lieferFirma;
  final String? lieferVorname;
  final String? lieferNachname;
  final String? lieferZusatz;
  final String? lieferStrasse;
  final String? lieferHausnummer;
  final String? lieferBezirkPostfach;
  final String? lieferPlz;
  final String? lieferOrt;
  final String? lieferLand;
  final String? lieferLaenderkuerzel;
  final String? lieferTelefon;
  final String? lieferEmail;

  CustomerImportData({
    this.kundenId,
    required this.firma,
    required this.vornameName,
    this.zusatz,
    required this.strasseHausnummer,
    this.bezirkPostfach,
    required this.plzOrt,
    required this.land,
    this.laenderkuerzel,
    this.email,
    this.telefon1,
    this.telefon2,
    this.vatNumber,
    this.eoriNumber,
    this.sprache,
    this.weihnachtskarte,
    this.notizen,
    this.abweichendeLieferadresse,
    this.lieferFirma,
    this.lieferVorname,
    this.lieferNachname,
    this.lieferZusatz,
    this.lieferStrasse,
    this.lieferHausnummer,
    this.lieferBezirkPostfach,
    this.lieferPlz,
    this.lieferOrt,
    this.lieferLand,
    this.lieferLaenderkuerzel,
    this.lieferTelefon,
    this.lieferEmail,
  });

  // Konvertiert den Import-Datensatz in das Customer-Format
  Map<String, dynamic> toCustomerMap(String newId) {
    // Parse Straße und Hausnummer
    final streetParts = _parseStreetAndHouseNumber(strasseHausnummer);

    // Parse PLZ und Ort
    final plzOrtParts = _parsePlzAndCity(plzOrt);

    // Parse Lieferadresse PLZ und Ort falls vorhanden
    String? lieferPlzParsed;
    String? lieferOrtParsed;
    if (lieferPlz != null && lieferOrt != null) {
      lieferPlzParsed = lieferPlz;
      lieferOrtParsed = lieferOrt;
    }

    final hasShippingAddress = abweichendeLieferadresse?.toUpperCase() == 'JA' ||
        abweichendeLieferadresse?.toUpperCase() == 'YES';

    return {
      'id': newId,
      'name': vornameName.trim(), // Verwende vollen Namen
      'company': firma.trim(),
      'firstName': '', // Leer lassen
      'lastName': vornameName.trim(), // Ganzer Name im Nachnamen-Feld
      'street': streetParts['street'] ?? '',
      'houseNumber': streetParts['houseNumber'] ?? '',
      'zipCode': plzOrtParts['zipCode'] ?? '',
      'city': plzOrtParts['city'] ?? '',
      'province': null,
      'country': land.trim(),
      'countryCode': laenderkuerzel?.trim().toUpperCase() ?? _getCountryCode(land.trim()),
      'email': email?.trim() ?? '',
      'addressSupplement': zusatz?.trim(),
      'districtPOBox': bezirkPostfach?.trim(),
      'phone1': telefon1?.trim(),
      'phone2': telefon2?.trim(),
      'vatNumber': vatNumber?.trim(),
      'eoriNumber': eoriNumber?.trim(),
      'language': _parseLanguage(sprache),
      'wantsChristmasCard': _parseWeihnachtskarte(weihnachtskarte),
      'notes': notizen?.trim(),
      'hasDifferentShippingAddress': hasShippingAddress,
      'shippingCompany': hasShippingAddress ? lieferFirma?.trim() : null,
      'shippingFirstName': hasShippingAddress ? lieferVorname?.trim() : null,
      'shippingLastName': hasShippingAddress ? lieferNachname?.trim() : null,
      'shippingStreet': hasShippingAddress ? lieferStrasse?.trim() : null,
      'shippingHouseNumber': hasShippingAddress ? lieferHausnummer?.trim() : null,
      'shippingZipCode': hasShippingAddress ? lieferPlzParsed : null,
      'shippingCity': hasShippingAddress ? lieferOrtParsed : null,
      'shippingProvince': null,
      'shippingCountry': hasShippingAddress ? lieferLand?.trim() : null,
      'shippingCountryCode': hasShippingAddress
          ? (lieferLaenderkuerzel?.trim().toUpperCase() ?? _getCountryCode(lieferLand?.trim() ?? ''))
          : null,
      'shippingPhone': hasShippingAddress ? lieferTelefon?.trim() : null,
      'shippingEmail': hasShippingAddress ? lieferEmail?.trim() : null,
      'showCustomFieldOnDocuments': false,
      'showVatOnDocuments': false,
      'showEoriOnDocuments': false,
      'customFieldTitle': null,
      'customFieldValue': null,
      'additionalAddressLines': <String>[],
      'shippingAdditionalAddressLines': <String>[],
      'customerGroupIds': <String>[],
    };
  }

  Map<String, String?> _parseStreetAndHouseNumber(String combined) {
    if (combined.isEmpty) return {'street': '', 'houseNumber': ''};

    final trimmed = combined.trim();

    // Versuche Hausnummer am Ende zu finden (Zahlen eventuell mit Buchstaben)
    final regExp = RegExp(r'^(.+?)\s+(\d+[a-zA-Z]*)$');
    final match = regExp.firstMatch(trimmed);

    if (match != null) {
      return {
        'street': match.group(1)?.trim(),
        'houseNumber': match.group(2)?.trim(),
      };
    }

    // Wenn kein Match, gesamter String ist die Straße
    return {'street': trimmed, 'houseNumber': ''};
  }

  Map<String, String?> _parsePlzAndCity(String combined) {
    if (combined.isEmpty) return {'zipCode': '', 'city': ''};

    final trimmed = combined.trim();

    // Versuche PLZ am Anfang zu finden (mehrere Zahlen)
    final regExp = RegExp(r'^(\d{4,6})\s+(.+)$');
    final match = regExp.firstMatch(trimmed);

    if (match != null) {
      return {
        'zipCode': match.group(1)?.trim(),
        'city': match.group(2)?.trim(),
      };
    }

    // Wenn kein Match, ist alles die Stadt
    return {'zipCode': '', 'city': trimmed};
  }

  String _parseLanguage(String? sprache) {
    if (sprache == null || sprache.isEmpty) return 'DE';

    final upper = sprache.trim().toUpperCase();
    if (upper == 'DE' || upper == 'DEUTSCH' || upper == 'GERMAN') return 'DE';
    if (upper == 'EN' || upper == 'ENGLISCH' || upper == 'ENGLISH') return 'EN';
    if (upper == 'FR' || upper == 'FRANZÖSISCH' || upper == 'FRENCH') return 'FR';
    if (upper == 'IT' || upper == 'ITALIENISCH' || upper == 'ITALIAN') return 'IT';
    if (upper == 'ES' || upper == 'SPANISCH' || upper == 'SPANISH') return 'ES';

    return 'DE';
  }

  bool _parseWeihnachtskarte(String? value) {
    if (value == null || value.isEmpty) return true;

    final upper = value.trim().toUpperCase();
    return upper != 'NEIN' && upper != 'NO' && upper != 'N';
  }

  static String _getCountryCode(String country) {
    if (country.isEmpty) return '';

    final Map<String, String> countryCodes = {
      'Deutschland': 'DE',
      'Deutschland (Festland)': 'DE',
      'Germany': 'DE',
      'Schweiz': 'CH',
      'Switzerland': 'CH',
      'Österreich': 'AT',
      'Austria': 'AT',
      'Frankreich': 'FR',
      'France': 'FR',
      'Italien': 'IT',
      'Italy': 'IT',
      'Spanien': 'ES',
      'Spain': 'ES',
      'SPAIN': 'ES',
      'Espagna': 'ES',
      'España': 'ES',
      'Vereinigtes Königreich': 'GB',
      'United Kingdom': 'GB',
      'UK': 'GB',
      'Großbritannien': 'GB',
      'Great Britain': 'GB',
      'England': 'GB',
      'Niederlande': 'NL',
      'Netherlands': 'NL',
      'Belgien': 'BE',
      'Belgium': 'BE',
      'Luxemburg': 'LU',
      'Luxembourg': 'LU',
      'Dänemark': 'DK',
      'Denmark': 'DK',
      'Schweden': 'SE',
      'Sweden': 'SE',
      'Norwegen': 'NO',
      'Norway': 'NO',
      'Finnland': 'FI',
      'Finland': 'FI',
      'Portugal': 'PT',
      'Griechenland': 'GR',
      'Greece': 'GR',
      'Irland': 'IE',
      'Ireland': 'IE',
      'USA': 'US',
      'Vereinigte Staaten': 'US',
      'United States': 'US',
      'Kanada': 'CA',
      'Canada': 'CA',
      'Japan': 'JP',
      'Polen': 'PL',
      'Poland': 'PL',
      'Tschechien': 'CZ',
      'Czech Republic': 'CZ',
      'Ungarn': 'HU',
      'Hungary': 'HU',
      'Slowakei': 'SK',
      'Slovakia': 'SK',
      'Slowenien': 'SI',
      'Slovenia': 'SI',
      'Kroatien': 'HR',
      'Croatia': 'HR',
      'Rumänien': 'RO',
      'Romania': 'RO',
      'Bulgarien': 'BG',
      'Bulgaria': 'BG',
    };

    final normalizedCountry = country.trim().toLowerCase();
    for (final entry in countryCodes.entries) {
      if (normalizedCountry == entry.key.toLowerCase()) {
        return entry.value;
      }
    }

    return '';
  }

  // Getter für Vorschau-Anzeige
  String get displayName {
    if (vornameName.isNotEmpty && firma.isNotEmpty) {
      return '$vornameName ($firma)';
    } else if (vornameName.isNotEmpty) {
      return vornameName;
    } else if (firma.isNotEmpty) {
      return firma;
    } else {
      return 'Unbekannt';
    }
  }

  String get displayAddress {
    final parts = <String>[];
    if (strasseHausnummer.isNotEmpty) parts.add(strasseHausnummer);
    if (plzOrt.isNotEmpty) parts.add(plzOrt);
    if (land.isNotEmpty) parts.add(land);
    return parts.isNotEmpty ? parts.join(', ') : 'Keine Adresse';
  }
}

class CustomerImportService {
  static Future<List<CustomerImportData>> parseExcelFile(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        throw Exception('Keine Tabelle in der Excel-Datei gefunden');
      }

      final List<CustomerImportData> customers = [];

      // Überspringe Header (Zeile 0) und leere Zeilen
      for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];

        // Überspringe komplett leere Zeilen
        if (row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        try {
          final firma = _getCellValue(row, 1) ?? '';
          final vornameName = _getCellValue(row, 2) ?? '';

          // Überspringe Zeilen ohne Firma UND ohne Name
          if (firma.isEmpty && vornameName.isEmpty) {
            debugPrint('Überspringe Zeile ${rowIndex + 1}: Weder Firma noch Name vorhanden');
            continue;
          }

          final importData = CustomerImportData(
            kundenId: _getCellValue(row, 0),
            firma: firma,
            vornameName: vornameName,
            zusatz: _getCellValue(row, 3),
            strasseHausnummer: _getCellValue(row, 4) ?? '',
            bezirkPostfach: _getCellValue(row, 5),
            plzOrt: _getCellValue(row, 6) ?? '',
            land: _getCellValue(row, 7) ?? '',
            laenderkuerzel: _getCellValue(row, 8),
            email: _getCellValue(row, 9),
            telefon1: _getCellValue(row, 10),
            telefon2: _getCellValue(row, 11),
            vatNumber: _getCellValue(row, 12),
            eoriNumber: _getCellValue(row, 13),
            sprache: _getCellValue(row, 14),
            weihnachtskarte: _getCellValue(row, 15),
            notizen: _getCellValue(row, 16),
            abweichendeLieferadresse: _getCellValue(row, 17),
            lieferFirma: _getCellValue(row, 18),
            lieferVorname: _getCellValue(row, 19),
            lieferNachname: _getCellValue(row, 20),
            lieferZusatz: _getCellValue(row, 21),
            lieferStrasse: _getCellValue(row, 22),
            lieferHausnummer: _getCellValue(row, 23),
            lieferBezirkPostfach: _getCellValue(row, 24),
            lieferPlz: _getCellValue(row, 25),
            lieferOrt: _getCellValue(row, 26),
            lieferLand: _getCellValue(row, 27),
            lieferLaenderkuerzel: _getCellValue(row, 28),
            lieferTelefon: _getCellValue(row, 29),
            lieferEmail: _getCellValue(row, 30),
          );

          customers.add(importData);
        } catch (e) {
          debugPrint('Fehler beim Parsen von Zeile ${rowIndex + 1}: $e');
        }
      }

      return customers;
    } catch (e) {
      debugPrint('Fehler beim Lesen der Excel-Datei: $e');
      rethrow;
    }
  }

  static String? _getCellValue(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null || cell.value == null) return null;
    return cell.value.toString().trim();
  }

  static Future<Map<String, dynamic>> importCustomers(
      List<CustomerImportData> customers, {
        Function(int current, int total)? onProgress,
      }) async {
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    int batchCount = 0;
    const maxBatchSize = 500;

    for (int i = 0; i < customers.length; i++) {
      try {
        final customer = customers[i];

        // Generiere neue ID
        final newId = const Uuid().v4();

        // Konvertiere zu Customer-Map
        final customerMap = customer.toCustomerMap(newId);

        // Füge zum Batch hinzu
        final docRef = firestore.collection('customers').doc(newId);
        batch.set(docRef, customerMap);

        batchCount++;

        // Wenn Batch voll ist, committen
        if (batchCount >= maxBatchSize) {
          await batch.commit();
          batchCount = 0;
        }

        successCount++;

        if (onProgress != null) {
          onProgress(i + 1, customers.length);
        }
      } catch (e) {
        errorCount++;
        errors.add('Zeile ${i + 2}: $e');
        debugPrint('Fehler beim Import von Kunde ${i + 1}: $e');
      }
    }

    // Restliche Batch committen
    if (batchCount > 0) {
      await batch.commit();
    }

    return {
      'success': successCount,
      'errors': errorCount,
      'errorMessages': errors,
    };
  }
}