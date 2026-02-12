// File: services/pdf_generators/base_pdf_generator.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../countries.dart';
import '../pdf_settings_screen.dart'; // NEU: Für PdfSettingsHelper

abstract class BasePdfGenerator {
  static String formatCurrency(dynamic amount, String currency, Map<String, double> exchangeRates) {
    double doubleAmount = 0.0;
    if (amount != null) {
      if (amount is num) {
        doubleAmount = amount.toDouble();
      } else if (amount is String) {
        doubleAmount = double.tryParse(amount) ?? 0.0;
      }
    }

    double convertedAmount = doubleAmount;
    if (currency != 'CHF' && exchangeRates.containsKey(currency)) {
      convertedAmount = doubleAmount * (exchangeRates[currency] ?? 1.0);
    }

    return '$currency ${_formatWithThousands(convertedAmount)}';
  }

  /// Formatiert Betrag OHNE Währungszeichen (für Tabellen)
  static String formatAmountOnly(dynamic amount, String currency, Map<String, double> exchangeRates) {
    double doubleAmount = 0.0;
    if (amount != null) {
      if (amount is num) {
        doubleAmount = amount.toDouble();
      } else if (amount is String) {
        doubleAmount = double.tryParse(amount) ?? 0.0;
      }
    }

    double convertedAmount = doubleAmount;
    if (currency != 'CHF' && exchangeRates.containsKey(currency)) {
      convertedAmount = doubleAmount * (exchangeRates[currency] ?? 1.0);
    }

    return _formatWithThousands(convertedAmount);
  }

