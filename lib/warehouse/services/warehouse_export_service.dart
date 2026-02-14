// lib/warehouse/services/warehouse_export_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Conditional imports für Web vs. Mobile
import 'warehouse_export_helper_stub.dart'
if (dart.library.html) 'warehouse_export_helper_web.dart'
if (dart.library.io) 'warehouse_export_helper_mobile.dart';

class WarehouseExportService {
  /// CSV Export - funktioniert auf Web und Mobile
  static Future<void> exportCsv({
    required List<Map<String, dynamic>> items,
    required bool isOnlineShopView,
    String? shopFilter,
  }) async {
    final fileName = isOnlineShopView
        ? 'Onlineshop_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv'
        : 'Lagerbestand_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv';

    final csvBytes = _buildCsvBytes(
      items: items,
      isOnlineShopView: isOnlineShopView,
      shopFilter: shopFilter,
    );

    await saveAndShareFile(
      bytes: csvBytes,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// PDF Export - funktioniert auf Web und Mobile
  static Future<void> exportPdf({
    required List<Map<String, dynamic>> items,
    required bool isOnlineShopView,
    String? shopFilter,
    Map<String, dynamic>? activeFilters,
  }) async {
    final fileName = isOnlineShopView
        ? 'Onlineshop_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf'
        : 'Lagerbestand_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf';

    final pdfBytes = await _buildPdfBytes(
      items: items,
      isOnlineShopView: isOnlineShopView,
      shopFilter: shopFilter,
      activeFilters: activeFilters,
    );

    await saveAndShareFile(
      bytes: pdfBytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }
  // ============================================================
  // CSV Aufbau
  // ============================================================

  static Uint8List _buildCsvBytes({
    required List<Map<String, dynamic>> items,
    required bool isOnlineShopView,
    String? shopFilter,
  }) {
    final StringBuffer csvContent = StringBuffer();

    // BOM für Excel UTF-8 Erkennung
    final bom = String.fromCharCodes([0xFEFF]);
    csvContent.write(bom);

    // Headers
    final headers = isOnlineShopView
        ? [
      'Artikelnummer',
      'Produkt',
      'Instrument',
      'Bauteil',
      'Holzart',
      'Qualität',
      'Status',
      'Preis CHF',
      'Eingestellt am',
      if (shopFilter == 'sold') 'Verkauft am',
    ]
        : [
      'Artikelnummer',
      'Produkt',
      'Instrument',
      'Bauteil',
      'Holzart',
      'Qualität',
      'Bestand',
      'Einheit',
      'Preis CHF',
    ];

    csvContent.writeln(headers.join(';'));

    // Data rows
    for (final item in items) {
      final row = isOnlineShopView
          ? [
        "'${item['barcode']}",
        item['product_name'],
        '${item['instrument_name']} (${item['instrument_code']})',
        '${item['part_name']} (${item['part_code']})',
        '${item['wood_name']} (${item['wood_code']})',
        '${item['quality_name']} (${item['quality_code']})',
        item['sold'] == true ? 'Verkauft' : 'Im Shop',
        NumberFormat.currency(
          locale: 'en_US',
          symbol: '',
          decimalDigits: 2,
        ).format(item['price_CHF']).trim(),
        item['created_at'] != null
            ? DateFormat('dd.MM.yyyy HH:mm')
            .format((item['created_at'] as Timestamp).toDate())
            : '',
        if (shopFilter == 'sold' && item['sold_at'] != null)
          DateFormat('dd.MM.yyyy HH:mm')
              .format((item['sold_at'] as Timestamp).toDate()),
      ]
          : [
        "'${item['short_barcode']}",
        item['product_name'],
        '${item['instrument_name']} (${item['instrument_code']})',
        '${item['part_name']} (${item['part_code']})',
        '${item['wood_name']} (${item['wood_code']})',
        '${item['quality_name']} (${item['quality_code']})',
        item['quantity'].toString(),
        item['unit'],
        NumberFormat.currency(
          locale: 'en_US',
          symbol: '',
          decimalDigits: 2,
        ).format(item['price_CHF']).trim(),
      ];
      csvContent.writeln(row.join(';'));
    }

    return Uint8List.fromList(utf8.encode(csvContent.toString()));
  }

  // ============================================================
  // PDF Aufbau
  // ============================================================

  static Future<Uint8List> _buildPdfBytes({
    required List<Map<String, dynamic>> items,
    required bool isOnlineShopView,
    String? shopFilter,
    Map<String, dynamic>? activeFilters,
  }) async {
    final pdf = pw.Document();

    final headerStyle = pw.TextStyle(
      fontSize: 7,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );
    final cellStyle = pw.TextStyle(fontSize: 6.5);

    // Filter-Info Text bauen
    String filterInfoText = _buildFilterInfoText(activeFilters, shopFilter);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        orientation: pw.PageOrientation.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          // Kompakter Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                isOnlineShopView
                    ? 'Onlineshop Übersicht'
                    : 'Lagerbestand Übersicht',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Stand: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 4),

          // Filter-Info
          if (filterInfoText.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Aktive Filter:',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    filterInfoText,
                    style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),

          pw.SizedBox(height: 4),

          // Anzahl Ergebnisse
          pw.Text(
            '${items.length} ${items.length == 1 ? 'Eintrag' : 'Einträge'}',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),

          pw.SizedBox(height: 6),

          pw.Table.fromTextArray(
            headerStyle: headerStyle,
            cellStyle: cellStyle,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 18,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 2,
            ),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.center,
              6: pw.Alignment.centerRight,
            },
            columnWidths: isOnlineShopView
                ? {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1.2),
              7: const pw.FlexColumnWidth(1.5),
              if (shopFilter == 'sold')
                8: const pw.FlexColumnWidth(1.5),
            }
                : {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1.2),
            },
            headers: isOnlineShopView
                ? [
              'Art.Nr.',
              'Produkt',
              'Instrument',
              'Holzart',
              'Qualität',
              'Status',
              'Preis CHF',
              'Eingestellt',
              if (shopFilter == 'sold') 'Verkauft',
            ]
                : [
              'Art.Nr.',
              'Produkt',
              'Instrument',
              'Holzart',
              'Qualität',
              'Bestand',
              'Preis CHF',
            ],
            data: items
                .map((item) => isOnlineShopView
                ? [
              item['barcode'] ?? '',
              item['product_name'] ?? '',
              '${item['instrument_name']} (${item['instrument_code']})',
              '${item['wood_name']} (${item['wood_code']})',
              '${item['quality_name']} (${item['quality_code']})',
              item['sold'] == true ? 'Verkauft' : 'Im Shop',
              NumberFormat.currency(
                  locale: 'de_DE',
                  symbol: '',
                  decimalDigits: 2)
                  .format(item['price_CHF']),
              item['created_at'] != null
                  ? DateFormat('dd.MM.yy').format(
                  (item['created_at'] as Timestamp).toDate())
                  : '',
              if (shopFilter == 'sold')
                item['sold_at'] != null
                    ? DateFormat('dd.MM.yy').format(
                    (item['sold_at'] as Timestamp).toDate())
                    : '',
            ]
                : [
              item['short_barcode'] ?? '',
              item['product_name'] ?? '',
              '${item['instrument_name']} (${item['instrument_code']})',
              '${item['wood_name']} (${item['wood_code']})',
              '${item['quality_name']} (${item['quality_code']})',
              '${item['quantity']} ${item['unit']}',
              NumberFormat.currency(
                  locale: 'de_DE',
                  symbol: '',
                  decimalDigits: 2)
                  .format(item['price_CHF']),
            ])
                .toList(),
          ),
        ],
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  /// Baut den Filter-Info-Text für das PDF
  static String _buildFilterInfoText(
      Map<String, dynamic>? activeFilters, String? shopFilter) {
    if (activeFilters == null) return '';

    final parts = <String>[];

    if (activeFilters['searchText'] != null &&
        (activeFilters['searchText'] as String).isNotEmpty) {
      parts.add('Suche: "${activeFilters['searchText']}"');
    }

    if (activeFilters['instruments'] != null &&
        (activeFilters['instruments'] as List).isNotEmpty) {
      parts.add('Instrument: ${(activeFilters['instruments'] as List).join(', ')}');
    }

    if (activeFilters['parts'] != null &&
        (activeFilters['parts'] as List).isNotEmpty) {
      parts.add('Bauteil: ${(activeFilters['parts'] as List).join(', ')}');
    }

    if (activeFilters['woodTypes'] != null &&
        (activeFilters['woodTypes'] as List).isNotEmpty) {
      parts.add('Holzart: ${(activeFilters['woodTypes'] as List).join(', ')}');
    }

    if (activeFilters['qualities'] != null &&
        (activeFilters['qualities'] as List).isNotEmpty) {
      parts.add('Qualität: ${(activeFilters['qualities'] as List).join(', ')}');
    }

    if (activeFilters['unit'] != null) {
      parts.add('Einheit: ${activeFilters['unit']}');
    }

    if (shopFilter != null) {
      final shopFilterName = {
        'sold': 'Verkauft',
        'available': 'Im Shop',
        'discounted': 'Rabattiert',
      }[shopFilter] ?? shopFilter;
      parts.add('Shop-Filter: $shopFilterName');
    }

    return parts.join('  |  ');
  }
}