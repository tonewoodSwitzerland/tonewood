// File: services/pdf_generators/base_pdf_generator.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class BasePdfGenerator {
  // Gemeinsame Formatierungslogik
  static String formatCurrency(dynamic amount, String currency, Map<String, double> exchangeRates) {
    // Konvertiere sicher zu double
    double doubleAmount = 0.0;
    if (amount != null) {
      if (amount is num) {
        doubleAmount = amount.toDouble();
      } else if (amount is String) {
        doubleAmount = double.tryParse(amount) ?? 0.0;
      }
    }

    // Konvertiere Währung
    double convertedAmount = doubleAmount;
    if (currency != 'CHF' && exchangeRates.containsKey(currency)) {
      convertedAmount = doubleAmount * (exchangeRates[currency] ?? 1.0);
    }

    return '$currency ${convertedAmount.toStringAsFixed(2)}';
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
          'QUOTE': 'OFFER',
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


  static pw.Widget buildCustomerAddress(Map<String, dynamic> customerData,String documentTitle, {String language = 'DE'}) {
    // Übersetzungsfunktion für Adressen
    String getAddressTranslation(String key) {
      final translations = {
        'DE': {
          'delivery_address': 'Lieferadresse',
          'billing_address': 'Rechnungsadresse',
          'email': 'E-Mail:',
          'phone': 'Tel.:',
          'eori': 'EORI:',
          'vat_id': 'MwST.:',
        },
        'EN': {
          'delivery_address': 'Delivery address',
          'billing_address': 'Billing address',
          'email': 'Email:',
          'phone': 'Phone:',
          'eori': 'EORI:',
          'vat_id': 'VAT ID:',
        }
      };
      return translations[language]?[key] ?? translations['DE']?[key] ?? key;
    }

    // Prüfen ob unterschiedliche Lieferadresse vorhanden ist
    final bool hasDifferentShippingAddress = customerData['hasDifferentShippingAddress'] == true;

    // Prüfen ob Firma vorhanden ist
    final bool hasCompany = customerData['company'] != null &&
        customerData['company'].toString().trim().isNotEmpty;

    // Vollständigen Namen aus firstName und lastName zusammensetzen
    final String firstName = customerData['firstName']?.toString().trim() ?? '';
    final String lastName = customerData['lastName']?.toString().trim() ?? '';
    final String fullName = '$firstName $lastName'.trim();
    final bool hasName = fullName.isNotEmpty;


    final String shippingFirstName = customerData['shippingFirstName']?.toString().trim() ?? '';
    final String shippingLastName = customerData['shippingLastName']?.toString().trim() ?? '';
    final String shippingFullName = '$shippingFirstName $shippingLastName'.trim();
    final bool hasShippingCompany = customerData['shippingCompany'] != null &&
        customerData['shippingCompany'].toString().trim().isNotEmpty;
    final bool hasShippingName = shippingFullName.isNotEmpty;



    // Widget für Kontaktinformationen - kompakter und inline
    pw.Widget buildContactInfo({bool useShippingData = false, String documentTitle = ''}) {
      final shouldUseShipping = useShippingData && documentTitle == 'delivery_note';
      final isDeliveryNote = documentTitle == 'delivery_note';

      // Entscheide welche Felder verwendet werden
      final emailField = hasDifferentShippingAddress==true
          ? customerData['shippingEmail']
          : customerData['email'];

      final phoneField  = hasDifferentShippingAddress==true
          ? customerData['shippingPhone']
          : customerData['phone1'];

      final eoriField  = hasDifferentShippingAddress==true
          ? customerData['shippingEoriNumber']
          : customerData['eoriNumber'];

      final vatField = hasDifferentShippingAddress==true
          ? customerData['shippingVatNumber']
          : customerData['vatNumber'];

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Email
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                getAddressTranslation('email'),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  emailField ?? '-',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 4),

          // Telefon
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                getAddressTranslation('phone'),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                phoneField?.toString().trim().isNotEmpty == true
                    ? phoneField
                    : '-',
                style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
              ),
            ],
          ),

          pw.SizedBox(height: 4),

          // NUR bei NICHT-Lieferscheinen EORI und MwSt anzeigen
          if (!isDeliveryNote) ...[
            pw.SizedBox(height: 4),

            // EORI
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  getAddressTranslation('eori'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Text(
                  eoriField?.toString().trim().isNotEmpty == true
                      ? eoriField
                      : '-',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
                ),
              ],
            ),

            pw.SizedBox(height: 4),

            // MwSt-Nummer
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  getAddressTranslation('vat_id'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Text(
                    vatField?.toString().trim().isNotEmpty == true
                        ? vatField
                        : '-',
                    style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    if (hasDifferentShippingAddress) {
      // Drei-spaltige Darstellung bei unterschiedlichen Adressen
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Lieferadresse (links)
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.only(right: 15),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header für Lieferadresse
                  pw.Text(
                    getAddressTranslation('delivery_address'),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  if (hasShippingCompany) ...[
                    pw.Text(
                      customerData['shippingCompany'],
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (hasShippingName) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        shippingFullName,
                        style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                      ),
                    ],
                  ] else ...[
                    if (hasShippingName)
                      pw.Text(
                        shippingFullName,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                  ],
                  pw.SizedBox(height: 6),

                  // Lieferadresse
                  pw.Text(
                    '${customerData['shippingStreet'] ?? customerData['street'] ?? ''} ${customerData['shippingHouseNumber'] ?? customerData['houseNumber'] ?? ''}'.trim(),
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  ),
                  pw.Text(
                    '${customerData['shippingZipCode'] ?? customerData['zipCode'] ?? ''} ${customerData['shippingCity'] ?? customerData['city'] ?? ''}'.trim(),
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  ),
                  if ((customerData['shippingCountry'] ?? customerData['country'])?.toString().trim().isNotEmpty == true)
                    pw.Text(
                      customerData['shippingCountry'] ?? customerData['country'],
                      style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),

          // Rechnungsadresse (mitte)
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.only(right: 15),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header für Rechnungsadresse
                  pw.Text(
                    getAddressTranslation('billing_address'),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Firma oder Name prominent
                  if (hasCompany) ...[
                    pw.Text(
                      customerData['company'],
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (hasName) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        fullName,
                        style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                      ),
                    ],
                  ] else ...[
                    if (hasName)
                      pw.Text(
                        fullName,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                  ],

                  pw.SizedBox(height: 6),

                  // Standard-Rechnungsadresse
                  pw.Text(
                    '${customerData['street'] ?? ''} ${customerData['houseNumber'] ?? ''}'.trim(),
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  ),
                  pw.Text(
                    '${customerData['zipCode'] ?? ''} ${customerData['city'] ?? ''}'.trim(),
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  ),
                  if (customerData['country']?.toString().trim().isNotEmpty == true)
                    pw.Text(
                      customerData['country'],
                      style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),

          // Kontaktdaten (rechts)
          pw.Expanded(
            flex: 2,
            child: buildContactInfo(useShippingData: true,  documentTitle: documentTitle),
          ),
        ],
      );
    } else {
      // Zweispaltige Darstellung bei gleicher Adresse - ohne Hintergrund
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Adresse (links)
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Wenn Firma vorhanden, zeige Firma an erster Stelle
                if (hasCompany) ...[
                  pw.Text(
                    customerData['company'],
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  if (hasName) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      fullName,
                      style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                    ),
                  ],
                ] else ...[
                  if (hasName)
                    pw.Text(
                      fullName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                ],

                pw.SizedBox(height: 6),

                // Straße und Hausnummer
                pw.Text(
                  '${customerData['street'] ?? ''} ${customerData['houseNumber'] ?? ''}'.trim(),
                  style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                ),

                // PLZ und Stadt
                pw.Text(
                  '${customerData['zipCode'] ?? ''} ${customerData['city'] ?? ''}'.trim(),
                  style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                ),

                // Land
                if (customerData['country'] != null &&
                    customerData['country'].toString().trim().isNotEmpty)
                  pw.Text(
                    customerData['country'],
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  ),
              ],
            ),
          ),

          pw.SizedBox(width: 30),

          // Kontaktdaten (rechts)
          pw.Expanded(
            flex: 2,
            child: buildContactInfo(),
          ),
        ],
      );
    }
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
              pw.Text('website: www.tonewood.ch',
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