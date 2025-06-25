// File: services/pdf_generators/quote_generator.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';

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
    int paymentTermDays = 30,
    required int taxOption,
    required double vatRate,
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    // Generiere Rechnungs-Nummer falls nicht übergeben
    final invoiceNum = invoiceNumber ?? await getNextInvoiceNumber();
    final paymentDue = DateTime.now().add(Duration(days: paymentTermDays));

    // Gruppiere Items nach Holzart
    final groupedItems = await _groupItemsByWoodType(items, language);
    final additionalTextsWidget = await _addInlineAdditionalTexts(language);

    // Übersetzungsfunktion
    String getTranslation(String key) {
      final translations = {
        'DE': {
          'invoice': 'RECHNUNG',
          'quote_reference': 'Angebotsnummer: $quoteNumber', // NEU
          'currency_note': 'Alle Preise in $currency (Umrechnungskurs: 1 CHF = ${exchangeRates[currency]!.toStringAsFixed(4)} $currency)',
          'payment_note': 'Zahlbar innerhalb von $paymentTermDays Tagen bis ${DateFormat('dd. MMMM yyyy', 'de_DE').format(paymentDue)}.',
        },
        'EN': {
          'invoice': 'INVOICE',
          'quote_reference': 'Quote Number: $quoteNumber', // NEU
          'currency_note': 'All prices in $currency (Exchange rate: 1 CHF = ${exchangeRates[currency]!.toStringAsFixed(4)} $currency)',
          'payment_note': 'Payment due within $paymentTermDays days until ${DateFormat('MMMM dd, yyyy', 'en_US').format(paymentDue)}.',
        }
      };
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
                date: DateTime.now(),
                logo: logo,
                costCenter: costCenterCode,
                language: language,
                additionalReference: quoteNumber != null ? getTranslation('quote_reference') : null, // NEU
              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
              BasePdfGenerator.buildCustomerAddress(customerData),

              pw.SizedBox(height: 15),

              // Währungshinweis (falls nicht CHF)
              if (currency != 'CHF')
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
                    _buildProductTable(groupedItems, currency, exchangeRates, language),
                    pw.SizedBox(height: 10),
                    // Summen-Bereich
                    _buildTotalsSection(items, currency, exchangeRates, language, shippingCosts, calculations, taxOption, vatRate),

                    pw.SizedBox(height: 10),
                    // Zahlungshinweis
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

      final groupKey = '$woodName ($woodNameLatin)';

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

  // Erstelle Produkttabelle mit Gruppierung
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String currency,
      Map<String, double> exchangeRates,
      String language) {

    final List<pw.TableRow> rows = [];

    // Header-Zeile
    // Header-Zeile mit Übersetzungen
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Product' : 'Produkt', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Instr.' : 'Instr.', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Type' : 'Typ', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qual.' : 'Qual.', 8),
          BasePdfGenerator.buildHeaderCell('FSC®', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Orig' : 'Urs', 8),
          BasePdfGenerator.buildHeaderCell('°C', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Dimensions' : 'Masse', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Anz.', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Unit' : 'Einh', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Total' : 'Gesamt', 8, align: pw.TextAlign.right), // NEU: Gesamt statt Disc.
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Disc.' : 'Rab.', 8, align: pw.TextAlign.right), // NEU: Rabatt nach Gesamt
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right), // NEU: Netto Gesamt statt Amount
        ],
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
      for (final item in items) {
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        final pricePerUnit = (item['price_per_unit'] as num? ?? 0).toDouble();
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
        if (item['custom_length'] != null || item['custom_width'] != null || item['custom_thickness'] != null) {
          final length = item['custom_length']?.toString() ?? '';
          final width = item['custom_width']?.toString() ?? '';
          final thickness = item['custom_thickness']?.toString() ?? '';
          dimensions = '${length}×${width}×${thickness}';
        }

        // Einheit korrigieren: "Stück" zu "Stk"
        String unit = item['unit'] ?? '';
        if (unit.toLowerCase() == 'stück') {
          unit = 'Stk';
        }

        rows.add(
          pw.TableRow(
            children: [
              BasePdfGenerator.buildContentCell(
                pw.Text(item['part_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['instrument_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['part_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['fst_status'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text('CH', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text('', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(dimensions, style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  quantity.toStringAsFixed(quantity == quantity.round() ? 0 : 3),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(unit, style: const pw.TextStyle(fontSize: 6)),
              ),

              // Originalpreis pro Einheit
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
                ),
              ),

// NEU: Gesamtpreis (Menge × Einzelpreis, unrabattiert)
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(quantity * pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 6),
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
                        '${discount['percentage']}%',
                        style: const pw.TextStyle(fontSize: 6, color: PdfColors.red),
                        textAlign: pw.TextAlign.right,
                      ),
                    if (discount != null && (discount['absolute'] as num? ?? 0) > 0)
                      pw.Text(
                        BasePdfGenerator.formatCurrency(
                            (discount['absolute'] as num).toDouble(),
                            currency,
                            exchangeRates
                        ),
                        style: const pw.TextStyle(fontSize: 6, color: PdfColors.red),
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
                    fontSize: 6,
                    fontWeight: discountAmount > 0 ? pw.FontWeight.bold : null,
                    color: discountAmount > 0 ? PdfColors.green : null,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }
    });

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),      // Produkt
        1: const pw.FlexColumnWidth(2.0),    // Instr.
        2: const pw.FlexColumnWidth(1.5),    // Typ
        3: const pw.FlexColumnWidth(1.5),    // Qual.
        4: const pw.FlexColumnWidth(1.5),    // FSC
        5: const pw.FlexColumnWidth(1.2),    // Urs
        6: const pw.FlexColumnWidth(1.0),    // °C
        7: const pw.FlexColumnWidth(2.5),    // Masse
        8: const pw.FlexColumnWidth(1.5),      // Anz.
        9: const pw.FlexColumnWidth(1.2),    // Einh
        10: const pw.FlexColumnWidth(2.0),   // Preis/E
        11: const pw.FlexColumnWidth(2.0),   // Gesamt (NEU)
        12: const pw.FlexColumnWidth(1.5),   // Rabatt
        13: const pw.FlexColumnWidth(2.0),   // Netto Gesamt (NEU)
      },
      children: rows,
    );
  }

  // Erstelle Summen-Bereich
  static pw.Widget _buildTotalsSection(
      List<Map<String, dynamic>> items,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      Map<String, dynamic>? shippingCosts,
      Map<String, dynamic>? calculations,
      int taxOption,  // NEU
      double vatRate, // NEU
      ) {
    double subtotal = 0.0;
    double actualItemDiscounts = 0.0;

    for (final item in items) {
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = (item['price_per_unit'] as num? ?? 0).toDouble();
      subtotal += quantity * pricePerUnit;
      final itemDiscountAmount = (item['discount_amount'] as num? ?? 0).toDouble();
      actualItemDiscounts += itemDiscountAmount;
    }

    final itemDiscounts = actualItemDiscounts > 0 ? actualItemDiscounts : (calculations?['item_discounts'] ?? 0.0);
    final totalDiscountAmount = calculations?['total_discount_amount'] ?? 0.0;
    final afterDiscounts = subtotal - itemDiscounts - totalDiscountAmount;

    // Versandkosten
    final plantCertificate = shippingCosts?['plant_certificate_enabled'] == true
        ? (shippingCosts?['plant_certificate_cost'] ?? 0.0)
        : 0.0;
    final packagingCost = shippingCosts?['packaging_cost'] ?? 0.0;
    final freightCost = shippingCosts?['freight_cost'] ?? 0.0;
    final shippingCombined = shippingCosts?['shipping_combined'] ?? true;
    final carrier = shippingCosts?['carrier'] ?? 'Swiss Post';

    final netAmount = afterDiscounts + plantCertificate + packagingCost + freightCost;

    // NEU: MwSt-Berechnung basierend auf taxOption
    double vatAmount = 0.0;
    double totalWithTax = netAmount;

    if (taxOption == 0) { // TaxOption.standard
      vatAmount = netAmount * (vatRate / 100);
      totalWithTax = netAmount + vatAmount;
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 300,
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
                pw.Text(language == 'EN' ? 'Subtotal' : 'Subtotal'),
                pw.Text(BasePdfGenerator.formatCurrency(subtotal, currency, exchangeRates)),
              ],
            ),

            // Positionsrabatte
            if (itemDiscounts > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'Item discounts' : 'Positionsrabatte'),
                  pw.Text('- ${BasePdfGenerator.formatCurrency(itemDiscounts, currency, exchangeRates)}'),
                ],
              ),
            ],

            // Gesamtrabatt
            if (totalDiscountAmount > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'Total discount' : 'Gesamtrabatt'),
                  pw.Text('- ${BasePdfGenerator.formatCurrency(totalDiscountAmount, currency, exchangeRates)}'),
                ],
              ),
            ],

            // Pflanzenschutzzeugniss
            if (plantCertificate > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'Phytosanitary certificate' : 'Pflanzenschutzzeugniss'),
                  pw.Text(BasePdfGenerator.formatCurrency(plantCertificate, currency, exchangeRates)),
                ],
              ),
            ],

            // Verpackung & Fracht
            if (shippingCombined) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      language == 'EN'
                          ? 'Packing & Freight costs ($carrier)'
                          : 'Verpackungs- & Frachtkosten ($carrier)'
                  ),
                  pw.Text(BasePdfGenerator.formatCurrency(packagingCost + freightCost, currency, exchangeRates)),
                ],
              ),
            ] else ...[
              if (packagingCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(language == 'EN' ? 'Packing costs' : 'Verpackungskosten'),
                    pw.Text(BasePdfGenerator.formatCurrency(packagingCost, currency, exchangeRates)),
                  ],
                ),
              ],
              if (freightCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        language == 'EN'
                            ? 'Freight costs ($carrier)'
                            : 'Frachtkosten ($carrier)'
                    ),
                    pw.Text(BasePdfGenerator.formatCurrency(freightCost, currency, exchangeRates)),
                  ],
                ),
              ],
            ],

            // NEU: MwSt-Bereich je nach Option
            if (taxOption == 0) ...[  // TaxOption.standard
              pw.Divider(color: PdfColors.blueGrey300),

              // Nettobetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'Net amount' : 'Nettobetrag'),
                  pw.Text(BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates)),
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
                          : 'MwSt (${vatRate.toStringAsFixed(1)}%)'
                  ),
                  pw.Text(BasePdfGenerator.formatCurrency(vatAmount, currency, exchangeRates)),
                ],
              ),

              pw.Divider(color: PdfColors.blueGrey300),

              // Gesamtbetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                  pw.Text(
                    BasePdfGenerator.formatCurrency(totalWithTax, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),

            ] else if (taxOption == 1) ...[  // TaxOption.noTax
              pw.Divider(color: PdfColors.blueGrey300),

              // Nettobetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN' ? 'Net amount' : 'Nettobetrag',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                  pw.Text(
                    BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Text(
                language == 'EN'
                    ? 'No VAT will be charged.'
                    : 'Es wird keine Mehrwertsteuer berechnet.',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),

            ] else ...[  // TaxOption.totalOnly
              pw.Divider(color: PdfColors.blueGrey300),

              // Gesamtbetrag inkl. MwSt
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN'
                        ? 'Total incl. VAT'
                        : 'Gesamtbetrag inkl. MwSt',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                  pw.Text(
                    BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Formatiere Betrag ohne Währungszeichen
  static String _formatAmountOnly(double amount, String currency, Map<String, double> exchangeRates) {
    double convertedAmount = amount;
    if (currency != 'CHF') {
      convertedAmount = amount * exchangeRates[currency]!;
    }
    return convertedAmount.toStringAsFixed(2);
  }
  static Future<pw.Widget> _addInlineAdditionalTexts(String language) async {
    try {
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();
      final List<pw.Widget> textWidgets = [];

      // Sammle alle ausgewählten Texte
      if (additionalTexts['legend']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['legend'],
                  'legend',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (additionalTexts['fsc']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['fsc'],
                  'fsc',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (additionalTexts['natural_product']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['natural_product'],
                  'natural_product',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (additionalTexts['bank_info']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['bank_info'],
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
      if (additionalTexts['free_text']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['free_text'],
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



  // Füge Zusatztexte-Seite hinzu
  static Future<void> _addAdditionalTextsPage(pw.Document pdf, pw.MemoryImage logo) async {
    try {
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();

      final List<String> textsToShow = [];

      // Legende
      if (additionalTexts['legend']?['selected'] == true) {
        textsToShow.add(AdditionalTextsManager.getTextContent(additionalTexts['legend'], 'legend'));
      }

      // FSC
      if (additionalTexts['fsc']?['selected'] == true) {
        textsToShow.add(AdditionalTextsManager.getTextContent(additionalTexts['fsc'], 'fsc'));
      }

      // Naturprodukt
      if (additionalTexts['natural_product']?['selected'] == true) {
        textsToShow.add(AdditionalTextsManager.getTextContent(additionalTexts['natural_product'], 'natural_product'));
      }

      if (textsToShow.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(10),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Zusätzliche Informationen',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  ...textsToShow.map((text) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
                  )),

                  pw.Expanded(child: pw.SizedBox()),
                  BasePdfGenerator.buildFooter(),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Hinzufügen der Zusatztexte-Seite: $e');
    }
  }
}