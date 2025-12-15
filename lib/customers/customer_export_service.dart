import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../constants.dart';
import 'customer.dart';
import 'customer_group/customer_group_service.dart';

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

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final StringBuffer csvContent = StringBuffer();


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

      // Datensätze
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
                  .join(', ')
          ),
        ];
        csvContent.writeln(row.join(';'));
      }

      await file.writeAsBytes(csvContent.toString().codeUnits);

      Navigator.of(context, rootNavigator: true).pop();

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      Future.delayed(const Duration(minutes: 1), () => file.delete());

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
