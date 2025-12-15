
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../document_selection_manager.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';
import '../swiss_rounding.dart';
class InvoiceGenerator extends BasePdfGenerator {
  // Erstelle eine neue Rechnungs-Nummer
  static Future<String> getNextInvoiceNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('invoice_counters');

      return await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        Map<String, dynamic> counters = {};
        if (counterDoc.exists) {
          counters = counterDoc.data() ?? {};
        }

        int currentNumber = counters[year.toString()] ?? 999; // Start bei 1000
        currentNumber++;

        transaction.set(counterRef, {
          year.toString(): currentNumber,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return '$year-$currentNumber';
      });
    } catch (e) {
      print('Fehler beim Erstellen der Rechnungs-Nummer: $e');
      return '${DateTime.now().year}-1000';
    }
  }

  static Future<Uint8List> generateInvoicePdf({
    required Map<String, bool> roundingSettings,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, dynamic>? fairData,
    required String costCenterCode,
    required String currency,
    required Map<String, double> exchangeRates,
    String? invoiceNumber,
    String? quoteNumber, // NEU
    required String language,
    Map<String, dynamic>? shippingCosts,
    Map<String, dynamic>? calculations,
    required int paymentTermDays,
    required int taxOption,
    required double vatRate,
    Map<String, dynamic>? downPaymentSettings,
    Map<String, dynamic>? additionalTexts,
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    print("paymentTermDayas:$paymentTermDays");
    // Generiere Rechnungs-Nummer falls nicht übergeben
    final invoiceNum = invoiceNumber ?? await getNextInvoiceNumber();
    final paymentDue = DateTime.now().add(Duration(days: paymentTermDays));

    // NEU: Lade Invoice-Einstellungen für showDimensions


    final invoiceSettings = downPaymentSettings ?? await DocumentSelectionManager.loadInvoiceSettings();
    DateTime invoiceDate = invoiceSettings['invoice_date'] ?? DateTime.now();

    final showDimensions = invoiceSettings['show_dimensions'] ?? false;
    // NEU: Prüfe ob 100% Vorkasse und hole Zahlungsmethode


    bool showExchangeRateOnDocument = false;
    try {
      final currencySettings = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('currency_settings')
          .get();

      if (currencySettings.exists) {
        showExchangeRateOnDocument = currencySettings.data()?['show_exchange_rate_on_documents'] ?? false;
      }
    } catch (e) {
      print('Fehler beim Laden der Currency Settings: $e');
    }





    final isFullPayment = invoiceSettings['is_full_payment'] ?? false;
    final paymentMethod = invoiceSettings['payment_method'] ?? 'BAR';
    final customPaymentMethod = invoiceSettings['custom_payment_method'] ?? '';

    // NEU: Hole das Zahlungsziel aus den Settings (überschreibt den Default)
    if (invoiceSettings['payment_term_days'] != null) {
      paymentTermDays = invoiceSettings['payment_term_days'];
    }

    // Gruppiere Items nach Holzart
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final serviceItems = items.where((item) => item['is_service'] == true).toList();

// Nur Produkte gruppieren (Dienstleistungen haben keine Holzart)
    final groupedProductItems = await _groupItemsByWoodType(productItems, language);


    final additionalTextsWidget = await _addInlineAdditionalTexts(language,additionalTexts);

    // Übersetzungsfunktion
    // In der getTranslation Funktion, ändere diese Zeilen:
    String getTranslation(String key) {
      // Sichere den Exchange Rate ab
      final exchangeRate = exchangeRates[currency] ?? 1.0;

      final translations = {
        'DE': {
          'invoice': 'RECHNUNG',
          'quote_reference': quoteNumber != null ? 'Angebotsnummer: $quoteNumber' : '',
          'currency_note': 'Alle Preise in $currency (Umrechnungskurs: 1 CHF = ${exchangeRate.toStringAsFixed(4)} $currency)',
          'payment_note': 'Zahlbar innerhalb von $paymentTermDays Tagen bis ${DateFormat('dd. MMMM yyyy', 'de_DE').format(paymentDue)}.',
        },
        'EN': {
          'invoice': 'INVOICE',
          'quote_reference': quoteNumber != null ? 'Quote Number: $quoteNumber' : '',
          'currency_note': 'All prices in $currency (Exchange rate: 1 CHF = ${exchangeRate.toStringAsFixed(4)} $currency)',
          'payment_note': 'Payment due within $paymentTermDays days until ${DateFormat('MMMM dd, yyyy', 'en_US').format(paymentDue)}.',
        }
      };

      // NEU: Bei 100% Vorkasse andere Zahlungsnotiz
      if (isFullPayment) {
        final paymentMethodText = paymentMethod == 'BAR'
            ? 'BAR'
            : customPaymentMethod;

        translations['DE']!['payment_note'] = 'Vollständig bezahlt';
        translations['EN']!['payment_note'] = 'Fully paid';
      }

      return translations[language]?[key] ?? translations['DE']?[key] ?? '';
    }
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              BasePdfGenerator.buildHeader(
                documentTitle: getTranslation('invoice'),
                documentNumber: invoiceNum,
                date: invoiceDate,
                logo: logo,
                costCenter: costCenterCode,
                language: language,
                additionalReference: quoteNumber != null && quoteNumber.isNotEmpty
                    ? getTranslation('quote_reference')
                    : null, // GEÄNDERT
              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
              BasePdfGenerator.buildCustomerAddress(customerData,'invoice', language: language),

              pw.SizedBox(height: 15),

              // Währungshinweis (falls nicht CHF)
              if (currency != 'CHF' && showExchangeRateOnDocument)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
                  ),
                  child: pw.Text(
                    getTranslation('currency_note'),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.amber900),
                  ),
                ),

              pw.SizedBox(height: 15),

              // Produkttabelle mit Holzart-Gruppierung
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Column(
                      children: [
                        // Produkttabelle nur wenn Produkte vorhanden
                        if (productItems.isNotEmpty)
                          _buildProductTable(groupedProductItems, currency, exchangeRates, language, showDimensions),

                        // Dienstleistungstabelle nur wenn Dienstleistungen vorhanden
                        if (serviceItems.isNotEmpty)
                          _buildServiceTable(serviceItems, currency, exchangeRates, language),
                      ],
                    ),  pw.SizedBox(height: 10),
                    // Summen-Bereich
                    _buildTotalsSection(items, currency, exchangeRates, language, shippingCosts, calculations, taxOption, vatRate, downPaymentSettings, // NEU
                      paymentDue,roundingSettings),

                    pw.SizedBox(height: 10),
                    // Zahlungshinweis - ANGEPASST
                    if (!isFullPayment) ...[
                      // Nur bei offener Zahlung anzeigen
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                        ),
                        child: pw.Text(
                          getTranslation('payment_note'),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue900),
                        ),
                      ),
                    ] else ...[
                      // Bei 100% Vorkasse - Zahlungsbestätigung
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: PdfColors.green200, width: 0.5),
                        ),
                        child: pw.Text(
                          getTranslation('payment_note'), // Nutzt die angepasste Übersetzung
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.green900),
                        ),
                      ),
                    ],

                    pw.SizedBox(height: 10),
                    additionalTextsWidget,
                  ],
                ),
              ),

              // Footer
              BasePdfGenerator.buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