  /// Hilfsmethode: Zahl mit Tausender-Apostroph formatieren
  /// 1234.56 → "1'234.56"
  static String _formatWithThousands(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    // Minuszeichen separat behandeln
    final isNegative = intPart.startsWith('-');
    final digits = isNegative ? intPart.substring(1) : intPart;

    String formatted = '';
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formatted = "'$formatted";
      }
      formatted = digits[i] + formatted;
      count++;
    }

    return '${isNegative ? '-' : ''}$formatted.$decPart';
  }

  /// Währungshinweis-Widget für über Tabellen
  static pw.Widget buildCurrencyHint(String currency, String language) {
    final currencyNames = {
      'CHF': {'DE': 'Schweizer Franken (CHF)', 'EN': 'Swiss Francs (CHF)'},
      'EUR': {'DE': 'Euro (EUR)', 'EN': 'Euros (EUR)'},
      'USD': {'DE': 'US-Dollar (USD)', 'EN': 'US Dollars (USD)'},
    };

    final name = currencyNames[currency]?[language] ?? currency;
    final text = language == 'EN'
        ? 'All prices in $name'
        : 'Alle Preise in $name';

    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.blueGrey600,
        ),
      ),
    );
  }

  static Map<String, String> _translateReference(String reference, String language) {
    final parts = reference.split(':');
    if (parts.length != 2) return {'label': reference, 'value': ''};

    final key = parts[0];
    final value = parts[1];

    final translations = {
      'DE': {
        'invoice_nr': 'Rechnungsnr.:',
        'quote_nr': 'Angebotsnr.:',
        'order_nr': 'Auftragsnr.:',
      },
      'EN': {
        'invoice_nr': 'Invoice No.:',
        'quote_nr': 'Quote No.:',
        'order_nr': 'Order No.:',
      }
    };

    final translatedKey = translations[language]?[key] ?? translations['DE']?[key] ?? key;
    return {'label': translatedKey, 'value': value};
  }

  static pw.Widget buildHeader({
    required String documentTitle,
    required String documentNumber,
    required DateTime date,
    required pw.MemoryImage logo,
    String? costCenter,
    String language = 'DE',
    String? additionalReference,
    String? secondaryReference,
  })
  {
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
          'cost_center': 'Kst-Nr.:',
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
          'cost_center': 'Cost Center:',
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
            // Dokumenttitel - fett und groß
            pw.Text(
              getHeaderTranslation(documentTitle.toUpperCase().replaceAll(' ', '_'), language),
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 8),

            // Dokumentnummer
            pw.Row(
              children: [
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    getHeaderTranslation('nr', language),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey600,
                    ),
                  ),
                ),
                pw.Text(
                  documentNumber,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.blueGrey600,
                  ),
                ),
              ],
            ),

            // Zusätzliche Referenzen
            if (additionalReference != null) ...[
              pw.SizedBox(height: 2),
                  () {
                final ref = _translateReference(additionalReference, language);
                return pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 90,
                      child: pw.Text(
                        ref['label']!,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.blueGrey600,
                        ),
                      ),
                    ),
                    pw.Text(
                      ref['value']!,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                  ],
                );
              }(),
            ],
            if (secondaryReference != null) ...[
              pw.SizedBox(height: 2),
                  () {
                final ref = _translateReference(secondaryReference, language);
                return pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 90,
                      child: pw.Text(
                        ref['label']!,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.blueGrey600,
                        ),
                      ),
                    ),
                    pw.Text(
                      ref['value']!,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                  ],
                );
              }(),
            ],
            pw.SizedBox(height: 2),

            // Datum
            pw.Row(
              children: [
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    getHeaderTranslation('date', language),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey600,
                    ),
                  ),
                ),
                pw.Text(
                  DateFormat('dd.MM.yyyy').format(date),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.blueGrey600,
                  ),
                ),
              ],
            ),

            // Cost Center
            if (costCenter != null) ...[
              pw.SizedBox(height: 2),
              pw.Row(
                children: [
                  pw.SizedBox(
                    width: 90,
                    child: pw.Text(
                      getHeaderTranslation('cost_center', language),
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                  ),
                  pw.Text(
                    costCenter,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.blueGrey600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        pw.Image(logo, width: 180),
      ],
    );
  }

  static pw.Widget buildCompactHeader({
    required String documentTitle,
    required String documentNumber,
    required pw.MemoryImage logo,
    required int pageNumber,
    required int totalPages,
    String language = 'DE',
  }) {
    final pageLabel = language == 'EN'
        ? 'Page $pageNumber / $totalPages'
        : 'Seite $pageNumber / $totalPages';

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Text(
                documentTitle,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                documentNumber,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blueGrey600,
                ),
              ),
              // pw.SizedBox(width: 20),
              // pw.Text(
              //   pageLabel,
              //   style: const pw.TextStyle(
              //     fontSize: 9,
              //     color: PdfColors.blueGrey400,
              //   ),
              // ),
            ],
          ),
          pw.Image(logo, width: 100),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Seitenzahl-Widget (für Seite 1 im Header oder standalone)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget buildPageNumber({
    required int pageNumber,
    required int totalPages,
    String language = 'DE',
  }) {
    final pageLabel = language == 'EN'
        ? 'Page $pageNumber / $totalPages'
        : 'Seite $pageNumber / $totalPages';

    return pw.Text(
      pageLabel,
      style: const pw.TextStyle(
        fontSize: 9,
        color: PdfColors.blueGrey400,
      ),
    );
  }

  // ============================================================================
  // NEU: Gibt den Standard-Anzeigemodus für einen Dokumenttyp zurück
  // ============================================================================
  static String _getDefaultAddressMode(String documentTitle) {
    switch (documentTitle.toLowerCase()) {
      case 'delivery_note':
      case 'packing_list':
        return 'shipping_only';
      case 'quote':
      case 'invoice':
      case 'commercial_invoice':
      default:
        return 'both';
    }
  }

  // ============================================================================
  // NEU: Hilfsmethode für einspaltiges Adress-Layout
  // ============================================================================
  static pw.Widget _buildSingleAddressLayout({
    required Map<String, dynamic> customerData,
    required String language,
    required bool useShipping,
    required bool hasCompany,
    required bool hasName,
    required String fullName,
    required dynamic country,
    required pw.Widget Function() buildContactInfo,
  }) {
    // Bestimme welche Felder verwendet werden sollen
    final street = useShipping
        ? (customerData['shippingStreet'] ?? customerData['street'] ?? '')
        : (customerData['street'] ?? '');
    final houseNumber = useShipping
        ? (customerData['shippingHouseNumber'] ?? customerData['houseNumber'] ?? '')
        : (customerData['houseNumber'] ?? '');
    final zipCode = useShipping
        ? (customerData['shippingZipCode'] ?? customerData['zipCode'] ?? '')
        : (customerData['zipCode'] ?? '');
    final city = useShipping
        ? (customerData['shippingCity'] ?? customerData['city'] ?? '')
        : (customerData['city'] ?? '');
    final province = useShipping
        ? (customerData['shippingProvince'] ?? customerData['province'])
        : customerData['province'];
    final countryName = useShipping
        ? (customerData['shippingCountry'] ?? customerData['country'])
        : customerData['country'];
    final additionalLines = useShipping
        ? (customerData['shippingAdditionalAddressLines'] as List? ?? [])
        : (customerData['additionalAddressLines'] as List? ?? []);
    final company = useShipping
        ? (customerData['shippingCompany'] ?? customerData['company'] ?? '')
        : (customerData['company'] ?? '');

    final countryObj = Countries.getCountryByName(countryName);

    // Für Shipping: Berechne Namen
    final shippingFirstName = customerData['shippingFirstName']?.toString().trim() ?? '';
    final shippingLastName = customerData['shippingLastName']?.toString().trim() ?? '';
    final shippingFullName = '$shippingFirstName $shippingLastName'.trim();
    final displayName = useShipping && shippingFullName.isNotEmpty ? shippingFullName : fullName;
    final displayHasName = displayName.isNotEmpty;
    final displayHasCompany = company.toString().trim().isNotEmpty;

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
              if (displayHasCompany) ...[
                pw.Text(
                  company.toString(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                if (displayHasName) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    displayName,
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  ),
                ],
              ] else ...[
                if (displayHasName)
                  pw.Text(
                    displayName,
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
                '$street $houseNumber'.trim(),
                style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
              ),

              // Zusätzliche Adress-Zeilen
              ...additionalLines.map((line) =>
                  pw.Text(
                    line.toString(),
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  )
              ).toList(),

              // PLZ und Stadt
              pw.Text(
                '$zipCode $city'.trim(),
                style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
              ),

              // Provinz
              if (province?.toString().trim().isNotEmpty == true)
                pw.Text(
                  province.toString(),
                  style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                ),

              // Land
              if (countryName != null && countryName.toString().trim().isNotEmpty)
                pw.Text(
                  countryObj?.getNameForLanguage(language).toUpperCase() ?? countryName.toString().toUpperCase(),
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

  // ============================================================================
  // HAUPTMETHODE: buildCustomerAddress mit addressDisplayMode Parameter
  // ============================================================================
  static pw.Widget buildCustomerAddress(
      Map<String, dynamic> customerData,
      String documentTitle, {
        String language = 'DE',
        String? addressDisplayMode, // NEU: Optional - überschreibt die Standard-Einstellung
      }) {
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
    final countryName = customerData['country'];
    final country = Countries.getCountryByName(countryName);

    // NEU: Bestimme den Anzeigemodus
    final String displayMode = addressDisplayMode ?? _getDefaultAddressMode(documentTitle);

    // Kontaktinfo-Builder
    pw.Widget buildContactInfo({bool useShippingData = false, String docTitle = ''}) {
      final isDeliveryOrPacking = docTitle == 'delivery_note' || docTitle == 'packing_list';
      final isInvoiceOrQuote = docTitle == 'invoice' || docTitle == 'quote';

      // Entscheide welche Felder verwendet werden
      final emailField = (hasDifferentShippingAddress == true && !isInvoiceOrQuote)
          ? customerData['shippingEmail']
          : customerData['email'];

      final phoneField = (hasDifferentShippingAddress == true && !isInvoiceOrQuote)
          ? customerData['shippingPhone']
          : customerData['phone1'];

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
                phoneField?.toString().trim().isNotEmpty == true ? phoneField : '-',
                style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
              ),
            ],
          ),

          // NUR bei NICHT-Lieferscheinen/Packlisten EORI und MwSt
          if (!isDeliveryOrPacking) ...[
            // EORI - wenn vorhanden UND Checkbox aktiviert
            if (customerData['showEoriOnDocuments'] == true &&
                customerData['eoriNumber']?.toString().trim().isNotEmpty == true) ...[
              pw.SizedBox(height: 4),
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
                    customerData['eoriNumber'],
                    style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
                  ),
                ],
              ),
            ],

            // MwSt - wenn vorhanden UND Checkbox aktiviert
            if (customerData['showVatOnDocuments'] == true &&
                customerData['vatNumber']?.toString().trim().isNotEmpty == true) ...[
              pw.SizedBox(height: 4),
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
                      customerData['vatNumber'],
                      style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ],
          ],

          // Custom Field - für ALLE Dokumente wenn aktiviert
          if (customerData['showCustomFieldOnDocuments'] == true &&
              customerData['customFieldTitle'] != null &&
              customerData['customFieldTitle'].toString().trim().isNotEmpty &&
              customerData['customFieldValue'] != null &&
              customerData['customFieldValue'].toString().trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${customerData['customFieldTitle'].toString()}:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Text(
                    customerData['customFieldValue'].toString(),
                    style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // ========================================================================
    // ENTSCHEIDUNGSLOGIK BASIEREND AUF DISPLAY MODE
    // ========================================================================

    // Fall 1: Nur Rechnungsadresse anzeigen
    if (displayMode == 'billing_only') {
      return _buildSingleAddressLayout(
        customerData: customerData,
        language: language,
        useShipping: false,
        hasCompany: hasCompany,
        hasName: hasName,
        fullName: fullName,
        country: country,
        buildContactInfo: () => buildContactInfo(docTitle: documentTitle),
      );
    }

    // Fall 2: Nur Lieferadresse anzeigen
    if (displayMode == 'shipping_only') {
      // Wenn keine abweichende Lieferadresse existiert, zeige Rechnungsadresse
      if (!hasDifferentShippingAddress) {
        return _buildSingleAddressLayout(
          customerData: customerData,
          language: language,
          useShipping: false,
          hasCompany: hasCompany,
          hasName: hasName,
          fullName: fullName,
          country: country,
          buildContactInfo: () => buildContactInfo(useShippingData: true, docTitle: documentTitle),
        );
      }

      // Zeige nur Lieferadresse
      return _buildSingleAddressLayout(
        customerData: customerData,
        language: language,
        useShipping: true,
        hasCompany: hasShippingCompany,
        hasName: hasShippingName,
        fullName: shippingFullName,
        country: Countries.getCountryByName(customerData['shippingCountry'] ?? customerData['country']),
        buildContactInfo: () => buildContactInfo(useShippingData: true, docTitle: documentTitle),
      );
    }

    // Fall 3: Beide Adressen anzeigen (displayMode == 'both')
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
                  // Zusätzliche Lieferadress-Zeilen
                  if (customerData['shippingAdditionalAddressLines'] != null)
                    ...(customerData['shippingAdditionalAddressLines'] as List).map((line) =>
                        pw.Text(
                          line.toString(),
                          style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                        )
                    ).toList(),

                  pw.Text(
                    '${customerData['shippingZipCode'] ?? customerData['zipCode'] ?? ''} ${customerData['shippingCity'] ?? customerData['city'] ?? ''}'.trim(),
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  ),
                  // Provinz für Lieferadresse
                  if ((customerData['shippingProvince'] ?? customerData['province'])?.toString().trim().isNotEmpty == true)
                    pw.Text(
                      customerData['shippingProvince'] ?? customerData['province'],
                      style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                    ),

                  if ((customerData['shippingCountry'] ?? customerData['country'])?.toString().trim().isNotEmpty == true) ...[
                        () {
                      final shippingCountryName = customerData['shippingCountry'] ?? customerData['country'];
                      final shippingCountry = Countries.getCountryByName(shippingCountryName);
                      return pw.Text(
                        shippingCountry?.getNameForLanguage(language).toUpperCase() ?? shippingCountryName.toUpperCase(),
                        style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                      );
                    }(),
                  ],
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
                  // Zusätzliche Rechnungsadress-Zeilen
                  if (customerData['additionalAddressLines'] != null)
                    ...(customerData['additionalAddressLines'] as List).map((line) =>
                        pw.Text(
                          line.toString(),
                          style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                        )
                    ).toList(),

                  pw.Text(
                    '${customerData['zipCode'] ?? ''} ${customerData['city'] ?? ''}'.trim(),
                    style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                  ),
                  // Provinz für Rechnungsadresse
                  if (customerData['province']?.toString().trim().isNotEmpty == true)
                    pw.Text(
                      customerData['province'],
                      style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                    ),

                  if (customerData['country'] != null &&
                      customerData['country'].toString().trim().isNotEmpty)
                    pw.Text(
                      country?.getNameForLanguage(language).toUpperCase() ?? customerData['country'].toUpperCase(),
                      style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),

          // Kontaktdaten (rechts)
          pw.Expanded(
            flex: 2,
            child: buildContactInfo(useShippingData: true, docTitle: documentTitle),
          ),
        ],
      );
    } else {
      // Zweispaltige Darstellung bei gleicher Adresse - ohne Hintergrund
      return _buildSingleAddressLayout(
        customerData: customerData,
        language: language,
        useShipping: false,
        hasCompany: hasCompany,
        hasName: hasName,
        fullName: fullName,
        country: country,
        buildContactInfo: () => buildContactInfo(docTitle: documentTitle),
      );
    }
  }

  // ============================================================================
  // NEU: Async Version die die Einstellungen aus Firestore lädt
  // ============================================================================
  static Future<pw.Widget> buildCustomerAddressAsync(
      Map<String, dynamic> customerData,
      String documentTitle, {
        String language = 'DE',
      }) async {
    // Lade die Einstellung aus Firestore
    final addressMode = await PdfSettingsHelper.getAddressDisplayMode(documentTitle);

    return buildCustomerAddress(
      customerData,
      documentTitle,
      language: language,
      addressDisplayMode: addressMode,
    );
  }

  // Gemeinsamer Footer
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
  static String getTranslation(String key, String language) {
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
  /// Erstellt eine Tabelle, die über Seitenumbrüche hinweg umbrechen kann.
  /// Jede Row wird als eigene Mini-Tabelle gerendert, damit MultiPage
  /// dazwischen umbrechen kann.
  static pw.Widget buildSplittableTable({
    required List<pw.TableRow> rows,
    required Map<int, pw.TableColumnWidth> columnWidths,
    pw.TableBorder? border,
  }) {
    if (rows.isEmpty) return pw.SizedBox.shrink();

    final effectiveBorder = border ?? pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5);

    final List<pw.Widget> tableWidgets = [];

    for (int i = 0; i < rows.length; i++) {
      final isFirst = i == 0;
      final isLast = i == rows.length - 1;

      tableWidgets.add(
        pw.Table(
          columnWidths: columnWidths,
          border: pw.TableBorder(
            left: effectiveBorder.left,
            right: effectiveBorder.right,
            top: isFirst ? effectiveBorder.top : effectiveBorder.horizontalInside,
            bottom: isLast ? effectiveBorder.bottom : pw.BorderSide.none,
            horizontalInside: effectiveBorder.horizontalInside,
            verticalInside: effectiveBorder.verticalInside,
          ),
          children: [rows[i]],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: tableWidgets,
    );
  }
}