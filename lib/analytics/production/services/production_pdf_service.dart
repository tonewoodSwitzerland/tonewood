import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/production_filter.dart';

class ProductionPdfService {

  static String _formatCurrency(double value) {
    // Zahl in Tausender-Format mit Punkt und 2 Dezimalstellen
    final wholePart = (value.toInt()).toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}\'',
    );

    // Dezimalstellen formatieren
    final decimalPart = ((value - value.toInt()) * 100).toInt().toString().padLeft(2, '0');

    return 'CHF $wholePart.$decimalPart';
  }

  static Future<Uint8List> generateBatchList(
      List<Map<String, dynamic>> batches, {
        required ProductionFilter filter,
      }) async {
    final pdf = pw.Document();

    // Logo laden
    final ByteData logoData = await rootBundle.load('images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    // Zusammenfassung berechnen
    final stats = _calculateBatchStats(batches);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Header mit Logo
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logo, width: 120),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Produktionsübersicht',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      DateFormat('dd.MM.yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Zusammenfassung
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Zusammenfassung',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Anzahl Chargen', stats['batchCount'].toString()),
                  _buildSummaryItem(
                    'Gesamtwert',
                    _formatCurrency(stats['totalValue']),
                  ),
                ],
              ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Spezialholz',
                        '${stats['specialWoodCount']} Chargen'),
                    _buildSummaryItem('Zeitraum', _getFilterTimeRange(filter)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Chargenliste
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,  // Kleinere Schrift für Header
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 8,  // Noch etwas kleinere Schrift für Zellen
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            headers: [
              'Datum',
              'Produktions-Nr.',
              'Artikel',
              'Holzart',
              'Qualität',
              'Menge',
              'Wert CHF',
              'Spezial',
            ],
            data: batches.map((batch) {
              final specialFlags = <String>[];
              if (batch['moonwood'] == true) specialFlags.add('M');
              if (batch['haselfichte'] == true) specialFlags.add('H');
              if (batch['thermally_treated'] == true) specialFlags.add('T');
              if (batch['FSC_100'] == true) specialFlags.add('F');
              final paddedBatchNumber = batch['batch_number'].toString().padLeft(4, '0');
              final productionNumber = pw.Text(
                '${batch['barcode']}.$paddedBatchNumber',
                style: pw.TextStyle(fontSize: 6),
              );
              return [
                DateFormat('dd.MM.yy').format(batch['stock_entry_date'] as DateTime),
                productionNumber,
                batch['product_name'],
                batch['wood_name'],
                batch['quality_name'],
                '${NumberFormat('#,##0').format(batch['quantity'])} ${batch['unit']}',
                NumberFormat('#,##0.00').format(batch['value']),
                specialFlags.join(','),
              ];
            }).toList(),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
            },

          ),

          // Legende für Spezialholz
          if (stats['hasSpecialWood'])
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Legende Spezialholz:',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'M = Mondholz, H = Haselfichte, T = Thermisch behandelt, F = FSC-100',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: const pw.TextStyle(
              color: PdfColors.grey700,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );

    return pdf.save();
  }


  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            color: PdfColors.grey700,
            fontSize: 12,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static Map<String, dynamic> _calculateBatchStats(List<Map<String, dynamic>> batches) {
    int specialWoodCount = 0;
    double totalValue = 0;

    for (var batch in batches) {
      if (batch['moonwood'] == true ||
          batch['haselfichte'] == true ||
          batch['thermally_treated'] == true ||
          batch['FSC_100'] == true) {
        specialWoodCount++;
      }
      totalValue += batch['value'] as double;
    }

    return {
      'batchCount': batches.length,
      'totalValue': totalValue,
      'specialWoodCount': specialWoodCount,
      'hasSpecialWood': specialWoodCount > 0,
    };
  }

  static String _getFilterTimeRange(ProductionFilter filter) {
    if (filter.timeRange != null) {
      switch (filter.timeRange) {
        case 'week': return 'Letzte Woche';
        case 'month': return 'Letzter Monat';
        case 'quarter': return 'Letztes Quartal';
        case 'year': return 'Letztes Jahr';
        default: return 'Benutzerdefiniert';
      }
    } else if (filter.startDate != null && filter.endDate != null) {
      return '${DateFormat('dd.MM.yy').format(filter.startDate!)} - '
          '${DateFormat('dd.MM.yy').format(filter.endDate!)}';
    }
    return 'Alle Chargen';
  }


}