// File: services/pdf_generators/delivery_note_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pdf_settings_screen.dart';
import '../product_sorting_manager.dart';
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

  /// Fasst Items mit gleicher product_id zusammen (addiert Mengen)
  static List<Map<String, dynamic>> _consolidateItems(List<Map<String, dynamic>> items) {
    final Map<String, Map<String, dynamic>> consolidated = {};

    for (final item in items) {
      final productId = item['product_id']?.toString() ?? '';

      if (productId.isEmpty) {
        // Ohne product_id: als einzelnes Item behalten
        consolidated[DateTime.now().microsecondsSinceEpoch.toString()] = Map<String, dynamic>.from(item);
        continue;
      }

      if (consolidated.containsKey(productId)) {
        // Existiert bereits: Menge addieren
        final existing = consolidated[productId]!;
        final existingQty = (existing['quantity'] as num? ?? 0).toDouble();
        final newQty = (item['quantity'] as num? ?? 0).toDouble();
        existing['quantity'] = existingQty + newQty;
      } else {
        // Neues Item
        consolidated[productId] = Map<String, dynamic>.from(item);
      }
    }

    return consolidated.values.toList();
  }
  /// Berechnet optimale Spaltenbreiten basierend auf Inhalt
  static Map<int, pw.FlexColumnWidth> _calculateOptimalColumnWidths(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String language,
      ) {
    const double charWidth = 0.18;

    int maxProductLen = language == 'EN' ? 7 : 7;
    int maxInstrLen = 10;
    int maxQualLen = language == 'EN' ? 8 : 10;
    int maxFscLen = 4;

    groupedItems.forEach((woodGroup, items) {
      for (final item in items) {
        String productText = language == 'EN'
            ? (item['part_name_en'] ?? item['part_name'] ?? '')
            : (item['part_name'] ?? '');
        if (productText.length > maxProductLen) maxProductLen = productText.length;

        String instrText = language == 'EN'
            ? (item['instrument_name_en'] ?? item['instrument_name'] ?? '')
            : (item['instrument_name'] ?? '');
        if (instrText.length > maxInstrLen) maxInstrLen = instrText.length;

        String qualText = item['quality_name'] ?? '';
        if (qualText.length > maxQualLen) maxQualLen = qualText.length;

        String fscText = item['fsc_status'] ?? '';
        if (fscText.length > maxFscLen) maxFscLen = fscText.length;
      }
    });

    double productWidth = (maxProductLen * charWidth).clamp(2.5, 4.0);
    double instrWidth = (maxInstrLen * charWidth).clamp(2.5, 4.0);
    double qualWidth = (maxQualLen * charWidth).clamp(1.5, 2.0);
    double fscWidth = (maxFscLen * charWidth).clamp(1.0, 1.5);

    return {
      0: pw.FlexColumnWidth(productWidth),  // Produkt
      1: pw.FlexColumnWidth(instrWidth),    // Instrument
      2: pw.FlexColumnWidth(qualWidth),     // Qualität
      3: pw.FlexColumnWidth(fscWidth),      // FSC
      4: const pw.FlexColumnWidth(1.0),     // Ursprung
      5: const pw.FlexColumnWidth(1.0),     // °C
      6: const pw.FlexColumnWidth(1.5),     // Anzahl
      7: const pw.FlexColumnWidth(1.0),     // Einheit
    };
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

    // Optimierte Spaltenbreiten basierend auf Inhalt
    final columnWidths = _calculateOptimalColumnWidths(
      groupedItems,
      language,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: columnWidths,
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
    final addressEmailSpacing = await PdfSettingsHelper.getDeliveryNoteAddressEmailSpacing();

    final pdf = pw.Document();
    final logo = await BaseDeliveryNotePdfGenerator.loadLogo();

    final deliveryNum = deliveryNoteNumber ?? await getNextDeliveryNoteNumber();

    final productItems = items.where((item) => item['is_service'] != true).toList();
    final consolidatedItems = _consolidateItems(productItems);  // NEU
    final groupedItems = await _groupItemsByWoodType(consolidatedItems, language);  // GEÄNDERT

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
                addressEmailSpacing: addressEmailSpacing,
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