// Gruppiere Items nach Holzart
  static Future<Map<String, List<Map<String, dynamic>>>> _groupItemsByWoodType(
      List<Map<String, dynamic>> items,
      String language  // Füge language Parameter hinzu
      ) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    for (final item in items) {
      final woodCode = item['wood_code'] as String;

      // Lade Holzart-Info (mit Cache)
      if (!woodTypeCache.containsKey(woodCode)) {
        woodTypeCache[woodCode] = await BasePdfGenerator.getWoodTypeInfo(woodCode) ?? {};
      }

      final woodInfo = woodTypeCache[woodCode]!;

      // Verwende name_english wenn Sprache EN ist
      final woodName = language == 'EN'
          ? (woodInfo['name_english'] ?? woodInfo['name'] ?? item['wood_name'] ?? 'Unknown wood type')
          : (woodInfo['name'] ?? item['wood_name'] ?? 'Unbekannte Holzart');

      final woodNameLatin = woodInfo['name_latin'] ?? '';

      final groupKey = '$woodName\n($woodNameLatin)';

      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }

      // Füge Holzart-Info zum Item hinzu
      final enhancedItem = Map<String, dynamic>.from(item);
      enhancedItem['wood_display_name'] = groupKey;
      enhancedItem['wood_name_latin'] = woodNameLatin;

      grouped[groupKey]!.add(enhancedItem);
    }

    return grouped;
  }

  static pw.Widget _buildServiceTable(
      List<Map<String, dynamic>> serviceItems,
      String currency,
      Map<String, double> exchangeRates,
      String language) {

    if (serviceItems.isEmpty) return pw.SizedBox.shrink();

    final List<pw.TableRow> rows = [];

    // Header für Dienstleistungen
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Service' : 'Dienstleistung', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Description' : 'Beschreibung', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Anz.', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Total' : 'Gesamt', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Disc.' : 'Rab.', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right),
        ],
      ),
    );

    // Dienstleistungen hinzufügen
    for (final service in serviceItems) {
      final quantity = (service['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = (service['custom_price_per_unit'] as num?) != null
          ? (service['custom_price_per_unit'] as num).toDouble()
          : (service['price_per_unit'] as num? ?? 0).toDouble();
      // Nachher:
// Rabatt-Berechnung
      final discount = service['discount'] as Map<String, dynamic>?;
      final totalBeforeDiscount = quantity * pricePerUnit;

      double discountAmount = 0.0;
      if (discount != null) {
        final percentage = (discount['percentage'] as num? ?? 0).toDouble();
        final absolute = (discount['absolute'] as num? ?? 0).toDouble();

        if (percentage > 0) {
          discountAmount = totalBeforeDiscount * (percentage / 100);
        } else if (absolute > 0) {
          discountAmount = absolute;
        }
      }

      final total = totalBeforeDiscount - discountAmount;

      rows.add(
        pw.TableRow(
          children: [
            BasePdfGenerator.buildContentCell(
              pw.Text(
                language == 'EN'
                    ? (service['name_en']?.isNotEmpty == true ? service['name_en'] : service['name'] ?? 'Unnamed Service')
                    : (service['name'] ?? 'Unbenannte Dienstleistung'),
                style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                language == 'EN'
                    ? (service['description_en']?.isNotEmpty == true ? service['description_en'] : service['description'] ?? '')
                    : (service['description'] ?? ''),
                style: const pw.TextStyle(fontSize: 6),
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                quantity.toStringAsFixed(0),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatCurrency(pricePerUnit, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatCurrency(totalBeforeDiscount, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
// NEU: Rabatt-Spalte
            BasePdfGenerator.buildContentCell(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (discount != null && (discount['percentage'] as num? ?? 0) > 0)
                    pw.Text(
                      '${discount['percentage'].toStringAsFixed(2)}%',
                      style: const pw.TextStyle(fontSize: 6),
                      textAlign: pw.TextAlign.right,
                    ),
                  if (discount != null && (discount['absolute'] as num? ?? 0) > 0)
                    pw.Text(
                      BasePdfGenerator.formatCurrency(
                          (discount['absolute'] as num).toDouble(),
                          currency,
                          exchangeRates
                      ),
                      style: const pw.TextStyle(fontSize: 6),
                      textAlign: pw.TextAlign.right,
                    ),
                ],
              ),
            ),
// NEU: Netto Gesamtpreis
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatCurrency(total, currency, exchangeRates),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: discountAmount > 0 ? pw.FontWeight.bold : null,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [

        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),    // Dienstleistung
            1: const pw.FlexColumnWidth(4),    // Beschreibung
            2: const pw.FlexColumnWidth(1),    // Anzahl
            3: const pw.FlexColumnWidth(2),    // Preis/E
            4: const pw.FlexColumnWidth(2),    // Gesamt
            5: const pw.FlexColumnWidth(1.5),  // Rabatt (NEU)
            6: const pw.FlexColumnWidth(2),    // Netto Gesamt (NEU)
          },
          children: rows,
        ),
      ],
    );
  }


  /// Berechnet optimale Spaltenbreiten basierend auf Inhalt
  static Map<int, pw.FlexColumnWidth> _calculateOptimalColumnWidths(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String language,
      bool showDimensions,
      ) {
    const double charWidth = 0.18;

    int maxProductLen = language == 'EN' ? 7 : 7;
    int maxInstrLen = 10;
    int maxQualLen = language == 'EN' ? 8 : 10;
    int maxFscLen = 4;
    int maxDimLen = language == 'EN' ? 10 : 5;

    groupedItems.forEach((woodGroup, items) {
      for (final item in items) {
        String productText = language == 'EN'
            ? (item['part_name_en'] ?? item['part_name'] ?? '')
            : (item['part_name'] ?? '');
        if (item['notes'] != null && item['notes'].toString().isNotEmpty) {
          productText += ' (${item['notes']})';
        }
        if (item['is_gratisartikel'] == true) productText += '  GRATIS';
        if (item['is_online_shop_item'] == true) productText += '  #0000';
        if (productText.length > maxProductLen) maxProductLen = productText.length;

        String instrText = language == 'EN'
            ? (item['instrument_name_en'] ?? item['instrument_name'] ?? '')
            : (item['instrument_name'] ?? '');
        if (instrText.length > maxInstrLen) maxInstrLen = instrText.length;

        String qualText = item['quality_name'] ?? '';
        if (qualText.length > maxQualLen) maxQualLen = qualText.length;

        String fscText = item['fsc_status'] ?? '';
        if (fscText.length > maxFscLen) maxFscLen = fscText.length;

        if (showDimensions) {
          final l = item['custom_length']?.toString() ?? '';
          final w = item['custom_width']?.toString() ?? '';
          final t = item['custom_thickness']?.toString() ?? '';
          String dimText = '$l×$w×$t';
          if (dimText.length > maxDimLen) maxDimLen = dimText.length;
        }
      }
    });

    double productWidth = (maxProductLen * charWidth).clamp(3.0, 5.5);
    double instrWidth = (maxInstrLen * charWidth).clamp(2.0, 3.5);
    double qualWidth = (maxQualLen * charWidth).clamp(1.5, 2.2);
    double fscWidth = (maxFscLen * charWidth).clamp(1.2, 1.8);
    double dimWidth = (maxDimLen * charWidth).clamp(1.8, 2.8);

    if (showDimensions) {
      return {
        0: pw.FlexColumnWidth(productWidth),
        1: pw.FlexColumnWidth(instrWidth),
        2: pw.FlexColumnWidth(qualWidth),
        3: pw.FlexColumnWidth(fscWidth),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.0),
        6: pw.FlexColumnWidth(dimWidth),
        7: const pw.FlexColumnWidth(1.3),
        8: const pw.FlexColumnWidth(1.2),
        9: const pw.FlexColumnWidth(2.0),
        10: const pw.FlexColumnWidth(2.0),
        11: const pw.FlexColumnWidth(1.6),
        12: const pw.FlexColumnWidth(2.2),
      };
    } else {
      return {
        0: pw.FlexColumnWidth(productWidth),
        1: pw.FlexColumnWidth(instrWidth),
        2: pw.FlexColumnWidth(qualWidth),
        3: pw.FlexColumnWidth(fscWidth),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.0),
        6: const pw.FlexColumnWidth(1.3),
        7: const pw.FlexColumnWidth(1.2),
        8: const pw.FlexColumnWidth(2.0),
        9: const pw.FlexColumnWidth(2.0),
        10: const pw.FlexColumnWidth(1.6),
        11: const pw.FlexColumnWidth(2.2),
      };
    }
  }

  // Erstelle Produkttabelle mit Gruppierung
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      bool showDimensions)
  {

    final List<pw.TableRow> rows = [];

    // Header-Zeile anpassen basierend auf showDimensions
    final headerCells = <pw.Widget>[
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Product' : 'Produkt', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Instrument' : 'Instrument', 8),
      // BasePdfGenerator.buildHeaderCell(
      //     language == 'EN' ? 'Type' : 'Typ', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Quality' : 'Qualität', 8),
      BasePdfGenerator.buildHeaderCell('FSC®', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Orig' : 'Urs', 8),
      BasePdfGenerator.buildHeaderCell('°C', 8),
    ];

    // NEU: Nur wenn showDimensions true ist
    if (showDimensions) {
      headerCells.add(BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Dimensions' : 'Masse', 8));
    }

    headerCells.addAll([
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Qty' : 'Anz.', 8, align: pw.TextAlign.right),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Unit' : 'Einh', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: pw.TextAlign.right),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Total' : 'Gesamt', 8, align: pw.TextAlign.right),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Disc.' : 'Rab.', 8, align: pw.TextAlign.right),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right),
    ]);

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: headerCells,
      ),
    );

    double totalAmount = 0.0;
    // Für jede Holzart-Gruppe
    groupedItems.forEach((woodGroup, items) {
      // Holzart-Header - Kompakte Zeile mit kleinem Padding
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            // Erste Zelle mit kompaktem Padding
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4), // Weniger Padding!
              child: pw.Text(
                woodGroup,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7, // Kleinere Schrift
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            // Alle anderen 12 Zellen minimal
            ...List.generate(13, (index) => pw.SizedBox(height: 16)), // Niedrige fixe Höhe
          ],
        ),
      );

      // Items der Holzart
      // Items der Holzart
      for (final item in items) {
        // NEU: Gratisartikel-Check hinzufügen
        final isGratisartikel = item['is_gratisartikel'] == true;

        final quantity = (item['quantity'] as num? ?? 0).toDouble();

        // ÄNDERUNG: Preis bei Gratisartikeln auf 0 setzen
        // NEU: Prüfe erst ob custom_price_per_unit existiert, sonst normalen Preis
        final pricePerUnit = isGratisartikel
            ? 0.0
            : (item['custom_price_per_unit'] as num?) != null
            ? (item['custom_price_per_unit'] as num).toDouble()
            : (item['price_per_unit'] as num? ?? 0).toDouble();

        final discount = item['discount'] as Map<String, dynamic>?;

        // Gesamtbetrag vor Rabatt
        final totalBeforeDiscount = quantity * pricePerUnit;

        // Rabattbetrag berechnen (nicht aus discount_amount lesen!)
        double discountAmount = 0.0;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();

          if (percentage > 0) {
            discountAmount = totalBeforeDiscount * (percentage / 100);
          } else if (absolute > 0) {
            discountAmount = absolute;
          }
        }

        // Gesamtbetrag nach Rabatt
        final itemTotal = totalBeforeDiscount - discountAmount;

        // Maße zusammenstellen
        String dimensions = '';
        final customLength = (item['custom_length'] as num?) ?? 0;
        final customWidth = (item['custom_width'] as num?) ?? 0;
        final customThickness = (item['custom_thickness'] as num?) ?? 0;

