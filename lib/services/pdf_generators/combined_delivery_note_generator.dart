import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';
import '../../components/order_model.dart';

class CombinedDeliveryNoteGenerator {
  static Future<Uint8List> generatePdf({
    required String shipmentNumber,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, String> orderReferences,
    required List<OrderX> orders,
    required Map<String, dynamic> settings,
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    // Bestimme gemeinsame Sprache (verwende erste Order)
    final language = orders.first.customer['language'] ?? 'DE';

    // Konvertiere alle Items zu sicheren Map<String, dynamic>
    final List<Map<String, dynamic>> safeItems = [];
    for (final item in items) {
      final Map<String, dynamic> safeItem = {};
      item.forEach((key, value) {
        safeItem[key.toString()] = value;
      });
      safeItems.add(safeItem);
    }

    // Gruppiere Items nach Holzart
    final productItems = safeItems.where((item) => item['is_service'] != true).toList();
    final groupedItems = await _groupItemsByWoodTypeAndOrder(productItems, language);

    // Lade Zusatztexte
    final additionalTextsWidget = await _addInlineAdditionalTexts(language);

    // Sammle alle Rechnungsnummern
    final invoiceNumbers = orders.map((o) => o.orderNumber).join(', ');

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Header mit mehreren Rechnungsnummern
          _buildCombinedHeader(
            documentTitle: language == 'EN' ? 'COMBINED DELIVERY NOTE' : 'SAMMEL-LIEFERSCHEIN',
            documentNumber: shipmentNumber,
            date: DateTime.now(),
            logo: logo,
            language: language,
            invoiceNumbers: invoiceNumbers,
          ),
          pw.SizedBox(height: 20),

          // Lieferadresse
          BasePdfGenerator.buildCustomerAddress(customerData, 'delivery_note', language: language),

          pw.SizedBox(height: 15),

          // Info-Box mit enthaltenen Aufträgen
          _buildOrderReferencesBox(orders, language),

          pw.SizedBox(height: 15),

          // Produkttabelle mit Rechnungsnummer-Spalte
          _buildCombinedProductTable(groupedItems, language),

          pw.SizedBox(height: 10),

          // Zusatztexte
          additionalTextsWidget,

          // Footer
          BasePdfGenerator.buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  // Angepasster Header für Sammellieferungen
  static pw.Widget _buildCombinedHeader({
    required String documentTitle,
    required String documentNumber,
    required DateTime date,
    required pw.MemoryImage? logo,
    required String language,
    required String invoiceNumbers,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Logo
        if (logo != null)
          pw.Container(
            width: 150,
            height: 80,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),

        // Dokumentinfo
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                documentTitle,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                language == 'EN' ? 'Number: $documentNumber' : 'Nummer: $documentNumber',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                language == 'EN' ? 'Date: ${DateFormat('dd.MM.yyyy').format(date)}' : 'Datum: ${DateFormat('dd.MM.yyyy').format(date)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Invoice Numbers:' : 'Rechnungsnummern:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                    pw.Text(
                      invoiceNumbers,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.amber900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Info-Box mit Auftragsdetails
  static pw.Widget _buildOrderReferencesBox(List<OrderX> orders, String language) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            language == 'EN' ? 'This delivery contains products from the following invoices:' : 'Diese Lieferung enthält Produkte aus folgenden Rechnungen:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 6),
          ...orders.map((order) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '• ',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Expanded(
                  child: pw.Text(
                    '${language == 'EN' ? 'Invoice' : 'Rechnung'} ${order.orderNumber}: ${order.customer['company'] ?? order.customer['fullName']} - CHF ${(order.calculations['total'] as num).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  // Gruppiere Items nach Holzart und Order
  static Future<Map<String, List<Map<String, dynamic>>>> _groupItemsByWoodTypeAndOrder(
      List<Map<String, dynamic>> items,
      String language
      ) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    for (final item in items) {
      final woodCode = item['wood_code'] as String? ?? '';

      if (!woodTypeCache.containsKey(woodCode) && woodCode.isNotEmpty) {
        final woodInfoRaw = await BasePdfGenerator.getWoodTypeInfo(woodCode);
        if (woodInfoRaw != null) {
          // Konvertiere woodInfo zu Map<String, dynamic>
          final Map<String, dynamic> woodInfo = {};
          if (woodInfoRaw is Map) {
            woodInfoRaw.forEach((key, value) {
              woodInfo[key.toString()] = value;
            });
          }
          woodTypeCache[woodCode] = woodInfo;
        } else {
          woodTypeCache[woodCode] = {};
        }
      }

      final woodInfo = woodTypeCache[woodCode] ?? {};
      final woodName = language == 'EN'
          ? (woodInfo['name_english'] ?? woodInfo['name'] ?? item['wood_name'] ?? 'Unknown wood type')
          : (woodInfo['name'] ?? item['wood_name'] ?? 'Unbekannte Holzart');

      final woodNameLatin = woodInfo['name_latin'] ?? '';
      final groupKey = '$woodName ($woodNameLatin)';

      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }

      grouped[groupKey]!.add(item);
    }

    return grouped;
  }
  // Produkttabelle mit Rechnungsnummer-Spalte
  static pw.Widget _buildCombinedProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String language
      ) {
    final List<pw.TableRow> rows = [];

    // Header mit zusätzlicher Spalte für Rechnungsnummer
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Invoice' : 'Rechnung', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Product' : 'Produkt', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Instrument' : 'Instrument', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Quality' : 'Qualität', 8),
          BasePdfGenerator.buildHeaderCell('FSC®', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Orig' : 'Urs', 8),
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
            ...List.generate(7, (index) => pw.SizedBox(height: 16)),
          ],
        ),
      );

      // Sortiere Items nach Rechnungsnummer
      items.sort((a, b) => (a['_invoice_number'] ?? '').compareTo(b['_invoice_number'] ?? ''));

      for (final item in items) {
        final quantity = (item['quantity'] as num? ?? 0).toDouble();

        String unit = item['unit'] ?? '';
if (unit.toLowerCase() == 'stück') {
  unit = language == 'EN' ? 'pcs' : 'Stk';
}

        rows.add(
          pw.TableRow(
            children: [
              // NEU: Rechnungsnummer-Spalte
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  item['_invoice_number'] ?? '',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                    language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
                    style: const pw.TextStyle(fontSize: 6)
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                    language == 'EN' ? item['instrument_name_en'] : item['instrument_name'] ?? '',
                    style: const pw.TextStyle(fontSize: 6)
                ),
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

    // Zusammenfassung am Ende
    final totalItems = groupedItems.values.expand((items) => items).length;
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey100,
          border: pw.Border(top: pw.BorderSide(width: 2, color: PdfColors.blueGrey700)),
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN' ? 'Total' : 'Gesamt',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '$totalItems ${language == 'EN' ? 'Items' : 'Positionen'}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),      // Rechnung
        1: const pw.FlexColumnWidth(3),      // Produkt
        2: const pw.FlexColumnWidth(3),      // Instr.
        3: const pw.FlexColumnWidth(1.5),    // Qual.
        4: const pw.FlexColumnWidth(1),      // FSC
        5: const pw.FlexColumnWidth(1),      // Urs
        6: const pw.FlexColumnWidth(1.5),    // Anz.
        7: const pw.FlexColumnWidth(1),      // Einh
      },
      children: rows,
    );
  }

  // Kopiere _addInlineAdditionalTexts aus dem normalen DeliveryNoteGenerator
  static Future<pw.Widget> _addInlineAdditionalTexts(String language) async {
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