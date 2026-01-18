import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../document_selection_manager.dart';
import '../product_sorting_manager.dart';
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
    String? quoteNumber,
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

    final invoiceSettings = downPaymentSettings ?? await DocumentSelectionManager.loadInvoiceSettings();
    DateTime invoiceDate = invoiceSettings['invoice_date'] ?? DateTime.now();

    final showDimensions = invoiceSettings['show_dimensions'] ?? false;

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

    if (invoiceSettings['payment_term_days'] != null) {
      paymentTermDays = invoiceSettings['payment_term_days'];
    }

    // Gruppiere Items nach Holzart
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final serviceItems = items.where((item) => item['is_service'] == true).toList();

    // DYNAMISCH: Prüfen ob Spalten benötigt werden
    final showThermalColumn = productItems.any((item) =>
    item['has_thermal_treatment'] == true &&
        item['thermal_treatment_temperature'] != null);

    final showDiscountColumn = productItems.any((item) {
      final discount = item['discount'] as Map<String, dynamic>?;
      if (discount == null) return false;
      final percentage = (discount['percentage'] as num? ?? 0).toDouble();
      final absolute = (discount['absolute'] as num? ?? 0).toDouble();
      return percentage > 0 || absolute > 0;
    });

    // Nur Produkte gruppieren (Dienstleistungen haben keine Holzart)
    final groupedProductItems = await _groupItemsByWoodType(productItems, language);

    final additionalTextsWidget = await _addInlineAdditionalTexts(language, additionalTexts);

    // Übersetzungsfunktion
    String getTranslation(String key) {
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

      if (isFullPayment) {
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
              //  additionalReference: quoteNumber != null && quoteNumber.isNotEmpty
              //      ? getTranslation('quote_reference')
              //      : null,
              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
              BasePdfGenerator.buildCustomerAddress(customerData, 'invoice', language: language),

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
                        BasePdfGenerator.buildCurrencyHint(currency, language),

                        // Produkttabelle nur wenn Produkte vorhanden
                        if (productItems.isNotEmpty)
                          _buildProductTable(groupedProductItems, currency, exchangeRates, language, showDimensions, showThermalColumn, showDiscountColumn),

                        // Dienstleistungstabelle nur wenn Dienstleistungen vorhanden
                        if (serviceItems.isNotEmpty)
                          _buildServiceTable(serviceItems, currency, exchangeRates, language),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    // Summen-Bereich
                    _buildTotalsSection(items, currency, exchangeRates, language, shippingCosts, calculations, taxOption, vatRate, downPaymentSettings, paymentDue, roundingSettings),

                    pw.SizedBox(height: 10),
                    // Zahlungshinweis
                    if (!isFullPayment) ...[
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
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: PdfColors.green200, width: 0.5),
                        ),
                        child: pw.Text(
                          getTranslation('payment_note'),
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

  /// Gruppiert Items nach Holzart mit konfigurierbarer Sortierung
  static Future<Map<String, List<Map<String, dynamic>>>> _groupItemsByWoodType(
      List<Map<String, dynamic>> items,
      String language,
      ) async {

    // Nutze den ProductSortingManager für die Gruppierung (Holzart ist fixiert)
    return await ProductSortingManager.groupAndSortProducts(
      items,
      language,
      getAdditionalInfo: (code, criteria) async {
        return await ProductSortingManager.getInfoForCriteria(code, criteria);
      },
    );
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
        ],
      ),
    );

    for (final service in serviceItems) {
      final quantity = (service['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = (service['custom_price_per_unit'] as num?) != null
          ? (service['custom_price_per_unit'] as num).toDouble()
          : (service['price_per_unit'] as num? ?? 0).toDouble();
      final total = quantity * pricePerUnit;

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
               BasePdfGenerator.formatAmountOnly(pricePerUnit, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
               BasePdfGenerator.formatAmountOnly(total, currency, exchangeRates),
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
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
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
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
      bool showThermalColumn,
      bool showDiscountColumn,
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

    // Dynamische Spaltenbreiten-Map erstellen
    final Map<int, pw.FlexColumnWidth> widths = {};
    int colIndex = 0;

    widths[colIndex++] = pw.FlexColumnWidth(productWidth);  // Produkt
    widths[colIndex++] = pw.FlexColumnWidth(instrWidth);    // Instr.
    widths[colIndex++] = pw.FlexColumnWidth(qualWidth);     // Qual.
    widths[colIndex++] = pw.FlexColumnWidth(fscWidth);      // FSC
    widths[colIndex++] = const pw.FlexColumnWidth(1.2);     // Urs

    if (showThermalColumn) {
      widths[colIndex++] = const pw.FlexColumnWidth(1.0);   // °C
    }
    if (showDimensions) {
      widths[colIndex++] = pw.FlexColumnWidth(dimWidth);    // Masse
    }

    widths[colIndex++] = const pw.FlexColumnWidth(1.3);     // Anz.
    widths[colIndex++] = const pw.FlexColumnWidth(1.2);     // Einh
    widths[colIndex++] = const pw.FlexColumnWidth(2.0);     // Preis/E
    widths[colIndex++] = const pw.FlexColumnWidth(2.0);     // Gesamt

    if (showDiscountColumn) {
      widths[colIndex++] = const pw.FlexColumnWidth(1.6);   // Rabatt
      widths[colIndex++] = const pw.FlexColumnWidth(2.2);   // Netto
    }

    return widths;
  }

  // Erstelle Produkttabelle mit Gruppierung
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      bool showDimensions,
      bool showThermalColumn,
      bool showDiscountColumn) {
    final List<pw.TableRow> rows = [];

    // Header-Zeile
    final headerCells = <pw.Widget>[
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Product' : 'Produkt', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Instrument' : 'Instrument', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Quality' : 'Qualität', 8),
      BasePdfGenerator.buildHeaderCell('FSC®', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Orig' : 'Urs', 8),
    ];

    // Thermobehandlung nur wenn aktiviert
    if (showThermalColumn) {
      headerCells.add(BasePdfGenerator.buildHeaderCell('°C', 8));
    }

    // Masse nur wenn aktiviert
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
    ]);

    // Rabatt und Netto nur wenn aktiviert
    if (showDiscountColumn) {
      headerCells.addAll([
        BasePdfGenerator.buildHeaderCell(
            language == 'EN' ? 'Disc.' : 'Rab.', 8, align: pw.TextAlign.right),
        BasePdfGenerator.buildHeaderCell(
            language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right),
      ]);
    }

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: headerCells,
      ),
    );

    double totalAmount = 0.0;

    // Für jede Holzart-Gruppe
    groupedItems.forEach((woodGroup, items) {
      // Holzart-Header
      final woodGroupCells = <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            woodGroup,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 7,
              color: PdfColors.blueGrey800,
            ),
          ),
        ),
      ];

      // Dynamische Anzahl leerer Zellen
      int emptyCellCount = 9; // Basis: Produkt, Instr, Qual, FSC, Urs, Anz, Einh, Preis/E, Gesamt
      if (showThermalColumn) emptyCellCount++;
      if (showDimensions) emptyCellCount++;
      if (showDiscountColumn) emptyCellCount += 2;

      woodGroupCells.addAll(List.generate(emptyCellCount, (index) => pw.SizedBox(height: 16)));

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: woodGroupCells,
        ),
      );

      // Items der Holzart
      for (final item in items) {
        final isGratisartikel = item['is_gratisartikel'] == true;

        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        final pricePerUnit = isGratisartikel
            ? 0.0
            : (item['custom_price_per_unit'] as num?) != null
            ? (item['custom_price_per_unit'] as num).toDouble()
            : (item['price_per_unit'] as num? ?? 0).toDouble();

        final discount = item['discount'] as Map<String, dynamic>?;
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

        final itemTotal = totalBeforeDiscount - discountAmount;

        // Maße zusammenstellen
        String dimensions = '';
        final customLength = (item['custom_length'] as num?) ?? 0;
        final customWidth = (item['custom_width'] as num?) ?? 0;
        final customThickness = (item['custom_thickness'] as num?) ?? 0;

        if (customLength > 0 || customWidth > 0 || customThickness > 0) {
          dimensions = '${customLength}×${customWidth}×${customThickness}';
        }

        String unit = item['unit'] ?? '';
        if (unit.toLowerCase() == 'stück') {
          unit = language == 'EN' ? 'pcs' : 'Stk';
        }

        // Zeilen-Zellen erstellen
        final rowCells = <pw.Widget>[
          BasePdfGenerator.buildContentCell(
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      pw.Text(
                          language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
                          style: const pw.TextStyle(fontSize: 8)),
                      if (item['notes'] != null && item['notes'].toString().isNotEmpty)
                        pw.Text(
                          ' (${item['notes']})',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontStyle: pw.FontStyle.italic,
                            color: PdfColors.grey700,
                          ),
                        ),
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
            pw.Text(language == 'EN' ? item['instrument_name_en'] : item['instrument_name'] ?? '',
                style: const pw.TextStyle(fontSize: 8)),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 8)),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text(item['fsc_status'] ?? '', style: const pw.TextStyle(fontSize: 8)),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text('CH', style: const pw.TextStyle(fontSize: 8)),
          ),
        ];

        // Thermobehandlung nur wenn aktiviert
        if (showThermalColumn) {
          rowCells.add(
            BasePdfGenerator.buildContentCell(
              pw.Text(
                item['has_thermal_treatment'] == true && item['thermal_treatment_temperature'] != null
                    ? item['thermal_treatment_temperature'].toString()
                    : '',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ),
          );
        }

        // Masse nur wenn aktiviert
        if (showDimensions) {
          rowCells.add(
            BasePdfGenerator.buildContentCell(
              pw.Text(dimensions, style: const pw.TextStyle(fontSize: 8)),
            ),
          );
        }

        rowCells.addAll([
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
          BasePdfGenerator.buildContentCell(
            pw.Text(
             BasePdfGenerator.formatAmountOnly(pricePerUnit, currency, exchangeRates),
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.right,
            ),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text(
             BasePdfGenerator.formatAmountOnly(quantity * pricePerUnit, currency, exchangeRates),
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ]);

        // Rabatt und Netto nur wenn aktiviert
        if (showDiscountColumn) {
          rowCells.addAll([
            BasePdfGenerator.buildContentCell(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (discount != null && (discount['percentage'] as num? ?? 0) > 0)
                    pw.Text(
                      '${discount['percentage'].toStringAsFixed(2)}%',
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  if (discount != null && (discount['absolute'] as num? ?? 0) > 0)
                    pw.Text(
                     BasePdfGenerator.formatAmountOnly(
                          (discount['absolute'] as num).toDouble(),
                          currency,
                          exchangeRates),
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                ],
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
               BasePdfGenerator.formatAmountOnly(itemTotal, currency, exchangeRates),
                style: pw.TextStyle(
                  fontSize: 8,
                  //fontWeight: discountAmount > 0 ? pw.FontWeight.bold : null,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ]);
        }

        rows.add(pw.TableRow(children: rowCells));
      }
    });

    final columnWidths = _calculateOptimalColumnWidths(
      groupedItems,
      language,
      showDimensions,
      showThermalColumn,
      showDiscountColumn,
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
      if (reference == 'Barzahlung' || reference == 'Cash payment') {
        return ' (${reference})';
      }
      parts.add(reference);
    }

    if (date != null) {
      parts.add(DateFormat('dd.MM.yyyy').format(date));
    }

    if (parts.isEmpty) {
      return '';
    }

    if (reference == 'Barzahlung' || reference == 'Cash payment' ||
        reference.toLowerCase().contains('paypal') ||
        reference.toLowerCase().contains('überweisung')) {
      return ' (${parts.join(', ')})';
    }
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

    final itemDiscounts = actualItemDiscounts > 0 ? actualItemDiscounts : (calculations?['item_discounts'] ?? 0.0);
    final totalDiscountAmount = calculations?['total_discount_amount'] ?? 0.0;
    final afterDiscounts = subtotal - itemDiscounts - totalDiscountAmount;

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

    final totalDeductions = ((shippingCosts?['totalDeductions'] as num?) ?? 0).toDouble();
    final totalSurcharges = ((shippingCosts?['totalSurcharges'] as num?) ?? 0).toDouble();

    final netAmount = afterDiscounts + plantCertificate + packagingCost + freightCost + totalSurcharges - totalDeductions;

    // MwSt-Berechnung
    double vatAmount = 0.0;
    double totalWithTax = netAmount;

    if (taxOption == 0) {
      final netAmountRounded = double.parse(netAmount.toStringAsFixed(2));
      vatAmount = double.parse((netAmountRounded * (vatRate / 100)).toStringAsFixed(2));
      totalWithTax = netAmountRounded + vatAmount;
    } else {
      totalWithTax = double.parse(netAmount.toStringAsFixed(2));
    }

    // Rundung anwenden
    double displayTotal = totalWithTax;
    double roundingDifference = 0.0;

    if (roundingSettings[currency] == true) {
      if (currency != 'CHF') {
        displayTotal = totalWithTax * (exchangeRates[currency] ?? 1.0);
      }

      final roundedDisplayTotal = SwissRounding.round(
        displayTotal,
        currency: currency,
        roundingSettings: roundingSettings,
      );

      roundingDifference = roundedDisplayTotal - displayTotal;
      displayTotal = roundedDisplayTotal;

      if (currency != 'CHF') {
        totalWithTax = displayTotal / (exchangeRates[currency] ?? 1.0);
      } else {
        totalWithTax = displayTotal;
      }
    }

    double totalInTargetCurrency = totalWithTax;
    if (currency != 'CHF') {
      totalInTargetCurrency = totalWithTax * (exchangeRates[currency] ?? 1.0);
    }

    // Anzahlung berechnen
    final isFullPayment = downPaymentSettings?['is_full_payment'] ?? false;

    double downPaymentAmount = 0.0;
    String downPaymentReference = '';
    DateTime? downPaymentDate;

    if (isFullPayment) {
      downPaymentAmount = totalInTargetCurrency;
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
      downPaymentReference = downPaymentSettings?['down_payment_reference'] ?? '';
      downPaymentDate = downPaymentSettings?['down_payment_date'];
    }

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
            // Subtotal
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
                      pw.Text(' (${(totalDiscountAmount / subtotal * 100).toStringAsFixed(2)}%)', style: const pw.TextStyle(fontSize: 9)),
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
              if (carrier == 'Persönlich abgeholt' || carrier == 'Collected in person') ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Collected in person' : 'Persönlich abgeholt',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
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
              if (carrier == 'Persönlich abgeholt' || carrier == 'Collected in person') ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Collected in person' : 'Persönlich abgeholt',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
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
              if ((shippingCosts['deduction_1_text'] ?? '').isNotEmpty && ((shippingCosts['deduction_1_amount'] as num?) ?? 0).toDouble() > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_1_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_1_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
              if ((shippingCosts['deduction_2_text'] ?? '').isNotEmpty && (shippingCosts['deduction_2_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_2_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_2_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9,),
                    ),
                  ],
                ),
              ],
              if ((shippingCosts['deduction_3_text'] ?? '').isNotEmpty && (shippingCosts['deduction_3_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_3_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_3_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9, ),
                    ),
                  ],
                ),
              ],
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
            if (taxOption == 0) ...[
              pw.Divider(color: PdfColors.blueGrey300),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'Subtotal' : 'Nettobetrag', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.SizedBox(height: 4),

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

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN' ? 'Invoice amount' : 'Rechnungsbetrag',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                  pw.Text(
                    BasePdfGenerator.formatCurrency(totalWithTax, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                ],
              ),

              if (downPaymentAmount > 0) ...[
                pw.SizedBox(height: 8),

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

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Balance due' : 'Restbetrag',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(
                      '$currency ${(totalInTargetCurrency - downPaymentAmount).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ],
                ),
              ],

            ] else if (taxOption == 1) ...[
              pw.Divider(color: PdfColors.blueGrey300),

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

              if (downPaymentAmount > 0) ...[
                pw.SizedBox(height: 8),

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

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Balance due' : 'Restbetrag',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(
                      '$currency ${(totalInTargetCurrency - downPaymentAmount).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ],
                ),
              ],

            ] else ...[
              pw.Divider(color: PdfColors.blueGrey300),

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
                    BasePdfGenerator.formatCurrency(totalWithTax, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                ],
              ),

              if (downPaymentAmount > 0) ...[
                pw.SizedBox(height: 8),

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

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Balance due' : 'Restbetrag',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(
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

  static Future<pw.Widget> _addInlineAdditionalTexts(
      String language,
      Map<String, dynamic>? additionalTexts,
      ) async {
    try {
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

      if (textsToUse['legend']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['legend'],
                  'legend',
                  language: language),
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
                  language: language),
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
                  language: language),
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
                  language: language),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textsToUse['free_text']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['free_text'],
                  'free_text',
                  language: language),
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