// Nur anzeigen wenn mindestens ein Maß größer als 0 ist
        if (customLength > 0 || customWidth > 0 || customThickness > 0) {
          dimensions = '${customLength}×${customWidth}×${customThickness}';
        }

        // Einheit korrigieren: "Stück" zu "Stk"
        String unit = item['unit'] ?? '';

if (unit.toLowerCase() == 'stück') {
  unit = language == 'EN' ? 'pcs' : 'Stk';
}


        rows.add(
          pw.TableRow(
            children: [
              // ÄNDERUNG: Produktname mit Gratisartikel-Badge
              BasePdfGenerator.buildContentCell(
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          pw.Text(
                              language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 8)
                          ),
                          // NEU: Hinweise in Klammern hinzufügen
                          if (item['notes'] != null && item['notes'].toString().isNotEmpty)
                            pw.Text(
                              ' (${item['notes']})',
                              style: pw.TextStyle(
                                fontSize: 6,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.grey700,
                              ),
                            ),
                          // Gratisartikel-Badge
                          if (isGratisartikel)
                            pw.Container(
                              margin: const pw.EdgeInsets.only(left: 4),
                              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.green,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Text(
                                language == 'EN' ? 'FREE' : 'GRATIS',
                                style: const pw.TextStyle(
                                  fontSize: 5,
                                  color: PdfColors.white,
                                ),
                              ),
                            ),
                          // NEU: Online-Shop Badge mit letzten 4 Ziffern
                          if (item['is_online_shop_item'] == true && item['online_shop_barcode'] != null)
                            pw.Container(
                              margin: const pw.EdgeInsets.only(left: 4),
                              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blueGrey600,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Text(
                                '#${item['online_shop_barcode'].toString().substring(item['online_shop_barcode'].toString().length - 4)}',
                                style: const pw.TextStyle(
                                  fontSize: 5,
                                  color: PdfColors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(  language == 'EN' ?item['instrument_name_en']:item['instrument_name'] ?? '', style: const pw.TextStyle(fontSize: 8)),
              ),
              // BasePdfGenerator.buildContentCell(
              //   pw.Text(  language == 'EN' ?item['part_name_en']:item['part_name'] ?? '', style: const pw.TextStyle(fontSize: 8)),
              // ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 8)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['fsc_status'] ?? '', style: const pw.TextStyle(fontSize: 8)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text('CH', style: const pw.TextStyle(fontSize: 8)),
              ),
// NEU: Thermobehandlungs-Temperatur anzeigen
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  item['has_thermal_treatment'] == true && item['thermal_treatment_temperature'] != null
                      ? item['thermal_treatment_temperature'].toString()
                      : '',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (showDimensions) BasePdfGenerator.buildContentCell(pw.Text(dimensions, style: const pw.TextStyle(fontSize: 8)),),

              BasePdfGenerator.buildContentCell(
                pw.Text(
                  unit != "Stk"
                      ? quantity.toStringAsFixed(3)
                      : quantity.toStringAsFixed(quantity == quantity.round() ? 0 : 3),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(unit, style: const pw.TextStyle(fontSize: 8)),
              ),

              // Originalpreis pro Einheit
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.right,
                ),
              ),

// NEU: Gesamtpreis (Menge × Einzelpreis, unrabattiert)
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(quantity * pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.right,
                ),
              ),

// NEU: Rabatt-Spalte (jetzt an 3. Stelle)
              BasePdfGenerator.buildContentCell(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (discount != null && (discount['percentage'] as num? ?? 0) > 0)
                      pw.Text(
                        '${discount['percentage'].toStringAsFixed(2)}%',
                        style: const pw.TextStyle(fontSize: 8, ),
                        textAlign: pw.TextAlign.right,
                      ),
                    if (discount != null && (discount['absolute'] as num? ?? 0) > 0)
                      pw.Text(
                        BasePdfGenerator.formatCurrency(
                            (discount['absolute'] as num).toDouble(),
                            currency,
                            exchangeRates
                        ),
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right,
                      ),
                  ],
                ),
              ),

