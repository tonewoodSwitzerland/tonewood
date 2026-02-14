// lib/customers/customer_export_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import 'customer.dart';
import 'customer_group/customer_group_service.dart';

// Gleiche Helper-Dateien wie beim Warehouse-Export verwenden!
// Pfad ggf. anpassen je nach deiner Ordnerstruktur
import '../warehouse/services/warehouse_export_helper_stub.dart'
if (dart.library.html) '../warehouse/services/warehouse_export_helper_web.dart'
if (dart.library.io) '../warehouse/services/warehouse_export_helper_mobile.dart';

class CustomerExportService {
  static Future<void> exportCustomersCsv(BuildContext context) async {
    final allGroups = await CustomerGroupService.getAllGroups();
    final groupNames = {for (var g in allGroups) g.id: g.name};

    try {
      // Ladeanzeige
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Daten abrufen
      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .get();

      final customers = snapshot.docs
          .map((doc) => Customer.fromMap(doc.data(), doc.id))
          .toList();

      final fileName =
          'Kundendatenbank_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv';

      // CSV aufbauen
      final StringBuffer csvContent = StringBuffer();

      // BOM für Excel UTF-8 Erkennung
      csvContent.write(String.fromCharCodes([0xFEFF]));

      final headers = [
        'ID',
        'Firma',
        'Vorname',
        'Nachname',
        'Straße',
        'PLZ',
        'Ort',
        'Land',
        'Zusatz',
        'Länderkürzel',
        'E-Mail',
        'Telefon 1',
        'Telefon 2',
        'MwSt-Nummer',
        'EORI-Nummer',
        'Sprache',
        'Weihnachtsbrief',
        'Notizen',
        'Abweichende Lieferadresse',
        'Liefer-Firma',
        'Liefer-Vorname',
        'Liefer-Nachname',
        'Liefer-Straße',
        'Liefer-Hausnummer',
        'Liefer-PLZ',
        'Liefer-Ort',
        'Liefer-Land',
        'Liefer-Länderkürzel',
        'Liefer-Telefon',
        'Liefer-E-Mail',
        'Kundengruppen',
      ];

      csvContent.writeln(headers.join(';'));

      for (final customer in customers) {
        final row = [
          _escapeCsvField(customer.id),
          _escapeCsvField(customer.company),
          _escapeCsvField(customer.firstName),
          _escapeCsvField(customer.lastName),
          _escapeCsvField(customer.street),
          _escapeCsvField(customer.zipCode),
          _escapeCsvField(customer.city),
          _escapeCsvField(customer.country),
          _escapeCsvField(customer.addressSupplement),
          _escapeCsvField(customer.countryCode),
          _escapeCsvField(customer.email),
          _escapeCsvField(customer.phone1),
          _escapeCsvField(customer.phone2),
          _escapeCsvField(customer.vatNumber),
          _escapeCsvField(customer.eoriNumber),
          _escapeCsvField(customer.language),
          customer.wantsChristmasCard ? 'JA' : 'NEIN',
          _escapeCsvField(customer.notes),
          customer.hasDifferentShippingAddress ? 'JA' : 'NEIN',
          _escapeCsvField(customer.shippingCompany),
          _escapeCsvField(customer.shippingFirstName),
          _escapeCsvField(customer.shippingLastName),
          _escapeCsvField(customer.shippingStreet),
          _escapeCsvField(customer.shippingHouseNumber),
          _escapeCsvField(customer.shippingZipCode),
          _escapeCsvField(customer.shippingCity),
          _escapeCsvField(customer.shippingCountry),
          _escapeCsvField(customer.shippingCountryCode),
          _escapeCsvField(customer.shippingPhone),
          _escapeCsvField(customer.shippingEmail),
          _escapeCsvField(
            customer.customerGroupIds
                .map((id) => groupNames[id] ?? 'Unbekannt')
                .join(', '),
          ),
        ];
        csvContent.writeln(row.join(';'));
      }

      // Dialog schließen
      Navigator.of(context, rootNavigator: true).pop();

      // Plattformübergreifend speichern/teilen
      final bytes = Uint8List.fromList(utf8.encode(csvContent.toString()));
      await saveAndShareFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'text/csv',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kundendatenbank wurde erfolgreich exportiert'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static String _escapeCsvField(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}