// File: services/pdf_generators/delivery_note_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_delivery_note_generator.dart';
import '../additional_text_manager.dart';

class DeliveryNoteGenerator extends BaseDeliveryNotePdfGenerator {

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

        int currentNumber = counters[year.toString()] ?? 999;
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

  // Gruppiere Items nach Holzart
  static Future<Map<String, List<Map<String, dynamic>>>> _groupItemsByWoodType(
      List<Map<String, dynamic>> items,
      String language,
      ) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    for (final item in items) {
      final woodCode = item['wood_code'] as String?;
      if (woodCode == null) continue;

      if (!woodTypeCache.containsKey(woodCode)) {
        woodTypeCache[woodCode] = await BaseDeliveryNotePdfGenerator.getWoodTypeInfo(woodCode) ?? {};
      }

      final woodInfo = woodTypeCache[woodCode]!;
      final woodName = language == 'EN'
          ? (woodInfo['name_english'] ?? woodInfo['name'] ?? item['wood_name'] ?? 'Unknown wood type')
          : (woodInfo['name'] ?? item['wood_name'] ?? 'Unbekannte Holzart');

      final woodNameLatin = woodInfo['name_latin'] ?? '';
      final groupKey = '$woodName\n($woodNameLatin)';

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

  // Produkttabelle (ohne Preise)
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String language,
      ) {
    final List<pw.TableRow> rows = [];

    // Header-Zeile
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Product' : 'Produkt', 8),
          BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Instrument' : 'Instrument', 8),
          BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Quality' : 'Qualität', 8),
          BaseDeliveryNotePdfGenerator.buildHeaderCell('FSC®', 8),
          BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Orig' : 'Urs', 8),
          BaseDeliveryNotePdfGenerator.buildHeaderCell('°C', 8),
          BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Qty' : 'Anz.', 8, align: pw.TextAlign.right),
          BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Unit' : 'Einh', 8),
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
            ...List.generate(7, (index) => pw.SizedBox(height: 16)),
          ],
        ),
      );

      for (final item in items) {
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        String unit = item['unit'] ?? '';

        if (unit.toLowerCase() == 'stück') {
          unit = language == 'EN' ? 'pcs' : 'Stk';
        }

        rows.add(
          pw.TableRow(
            children: [
              BaseDeliveryNotePdfGenerator.buildContentCell(
                pw.Text(
                  language == 'EN' ? item['part_name_en'] ?? item['part_name'] ?? '' : item['part_name'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              BaseDeliveryNotePdfGenerator.buildContentCell(
                pw.Text(
                  language == 'EN' ? item['instrument_name_en'] ?? item['instrument_name'] ?? '' : item['instrument_name'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              BaseDeliveryNotePdfGenerator.buildContentCell(
                pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 8)),
              ),
              BaseDeliveryNotePdfGenerator.buildContentCell(
                pw.Text(item['fsc_status'] ?? '-', style: const pw.TextStyle(fontSize: 8)),
              ),
              BaseDeliveryNotePdfGenerator.buildContentCell(
                pw.Text('CH', style: const pw.TextStyle(fontSize: 8)),
              ),
              BaseDeliveryNotePdfGenerator.buildContentCell(
                pw.Text(
                  item['has_thermal_treatment'] == true && item['thermal_treatment_temperature'] != null
                      ? item['thermal_treatment_temperature'].toString()
                      : '',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              BaseDeliveryNotePdfGenerator.buildContentCell(
                pw.Text(
                  unit != "Stk"
                      ? quantity.toStringAsFixed(3)
                      : quantity.toStringAsFixed(quantity == quantity.round() ? 0 : 3),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              BaseDeliveryNotePdfGenerator.buildContentCell(
                pw.Text(unit, style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          ),
        );
      }
    });

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),    // Produkt
        1: const pw.FlexColumnWidth(3),    // Instrument
        2: const pw.FlexColumnWidth(1.5),  // Qualität
        3: const pw.FlexColumnWidth(1.0),  // FSC
        4: const pw.FlexColumnWidth(1.0),  // Ursprung
        5: const pw.FlexColumnWidth(1.0),  // °C
        6: const pw.FlexColumnWidth(1.5),  // Anzahl
        7: const pw.FlexColumnWidth(1.0),  // Einheit
      },
      children: rows,
    );
  }

  // Zusatztexte
  static Future<pw.Widget> _buildAdditionalTexts(String language) async {
    try {
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();
      final List<pw.Widget> textWidgets = [];

      if (additionalTexts['legend']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(additionalTexts['legend'], 'legend', language: language),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
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
              AdditionalTextsManager.getTextContent(additionalTexts['fsc'], 'fsc', language: language),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
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
              AdditionalTextsManager.getTextContent(additionalTexts['natural_product'], 'natural_product', language: language),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
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
              AdditionalTextsManager.getTextContent(additionalTexts['free_text'], 'free_text', language: language),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
            ),
          ),
        );
      }

      if (textWidgets.isEmpty) {
        return pw.SizedBox.shrink();
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: textWidgets,
      );
    } catch (e) {
      print('Fehler beim Laden der Zusatztexte: $e');
      return pw.SizedBox.shrink();
    }
  }

  /// HAUPTMETHODE: PDF generieren
  static Future<Uint8List> generateDeliveryNotePdf({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, dynamic>? fairData,
    required String costCenterCode,
    required String currency,
    required Map<String, double> exchangeRates,
    String? deliveryNoteNumber,
    String? invoiceNumber,
    String? quoteNumber,
    required String language,
    DateTime? deliveryDate,
    DateTime? paymentDate,
  }) async {
    final pdf = pw.Document();
    final logo = await BaseDeliveryNotePdfGenerator.loadLogo();

    final deliveryNum = deliveryNoteNumber ?? await getNextDeliveryNoteNumber();

    final productItems = items.where((item) => item['is_service'] != true).toList();
    final groupedItems = await _groupItemsByWoodType(productItems, language);
    final additionalTextsWidget = await _buildAdditionalTexts(language);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER mit Fenster-Layout
              BaseDeliveryNotePdfGenerator.buildWindowHeader(
                documentTitle: 'delivery_note',
                documentNumber: deliveryNum,
                date: DateTime.now(),
                logo: logo,
                customerData: customerData,
                costCenter: costCenterCode,
                invoiceNumber: invoiceNumber,
                quoteNumber: quoteNumber,
                language: language,
              ),

              pw.SizedBox(height: 15),

              // Datums-Box
              BaseDeliveryNotePdfGenerator.buildDateBox(
                deliveryDate: deliveryDate,
                paymentDate: paymentDate,
                language: language,
              ),

              pw.SizedBox(height: 15),

              // Produkttabelle
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildProductTable(groupedItems, language),
                    pw.SizedBox(height: 10),
                    additionalTextsWidget,
                  ],
                ),
              ),

              // Footer
              BaseDeliveryNotePdfGenerator.buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}