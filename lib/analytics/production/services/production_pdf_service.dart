// lib/analytics/production/services/production_pdf_service.dart
//
// PDF-Export für die neue flache production_batches Collection.
// Professionelles Layout nach dem Vorbild des Roundwood PDF Service.

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ProductionPdfService {
  // =============================================
  // PUBLIC API
  // =============================================

  /// Generiert eine professionelle Chargenliste als PDF.
  ///
  /// [batches] - Liste von Maps aus ProductionBatchService
  /// [activeFilters] - Aktive Filter für die Anzeige im PDF-Header
  /// [includeAnalytics] - Ob eine Analyse-Seite angehängt werden soll
  static Future<Uint8List> generateBatchList(
      List<Map<String, dynamic>> batches, {
        Map<String, dynamic>? activeFilters,
        bool includeAnalytics = false,
      }) async {
    final pdf = pw.Document();

    // Logo laden
    final ByteData logoData = await rootBundle.load('images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    // Sortiere nach Datum (neueste zuerst)
    batches.sort((a, b) {
      final dateA = _extractDate(a);
      final dateB = _extractDate(b);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    // Statistiken berechnen
    final stats = _calculateStats(batches);
    final filterText = _buildFilterInfoText(activeFilters);

    // Hauptseiten
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          _buildHeader(logo),
          pw.SizedBox(height: 12),

          // Filter-Info
          if (filterText.isNotEmpty) ...[
            _buildFilterInfoBox(filterText),
            pw.SizedBox(height: 8),
          ],

          // Zusammenfassung
          _buildSummarySection(stats),
          pw.SizedBox(height: 12),

          // Anzahl Ergebnisse
          pw.Text(
            '${batches.length} ${batches.length == 1 ? 'Charge' : 'Chargen'}',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 6),

          // Haupttabelle
          _buildMainTable(batches),

          // Legende
          if (stats['hasSpecialWood'] == true) ...[
            pw.SizedBox(height: 16),
            _buildLegend(),
          ],
        ],
        footer: (pw.Context context) => _buildFooter(context),
      ),
    );

    // Optionale Analyse-Seite
    if (includeAnalytics && batches.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => _buildAnalyticsPage(batches, stats),
        ),
      );
    }

    return pdf.save();
  }

  // =============================================
  // HEADER & FOOTER
  // =============================================

  static pw.Widget _buildHeader(pw.MemoryImage logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Produktionsübersicht',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Datum: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
            ),
          ],
        ),
        pw.Image(logo, width: 180),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Florinett AG - Tonewood Switzerland',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600),
          ),
          pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600),
          ),
        ],
      ),
    );
  }

  // =============================================
  // FILTER INFO
  // =============================================

  static pw.Widget _buildFilterInfoBox(String filterText) {
    return pw.Container(
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
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            filterText,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static String _buildFilterInfoText(Map<String, dynamic>? activeFilters) {
    if (activeFilters == null || activeFilters.isEmpty) return '';

    final parts = <String>[];

    // Zeitraum
    if (activeFilters['timeRange'] != null) {
      final timeRangeNames = {
        'week': 'Letzte Woche',
        'month': 'Letzter Monat',
        'quarter': 'Letztes Quartal',
        'year': 'Letztes Jahr',
      };
      parts.add('Zeitraum: ${timeRangeNames[activeFilters['timeRange']] ?? activeFilters['timeRange']}');
    }

    if (activeFilters['startDate'] != null && activeFilters['endDate'] != null) {
      final start = activeFilters['startDate'];
      final end = activeFilters['endDate'];
      final startStr = start is DateTime ? DateFormat('dd.MM.yy').format(start) : start.toString();
      final endStr = end is DateTime ? DateFormat('dd.MM.yy').format(end) : end.toString();
      parts.add('Zeitraum: $startStr - $endStr');
    }

    if (activeFilters['years'] != null && (activeFilters['years'] as List).isNotEmpty) {
      parts.add('Jahre: ${(activeFilters['years'] as List).join(', ')}');
    }

    if (activeFilters['instruments'] != null && (activeFilters['instruments'] as List).isNotEmpty) {
      parts.add('Instrumente: ${(activeFilters['instruments'] as List).join(', ')}');
    }

    if (activeFilters['parts'] != null && (activeFilters['parts'] as List).isNotEmpty) {
      parts.add('Bauteile: ${(activeFilters['parts'] as List).join(', ')}');
    }

    if (activeFilters['woodTypes'] != null && (activeFilters['woodTypes'] as List).isNotEmpty) {
      parts.add('Holzart: ${(activeFilters['woodTypes'] as List).join(', ')}');
    }

    if (activeFilters['qualities'] != null && (activeFilters['qualities'] as List).isNotEmpty) {
      parts.add('Qualität: ${(activeFilters['qualities'] as List).join(', ')}');
    }

    if (activeFilters['isMoonwood'] == true) parts.add('Mondholz: Ja');
    if (activeFilters['isHaselfichte'] == true) parts.add('Haselfichte: Ja');
    if (activeFilters['isThermallyTreated'] == true) parts.add('Therm. behandelt: Ja');
    if (activeFilters['isFSC'] == true) parts.add('FSC-100: Ja');

    return parts.join('  |  ');
  }

  // =============================================
  // ZUSAMMENFASSUNG
  // =============================================

  static pw.Widget _buildSummarySection(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: PdfColors.grey50,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Chargen', stats['batchCount'].toString(), 'Stück'),
          _buildSummaryItem(
            'Gesamtwert',
            _formatCurrency(stats['totalValue'] as double),
            '',
          ),
          _buildSummaryItem(
            'Spezialholz',
            stats['specialWoodCount'].toString(),
            'Chargen',
          ),
          _buildSummaryItem(
            'Ø Chargengrösse',
            (stats['avgBatchSize'] as double).toStringAsFixed(1),
            stats['primaryUnit'] ?? 'Stk',
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value, String unit) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.blueGrey600,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        if (unit.isNotEmpty)
          pw.Text(
            unit,
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey500),
          ),
      ],
    );
  }

  // =============================================
  // HAUPTTABELLE
  // =============================================

  static pw.Widget _buildMainTable(List<Map<String, dynamic>> batches) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.center,
      },
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
      headers: [
        'Datum',
        'Prod.-Nr.',
        'Artikel',
        'Holzart',
        'Qualität',
        'Menge',
        'Wert CHF',
        'Spezial',
      ],
      data: batches.map((batch) {
        final date = _extractDate(batch);
        final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
        final price = (batch['price_CHF'] as num?)?.toDouble() ?? 0.0;
        final value = (batch['value'] as num?)?.toDouble() ?? (quantity * price);
        final unit = batch['unit'] ?? 'Stk';

        // Spezialholz-Flags
        final specialFlags = <String>[];
        if (batch['moonwood'] == true) specialFlags.add('M');
        if (batch['haselfichte'] == true) specialFlags.add('H');
        if (batch['thermally_treated'] == true) specialFlags.add('T');
        if (batch['FSC_100'] == true) specialFlags.add('F');

        // Produktionsnummer
        final barcode = batch['barcode'] ?? '';
        final batchNumber = (batch['batch_number'] ?? 0).toString().padLeft(4, '0');
        final productionNumber = barcode.isNotEmpty ? '$barcode.$batchNumber' : batchNumber;

        return [
          date != null ? DateFormat('dd.MM.yy').format(date) : '',
          productionNumber,
          batch['product_name'] ?? '',
          batch['wood_name'] ?? '',
          batch['quality_name'] ?? '',
          '${NumberFormat('#,##0').format(quantity)} $unit',
          NumberFormat('#,##0.00').format(value),
          specialFlags.join(','),
        ];
      }).toList(),
    );
  }

  // =============================================
  // LEGENDE
  // =============================================

  static pw.Widget _buildLegend() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Legende: M = Mondholz, H = Haselfichte, T = Thermisch behandelt, F = FSC-100',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
    );
  }

  // =============================================
  // ANALYSE-SEITE (optional)
  // =============================================

  static pw.Widget _buildAnalyticsPage(
      List<Map<String, dynamic>> batches,
      Map<String, dynamic> stats,
      ) {
    // Verteilung nach Holzart
    final woodDistribution = <String, int>{};
    final woodValues = <String, double>{};
    for (final batch in batches) {
      final wood = batch['wood_name'] as String? ?? 'Unbekannt';
      woodDistribution[wood] = (woodDistribution[wood] ?? 0) + 1;
      final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      final price = (batch['price_CHF'] as num?)?.toDouble() ?? 0.0;
      woodValues[wood] = (woodValues[wood] ?? 0.0) + (quantity * price);
    }

    // Verteilung nach Instrument
    final instrumentDistribution = <String, int>{};
    for (final batch in batches) {
      final instrument = batch['instrument_name'] as String? ?? 'Unbekannt';
      instrumentDistribution[instrument] = (instrumentDistribution[instrument] ?? 0) + 1;
    }

    // Sortiere absteigend
    final sortedWood = woodDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedInstruments = instrumentDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Produktionsanalyse',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 20),

        // Verteilung nach Holzart
        _buildDistributionSection(
          'Verteilung nach Holzart',
          sortedWood,
          batches.length,
          woodValues,
        ),

        pw.SizedBox(height: 24),

        // Verteilung nach Instrument
        _buildDistributionSection(
          'Verteilung nach Instrument',
          sortedInstruments,
          batches.length,
          null,
        ),
      ],
    );
  }

  static pw.Widget _buildDistributionSection(
      String title,
      List<MapEntry<String, int>> entries,
      int total,
      Map<String, double>? values,
      ) {
    // Farben für die Balken
    const colors = [
      PdfColors.blue700,
      PdfColors.green700,
      PdfColors.orange700,
      PdfColors.purple700,
      PdfColors.teal700,
      PdfColors.red700,
      PdfColors.amber700,
      PdfColors.cyan700,
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        ...entries.asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final entry = mapEntry.value;
          final percentage = total > 0 ? entry.value / total : 0.0;
          final color = colors[index % colors.length];

          String label = entry.key;
          if (values != null && values.containsKey(entry.key)) {
            label += ' (${_formatCurrency(values[entry.key]!)})';
          }

          return pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(width: 10, height: 10, color: color),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Text(
                      '${(percentage * 100).toStringAsFixed(1)}% (${entry.value})',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Container(
                  width: percentage * 350,
                  height: 6,
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // =============================================
  // HILFSMETHODEN
  // =============================================

  static Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> batches) {
    int specialWoodCount = 0;
    double totalValue = 0;
    double totalQuantity = 0;
    final unitCounts = <String, int>{};

    for (var batch in batches) {
      final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      final price = (batch['price_CHF'] as num?)?.toDouble() ?? 0.0;
      final value = (batch['value'] as num?)?.toDouble() ?? (quantity * price);
      final unit = batch['unit'] as String? ?? 'Stk';

      totalValue += value;
      totalQuantity += quantity;
      unitCounts[unit] = (unitCounts[unit] ?? 0) + 1;

      if (batch['moonwood'] == true ||
          batch['haselfichte'] == true ||
          batch['thermally_treated'] == true ||
          batch['FSC_100'] == true) {
        specialWoodCount++;
      }
    }

    // Häufigste Einheit ermitteln
    String primaryUnit = 'Stk';
    int maxCount = 0;
    unitCounts.forEach((unit, count) {
      if (count > maxCount) {
        maxCount = count;
        primaryUnit = unit;
      }
    });

    return {
      'batchCount': batches.length,
      'totalValue': totalValue,
      'specialWoodCount': specialWoodCount,
      'hasSpecialWood': specialWoodCount > 0,
      'avgBatchSize': batches.isNotEmpty ? totalQuantity / batches.length : 0.0,
      'primaryUnit': primaryUnit,
    };
  }

  static String _formatCurrency(double value) {
    final wholePart = value.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}\'',
    );
    final decimalPart = ((value - value.toInt()).abs() * 100).round().toString().padLeft(2, '0');
    return 'CHF $wholePart.$decimalPart';
  }

  static DateTime? _extractDate(Map<String, dynamic> batch) {
    final dateField = batch['stock_entry_date'];
    if (dateField == null) return null;
    if (dateField is DateTime) return dateField;
    if (dateField is dynamic && dateField.toDate != null) {
      try {
        return (dateField).toDate();
      } catch (_) {}
    }
    return null;
  }
}