// File: services/pdf_generators/base_delivery_note_generator.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../countries.dart';

/// Basis-Generator für Dokumente mit Fenstertaschen-Layout
/// C6/5 Dokumententasche mit Fenster RECHTS
///
/// Norm-Werte (Fenster rechts, C5/6):
/// - Fenstergröße: 45 × 90 mm
/// - Position: 20 mm vom rechten Rand, 15 mm vom unteren Rand
///
/// Adressfeld auf Dokument:
/// - Größe: 80 × 40 mm
/// - Position: 25 mm vom rechten Rand, 50 mm von oben
abstract class BaseDeliveryNotePdfGenerator {

  // Konstanten für Fenster-Positionierung (in mm)
  static const double addressFieldWidth = 80.0;   // mm
  static const double addressFieldHeight = 60.0;  // mm
  static const double addressFieldFromRight = 25.0; // mm vom rechten Rand
  static const double addressFieldFromTop = 50.0;   // mm von oben

  // Lade Logo
  static Future<pw.MemoryImage> loadLogo() async {
    final logoImage = await rootBundle.load('images/logo.png');
    return pw.MemoryImage(logoImage.buffer.asUint8List());
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

  /// Übersetzungs-Helfer
  static String getTranslation(String key, String language) {
    final translations = {
      'DE': {
        'delivery_note': 'LIEFERSCHEIN',
        'nr': 'Nr.:',
        'date': 'Datum:',
        'cost_center': 'KST:',
        'invoice_nr': 'Rechnungsnr.:',
        'quote_nr': 'Angebotsnr.:',
        'order_nr': 'Auftragsnr.:',
        'delivery_date': 'Lieferdatum',
        'payment_date': 'Zahlungsdatum',
        'email': 'E-Mail:',
        'phone': 'Tel.:',
      },
      'EN': {
        'delivery_note': 'DELIVERY NOTE',
        'nr': 'No.:',
        'date': 'Date:',
        'cost_center': 'Cost Center:',
        'invoice_nr': 'Invoice No.:',
        'quote_nr': 'Quote No.:',
        'order_nr': 'Order No.:',
        'delivery_date': 'Delivery date',
        'payment_date': 'Payment date',
        'email': 'Email:',
        'phone': 'Phone:',
      }
    };
    return translations[language]?[key] ?? translations['DE']?[key] ?? key;
  }

  /// HEADER für Fenstertaschen: Logo LINKS, Adresse RECHTS (Norm-konform)
  ///
  /// A4 = 210 x 297 mm
  /// Page margin = 20 mm
  /// Nutzbarer Bereich = 170 x 257 mm
  ///
  /// Adressfeld: 80 x 40 mm, 25 mm vom rechten Rand, 50 mm von oben
  static pw.Widget buildWindowHeader({
    required String documentTitle,
    required String documentNumber,
    required DateTime date,
    required pw.MemoryImage logo,
    required Map<String, dynamic> customerData,
    String? costCenter,
    String? invoiceNumber,
    String? quoteNumber,
    required String language,
    double addressEmailSpacing = 6.0,
  }) {
    // A4 Breite = 210mm, Page-Margin = 20mm auf jeder Seite
    // Nutzbarer Bereich = 170mm
    // Adressfeld: 25mm vom rechten Dokumentrand = 210 - 25 - 80 = 105mm vom linken Rand
    // Mit 20mm Page-Margin: 105 - 20 = 85mm vom linken Content-Rand

    // Berechnung der linken Spalte (für Logo + Dokumentinfo)
    // Gesamtbreite = 170mm (nutzbar)
    // Adressfeld = 80mm
    // Abstand zwischen = ca. 5mm
    // Linke Spalte = 170 - 80 - 5 = 85mm

    return pw.Container(
      height: 90 * PdfPageFormat.mm, // Genug Höhe für Header-Bereich
      child: pw.Stack(
        children: [
          // LINKE SEITE: Logo + Dokumentinfo (absolute Position)
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Container(
              width: 85 * PdfPageFormat.mm,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo
                  pw.Image(logo, width: 140),
                  pw.SizedBox(height: 10),

                  // Dokumenttitel
                  pw.Text(
                    getTranslation(documentTitle.toLowerCase().replaceAll(' ', '_'), language),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 6),

                  // Dokumentnummer
                  _buildInfoRow(getTranslation('nr', language), documentNumber, isBold: true),

                  // Rechnungsnummer
                  if (invoiceNumber != null)
                    _buildInfoRow(getTranslation('invoice_nr', language), invoiceNumber),

                  // Angebotsnummer
                  if (quoteNumber != null)
                    _buildInfoRow(getTranslation('quote_nr', language), quoteNumber),

                  // Datum
                  _buildInfoRow(
                    getTranslation('date', language),
                    DateFormat('dd.MM.yyyy').format(date),
                  ),

                  // Kostenstelle
                  if (costCenter != null)
                    _buildInfoRow(getTranslation('cost_center', language), costCenter),
                ],
              ),
            ),
          ),

          // RECHTE SEITE: Adressfeld (exakt positioniert für Fenstertasche)
          // 50mm von oben, aber wir sind bereits im Content-Bereich (20mm Page-Margin)
          // Also: 50 - 20 = 30mm vom oberen Content-Rand
          // RECHTE SEITE: Adressfeld + Kontakt im Fenstertaschen-Bereich
          pw.Positioned(
            right: 5 * PdfPageFormat.mm,
            top: 30 * PdfPageFormat.mm,
            child: pw.Container(
              width: addressFieldWidth * PdfPageFormat.mm,
              height: addressFieldHeight * PdfPageFormat.mm,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // Adresse – nimmt so viel Platz wie nötig
                  _buildAddressBox(customerData, language),
                  // Manuell einstellbarer Abstand
                  pw.SizedBox(height: addressEmailSpacing),
                  // Kontaktdaten direkt inline (ohne _buildContactInfo wegen Expanded-Problem)
                  ..._buildContactInfoWidgets(customerData, language),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  /// Kontaktdaten als Widget-Liste (ohne Expanded, für Verwendung in Column mit fester Höhe)
  static List<pw.Widget> _buildContactInfoWidgets(Map<String, dynamic> customerData, String language) {
    final bool hasDifferentShippingAddress = customerData['hasDifferentShippingAddress'] == true;

    final String? email = hasDifferentShippingAddress
        ? customerData['shippingEmail']?.toString().trim()
        : customerData['email']?.toString().trim();
    final String? phone = hasDifferentShippingAddress
        ? customerData['shippingPhone']?.toString().trim()
        : customerData['phone1']?.toString().trim();

    return [
      if (email != null && email.isNotEmpty)
        pw.Text(
          '${getTranslation('email', language)} $email',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.blueGrey600,
          ),
        ),
      if (phone != null && phone.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            '${getTranslation('phone', language)} $phone',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.blueGrey600,
            ),
          ),
        ),
    ];
  }
  /// Hilfs-Widget für Info-Zeilen im Header
  static pw.Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.blueGrey600,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Adressbox für Fensterbereich - NUR Adresse (80 x 40 mm)
  static pw.Widget _buildAddressBox(Map<String, dynamic> customerData, String language) {
    final bool hasDifferentShippingAddress = customerData['hasDifferentShippingAddress'] == true;

    // Bei Lieferschein immer die Lieferadresse verwenden (falls vorhanden)
    String company;
    String firstName;
    String lastName;
    String street;
    String houseNumber;
    String zipCode;
    String city;
    String? province;
    String? country;
    List<dynamic>? additionalLines;

    if (hasDifferentShippingAddress) {
      company = customerData['shippingCompany']?.toString().trim() ?? '';
      firstName = customerData['shippingFirstName']?.toString().trim() ?? '';
      lastName = customerData['shippingLastName']?.toString().trim() ?? '';
      street = customerData['shippingStreet']?.toString().trim() ?? customerData['street']?.toString().trim() ?? '';
      houseNumber = customerData['shippingHouseNumber']?.toString().trim() ?? customerData['houseNumber']?.toString().trim() ?? '';
      zipCode = customerData['shippingZipCode']?.toString().trim() ?? customerData['zipCode']?.toString().trim() ?? '';
      city = customerData['shippingCity']?.toString().trim() ?? customerData['city']?.toString().trim() ?? '';
      province = customerData['shippingProvince']?.toString().trim() ?? customerData['province']?.toString().trim();
      country = customerData['shippingCountry']?.toString().trim() ?? customerData['country']?.toString().trim();
      additionalLines = customerData['shippingAdditionalAddressLines'] ?? customerData['additionalAddressLines'];
    } else {
      company = customerData['company']?.toString().trim() ?? '';
      firstName = customerData['firstName']?.toString().trim() ?? '';
      lastName = customerData['lastName']?.toString().trim() ?? '';
      street = customerData['street']?.toString().trim() ?? '';
      houseNumber = customerData['houseNumber']?.toString().trim() ?? '';
      zipCode = customerData['zipCode']?.toString().trim() ?? '';
      city = customerData['city']?.toString().trim() ?? '';
      province = customerData['province']?.toString().trim();
      country = customerData['country']?.toString().trim();
      additionalLines = customerData['additionalAddressLines'];
    }

    final String fullName = '$firstName $lastName'.trim();
    final bool hasCompany = company.isNotEmpty;
    final bool hasName = fullName.isNotEmpty;

    return pw.Container(
    //  padding: const pw.EdgeInsets.all(6),

      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // Firma
          if (hasCompany)
            pw.Text(
              company,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),

          // Name
          if (hasName)
            pw.Text(
              fullName,
              style: pw.TextStyle(
                fontSize: hasCompany ? 9 : 10,
                fontWeight: hasCompany ? null : pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),

          // Straße + Hausnummer
          pw.Text(
            '$street $houseNumber'.trim(),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
          ),

          // Zusätzliche Adresszeilen
          if (additionalLines != null)
            ...additionalLines.map((line) => pw.Text(
              line.toString(),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
            )),

          // PLZ + Stadt
          pw.Text(
            '$zipCode $city'.trim(),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
          ),

          // Provinz
          if (province != null && province.isNotEmpty)
            pw.Text(
              province,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
            ),

          // Land
          // Land - mit Übersetzung
          if (country != null && country.isNotEmpty) ...[
                () {
              final countryObj = Countries.getCountryByName(country!);  // <-- ! hinzugefügt
              final translatedCountry = countryObj?.getNameForLanguage(language) ?? country;
              return pw.Text(
                translatedCountry,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
              );
            }(),
          ],
        ],
      ),
    );
  }

