// File: services/pdf_generators/delivery_note_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/services/pdf_generators/base_pdf_generator.dart';
import '../pdf_settings_screen.dart';
import '../product_sorting_manager.dart';
import 'base_delivery_note_generator.dart';
import '../additional_text_manager.dart';

class DeliveryNoteGenerator extends BaseDeliveryNotePdfGenerator {

  // ═══════════════════════════════════════════════════════════════════════════
  // NEU: Helper-Funktion für Spaltenausrichtung
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.TextAlign _getTextAlign(String alignment) {
    switch (alignment) {
      case 'left':
        return pw.TextAlign.left;
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
  }

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

  /// Prüft ob mindestens ein Item thermobehandelt ist
  static bool _hasAnyThermalTreatment(Map<String, List<Map<String, dynamic>>> groupedItems) {
    for (final items in groupedItems.values) {
      for (final item in items) {
        if (item['has_thermal_treatment'] == true && item['thermal_treatment_temperature'] != null) {
          return true;
        }
      }
    }
    return false;
  }

  /// Berechnet optimale Spaltenbreiten basierend auf Inhalt
  /// Berechnet optimale Spaltenbreiten basierend auf Inhalt
  static Map<int, pw.FlexColumnWidth> _calculateOptimalColumnWidths(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String language,
      bool showThermalColumn,
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

    double productWidth = (maxProductLen * charWidth).clamp(3.0, 5.0);  // Größer
    double instrWidth = (maxInstrLen * charWidth).clamp(2.5, 4.0);
    double qualWidth = (maxQualLen * charWidth).clamp(1.5, 2.0);
    double fscWidth = (maxFscLen * charWidth).clamp(1.0, 1.5);

    if (showThermalColumn) {
      return {
        0: pw.FlexColumnWidth(productWidth),  // Produkt (größer)
        1: pw.FlexColumnWidth(instrWidth),    // Instrument
        2: pw.FlexColumnWidth(qualWidth),     // Qualität
        3: pw.FlexColumnWidth(fscWidth),      // FSC
        4: const pw.FlexColumnWidth(1.0),     // Ursprung
        5: const pw.FlexColumnWidth(1.0),     // °C
        6: const pw.FlexColumnWidth(1.0),     // Anzahl (kleiner)
        7: const pw.FlexColumnWidth(1.0),     // Einheit
      };
    } else {
      return {
        0: pw.FlexColumnWidth(productWidth),  // Produkt (größer)
        1: pw.FlexColumnWidth(instrWidth),    // Instrument
        2: pw.FlexColumnWidth(qualWidth),     // Qualität
        3: pw.FlexColumnWidth(fscWidth),      // FSC
        4: const pw.FlexColumnWidth(1.0),     // Ursprung
        5: const pw.FlexColumnWidth(1.0),     // Anzahl (kleiner)
        6: const pw.FlexColumnWidth(1.0),     // Einheit
      };
    }
  }

  // Produkttabelle (ohne Preise) - NEU: mit columnAlignments Parameter
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String language,
      bool showThermalColumn,
      Map<int, pw.FlexColumnWidth> columnWidths,
      Map<String, String> columnAlignments,
      ) {
    final List<pw.TableRow> rows = [];

    // NEU: Ausrichtungen holen
    final productAlign = _getTextAlign(columnAlignments['product'] ?? 'left');
    final instrumentAlign = _getTextAlign(columnAlignments['instrument'] ?? 'left');
    final qualityAlign = _getTextAlign(columnAlignments['quality'] ?? 'left');
    final fscAlign = _getTextAlign(columnAlignments['fsc'] ?? 'left');
    final originAlign = _getTextAlign(columnAlignments['origin'] ?? 'left');
    final thermalAlign = _getTextAlign(columnAlignments['thermal'] ?? 'center');
    final qtyAlign = _getTextAlign(columnAlignments['quantity'] ?? 'right');
    final unitAlign = _getTextAlign(columnAlignments['unit'] ?? 'center');

    // Header-Zeile - NEU: mit align Parameter
    final headerCells = <pw.Widget>[
      BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Product' : 'Produkt', 8, align: productAlign),
      BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Instrument' : 'Instrument', 8, align: instrumentAlign),
      BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Quality' : 'Qualität', 8, align: qualityAlign),
      BaseDeliveryNotePdfGenerator.buildHeaderCell('FSC®', 8, align: fscAlign),
      BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Orig' : 'Urs', 8, align: originAlign),
    ];

    if (showThermalColumn) {
      headerCells.add(BaseDeliveryNotePdfGenerator.buildHeaderCell('°C', 8, align: thermalAlign));
    }

    headerCells.addAll([
      BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Qty' : 'Anz.', 8, align: qtyAlign),
      BaseDeliveryNotePdfGenerator.buildHeaderCell(language == 'EN' ? 'Unit' : 'Einh', 8, align: unitAlign),
    ]);

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: headerCells,
      ),
    );

    // Anzahl Spalten für leere Zellen in Gruppenheader
    final emptyColumnsCount = showThermalColumn ? 7 : 6;

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
            ...List.generate(emptyColumnsCount, (index) => pw.SizedBox(height: 16)),
          ],
        ),
      );

      for (final item in items) {
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        String unit = item['unit'] ?? '';

        if (unit.toLowerCase() == 'stück') {
          unit = language == 'EN' ? 'pcs' : 'Stk';
        }

        final contentCells = <pw.Widget>[
          // Produkt - NEU: mit textAlign
          BaseDeliveryNotePdfGenerator.buildContentCell(
            pw.Text(
              language == 'EN' ? item['part_name_en'] ?? item['part_name'] ?? '' : item['part_name'] ?? '',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: productAlign,
            ),
          ),
          // Instrument - NEU: mit textAlign
          BaseDeliveryNotePdfGenerator.buildContentCell(
            pw.Text(
              language == 'EN' ? item['instrument_name_en'] ?? item['instrument_name'] ?? '' : item['instrument_name'] ?? '',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: instrumentAlign,
            ),
          ),
          // Qualität - NEU: mit textAlign
          BaseDeliveryNotePdfGenerator.buildContentCell(
            pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 8), textAlign: qualityAlign),
          ),
          // FSC - NEU: mit textAlign
          BaseDeliveryNotePdfGenerator.buildContentCell(
            pw.Text(item['fsc_status'] ?? '-', style: const pw.TextStyle(fontSize: 8), textAlign: fscAlign),
          ),
          // Ursprung - NEU: mit textAlign
          BaseDeliveryNotePdfGenerator.buildContentCell(
            pw.Text('CH', style: const pw.TextStyle(fontSize: 8), textAlign: originAlign),
          ),
        ];

        // Thermobehandlung - NEU: mit textAlign
        if (showThermalColumn) {
          contentCells.add(
            BaseDeliveryNotePdfGenerator.buildContentCell(
              pw.Text(
                item['has_thermal_treatment'] == true && item['thermal_treatment_temperature'] != null
                    ? item['thermal_treatment_temperature'].toString()
                    : '',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: thermalAlign,
              ),
            ),
          );
        }

        // Anzahl und Einheit - NEU: mit textAlign
        contentCells.addAll([
          BaseDeliveryNotePdfGenerator.buildContentCell(
            pw.Text(
              unit != "Stk"
                  ? quantity.toStringAsFixed(3)
                  : quantity.toStringAsFixed(quantity == quantity.round() ? 0 : 3),
              style: const pw.TextStyle(fontSize: 8),
              textAlign: qtyAlign,
            ),
          ),
          BaseDeliveryNotePdfGenerator.buildContentCell(
            pw.Text(unit, style: const pw.TextStyle(fontSize: 8), textAlign: unitAlign),
          ),
        ]);

        rows.add(
          pw.TableRow(
            children: contentCells,
          ),
        );
      }
    });

    return BasePdfGenerator.buildSplittableTable(
      rows: rows,
      columnWidths: columnWidths,
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
    );
  }

  // Zusatztexte
  static Future<pw.Widget> _buildAdditionalTexts(String language, Map<String, dynamic>? passedAdditionalTexts) async {
    try {
      final additionalTexts = passedAdditionalTexts ?? await AdditionalTextsManager.loadAdditionalTexts();

      // Migration: altes 'legend' Feld auf neue Felder mappen
      if (additionalTexts.containsKey('legend') && !additionalTexts.containsKey('legend_origin')) {
        final legendSelected = additionalTexts['legend']?['selected'] ?? false;
        final legendType = additionalTexts['legend']?['type'] ?? 'standard';
        final legendCustom = additionalTexts['legend']?['custom_text'] ?? '';
        additionalTexts['legend_origin'] = {
          'type': legendType,
          'custom_text': legendCustom,
          'selected': legendSelected,
        };
        additionalTexts['legend_temperature'] = {
          'type': legendType,
          'custom_text': '',
          'selected': legendSelected,
        };
      }

      final List<pw.Widget> textWidgets = [];

// Legende (Ursprung + Temperatur)
      final hasOrigin = additionalTexts['legend_origin']?['selected'] == true;
      final hasTemperature = additionalTexts['legend_temperature']?['selected'] == true;

      if (hasOrigin || hasTemperature) {
        final parts = <String>[];
        if (hasOrigin) {
          parts.add(AdditionalTextsManager.getTextContent(
              additionalTexts['legend_origin'], 'legend_origin', language: language));
        }
        if (hasTemperature) {
          parts.add(AdditionalTextsManager.getTextContent(
              additionalTexts['legend_temperature'], 'legend_temperature', language: language));
        }
        final prefix = language == 'EN' ? 'Legend: ' : 'Legende: ';
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              '$prefix${parts.join(", ")}',
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
    Map<String, dynamic>? additionalTexts,
  }) async {
    final addressEmailSpacing = await PdfSettingsHelper.getDeliveryNoteAddressEmailSpacing();

    // NEU: Lade Spaltenausrichtungen
    final columnAlignments = await PdfSettingsHelper.getColumnAlignments('delivery_note');

    final pdf = pw.Document();
    final logo = await BaseDeliveryNotePdfGenerator.loadLogo();

    final deliveryNum = deliveryNoteNumber ?? await getNextDeliveryNoteNumber();

    final productItems = items.where((item) => item['is_service'] != true).toList();
    final consolidatedItems = _consolidateItems(productItems);
    final groupedItems = await _groupItemsByWoodType(consolidatedItems, language);

    // NEU: Prüfe ob °C-Spalte angezeigt werden soll
    final showThermalColumn = _hasAnyThermalTreatment(groupedItems);

    // NEU: Berechne Spaltenbreiten
    final columnWidths = _calculateOptimalColumnWidths(
      groupedItems,
      language,
      showThermalColumn,
    );

    final additionalTextsWidget = await _buildAdditionalTexts(language, additionalTexts);

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          if (context.pageNumber == 1) return pw.SizedBox.shrink();
          return pw.Column(
            children: [
              BasePdfGenerator.buildCompactHeader(
                documentTitle: 'delivery_note',
                documentNumber: deliveryNum,
                logo: logo,
                pageNumber: context.pageNumber,
                totalPages: context.pagesCount,
                language: language,
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) => BaseDeliveryNotePdfGenerator.buildFooter(
          pageNumber: context.pageNumber,
          totalPages: context.pagesCount,
          language: language,
        ),
        build: (pw.Context context) {
          return [
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

            // Produkttabelle mit dynamischer °C-Spalte und Spaltenausrichtungen
            _buildProductTable(groupedItems, language, showThermalColumn, columnWidths, columnAlignments),

            pw.SizedBox(height: 10),
            additionalTextsWidget,
          ];
        },
      ),
    );

    return pdf.save();

  }
}