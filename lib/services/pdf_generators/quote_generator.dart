// File: services/pdf_generators/quote_generator.dart

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
    required Map<String, bool> roundingSettings,
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
    final showValidityAddition = quoteSettings['show_validity_addition'] ?? true; // NEU

// Fügen Sie diese Trennung hinzu:
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final serviceItems = items.where((item) => item['is_service'] == true).toList();
    final groupedProductItems = await _groupItemsByWoodType(productItems, language);

// Dynamisch prüfen ob Spalten benötigt werden
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

    final additionalTextsWidget = await _addInlineAdditionalTexts(language);


// Lade Currency Settings für Kurs-Anzeige
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


    // Übersetzungsfunktion
    String getTranslation(String key) {
      final translations = {
        'DE': {
          'quote': 'OFFERTE',
          'currency_note': 'Alle Preise in $currency (Umrechnungskurs: 1 CHF = ${exchangeRates[currency]!.toStringAsFixed(4)} $currency)',
          'validity_note': 'Diese Offerte ist bis ${DateFormat('dd. MMMM yyyy', 'de_DE').format(validUntil)} gültig.',
          'validity_note_addition': 'Sollte bis dahin keine Zahlung bei uns eingehen, werden wir die Reservation stornieren.',
          'net_amount': 'Nettobetrag',
          'vat': 'MwSt',
          'total': 'Gesamtbetrag',
          'no_vat_note': 'Es wird keine Mehrwertsteuer berechnet.',
          'total_incl_vat': 'Gesamtbetrag inkl. MwSt',
        },
        'EN': {
          'quote': 'QUOTE',
          'currency_note': 'All prices in $currency (Exchange rate: 1 CHF = ${exchangeRates[currency]!.toStringAsFixed(4)} $currency)',
          'validity_note': 'This offer is valid until ${DateFormat('MMMM dd, yyyy', 'en_US').format(validUntil)}.',
          'validity_note_addition':' If payment is not received by then, we will cancel the reservation.',
          'net_amount': 'Total amount',
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
             BasePdfGenerator.buildCustomerAddress(customerData,'quote', language: language),

              pw.SizedBox(height: 15),

              // Währungshinweis (falls nicht CHF UND showExchangeRateOnDocument aktiviert)
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
                    BasePdfGenerator.buildCurrencyHint(currency, language),

                    // Erst Produkte
                    if (productItems.isNotEmpty)

                    _buildProductTable(groupedProductItems, currency, exchangeRates, language, showDimensions, showThermalColumn, showDiscountColumn),
// Dann Dienstleistungen
                    if (serviceItems.isNotEmpty)
                      _buildServiceTable(serviceItems, currency, exchangeRates, language), pw.SizedBox(height: 10),
                    // Summen-Bereich
                    _buildTotalsSection(items, currency, exchangeRates, language, shippingCosts, calculations,taxOption, vatRate, roundingSettings,),
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
                    // NEU: Zusätzlicher Zahlungshinweis nur wenn aktiviert
                    if (showValidityAddition) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        getTranslation('validity_note_addition'),
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.orange900,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
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
// Neue Methode nach _buildProductTable hinzufügen:
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
              language == 'EN' ? 'Service' : 'Dienstleistung', 10),
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

    // Dienstleistungen hinzufügen
    for (final service in serviceItems) {
      final quantity = (service['quantity'] as num? ?? 0).toDouble();
      // NEU: Prüfe erst ob custom_price_per_unit existiert
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
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.right,
              ),
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
               BasePdfGenerator.formatAmountOnly(total, currency, exchangeRates),
                style:  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
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
          },
          children: rows,
        ),
      ],
    );
  }

  /// Berechnet optimale Spaltenbreiten basierend auf Inhalt
  /// Berechnet optimale Spaltenbreiten basierend auf Inhalt
  static Map<int, pw.FlexColumnWidth> _calculateOptimalColumnWidths(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String language,
      bool showDimensions,
      bool showThermalColumn,
      bool showDiscountColumn,
      ) {
    // Zeichenbreiten-Faktor für 8pt Font
    const double charWidth = 0.18;

    // Startlängen (Header-Texte)
    int maxProductLen = language == 'EN' ? 7 : 7;   // "Product" / "Produkt"
    int maxInstrLen = 10;                            // "Instrument"
    int maxQualLen = language == 'EN' ? 7 : 8;      // "Quality" / "Qualität"
    int maxFscLen = 4;                               // "FSC®"
    int maxDimLen = language == 'EN' ? 10 : 5;      // "Dimensions" / "Masse"

    // Durch alle Items iterieren
    groupedItems.forEach((woodGroup, items) {
      for (final item in items) {
        // Produkt (inkl. Notes + Badges)
        String productText = language == 'EN'
            ? (item['part_name_en'] ?? item['part_name'] ?? '')
            : (item['part_name'] ?? '');
        if (item['notes'] != null && item['notes'].toString().isNotEmpty) {
          productText += ' (${item['notes']})';
        }
        // Badge-Platz einrechnen
        if (item['is_gratisartikel'] == true) productText += '  GRATIS';
        if (item['is_online_shop_item'] == true) productText += '  #0000';
        if (productText.length > maxProductLen) maxProductLen = productText.length;

        // Instrument
        String instrText = language == 'EN'
            ? (item['instrument_name_en'] ?? item['instrument_name'] ?? '')
            : (item['instrument_name'] ?? '');
        if (instrText.length > maxInstrLen) maxInstrLen = instrText.length;

        // Qualität
        String qualText = item['quality_name'] ?? '';
        if (qualText.length > maxQualLen) maxQualLen = qualText.length;

        // FSC
        String fscText = item['fsc_status'] ?? '';
        if (fscText.length > maxFscLen) maxFscLen = fscText.length;

        // Masse
        if (showDimensions) {
          final l = item['custom_length']?.toString() ?? '';
          final w = item['custom_width']?.toString() ?? '';
          final t = item['custom_thickness']?.toString() ?? '';
          String dimText = '$l×$w×$t';
          if (dimText.length > maxDimLen) maxDimLen = dimText.length;
        }
      }
    });

    // Breiten berechnen mit Clamp (Min/Max)
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
  bool showDiscountColumn
      ) { // NEU: showDimensions Parameter

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

     int  emptyCellCount = 10; // Basis: Produkt, Instr, Qual, FSC, Urs, Anz, Einh, Preis/E, Gesamt
      if (showThermalColumn) emptyCellCount++;
      if (showDimensions) emptyCellCount++;
      if (showDiscountColumn) emptyCellCount += 2; // Rabatt + Netto

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
            ? 0.0
            : (item['custom_price_per_unit'] as num?) != null
            ? (item['custom_price_per_unit'] as num).toDouble()
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
                          style: const pw.TextStyle(fontSize: 8)
                      ),
                      // NEU: Hinweise in Klammern hinzufügen
                      if (item['notes'] != null && item['notes'].toString().isNotEmpty)
                        pw.Text(
                          ' (${item['notes']})',
                          style: pw.TextStyle(
                            fontSize: 8,
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
            pw.Text(language == 'EN' ? item['instrument_name_en'] : item['instrument_name'] ?? '',
                style: const pw.TextStyle(fontSize: 8)),
          ),
          // BasePdfGenerator.buildContentCell(
          //   pw.Text(language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
          //       style: const pw.TextStyle(fontSize: 6)),
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

        // NEU: Nur wenn showDimensions true ist
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
             BasePdfGenerator.formatAmountOnly(totalBeforeDiscount, currency, exchangeRates),
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.right,
            ),
          ),

