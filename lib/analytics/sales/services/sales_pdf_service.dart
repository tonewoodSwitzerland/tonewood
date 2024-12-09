import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_filter.dart';

class SalesPdfService {
  static String _formatCurrency(double value) {
    final wholePart = (value.toInt()).toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}\'',
    );
    final decimalPart = ((value - value.toInt()) * 100).toInt().toString().padLeft(2, '0');
    return 'CHF $wholePart.$decimalPart';
  }

  static Future<Uint8List> generateSalesList(
      List<Map<String, dynamic>> sales, {
        required SalesFilter filter,
      }) async {
    final pdf = pw.Document();

    // Logo laden
    final ByteData logoData = await rootBundle.load('images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    // Zusammenfassung berechnen
    final stats = _calculateSalesStats(sales);

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
                      'Verkaufsübersicht',
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
                    _buildSummaryItem('Anzahl Verkäufe', stats['salesCount'].toString()),
                    _buildSummaryItem(
                      'Gesamtumsatz',
                      _formatCurrency(stats['totalRevenue']),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Durchschn. Bestellwert',
                        _formatCurrency(stats['averageOrderValue'])),
                    _buildSummaryItem('Zeitraum', _getFilterTimeRange(filter)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Verkaufsliste
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            headers: [
              'Datum',
              'Beleg-Nr.',
              'Kunde',
              'Artikel',
              'Menge',
              'Netto CHF',
              'MwSt CHF',
              'Total CHF',
            ],
            data: sales.map((sale) {
              final items = (sale['items'] as List).cast<Map<String, dynamic>>();
              final calculations = sale['calculations'] as Map<String, dynamic>;
              final metadata = sale['metadata'] as Map<String, dynamic>;
              final customer = sale['customer'] as Map<String, dynamic>;
              final timestamp = (metadata['timestamp'] as Timestamp).toDate();

              return [
                DateFormat('dd.MM.yy').format(timestamp),
                sale['receipt_number'] ?? '-',
                customer['company'],
                '${items.length} Artikel',
                items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int)),
                NumberFormat('#,##0.00').format(calculations['net_amount']),
                NumberFormat('#,##0.00').format(calculations['vat_amount']),
                NumberFormat('#,##0.00').format(calculations['total']),
              ];
            }).toList(),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
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

  static Map<String, dynamic> _calculateSalesStats(List<Map<String, dynamic>> sales) {
    double totalRevenue = 0;

    for (var sale in sales) {
      final calculations = sale['calculations'] as Map<String, dynamic>;
      totalRevenue += calculations['total'] as double;
    }

    return {
      'salesCount': sales.length,
      'totalRevenue': totalRevenue,
      'averageOrderValue': sales.isEmpty ? 0 : totalRevenue / sales.length,
    };
  }

  static String _getFilterTimeRange(SalesFilter filter) {
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
    return 'Alle Verkäufe';
  }
}