// NEU: Netto Gesamtpreis - Rabattierter Gesamtbetrag (jetzt an 4. Stelle)
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(itemTotal, currency, exchangeRates),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: discountAmount > 0 ? pw.FontWeight.bold : null,

                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }
    });

    final columnWidths = _calculateOptimalColumnWidths(
      groupedItems,
      language,
      showDimensions,
    );
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }
// Hilfsmethode für die Referenz-Formatierung
  static String _buildDownPaymentReference(String reference, DateTime? date, String language) {
    final List<String> parts = [];

    if (reference.isNotEmpty) {
      // Bei Zahlungsmethoden direkt anzeigen
      if (reference == 'Barzahlung' || reference == 'Cash payment') {
        return ' (${reference})';
      }
      // Bei anderen Referenzen
      parts.add(reference);
    }

    if (date != null) {
      parts.add(DateFormat('dd.MM.yyyy').format(date));
    }

    if (parts.isEmpty) {
      return '';
    }

    // Keine "Referenz:" Prefix bei Zahlungsmethoden
    if (reference == 'Barzahlung' || reference == 'Cash payment' ||
        reference.toLowerCase().contains('paypal') ||
        reference.toLowerCase().contains('überweisung')) {
      return ' (${parts.join(', ')})';
    }
    final referenceText = language == 'EN' ? '' : '';
    //final referenceText = language == 'EN' ? 'Reference' : 'Referenz';
    //return ' ($referenceText: ${parts.join(', ')})';
    return ' (${parts.join(', ')})';
  }

  static pw.Widget _buildTotalsSection(
      List<Map<String, dynamic>> items,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      Map<String, dynamic>? shippingCosts,
      Map<String, dynamic>? calculations,
      int taxOption,
      double vatRate,
      Map<String, dynamic>? downPaymentSettings,
      DateTime? paymentDue,
      Map<String, bool> roundingSettings,
      ) {
    print('===== DEBUG _buildTotalsSection START =====');
    print('Currency: $currency');
    print('Exchange Rates: $exchangeRates');
    print('Tax Option: $taxOption');
    print('VAT Rate: $vatRate');
    print('Down Payment Settings: $downPaymentSettings');

    double subtotal = 0.0;
    double actualItemDiscounts = 0.0;

    for (final item in items) {
      final isGratisartikel = item['is_gratisartikel'] == true;
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = isGratisartikel
          ? 0.0
          : (item['custom_price_per_unit'] as num?) != null
          ? (item['custom_price_per_unit'] as num).toDouble()
          : (item['price_per_unit'] as num? ?? 0).toDouble();

      subtotal += quantity * pricePerUnit;

      if (!isGratisartikel) {
        final itemDiscountAmount = (item['discount_amount'] as num? ?? 0).toDouble();
        actualItemDiscounts += itemDiscountAmount;
      }
    }

    print('Subtotal: $subtotal');
    print('Actual Item Discounts: $actualItemDiscounts');

    final itemDiscounts = actualItemDiscounts > 0 ? actualItemDiscounts : (calculations?['item_discounts'] ?? 0.0);
    final totalDiscountAmount = calculations?['total_discount_amount'] ?? 0.0;
    final afterDiscounts = subtotal - itemDiscounts - totalDiscountAmount;

    print('After Discounts: $afterDiscounts');

    // Versandkosten
    final plantCertificate = shippingCosts?['plant_certificate_enabled'] == true
        ? ((shippingCosts?['plant_certificate_cost'] as num?) ?? 0).toDouble()
        : 0.0;
    final packagingCost = ((shippingCosts?['packaging_cost'] as num?) ?? 0).toDouble();
    final freightCost = ((shippingCosts?['freight_cost'] as num?) ?? 0).toDouble();
    final shippingCombined = shippingCosts?['shipping_combined'] ?? true;
    final carrier = (shippingCosts?['carrier'] == 'Persönlich abgeholt' && language == 'EN')
        ? 'Collected in person'
        : (shippingCosts?['carrier'] ?? 'Swiss Post');

    // Abschläge und Zuschläge
    final totalDeductions = ((shippingCosts?['totalDeductions'] as num?) ?? 0).toDouble();
    final totalSurcharges = ((shippingCosts?['totalSurcharges'] as num?) ?? 0).toDouble();

    final netAmount = afterDiscounts + plantCertificate + packagingCost + freightCost + totalSurcharges - totalDeductions;

    print('Amount (before tax): $netAmount');
    print('Amount in CHF: $netAmount');

    // MwSt-Berechnung basierend auf taxOption
    double vatAmount = 0.0;
    double totalWithTax = netAmount;

    if (taxOption == 0) { // TaxOption.standard
      final netAmountRounded = double.parse(netAmount.toStringAsFixed(2));
      vatAmount = double.parse((netAmountRounded * (vatRate / 100)).toStringAsFixed(2));
      totalWithTax = netAmountRounded + vatAmount;
      print('Standard Tax - VAT Amount: $vatAmount');
      print('Standard Tax - Total with Tax: $totalWithTax');
    } else {
      totalWithTax = double.parse(netAmount.toStringAsFixed(2));
      print('No/Included Tax - Total: $totalWithTax');
    }

    // Rundung anwenden
    double displayTotal = totalWithTax;
    double roundingDifference = 0.0;

    print('Before Rounding - Display Total: $displayTotal');
    print('Rounding Settings for $currency: ${roundingSettings[currency]}');

    if (roundingSettings[currency] == true) {
      if (currency != 'CHF') {
        displayTotal = totalWithTax * (exchangeRates[currency] ?? 1.0);
        print('Converted to $currency for rounding: $displayTotal');
      }

      final roundedDisplayTotal = SwissRounding.round(
        displayTotal,
        currency: currency,
        roundingSettings: roundingSettings,
      );

      print('After SwissRounding.round: $roundedDisplayTotal');
      roundingDifference = roundedDisplayTotal - displayTotal;
      print('Rounding Difference: $roundingDifference');

      displayTotal = roundedDisplayTotal;

      if (currency != 'CHF') {
        totalWithTax = displayTotal / (exchangeRates[currency] ?? 1.0);
        print('Converted back to CHF after rounding: $totalWithTax');
      } else {
        totalWithTax = displayTotal;
      }
    }

    print('Final totalWithTax in CHF: $totalWithTax');

    double totalInTargetCurrency = totalWithTax;
    if (currency != 'CHF') {
      totalInTargetCurrency = totalWithTax * (exchangeRates[currency] ?? 1.0);
      print('Total in Target Currency ($currency): $totalInTargetCurrency');
    }

    // Anzahlung berechnen
    final isFullPayment = downPaymentSettings?['is_full_payment'] ?? false;
    print('Is Full Payment: $isFullPayment');

    double downPaymentAmount = 0.0;
    String downPaymentReference = '';
    DateTime? downPaymentDate;

    if (isFullPayment) {
      downPaymentAmount = totalInTargetCurrency;
      print('Full Payment - Down Payment Amount = Total in Target Currency: $downPaymentAmount');

      final paymentMethod = downPaymentSettings?['payment_method'] ?? 'BAR';
      if (paymentMethod == 'BAR') {
        downPaymentReference = language == 'EN' ? 'Cash payment' : 'Barzahlung';
      } else {
        downPaymentReference = downPaymentSettings?['custom_payment_method'] ?? '';
      }
      downPaymentDate = DateTime.now();
    } else {
      downPaymentAmount = downPaymentSettings != null
          ? ((downPaymentSettings['down_payment_amount'] as num?) ?? 0.0).toDouble()
          : 0.0;
      print('Partial Payment - Down Payment Amount: $downPaymentAmount');
      downPaymentReference = downPaymentSettings?['down_payment_reference'] ?? '';
      downPaymentDate = downPaymentSettings?['down_payment_date'];
    }

    // KRITISCHER BEREICH - Restbetragsberechnung
    print('===== RESTBETRAG BERECHNUNG =====');
    print('Tax Option: $taxOption');
    print('Currency: $currency');
    print('totalInTargetCurrency: $totalInTargetCurrency');
    print('downPaymentAmount: $downPaymentAmount');

    double balanceDue = 0.0;

    if (taxOption == 0) { // Standard Tax
      balanceDue = totalInTargetCurrency - downPaymentAmount;
      print('[Standard Tax] Balance Due = $totalInTargetCurrency - $downPaymentAmount = $balanceDue');
    } else if (taxOption == 1) { // No Tax
      if (currency != 'CHF') {
        // Bei noTax müssen wir netAmount in Zielwährung umrechnen
        final netInTargetCurrency = netAmount * (exchangeRates[currency] ?? 1.0);
        balanceDue = netInTargetCurrency - downPaymentAmount;
        print('[No Tax] Net in Target Currency: $netInTargetCurrency');
        print('[No Tax] Balance Due = $netInTargetCurrency - $downPaymentAmount = $balanceDue');
      } else {
        balanceDue = netAmount - downPaymentAmount;
        print('[No Tax CHF] Balance Due = $netAmount - $downPaymentAmount = $balanceDue');
      }
    } else { // Tax Option 2 - Total Only (Steuer inkludiert)
      print('[Total Only] This is the problematic case!');
      print('[Total Only] netAmount (CHF): $netAmount');
      print('[Total Only] currency: $currency');

      if (currency != 'CHF') {
        // HIER IST VERMUTLICH DER FEHLER
        final netInTargetCurrency = netAmount * (exchangeRates[currency] ?? 1.0);
        print('[Total Only] Net in Target Currency: $netInTargetCurrency');
        print('[Total Only] Down Payment Amount: $downPaymentAmount');
        balanceDue = netInTargetCurrency - downPaymentAmount;
        print('[Total Only] Balance Due = $netInTargetCurrency - $downPaymentAmount = $balanceDue');
      } else {
        balanceDue = netAmount - downPaymentAmount;
        print('[Total Only CHF] Balance Due = $netAmount - $downPaymentAmount = $balanceDue');
      }
    }

    print('===== FINAL BALANCE DUE: $balanceDue =====');
    print('===== DEBUG _buildTotalsSection END =====');

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 400,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Subtotal (bereits reduziert um Positionsrabatte)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(language == 'EN' ? 'Subtotal' : 'Subtotal', style: const pw.TextStyle(fontSize: 9)),
                pw.Text(BasePdfGenerator.formatCurrency(subtotal - itemDiscounts, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
              ],
            ),

            // Gesamtrabatt
            if (totalDiscountAmount > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(

                    children: [

                      pw.Text(language == 'EN' ? 'Total discount' : 'Gesamtrabatt', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(' (${(totalDiscountAmount/subtotal*100).toStringAsFixed(2)}%)', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),

                  pw.Text('- ${BasePdfGenerator.formatCurrency(totalDiscountAmount, currency, exchangeRates)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],

            // Pflanzenschutzzeugniss
            if (plantCertificate > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'Phytosanitary certificate' : 'Pflanzenschutzzeugniss', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(BasePdfGenerator.formatCurrency(plantCertificate, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
// Verpackung & Fracht
            if (shippingCombined) ...[
              // NEU: Prüfe ob persönlich abgeholt
              // Statt nur zu prüfen ob "Persönlich abgeholt"
              if (carrier == 'Persönlich abgeholt' || carrier == 'Collected in person') ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Collected in person' : 'Persönlich abgeholt',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    // NEU: Nur wenn Kosten 0 sind, nichts anzeigen, sonst Preis zeigen
                    if (packagingCost + freightCost > 0)
                      pw.Text(BasePdfGenerator.formatCurrency(packagingCost + freightCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9))
                    else
                      pw.SizedBox(),
                  ],
                ),
              ] else if (packagingCost + freightCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN'
                          ? 'Packing & Freight costs ($carrier)'
                          : 'Verpackungs- & Frachtkosten ($carrier)',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(BasePdfGenerator.formatCurrency(packagingCost + freightCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ] else ...[
              // Getrennt
              if (packagingCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(language == 'EN' ? 'Packing costs' : 'Verpackungskosten', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(BasePdfGenerator.formatCurrency(packagingCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
              // NEU: Bei getrennter Anzeige auch prüfen ob persönlich abgeholt
              if (carrier == 'Persönlich abgeholt' || carrier == 'Collected in person') ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Collected in person' : 'Persönlich abgeholt',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    // NEU: Nur wenn Frachtkosten 0 sind, nichts anzeigen, sonst Preis zeigen
                    if (freightCost > 0)
                      pw.Text(BasePdfGenerator.formatCurrency(freightCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9))
                    else
                      pw.SizedBox(),
                  ],
                ),
              ] else if (freightCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN'
                          ? 'Freight costs ($carrier)'
                          : 'Frachtkosten ($carrier)',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(BasePdfGenerator.formatCurrency(freightCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ],

            // Abschläge und Zuschläge
            if (shippingCosts != null) ...[
              // Abschlag 1
              if ((shippingCosts['deduction_1_text'] ?? '').isNotEmpty && ((shippingCosts['deduction_1_amount'] as num?) ?? 0).toDouble()> 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_1_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_1_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
                    ),
                  ],
                ),
              ],

              // Abschlag 2
              if ((shippingCosts['deduction_2_text'] ?? '').isNotEmpty && (shippingCosts['deduction_2_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_2_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_2_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
                    ),
                  ],
                ),
              ],

              // Abschlag 3
              if ((shippingCosts['deduction_3_text'] ?? '').isNotEmpty && (shippingCosts['deduction_3_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_3_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_3_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
                    ),
                  ],
                ),
              ],

              // Zuschlag 1
              if ((shippingCosts['surcharge_1_text'] ?? '').isNotEmpty && (shippingCosts['surcharge_1_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['surcharge_1_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      BasePdfGenerator.formatCurrency(shippingCosts['surcharge_1_amount'], currency, exchangeRates),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],

              // Zuschlag 2
              if ((shippingCosts['surcharge_2_text'] ?? '').isNotEmpty && (shippingCosts['surcharge_2_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['surcharge_2_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      BasePdfGenerator.formatCurrency(shippingCosts['surcharge_2_amount'], currency, exchangeRates),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],

              // Zuschlag 3
              if ((shippingCosts['surcharge_3_text'] ?? '').isNotEmpty && (shippingCosts['surcharge_3_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['surcharge_3_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      BasePdfGenerator.formatCurrency(shippingCosts['surcharge_3_amount'], currency, exchangeRates),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ],

            // MwSt-Bereich je nach Option
            if (taxOption == 0) ...[  // TaxOption.standard
              pw.Divider(color: PdfColors.blueGrey300),

              // Nettobetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'invoice amount' : 'Nettobetrag', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.SizedBox(height: 4),

              // MwSt
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN'
                        ? 'VAT (${vatRate.toStringAsFixed(1)}%)'
                        : 'MwSt (${vatRate.toStringAsFixed(1)}%)',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(BasePdfGenerator.formatCurrency(vatAmount, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.SizedBox(height: 4),
              // Rundungsdifferenz anzeigen (falls vorhanden)
              if (roundingSettings[currency] == true && roundingDifference != 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Rounding' : 'Rundung',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      roundingDifference > 0
                          ? '+${BasePdfGenerator.formatCurrency(roundingDifference.abs() / exchangeRates[currency]!, currency, exchangeRates)}'
                          : '-${BasePdfGenerator.formatCurrency(roundingDifference.abs() / exchangeRates[currency]!, currency, exchangeRates)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: roundingDifference > 0 ? PdfColors.green700 : PdfColors.orange800,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],


              pw.Divider(color: PdfColors.blueGrey300),

              // Gesamtbetrag
    // Bruttobetrag
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Text(
    language == 'EN' ? 'Gross amount' : 'Bruttobetrag',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    pw.Text(
    BasePdfGenerator.formatCurrency(totalWithTax, currency, exchangeRates),
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    ],
    ),

    // NEU: Anzahlung abziehen falls vorhanden
              // NEU: Anzahlung/Vollzahlung abziehen falls vorhanden
              if (downPaymentAmount > 0) ...[
                pw.SizedBox(height: 8),

                // Anzahlungszeile
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isFullPayment
                          ? (language == 'EN'
                          ? './ Payment received${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
                          : './ Zahlung erhalten${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}')
                          : (language == 'EN'
                          ? './ Down payment${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
                          : './ Anzahlung${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      '$currency ${downPaymentAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),

                pw.SizedBox(height: 4),

                // Restbetrag
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN'
                          ? 'Balance due'
                          : 'Restbetrag',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(
                      '$currency ${(totalInTargetCurrency - downPaymentAmount).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ],
                ),
              ],

    ] else if (taxOption == 1) ...[  // TaxOption.noTax
    pw.Divider(color: PdfColors.blueGrey300),

    // Nettobetrag
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Text(
    language == 'EN' ? 'invoice amount' : 'Nettobetrag',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    pw.Text(
    BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates),
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    ],
    ),

    // pw.SizedBox(height: 4),
    // pw.Text(
    // language == 'EN'
    // ? 'No VAT will be charged.'
    //     : 'Es wird keine Mehrwertsteuer berechnet.',
    // style: pw.TextStyle(
    // fontSize: 9,
    // fontStyle: pw.FontStyle.italic,
    // color: PdfColors.grey700,
    // ),
    // ),

    // NEU: Anzahlung auch bei noTax abziehen
    if (downPaymentAmount > 0) ...[
    pw.SizedBox(height: 8),

    // Anzahlungszeile
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Text(
    language == 'EN'
    ? './ Down payment${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
        : './ Anzahlung${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}',
    style: const pw.TextStyle(fontSize: 9),
    ),
    pw.Text(
    '$currency ${downPaymentAmount.toStringAsFixed(2)}',
    style: const pw.TextStyle(fontSize: 9),
    ),
    ],
    ),

    pw.SizedBox(height: 4),

    // Restbetrag
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Text(
    language == 'EN'
    ? 'Balance due'
        : 'Restbetrag',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    pw.Text(
    BasePdfGenerator.formatCurrency(netAmount - downPaymentAmount, currency, exchangeRates),
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    ],
    ),
    ],

            ] else ...[  // TaxOption.totalOnly
              pw.Divider(color: PdfColors.blueGrey300),

              // Gesamtbetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN'
                        ? 'Total incl. ${vatRate.toStringAsFixed(1)}% VAT'
                        : 'Gesamtbetrag inkl. ${vatRate.toStringAsFixed(1)}% MwSt',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                  pw.Text(
                    // ÄNDERUNG: Verwende totalWithTax statt netAmount
                    BasePdfGenerator.formatCurrency(totalWithTax, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                ],
              ),

              // Anzahlung falls vorhanden
              if (downPaymentAmount > 0) ...[
                pw.SizedBox(height: 8),

                // Anzahlungszeile
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isFullPayment
                          ? (language == 'EN'
                          ? './ Payment received${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
                          : './ Zahlung erhalten${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}')
                          : (language == 'EN'
                          ? './ Down payment${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
                          : './ Anzahlung${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      '$currency ${downPaymentAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),

                pw.SizedBox(height: 4),

                // Restbetrag
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Balance due' : 'Restbetrag',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(
                      // ÄNDERUNG: Verwende totalInTargetCurrency - downPaymentAmount
                      '$currency ${(totalInTargetCurrency - downPaymentAmount).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Ändere die _addInlineAdditionalTexts Methode:
  static Future<pw.Widget> _addInlineAdditionalTexts(
      String language,
      Map<String, dynamic>? additionalTexts, // NEU: Additional Texts als Parameter
      ) async {
    try {
      // NEU: Verwende die übergebenen Additional Texts oder lade Default-Werte
      final textsToUse = additionalTexts ?? {
        'legend': {
          'type': 'standard',
          'custom_text': '',
          'selected': true,
        },
        'fsc': {
          'type': 'standard',
          'custom_text': '',
          'selected': false,
        },
        'natural_product': {
          'type': 'standard',
          'custom_text': '',
          'selected': true,
        },
        'bank_info': {
          'type': 'standard',
          'custom_text': '',
          'selected': true,
        },
        'free_text': {
          'type': 'custom',
          'custom_text': '',
          'selected': false,
        },
      };

      final List<pw.Widget> textWidgets = [];

      // Sammle alle ausgewählten Texte
      if (textsToUse['legend']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['legend'],
                  'legend',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textsToUse['fsc']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['fsc'],
                  'fsc',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textsToUse['natural_product']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['natural_product'],
                  'natural_product',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textsToUse['bank_info']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['bank_info'],
                  'bank_info',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      // Neues Freitextfeld
      if (textsToUse['free_text']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['free_text'],
                  'free_text',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textWidgets.isEmpty) {
        return pw.SizedBox.shrink();
      }

      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: textWidgets,
        ),
      );
    } catch (e) {
      print('Fehler beim Laden der Zusatztexte: $e');
      return pw.SizedBox.shrink();
    }
  }

}