// MIT:
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
                          exchangeRates
                      ),
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
                 // fontWeight: discountAmount > 0 ? pw.FontWeight.bold : null,
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
      Map<String, bool> roundingSettings,
      ) {
    double subtotal = 0.0;
    double actualItemDiscounts = 0.0;

    for (final item in items) {
      final isGratisartikel = item['is_gratisartikel'] == true;
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      // NEU: Prüfe erst ob custom_price_per_unit existiert
      final pricePerUnit = isGratisartikel
          ? 0.0
          : (item['custom_price_per_unit'] as num?) != null
          ? (item['custom_price_per_unit'] as num).toDouble()
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
    // MwSt-Berechnung basierend auf taxOption
    double vatAmount = 0.0;
    double totalWithTax = netAmount;

    if (taxOption == 0) { // TaxOption.standard
      // NEU: Erst Nettobetrag auf 2 Nachkommastellen runden
      final netAmountRounded = double.parse(netAmount.toStringAsFixed(2));

      // NEU: MwSt berechnen und auf 2 Nachkommastellen runden
      vatAmount = double.parse((netAmountRounded * (vatRate / 100)).toStringAsFixed(2));

      // NEU: Total ist Summe der gerundeten Beträge
      totalWithTax = netAmountRounded + vatAmount;
    } else {
      // Bei anderen Steueroptionen auch auf 2 Nachkommastellen runden
      totalWithTax = double.parse(netAmount.toStringAsFixed(2));
    }
// Nach der Zeile: double totalWithTax = netAmount + vatAmount;

// NEU: Rundung anwenden
    double displayTotal = totalWithTax;
    double roundingDifference = 0.0;

// Prüfe ob Rundung für diese Währung aktiviert ist
    if (roundingSettings[currency] == true) {
      // Konvertiere in Anzeigewährung
      if (currency != 'CHF') {
        displayTotal = totalWithTax * exchangeRates[currency]!;
      }

      // Wende Rundung an
      final roundedDisplayTotal = SwissRounding.round(
        displayTotal,
        currency: currency,
        roundingSettings: roundingSettings,
      );

      roundingDifference = roundedDisplayTotal - displayTotal;

      // Setze den gerundeten Wert
      displayTotal = roundedDisplayTotal;

      // Konvertiere zurück in CHF falls nötig
      if (currency != 'CHF') {
        totalWithTax = displayTotal / exchangeRates[currency]!;
      } else {
        totalWithTax = displayTotal;
      }
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
                // KORREKTUR: Normale Anzeige mit Carrier-Name
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
              // NEU: Prüfe ob persönlich abgeholt
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
              // Abschlag 1
              if ((shippingCosts['deduction_1_text'] ?? '').isNotEmpty && (shippingCosts['deduction_1_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_1_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_1_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9,),
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
                      style: const pw.TextStyle(fontSize: 9,),
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
                      style: const pw.TextStyle(fontSize: 9, ),
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
                  pw.Text(language == 'EN' ? 'Subtotal' : 'Nettobetrag', style: const pw.TextStyle(fontSize: 9)),
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
              // Gesamtbetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN' ? 'Total amount' : 'Gesamtbetrag',
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
                    language == 'EN' ? 'Total amount' : 'Nettobetrag',
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
              //   language == 'EN'
              //       ? 'No VAT will be charged.'
              //       : 'Es wird keine Mehrwertsteuer berechnet.',
              //   style: pw.TextStyle(
              //     fontSize: 9,
              //     fontStyle: pw.FontStyle.italic,
              //     color: PdfColors.grey700,
              //   ),
              // ),

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