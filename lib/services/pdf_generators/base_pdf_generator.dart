// File: services/pdf_generators/base_pdf_generator.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class BasePdfGenerator {
  // Gemeinsame Formatierungslogik
  static String formatCurrency(double amount, String currency, Map<String, double> exchangeRates) {
    double convertedAmount = amount;
    if (currency != 'CHF') {
      convertedAmount = amount * exchangeRates[currency]!;
    }
    return '${convertedAmount.toStringAsFixed(2)} $currency';
  }

  // Gemeinsame Header-Erstellung
// Gemeinsame Header-Erstellung
  static pw.Widget buildHeader({
    required String documentTitle,
    required String documentNumber,
    required DateTime date,
    required pw.MemoryImage logo,
    String? costCenter,
    String language = 'DE',
    String? additionalReference, // NEU
    String? secondaryReference, // NEU
  }) {
    // Übersetzungsfunktion für Header
    String getHeaderTranslation(String key, String lang) {
      final translations = {
        'DE': {
          'QUOTE': 'OFFERTE',
          'LIEFERSCHEIN': 'LIEFERSCHEIN',
          'INVOICE': 'RECHNUNG',
          'ORDER': 'BESTELLUNG',
          'nr': 'Nr.:',
          'date': 'Datum:',
          'cost_center': 'Kst-Nr.',
          'invoice': 'RECHNUNG',
          'quote_nr': 'Angebotsnr.:',
          'invoice_nr': 'Rechnungsnr.:',
          'order_nr': 'Auftragsnr.:',
        },
        'EN': {
          'QUOTE': 'QUOTE',
          'LIEFERSCHEIN': 'DELIVERY NOTE',
          'INVOICE': 'INVOICE',
          'ORDER': 'ORDER',
          'nr': 'No.:',
          'date': 'Date:',
          'cost_center': 'Cost Center',
          'invoice': 'INVOICE',
          'quote_nr': 'Quote No.:',
          'invoice_nr': 'Invoice No.:',
          'order_nr': 'Order No.:',
        }
      };
      return translations[lang]?[key] ?? translations['DE']?[key] ?? key;
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              getHeaderTranslation(documentTitle.toUpperCase().replaceAll(' ', '_'), language),
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '${getHeaderTranslation('nr', language)} $documentNumber',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
            ),

            // NEU: Zusätzliche Referenzen
            if (additionalReference != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                additionalReference,
                style:  pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blueGrey600,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
            if (secondaryReference != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                secondaryReference,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],

            pw.SizedBox(height: 4),
            pw.Text(
              '${getHeaderTranslation('date', language)} ${DateFormat('dd.MM.yyyy').format(date)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
            ),
            if (costCenter != null)
              pw.Text(
                '${getHeaderTranslation('cost_center', language)} $costCenter',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
              ),
          ],
        ),
        pw.Image(logo, width: 180),
      ],
    );
  }

  // Gemeinsame Kunden-Adressbox
  static pw.Widget buildCustomerAddress(Map<String, dynamic> customerData) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            customerData['company'] ?? '',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            customerData['fullName'] ?? '',
            style: const pw.TextStyle(color: PdfColors.blueGrey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${customerData['street'] ?? ''} ${customerData['houseNumber'] ?? ''}',
            style: const pw.TextStyle(color: PdfColors.blueGrey700),
          ),
          pw.Text(
            '${customerData['zipCode'] ?? ''} ${customerData['city'] ?? ''}',
            style: const pw.TextStyle(color: PdfColors.blueGrey700),
          ),
          pw.Text(
            customerData['country'] ?? '',
            style: const pw.TextStyle(color: PdfColors.blueGrey700),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'per mail an:',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            customerData['email'] ?? '',
            style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 8),
          ),
        ],
      ),
    );
  }

  // Gemeinsamer Footer
  static pw.Widget buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Florinett AG',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.Text('Tonewood Switzerland',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600)),
              pw.Text('Veja Zinols 6',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600)),
              pw.Text('7482 Bergün',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600)),
              pw.Text('Switzerland',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('phone: +41 81 407 21 34',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600)),
              pw.Text('e-mail: info@tonewood.ch',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600)),
              pw.Text('VAT: CHE-102.853.600 MWST',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600)),
            ],
          ),
        ],
      ),
    );
  }
  static String getTranslation(String key, String language) {  // <-- Geändert von Map<String, String> zu String
    final translations = {
      'DE': {
        'quote': 'OFFERTE',
        'delivery_note': 'LIEFERSCHEIN',
        'invoice': 'RECHNUNG',
        'packing_list': 'PACKLISTE',
        'per_email_to': 'per mail an:',
        'subtotal': 'Subtotal',
        'surcharges': 'Zuschläge',
        'packing_freight': 'Verpackungs- & Frachtkosten',
        'total': 'Total',
        'product': 'Produkt',
        'quantity': 'Menge',
        'unit': 'Einh',
        'price_per_unit': 'Preis/E',
        'currency': 'Wä',
        'amount': 'Betrag',
      },
      'EN': {
        'quote': 'QUOTATION',
        'delivery_note': 'DELIVERY NOTE',
        'invoice': 'INVOICE',
        'packing_list': 'PACKING LIST',
        'per_email_to': 'per email to:',
        'subtotal': 'Subtotal',
        'surcharges': 'Surcharges',
        'packing_freight': 'Packing & Freight costs',
        'total': 'Total',
        'product': 'Product',
        'quantity': 'Qty',
        'unit': 'Unit',
        'price_per_unit': 'Price/Unit',
        'currency': 'Curr',
        'amount': 'Amount',
      },
    };

    return translations[language]?[key] ?? translations['DE']?[key] ?? key;
  }
  // Hilfsmethoden für Zellen-Formatierung
  static pw.Widget buildHeaderCell(String text, double fontSize, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget buildContentCell(pw.Widget content) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: content,
    );
  }

  // Hole Holzart-Informationen
  static Future<Map<String, dynamic>?> getWoodTypeInfo(String woodCode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('wood_types')
          .doc(woodCode)
          .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Fehler beim Laden der Holzart: $e');
    }
    return null;
  }

  // Lade Logo
  static Future<pw.MemoryImage> loadLogo() async {
    final logoImage = await rootBundle.load('images/logo.png');
    return pw.MemoryImage(logoImage.buffer.asUint8List());
  }
}