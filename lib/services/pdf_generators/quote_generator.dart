// File: services/pdf_generators/quote_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../document_selection_manager.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';

class QuoteGenerator extends BasePdfGenerator {

  // Erstelle eine neue Offerten-Nummer
  static Future<String> getNextQuoteNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('quote_counters');

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
      print('Fehler beim Erstellen der Offerten-Nummer: $e');
      return '${DateTime.now().year}-1000';
    }
  }

// In quote_generator.dart, ersetze die generateQuotePdf Methode:

  static Future<Uint8List> generateQuotePdf({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, dynamic>? fairData,
    required String costCenterCode,
    required String currency,
    required Map<String, double> exchangeRates,
    String? quoteNumber,
    required String language,
    Map<String, dynamic>? shippingCosts,
    Map<String, dynamic>? calculations,
    required int taxOption,  // 0=standard, 1=noTax, 2=totalOnly
    required double vatRate,
  DateTime? validityDate,
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    // Generiere Offerten-Nummer falls nicht übergeben
    final quoteNum = quoteNumber ?? await getNextQuoteNumber();
    final validUntil = validityDate ?? DateTime.now().add(Duration(days: 14));

    final quoteSettings = await DocumentSelectionManager.loadQuoteSettings();
    final showDimensions = quoteSettings['show_dimensions'] ?? false;
    // Gruppiere Items nach Holzart
    final groupedItems = await _groupItemsByWoodType(items, language);
    final additionalTextsWidget = await _addInlineAdditionalTexts(language);

    // Übersetzungsfunktion
    String getTranslation(String key) {
      final translations = {
        'DE': {
          'quote': 'OFFERTE',
          'currency_note': 'Alle Preise in $currency (Umrechnungskurs: 1 CHF = ${exchangeRates[currency]!.toStringAsFixed(4)} $currency)',
          'validity_note': 'Diese Offerte ist bis ${DateFormat('dd. MMMM yyyy', 'de_DE').format(validUntil)} gültig. Sollte bis dahin keine Zahlung bei uns eingehen, werden wir die Reservation stornieren.',
          'net_amount': 'Nettobetrag',
          'vat': 'MwSt',
          'total': 'Gesamtbetrag',
          'no_vat_note': 'Es wird keine Mehrwertsteuer berechnet.',
          'total_incl_vat': 'Gesamtbetrag inkl. MwSt',
        },
        'EN': {
          'quote': 'QUOTE',
          'currency_note': 'All prices in $currency (Exchange rate: 1 CHF = ${exchangeRates[currency]!.toStringAsFixed(4)} $currency)',
          'validity_note': 'This offer is valid until ${DateFormat('MMMM dd, yyyy', 'en_US').format(validUntil)}. If payment is not received by then, we will cancel the reservation.',
          'net_amount': 'Net amount',
          'vat': 'VAT',
          'total': 'Total',
          'no_vat_note': 'No VAT will be charged.',
          'total_incl_vat': 'Total incl. VAT',
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
                documentTitle: getTranslation('quote'),
                documentNumber: quoteNum,
                date: DateTime.now(),
                logo: logo,
                costCenter: costCenterCode,
                language: language,
              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
             BasePdfGenerator.buildCustomerAddress(customerData, language: language),

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
                    _buildProductTable(groupedItems, currency, exchangeRates, language, showDimensions),
                    pw.SizedBox(height: 10),
                    // Summen-Bereich
                    _buildTotalsSection(items, currency, exchangeRates, language, shippingCosts, calculations,taxOption, vatRate),
                    pw.SizedBox(height: 10),
                    // Gültigkeitshinweis
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.orange50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: PdfColors.orange200, width: 0.5),
                      ),
                      child: pw.Text(
                        getTranslation('validity_note'),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.orange900),
                      ),
                    ),

                    pw.SizedBox(height: 10),
                    additionalTextsWidget,
                  ],
                ),
              ),

              // Footer - jetzt wirklich am Seitenende
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
      String language,
      bool showDimensions) { // NEU: showDimensions Parameter

    final List<pw.TableRow> rows = [];

    // Header-Zeile anpassen basierend auf showDimensions
    final headerCells = <pw.Widget>[
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
          language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right),
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
      // Holzart-Header - Anzahl der Zellen anpassen
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

      // NEU: Anzahl der leeren Zellen basierend auf showDimensions
      final emptyCellCount = showDimensions ? 13 : 12;
      woodGroupCells.addAll(List.generate(emptyCellCount, (index) => pw.SizedBox(height: 16)));

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: woodGroupCells,
        ),
      );

      for (final item in items) {
        final isGratisartikel = item['is_gratisartikel'] == true;

        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        final pricePerUnit = isGratisartikel
            ? 0.0  // Gratisartikel haben Preis 0
            : (item['price_per_unit'] as num? ?? 0).toDouble();

        final totalBeforeDiscount = quantity * pricePerUnit;

        // Rabattberechnung
        final discount = item['discount'] as Map<String, dynamic>?;
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
        totalAmount += itemTotal;

        // Maße zusammenstellen
        String dimensions = '';
        if (item['custom_length'] != null || item['custom_width'] != null || item['custom_thickness'] != null) {
          final length = item['custom_length']?.toString() ?? '';
          final width = item['custom_width']?.toString() ?? '';
          final thickness = item['custom_thickness']?.toString() ?? '';

          final lengthNum = double.tryParse(length) ?? 0;
          final widthNum = double.tryParse(width) ?? 0;
          final thicknessNum = double.tryParse(thickness) ?? 0;

          if (lengthNum > 0 || widthNum > 0 || thicknessNum > 0) {
            dimensions = '${length}×${width}×${thickness}';
          }
        }

        // Einheit korrigieren
        String unit = item['unit'] ?? '';
        if (unit.toLowerCase() == 'stück') {
          unit = 'Stk';
        }

        // Zeilen-Zellen erstellen
        final rowCells = <pw.Widget>[
          BasePdfGenerator.buildContentCell(
            pw.Row(
              children: [
                pw.Text(
                    language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
                    style: const pw.TextStyle(fontSize: 6)
                ),
                // NEU: Gratisartikel-Badge
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
              ],
            ),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text(language == 'EN' ? item['instrument_name_en'] : item['instrument_name'] ?? '',
                style: const pw.TextStyle(fontSize: 6)),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text(language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
                style: const pw.TextStyle(fontSize: 6)),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text(item['fsc_status'] ?? '', style: const pw.TextStyle(fontSize: 6)),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text('CH', style: const pw.TextStyle(fontSize: 6)),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text('', style: const pw.TextStyle(fontSize: 6)),
          ),
        ];

        // NEU: Nur wenn showDimensions true ist
        if (showDimensions) {
          rowCells.add(
            BasePdfGenerator.buildContentCell(
              pw.Text(dimensions, style: const pw.TextStyle(fontSize: 6)),
            ),
          );
        }

        rowCells.addAll([
          BasePdfGenerator.buildContentCell(
            pw.Text(
              unit != "Stk"
                  ? quantity.toStringAsFixed(3)
                  : quantity.toStringAsFixed(quantity == quantity.round() ? 0 : 3),
              style: const pw.TextStyle(fontSize: 6),
              textAlign: pw.TextAlign.right,
            ),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text(unit, style: const pw.TextStyle(fontSize: 6)),
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
        ]);

        rows.add(pw.TableRow(children: rowCells));
      }
    });

    // NEU: Spaltenbreiten anpassen basierend auf showDimensions
    final columnWidths = showDimensions ? {
      0: const pw.FlexColumnWidth(3),      // Produkt
      1: const pw.FlexColumnWidth(2.0),    // Instr.
      2: const pw.FlexColumnWidth(2.0),    // Typ
      3: const pw.FlexColumnWidth(1.5),    // Qual.
      4: const pw.FlexColumnWidth(1.5),    // FSC
      5: const pw.FlexColumnWidth(1.5),    // Urs
      6: const pw.FlexColumnWidth(1.0),    // °C
      7: const pw.FlexColumnWidth(2.5),    // Masse
      8: const pw.FlexColumnWidth(1.2),    // Anz.
      9: const pw.FlexColumnWidth(1.2),    // Einh
      10: const pw.FlexColumnWidth(2.0),   // Preis/E
      11: const pw.FlexColumnWidth(2.0),   // Gesamt
      12: const pw.FlexColumnWidth(1.5),   // Rabatt
      13: const pw.FlexColumnWidth(2.0),   // Netto Gesamt
    } : {
      0: const pw.FlexColumnWidth(3.5),    // Produkt (mehr Platz ohne Masse)
      1: const pw.FlexColumnWidth(2.2),    // Instr.
      2: const pw.FlexColumnWidth(2.2),    // Typ
      3: const pw.FlexColumnWidth(1.8),    // Qual.
      4: const pw.FlexColumnWidth(1.8),    // FSC
      5: const pw.FlexColumnWidth(1.5),    // Urs
      6: const pw.FlexColumnWidth(1.0),    // °C
      7: const pw.FlexColumnWidth(1.5),    // Anz.
      8: const pw.FlexColumnWidth(1.5),    // Einh
      9: const pw.FlexColumnWidth(2.2),    // Preis/E
      10: const pw.FlexColumnWidth(2.2),   // Gesamt
      11: const pw.FlexColumnWidth(1.8),   // Rabatt
      12: const pw.FlexColumnWidth(2.3),   // Netto Gesamt
    };

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: columnWidths,
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
      int taxOption,
      double vatRate,
      ) {
    double subtotal = 0.0;
    double actualItemDiscounts = 0.0;

    for (final item in items) {
      final isGratisartikel = item['is_gratisartikel'] == true;
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = isGratisartikel
          ? 0.0
          : (item['price_per_unit'] as num? ?? 0).toDouble();

      final itemSubtotal = quantity * pricePerUnit;
      subtotal += itemSubtotal;
      // Rabatte nur auf nicht-Gratisartikel berechnen
      if (!isGratisartikel) {
        final itemDiscountAmount = (item['discount_amount'] as num? ?? 0).toDouble();
        actualItemDiscounts += itemDiscountAmount;
      }
    }

    final itemDiscounts = actualItemDiscounts > 0 ? actualItemDiscounts : (calculations?['item_discounts'] ?? 0.0);
    final totalDiscountAmount = calculations?['total_discount_amount'] ?? 0.0;
    final afterDiscounts = (subtotal - itemDiscounts) - totalDiscountAmount;

    // Versandkosten
    final plantCertificate = shippingCosts?['plant_certificate_enabled'] == true
        ? (shippingCosts?['plant_certificate_cost'] ?? 0.0)
        : 0.0;
    final packagingCost = shippingCosts?['packaging_cost'] ?? 0.0;
    final freightCost = shippingCosts?['freight_cost'] ?? 0.0;
    final shippingCombined = shippingCosts?['shipping_combined'] ?? true;
    final carrier = (shippingCosts?['carrier'] == 'Persönlich abgeholt' && language == 'EN')
        ? 'Collected in person'
        : (shippingCosts?['carrier'] ?? 'Swiss Post');

    // Abschläge und Zuschläge
    final totalDeductions = shippingCosts?['totalDeductions'] ?? 0.0;
    final totalSurcharges = shippingCosts?['totalSurcharges'] ?? 0.0;

    final netAmount = afterDiscounts + plantCertificate + packagingCost + freightCost + totalSurcharges - totalDeductions;

    // MwSt-Berechnung basierend auf taxOption
    double vatAmount = 0.0;
    double totalWithTax = netAmount;

    if (taxOption == 0) { // TaxOption.standard
      vatAmount = netAmount * (vatRate / 100);
      totalWithTax = netAmount + vatAmount;
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
                  pw.Text(language == 'EN' ? 'Total discount' : 'Gesamtrabatt', style: const pw.TextStyle(fontSize: 9)),
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
              if (freightCost > 0) ...[
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
              if ((shippingCosts['deduction_1_text'] ?? '').isNotEmpty && (shippingCosts['deduction_1_amount'] ?? 0.0) > 0) ...[
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
                  pw.Text(language == 'EN' ? 'Net amount' : 'Nettobetrag', style: const pw.TextStyle(fontSize: 9)),
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

              pw.Divider(color: PdfColors.blueGrey300),

              // Gesamtbetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                  pw.Text(
                    BasePdfGenerator.formatCurrency(totalWithTax, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
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
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                  pw.Text(
                    BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Text(
                language == 'EN'
                    ? 'No VAT will be charged.'
                    : 'Es wird keine Mehrwertsteuer berechnet.',
                style: pw.TextStyle(
                  fontSize: 9,
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
                        ? 'Total incl. ${vatRate.toStringAsFixed(1)}% VAT'
                        : 'Gesamtbetrag inkl. ${vatRate.toStringAsFixed(1)}% MwSt',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                  pw.Text(
                    BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
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
  static String _formatAmountOnly(num amount, String currency, Map<String, double> exchangeRates) {
    double convertedAmount = amount.toDouble();
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

      // if (additionalTexts['bank_info']?['selected'] == true) {
      //   textWidgets.add(
      //     pw.Container(
      //       alignment: pw.Alignment.centerLeft,
      //       margin: const pw.EdgeInsets.only(bottom: 3),
      //       child: pw.Text(
      //         AdditionalTextsManager.getTextContent(
      //             additionalTexts['bank_info'],
      //             'bank_info',
      //             language: language
      //         ),
      //         style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
      //         textAlign: pw.TextAlign.left,
      //       ),
      //     ),
      //   );
      // }

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
                    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
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