  /// Kontaktdaten (Email, Telefon) - UNTER dem Adressfeld
  static pw.Widget _buildContactInfo(
      Map<String, dynamic> customerData,
      String language,
      {double spacing = 6.0}  // NEU: Parameter für Abstand
      ) {
    final bool hasDifferentShippingAddress = customerData['hasDifferentShippingAddress'] == true;

    final String? email = hasDifferentShippingAddress
        ? customerData['shippingEmail']?.toString().trim()
        : customerData['email']?.toString().trim();
    final String? phone = hasDifferentShippingAddress
        ? customerData['shippingPhone']?.toString().trim()
        : customerData['phone1']?.toString().trim();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // NEU: Dynamischer Abstand vor den Kontaktdaten
        pw.SizedBox(height: spacing),

        if (email != null && email.isNotEmpty)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                getTranslation('email', language),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal700,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  email,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600),
                ),
              ),
            ],
          ),
        if (phone != null && phone.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Row(
            children: [
              pw.Text(
                getTranslation('phone', language),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal700,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                phone,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600),
              ),
            ],
          ),
        ],
      ],
    );
  }
  /// Kombinierte Methode für Header + Adresse (für einfache Verwendung)
  static pw.Widget buildWindowAddress(Map<String, dynamic> customerData, String language) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildAddressBox(customerData, language),
        pw.SizedBox(height: 6),
        _buildContactInfo(customerData, language),
      ],
    );
  }

  /// Datums-Box (Liefer- und Zahlungsdatum)
  static pw.Widget buildDateBox({
    DateTime? deliveryDate,
    DateTime? paymentDate,
    required String language,
  }) {
    if (deliveryDate == null && paymentDate == null) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          if (deliveryDate != null)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  getTranslation('delivery_date', language),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.Text(
                  DateFormat('dd.MM.yyyy').format(deliveryDate),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          if (paymentDate != null)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  getTranslation('payment_date', language),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.Text(
                  DateFormat('dd.MM.yyyy').format(paymentDate),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static pw.Widget buildFooter({int? pageNumber, int? totalPages, String language = 'DE'}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
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
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800, fontSize: 8)),
              pw.Text('Tonewood Switzerland',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8)),
              pw.Text('Veja Zinols 6',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8)),
              pw.Text('7482 Bergün',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8)),
              pw.Text('Switzerland',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8)),
            ],
          ),
          if (pageNumber != null && totalPages != null)
            pw.Text(
              language == 'EN'
                  ? 'Page $pageNumber / $totalPages'
                  : 'Seite $pageNumber / $totalPages',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.blueGrey400,
              ),
            ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('phone: +41 81 407 21 34',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8)),
              pw.Text('e-mail: info@tonewood.ch',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8)),
              pw.Text('website: www.tonewood.ch',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8)),
              pw.Text('VAT: CHE-102.853.600 MWST',
                  style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  /// Hilfsmethoden für Tabellen-Zellen
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
}