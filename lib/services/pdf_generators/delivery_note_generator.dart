// File: services/pdf_generators/delivery_note_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';

class DeliveryNoteGenerator extends BasePdfGenerator {

  // Erstelle eine neue Lieferschein-Nummer
  static Future<String> getNextDeliveryNoteNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('delivery_note_counters');

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

        return 'LS-$year-$currentNumber';
      });
    } catch (e) {
      print('Fehler beim Erstellen der Lieferschein-Nummer: $e');
      return 'LS-${DateTime.now().year}-1000';
    }
  }

  static Future<Uint8List> generateDeliveryNotePdf({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, dynamic>? fairData,
    required String costCenterCode,
    required String currency,
    required Map<String, double> exchangeRates,
    String? deliveryNoteNumber,
    String? invoiceNumber, // NEU
    String? quoteNumber, // NEU
    required String language,
    DateTime? deliveryDate,  // NEU
    DateTime? paymentDate,   // NEU
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    // Generiere Lieferschein-Nummer falls nicht übergeben
    final deliveryNum = deliveryNoteNumber ?? await getNextDeliveryNoteNumber();

    // Gruppiere Items nach Holzart
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final groupedItems = await _groupItemsByWoodType(productItems, language);
    final additionalTextsWidget = await _addInlineAdditionalTexts(language);

    // Übersetzungsfunktion
    // Übersetzungsfunktion
    String getTranslation(String key) {
      // Sichere den currency Wert
      final safeCurrency = currency ?? 'CHF';
      final exchangeRate = exchangeRates[safeCurrency] ?? 1.0;

      final translations = {
        'DE': {
          'delivery_note': 'LIEFERSCHEIN',
          'currency_note': 'Alle Preise in $safeCurrency (Umrechnungskurs: 1 CHF = ${exchangeRate.toStringAsFixed(4)} $safeCurrency)',
          'delivery_date': 'Lieferdatum',
          'payment_date': 'Zahlungsdatum',
        },
        'EN': {
          'delivery_note': 'DELIVERY NOTE',
          'currency_note': 'All prices in $safeCurrency (Exchange rate: 1 CHF = ${exchangeRate.toStringAsFixed(4)} $safeCurrency)',
          'delivery_date': 'Delivery date',
          'payment_date': 'Payment date',
        }
      };

      // Sichere Rückgabe ohne ! Operator
      final langTranslations = translations[language];
      if (langTranslations != null && langTranslations[key] != null) {
        return langTranslations[key]!;
      }

      // Fallback auf DE
      final deTranslations = translations['DE'];
      if (deTranslations != null && deTranslations[key] != null) {
        return deTranslations[key]!;
      }

      // Letzter Fallback
      return key;
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
                documentTitle: getTranslation('delivery_note'),
                documentNumber: deliveryNum,
                date: DateTime.now(),
                logo: logo,
                costCenter: costCenterCode,
                language: language,
                additionalReference: invoiceNumber != null ? 'invoice_nr:$invoiceNumber' : null,
                secondaryReference: quoteNumber != null ? 'quote_nr:$quoteNumber' : null,

              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
             BasePdfGenerator.buildCustomerAddress(customerData,"delivery_note", language: language),

              pw.SizedBox(height: 15),

              // NEU: Liefer- und Zahlungsdaten
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    if (deliveryDate != null) ...[
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            getTranslation('delivery_date'),
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
                    ],
                    if (paymentDate != null) ...[
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            getTranslation('payment_date'),
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
                  ],
                ),
              ),


              pw.SizedBox(height: 15),

              // Produkttabelle
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildProductTable(groupedItems, currency, exchangeRates, language),
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

  // Kopiere die gleichen Methoden aus QuoteGenerator, aber OHNE Preisspalten
  static Future<Map<String, List<Map<String, dynamic>>>> _groupItemsByWoodType(
      List<Map<String, dynamic>> items,
      String language
      ) async {
    // Gleicher Code wie in QuoteGenerator
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    for (final item in items) {
      final woodCode = item['wood_code'] as String;

      if (!woodTypeCache.containsKey(woodCode)) {
        woodTypeCache[woodCode] = await BasePdfGenerator.getWoodTypeInfo(woodCode) ?? {};
      }

      final woodInfo = woodTypeCache[woodCode]!;
      final woodName = language == 'EN'
          ? (woodInfo['name_english'] ?? woodInfo['name'] ?? item['wood_name'] ?? 'Unknown wood type')
          : (woodInfo['name'] ?? item['wood_name'] ?? 'Unbekannte Holzart');

      final woodNameLatin = woodInfo['name_latin'] ?? '';
      final groupKey = '$woodName ($woodNameLatin)';

      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }

      final enhancedItem = Map<String, dynamic>.from(item);
      enhancedItem['wood_display_name'] = groupKey;
      enhancedItem['wood_name_latin'] = woodNameLatin;

      grouped[groupKey]!.add(enhancedItem);
    }

    return grouped;
  }

  // Tabelle OHNE Preisspalten
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String currency,
      Map<String, double> exchangeRates,
      String language) {

    final List<pw.TableRow> rows = [];

    // Header-Zeile OHNE Preisspalten
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
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
          // BasePdfGenerator.buildHeaderCell(language == 'EN' ? 'Dimensions' : 'Masse', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Anz.', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Unit' : 'Einh', 8),
        ],
      ),
    );

    // Für jede Holzart-Gruppe
    groupedItems.forEach((woodGroup, items) {
      // Holzart-Header
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
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
            ...List.generate(8, (index) => pw.SizedBox(height: 16)),
          ],
        ),
      );

      for (final item in items) {
        final quantity = (item['quantity'] as num? ?? 0).toDouble();

        // Maße zusammenstellen
        String dimensions = '';
        final customLength = (item['custom_length'] as num?) ?? 0;
        final customWidth = (item['custom_width'] as num?) ?? 0;
        final customThickness = (item['custom_thickness'] as num?) ?? 0;

// Nur anzeigen wenn mindestens ein Maß größer als 0 ist
        if (customLength > 0 || customWidth > 0 || customThickness > 0) {
          dimensions = '${customLength}×${customWidth}×${customThickness}';
        }

        String unit = item['unit'] ?? '';

if (unit.toLowerCase() == 'stück') {
  unit = language == 'EN' ? 'pcs' : 'Stk';
}

        rows.add(
          pw.TableRow(
            children: [
              BasePdfGenerator.buildContentCell(
                pw.Text(  language == 'EN' ?item['part_name_en']:item['part_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(  language == 'EN' ?item['instrument_name_en']:item['instrument_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              // BasePdfGenerator.buildContentCell(
              //   pw.Text(  language == 'EN' ?item['part_name_en']:item['part_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              // ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['fst_status'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text('CH', style: const pw.TextStyle(fontSize: 6)),
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
              // BasePdfGenerator.buildContentCell(
              //   pw.Text(dimensions, style: const pw.TextStyle(fontSize: 6)),
              // ),
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
            ],
          ),
        );
      }
    });

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),      // Produkt
        1: const pw.FlexColumnWidth(3.0),    // Instr.
       // 2: const pw.FlexColumnWidth(2.0),    // Typ
        2: const pw.FlexColumnWidth(1.5),    // Qual.
        3: const pw.FlexColumnWidth(1.0),    // FSC
        4: const pw.FlexColumnWidth(1.0),    // Urs
        5: const pw.FlexColumnWidth(1.0),    // °C
       // 7: const pw.FlexColumnWidth(2.5),    // Masse
        6: const pw.FlexColumnWidth(1.5),    // Anz.
        7: const pw.FlexColumnWidth(1.0),    // Einh
      },
      children: rows,
    );
  }

  // Kopiere _addInlineAdditionalTexts aus QuoteGenerator
  static Future<pw.Widget> _addInlineAdditionalTexts(String language) async {
    // Gleicher Code wie in QuoteGenerator
    try {
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();
      final List<pw.Widget> textWidgets = [];

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
}