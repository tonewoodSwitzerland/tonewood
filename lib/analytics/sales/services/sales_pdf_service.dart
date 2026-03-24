// lib/analytics/sales/services/sales_pdf_service.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_filter.dart';
import '../models/sales_analytics_models.dart';
import '../../../services/countries.dart';

class SalesPdfService {

  static String _formatCurrency(double value) {
    final isNegative = value < 0;
    final absValue = value.abs();
    final wholePart = absValue.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => "${m[1]}'",
    );
    final decimalPart = ((absValue - absValue.toInt()) * 100).round().toString().padLeft(2, '0');
    return '${isNegative ? "-" : ""}CHF $wholePart.$decimalPart';
  }

  static final _dateFormat = DateFormat('dd.MM.yyyy');
  static final _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  // ============================================================
  // 1) DETAIL-LISTE: Einzelne Aufträge (Buchhaltung)
  // FIX: MwSt/Total-Spalten entfernt, Land eingefügt
  // FIX: Nur shipped, Warenwert (subtotal) als Basis
  // ============================================================

  static Future<Uint8List> generateSalesDetailList(
      List<Map<String, dynamic>> sales, {
        required SalesFilter filter,
      }) async {
    final pdf = pw.Document();

    // Verkäufe nach Filter filtern
    final filteredSales = _filterSales(sales, filter);

    // Nach Versanddatum sortieren (neueste zuerst)
    filteredSales.sort((a, b) {
      final aShipped = a['shippedAt'];
      final aOrder = a['orderDate'];
      final bShipped = b['shippedAt'];
      final bOrder = b['orderDate'];
      DateTime? dateA;
      DateTime? dateB;
      if (aShipped is Timestamp) { dateA = aShipped.toDate(); } else if (aOrder is Timestamp) { dateA = aOrder.toDate(); }
      if (bShipped is Timestamp) { dateB = bShipped.toDate(); } else if (bOrder is Timestamp) { dateB = bOrder.toDate(); }
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('images/logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final stats = _calculateSalesStats(filteredSales);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logo != null) pw.Image(logo, width: 120),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Verkaufsübersicht',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_dateFormat.format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Zusammenfassung
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Zusammenfassung',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Anzahl Aufträge', stats['salesCount'].toString()),
                    _buildSummaryItem('Zeitraum', _getFilterTimeRange(filter)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 6),
                _buildSummaryLine(
                  'Warenwert (netto Ware) *',
                  _formatCurrency(stats['totalSubtotal'] as double),
                ),
                if ((stats['totalGratisValue'] as double? ?? 0) > 0)
                  _buildSummaryLine(
                    '  * inkl. ${_formatCurrency(stats['totalGratisValue'])} Gratisartikel (bereits abgezogen)',
                    '',
                    color: PdfColors.grey600,
                  ),
                if ((stats['totalServiceRevenue'] as double) > 0)
                  _buildSummaryLine(
                    '+ Dienstleistungen',
                    _formatCurrency(stats['totalServiceRevenue']),
                  ),
                if ((stats['totalFreight'] as double? ?? 0) > 0)
                  _buildSummaryLine(
                    '+ Fracht',
                    _formatCurrency(stats['totalFreight']),
                  ),
                if ((stats['totalPhyto'] as double? ?? 0) > 0)
                  _buildSummaryLine(
                    '+ Phytosanitary',
                    _formatCurrency(stats['totalPhyto']),
                  ),
                if ((stats['totalDeductions'] as double? ?? 0) > 0)
                  _buildSummaryLine(
                    '- Abschläge',
                    _formatCurrency(stats['totalDeductions']),
                    color: PdfColors.deepOrange,
                  ),
                if ((stats['totalSurcharges'] as double? ?? 0) > 0)
                  _buildSummaryLine(
                    '+ Zuschläge',
                    _formatCurrency(stats['totalSurcharges']),
                    color: PdfColors.teal,
                  ),
                pw.SizedBox(height: 4),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 4),
                _buildSummaryLine(
                  '= Rechnungsbetrag netto',
                  _formatCurrency(stats['totalNetAmount']),
                  bold: true,
                ),
                if ((stats['totalVat'] as double? ?? 0) > 0)
                  _buildSummaryLine(
                    '+ MwSt',
                    _formatCurrency(stats['totalVat']),
                  ),
                _buildSummaryLine(
                  '= Rechnungsbetrag brutto',
                  _formatCurrency(stats['totalRevenue']),
                  bold: true,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.SizedBox(height: 6),
          pw.Text(
            '* Warenwert bereits nach Rabatten (${_formatCurrency(stats['totalDiscount'] as double)}) & Gratisartikeln (${_formatCurrency(stats['totalGratisValue'] as double)})',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 20),
          // Aktive Filter anzeigen
          if (_hasActiveFilter(filter))
            ..._buildFilterChips(filter),
          if (_hasActiveFilter(filter))
            pw.SizedBox(height: 12),

          // Tabelle — FIX: MwSt/Total raus, Land nach Kunde eingefügt
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headers: [
              'Versand', 'Nr.', 'Kunde', 'Land', 'Bestellart', 'Artikel',
              'Warenwert', 'Rechn. netto', 'Rechn. brutto',
            ],
            data: filteredSales.where((s) => s['status'] != 'cancelled').map((sale) {
              final items        = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              final calculations = sale['calculations'] as Map<String, dynamic>? ?? {};
              final metadata     = sale['metadata'] as Map<String, dynamic>? ?? {};
              final customer     = sale['customer'] as Map<String, dynamic>? ?? {};
              final distChannel  = metadata['distributionChannel'] as Map<String, dynamic>?;

              DateTime? ts;
              final shippedAt = sale['shippedAt'];
              final od = sale['orderDate'];
              if (shippedAt is Timestamp) {
                ts = shippedAt.toDate();
              } else if (od is Timestamp) {
                ts = od.toDate();
              }

              // Warenwert: item-by-item ohne Service + ohne Gratisartikel
              final orderTotalDisc = (calculations['total_discount_amount'] as num?)?.toDouble() ?? 0;
              double warenwert = 0;
              for (final it in items) {
                if (it['is_service'] == true || it['is_gratisartikel'] == true) continue;
                final qty   = (it['quantity']              as num?)?.toDouble() ?? 0;
                final price = (it['custom_price_per_unit'] as num?)?.toDouble()
                    ?? (it['price_per_unit']               as num?)?.toDouble() ?? 0;
                final disc    = it['discount'] as Map<String, dynamic>?;
                final discPct = (disc?['percentage']       as num?)?.toDouble() ?? 0;
                final discAbs = (disc?['absolute']         as num?)?.toDouble() ?? 0;
                warenwert += qty * price - (qty * price * discPct / 100) - discAbs;
              }
              warenwert -= orderTotalDisc;

              final netAmount  = (calculations['net_amount'] as num?)?.toDouble() ?? 0;
              final totalGross = (calculations['total']      as num?)?.toDouble() ?? 0;

              final countryCode = customer['countryCode']?.toString() ??
                  customer['country']?.toString() ?? '';
              final country = Countries.getCountryByCode(countryCode);

              return [
                ts != null ? DateFormat('dd.MM.yy').format(ts) : '-',
                sale['orderNumber'] ?? sale['receipt_number'] ?? '-',
                _getCustomerDisplayName(customer),
                country.name.isNotEmpty ? country.name : countryCode,
                distChannel?['name'] ?? '-',
                '${items.length} Pos.',
                _formatCurrency(warenwert),
                _formatCurrency(netAmount),
                _formatCurrency(totalGross),
              ];
            }).toList(),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerLeft,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(2.8),
              3: const pw.FlexColumnWidth(1.3),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.6),
              7: const pw.FlexColumnWidth(1.6),
              8: const pw.FlexColumnWidth(1.6),
            },
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Florinett AG - Tonewood Switzerland',
                  style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
              pw.Text('Seite ${context.pageNumber} von ${context.pagesCount}',
                  style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }
  static pw.Widget _buildSummaryLine(String label, String value,
      {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          )),
          pw.Text(value, style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          )),
        ],
      ),
    );
  }
  // ============================================================
  // 2) ANALYTICS-BERICHT: KPI + Länder + Produkte (3 Seiten)
  // ============================================================

  static Future<Uint8List> generateAnalyticsReport(
      SalesAnalytics analytics, {
        SalesFilter? filter,
      }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('images/logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // Seite 1: KPIs
    pdf.addPage(_buildKpiPage(analytics, logo, filter));

    // Seite 2: Länder
    pdf.addPage(_buildCountryPage(analytics, logo));

    // Seite 3: Produkte
    pdf.addPage(_buildProductPage(analytics, logo));

    return pdf.save();
  }

  // ============================================================
  // SEITE 1: KPI-ÜBERSICHT — NEU: Warenwert + Gesamtbetrag
  // ============================================================

  static pw.Page _buildKpiPage(SalesAnalytics analytics, pw.MemoryImage? logo, SalesFilter? filter) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader('Verkaufsanalyse - Übersicht', logo),
            pw.SizedBox(height: 4),
            pw.Text('Stand: ${_dateTimeFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            if (filter != null && _hasActiveFilter(filter))
              ..._buildFilterChips(filter),
            pw.SizedBox(height: 20),

            // KPIs — Warenwert
            pw.Text('Warenwert (netto Ware)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildDataTable(
              headers: ['Kennzahl', 'Wert', 'Veränderung'],
              widths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(2)},
              rows: _buildRevenueRows(analytics, filter),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '* Warenwert bereits nach Rabatten (${_formatCurrency(analytics.revenue.totalDiscount)}) & Gratisartikeln (${_formatCurrency(analytics.revenue.totalGratisValue)})',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 16),

            // KPIs — Gesamtbetrag
            pw.Text('Gesamtbetrag (inkl. Versand, MwSt)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildDataTable(
              headers: ['Kennzahl', 'Wert', 'Veränderung'],
              widths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(2)},
              rows: _buildRevenueGrossRows(analytics, filter),
            ),
            pw.SizedBox(height: 16),

            // Dienstleistungen
            if (analytics.serviceStats.serviceItemCount > 0) ...[
              pw.Text('Dienstleistungen', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              _buildDataTable(
                headers: ['Kennzahl', 'Wert', 'Detail'],
                widths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(2)},
                rows: [
                  ['Anteil Artikel', '${analytics.serviceStats.itemSharePercent.toStringAsFixed(1)}%',
                    '${analytics.serviceStats.serviceItemCount} von ${analytics.serviceStats.totalItemCount}'],
                  ['Anteil Umsatz', '${analytics.serviceStats.revenueSharePercent.toStringAsFixed(1)}%',
                    _formatCurrency(analytics.serviceStats.serviceRevenue)],
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Monatliche Umsätze
            pw.Text('Monatliche Umsätze (Warenwert)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildMonthlyTable(analytics.revenue.monthlyRevenue, analytics.revenue.monthlyRevenueLastYear),

            pw.Expanded(child: pw.SizedBox()),
            _buildFooter(),
          ],
        );
      },
    );
  }

  // ============================================================
  // SEITE 2: LÄNDER — zeigt jetzt Warenwert
  // ============================================================

  static pw.Page _buildCountryPage(SalesAnalytics analytics, pw.MemoryImage? logo) {
    final countries = analytics.countryStats.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final totalRevenue = countries.fold<double>(0, (sum, c) => sum + c.revenue);
    final totalOrders = countries.fold<int>(0, (sum, c) => sum + c.orderCount);
    final totalItems = countries.fold<int>(0, (sum, c) => sum + c.itemCount);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader('Verkaufsanalyse - Länder', logo),
            pw.SizedBox(height: 4),
            pw.Text(
              '${countries.length} Länder | $totalOrders Lieferungen | Warenwert: ${_formatCurrency(totalRevenue)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 16),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                _buildHeaderRow(['Land', 'Warenwert CHF', '%', 'Aufträge', 'Artikel']),
                ...countries.take(25).map((c) {
                  final pct = totalRevenue > 0 ? (c.revenue / totalRevenue * 100).toStringAsFixed(1) : '0.0';
                  return _buildRow([c.countryName, _formatCurrency(c.revenue), '$pct%',
                    c.orderCount.toString(), c.itemCount.toString()]);
                }),
                // Total
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Total', bold: true), _cell(_formatCurrency(totalRevenue), bold: true),
                    _cell('100%', bold: true), _cell(totalOrders.toString(), bold: true),
                    _cell(totalItems.toString(), bold: true),
                  ],
                ),
              ],
            ),
            if (countries.length > 25)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text('+ ${countries.length - 25} weitere Länder',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ),

            pw.Expanded(child: pw.SizedBox()),
            _buildFooter(),
          ],
        );
      },
    );
  }

  // ============================================================
  // SEITE 3: PRODUKTE — NEU: m³-Spalte bei Holzarten
  // ============================================================

  static pw.Page _buildProductPage(SalesAnalytics analytics, pw.MemoryImage? logo) {
    final woodTypes = analytics.woodTypeStats.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final totalWoodRevenue = woodTypes.fold<double>(0, (sum, w) => sum + w.revenue);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader('Verkaufsanalyse - Produkte', logo),
            pw.SizedBox(height: 16),

            // Top Produkte
            pw.Text('Top 10 Produkte', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                _buildHeaderRow(['#', 'Produkt', 'Stück', 'Umsatz CHF']),
                ...analytics.topProductCombos.asMap().entries.map((e) {
                  return _buildRow(['${e.key + 1}', e.value.displayName,
                    e.value.quantity.toString(), _formatCurrency(e.value.revenue)]);
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Holzarten — NEU: mit m³-Spalte
            pw.Text('Umsatz nach Holzart', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                _buildHeaderRow(['Holzart', 'Stück', 'm³', '%', 'Umsatz CHF']),
                ...woodTypes.take(15).map((w) {
                  final pct = totalWoodRevenue > 0 ? (w.revenue / totalWoodRevenue * 100).toStringAsFixed(1) : '0.0';
                  final volumeStr = w.volume > 0 ? w.volume.toStringAsFixed(4) : '-';
                  return _buildRow([w.woodName, w.quantity.toString(), volumeStr, '$pct%', _formatCurrency(w.revenue)]);
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // Thermobehandlung
            pw.Text('Thermobehandlung', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildDataTable(
              headers: ['Kennzahl', 'Wert', 'Detail'],
              widths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(2)},
              rows: [
                ['Anteil Artikel', '${analytics.thermoStats.itemSharePercent.toStringAsFixed(1)}%',
                  '${analytics.thermoStats.thermoItemCount} von ${analytics.thermoStats.totalItemCount}'],
                ['Anteil Umsatz', '${analytics.thermoStats.revenueSharePercent.toStringAsFixed(1)}%',
                  _formatCurrency(analytics.thermoStats.thermoRevenue)],
              ],
            ),

            pw.Expanded(child: pw.SizedBox()),
            _buildFooter(),
          ],
        );
      },
    );
  }

  // ============================================================
  // SHARED WIDGETS
  // ============================================================

  static List<pw.Widget> _buildFilterChips(SalesFilter filter) {
    final chips = <String>[];

    if (filter.timeRange != null) {
      chips.add('Zeitraum: ${_getFilterTimeRange(filter)}');
    } else if (filter.startDate != null || filter.endDate != null) {
      final start = filter.startDate != null ? _dateFormat.format(filter.startDate!) : '...';
      final end = filter.endDate != null ? _dateFormat.format(filter.endDate!) : '...';
      chips.add('Zeitraum: $start - $end');
    }

    if (filter.minAmount != null && filter.maxAmount != null) {
      chips.add('Betrag: ${_formatCurrency(filter.minAmount!)} – ${_formatCurrency(filter.maxAmount!)}');
    } else if (filter.minAmount != null) {
      chips.add('Min. ${_formatCurrency(filter.minAmount!)}');
    } else if (filter.maxAmount != null) {
      chips.add('Max. ${_formatCurrency(filter.maxAmount!)}');
    }

    if (filter.countries != null && filter.countries!.isNotEmpty) {
      final names = filter.countries!
          .map((code) => Countries.getCountryByCode(code).name)
          .toList();
      chips.add('Land: ${names.join(', ')}');
    }

    if (filter.woodTypes != null && filter.woodTypes!.isNotEmpty) {
      chips.add('Holzart: ${filter.woodTypes!.join(', ')}');
    }

    if (filter.qualities != null && filter.qualities!.isNotEmpty) {
      chips.add('Qualität: ${filter.qualities!.join(', ')}');
    }

    if (filter.instruments != null && filter.instruments!.isNotEmpty) {
      chips.add('Instrument: ${filter.instruments!.join(', ')}');
    }

    if (filter.parts != null && filter.parts!.isNotEmpty) {
      chips.add('Bauteil: ${filter.parts!.join(', ')}');
    }

    if (filter.costCenters != null && filter.costCenters!.isNotEmpty) {
      chips.add('Kostenstelle: ${filter.costCenters!.join(', ')}');
    }

    if (filter.distributionChannels != null && filter.distributionChannels!.isNotEmpty) {
      chips.add('Bestellart: ${filter.distributionChannels!.join(', ')}');
    }

    if (filter.selectedCustomers != null && filter.selectedCustomers!.isNotEmpty) {
      chips.add('${filter.selectedCustomers!.length} Kunde(n)');
    }

    if (filter.selectedFairs != null && filter.selectedFairs!.isNotEmpty) {
      chips.add('${filter.selectedFairs!.length} Messe(n)');
    }

    if (filter.selectedProducts != null && filter.selectedProducts!.isNotEmpty) {
      chips.add('${filter.selectedProducts!.length} Artikel');
    }

    if (chips.isEmpty) return [];

    return [
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.orange50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: PdfColors.orange200, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Aktive Filter',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
            pw.SizedBox(height: 4),
            pw.Wrap(
              spacing: 6,
              runSpacing: 4,
              children: chips.map((label) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.orange300, width: 0.5),
                ),
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
              )).toList(),
            ),
          ],
        ),
      ),
    ];
  }

  static pw.Widget _buildHeader(String title, pw.MemoryImage? logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (logo != null) pw.Image(logo, width: 110),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Florinett AG - Tonewood Switzerland',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        pw.Text('Erstellt: ${_dateTimeFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ],
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildDataTable({
    required List<String> headers,
    required Map<int, pw.TableColumnWidth> widths,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: widths,
      children: [
        _buildHeaderRow(headers),
        ...rows.map((r) => _buildRow(r)),
      ],
    );
  }

  static pw.Widget _buildMonthlyTable(
      Map<String, double> monthlyRevenue,
      Map<String, double> monthlyRevenueLastYear,
      ) {
    final sorted = monthlyRevenue.keys.toList()..sort();
    final last12 = sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;
    if (last12.isEmpty) return pw.Text('Keine Daten', style: const pw.TextStyle(fontSize: 9));

    final currentYear = DateTime.now().year;
    final lastYear = currentYear - 1;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        _buildHeaderRow(['Monat', 'Warenwert $currentYear', 'Warenwert $lastYear', '+/- %']),
        ...last12.map((k) {
          final parts = k.split('-');
          final month = int.tryParse(parts.length == 2 ? parts[1] : '1') ?? 1;
          // Vorjahr-Key: gleicher Monat, Jahr -1
          final lastYearKey = '${lastYear}-${month.toString().padLeft(2, '0')}';
          final current = monthlyRevenue[k] ?? 0;
          final previous = monthlyRevenueLastYear[lastYearKey] ?? 0;

          String changeStr = '-';
          if (previous > 0) {
            final pct = ((current - previous) / previous) * 100;
            changeStr = '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%';
          }

          return pw.TableRow(
            children: [
              _cell(_formatMonthKey(k)),
              _cell(_formatCurrency(current)),
              _cell(previous > 0 ? _formatCurrency(previous) : '-'),
              _cell(changeStr),
            ],
          );
        }),
      ],
    );
  }

  static pw.TableRow _buildHeaderRow(List<String> headers) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: headers.map((h) => _cell(h, bold: true)).toList(),
    );
  }

  static pw.TableRow _buildRow(List<String> cells) {
    return pw.TableRow(children: cells.map((c) => _cell(c)).toList());
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Text(text, style: pw.TextStyle(
        fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      )),
    );
  }

  // ============================================================
  // HILFSFUNKTIONEN
  // ============================================================
  static Map<String, dynamic> _calculateSalesStats(List<Map<String, dynamic>> sales) {
    double totalRevenue = 0;
    double totalNetAmount = 0;
    double totalSubtotal = 0;
    double totalServiceRevenue = 0;
    double totalFreight = 0;
    double totalPhyto = 0;
    double totalDeductions = 0;
    double totalSurcharges = 0;
    double totalDiscount = 0;
    double totalVat = 0;
    double totalGratisValue = 0;  // NEU
    int count = 0;

    for (var sale in sales) {
      if (sale['status'] == 'cancelled') continue;
      final calculations = sale['calculations'] as Map<String, dynamic>? ?? {};
      final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final orderFreight       = (calculations['freight']               as num?)?.toDouble() ?? 0;
      final orderPhyto         = (calculations['phytosanitary']         as num?)?.toDouble() ?? 0;
      final orderDeductions    = (calculations['total_deductions']      as num?)?.toDouble() ?? 0;
      final orderSurcharges    = (calculations['total_surcharges']      as num?)?.toDouble() ?? 0;
      final orderTotalDiscount = (calculations['total_discount_amount'] as num?)?.toDouble() ?? 0;
      final orderVat           = (calculations['vat_amount']            as num?)?.toDouble() ?? 0;

      totalRevenue   += (calculations['total']      as num?)?.toDouble() ?? 0;
      totalNetAmount += (calculations['net_amount'] as num?)?.toDouble() ?? 0;
      totalFreight    += orderFreight;
      totalPhyto      += orderPhyto;
      totalDeductions += orderDeductions;
      totalSurcharges += orderSurcharges;
      totalDiscount   += orderTotalDiscount;
      totalVat        += orderVat;

      double orderSubtotal = 0;
      double orderServiceRev = 0;

      for (final it in items) {
        final qty      = (it['quantity']              as num?)?.toDouble() ?? 0;
        final price    = (it['custom_price_per_unit'] as num?)?.toDouble()
            ?? (it['price_per_unit']                  as num?)?.toDouble() ?? 0;
        final disc     = it['discount'] as Map<String, dynamic>?;
        final discPct  = (disc?['percentage']         as num?)?.toDouble() ?? 0;
        final discAbs  = (disc?['absolute']           as num?)?.toDouble() ?? 0;
        final lineDiscount = qty * price * discPct / 100 + discAbs;
        final lineTotal = qty * price - lineDiscount;

        if (it['is_service'] == true) {
          orderServiceRev += lineTotal;
        } else if (it['is_gratisartikel'] == true) {
          totalGratisValue += lineTotal;  // NEU: Gratisartikel-Wert merken
        } else {
          orderSubtotal += lineTotal;
        }
      }

      orderSubtotal -= orderTotalDiscount;
      totalSubtotal       += orderSubtotal;
      totalServiceRevenue += orderServiceRev;
      count++;
    }

    return {
      'salesCount':          count,
      'totalRevenue':        totalRevenue,
      'totalNetAmount':      totalNetAmount,
      'totalSubtotal':       totalSubtotal,
      'totalServiceRevenue': totalServiceRevenue,
      'totalFreight':        totalFreight,
      'totalPhyto':          totalPhyto,
      'totalDeductions':     totalDeductions,
      'totalSurcharges':     totalSurcharges,
      'totalDiscount':       totalDiscount,
      'totalVat':            totalVat,
      'totalGratisValue':    totalGratisValue,  // NEU
      'averageOrderValue':   count == 0 ? 0.0 : totalSubtotal / count,
    };
  }

  static String _getFilterTimeRange(SalesFilter filter) {
    if (filter.timeRange != null) {
      switch (filter.timeRange) {
        case 'week': return 'Diese Woche';
        case 'month': return 'Dieser Monat';
        case 'quarter': return 'Dieses Quartal';
        case 'year': return 'Dieses Jahr';
        default: return 'Benutzerdefiniert';
      }
    } else if (filter.startDate != null && filter.endDate != null) {
      return '${_dateFormat.format(filter.startDate!)} - ${_dateFormat.format(filter.endDate!)}';
    }
    return 'Alle Aufträge';
  }

  static bool _hasActiveFilter(SalesFilter filter) {
    return filter.timeRange != null || filter.startDate != null || filter.minAmount != null ||
        (filter.selectedFairs?.isNotEmpty ?? false) || (filter.selectedCustomers?.isNotEmpty ?? false) ||
        (filter.woodTypes?.isNotEmpty ?? false) || (filter.qualities?.isNotEmpty ?? false) ||
        (filter.parts?.isNotEmpty ?? false) || (filter.instruments?.isNotEmpty ?? false) ||
        (filter.costCenters?.isNotEmpty ?? false) || (filter.distributionChannels?.isNotEmpty ?? false) ||
        (filter.countries?.isNotEmpty ?? false);
  }

  /// FIX: Filtert jetzt nur shipped Aufträge
  static List<Map<String, dynamic>> _filterSales(
      List<Map<String, dynamic>> sales, SalesFilter filter) {
    return sales.where((sale) {
      // Stornierte überspringen
      if (sale['status'] == 'cancelled') return false;

      // FIX: Nur versendete Aufträge
      if (sale['status'] != 'shipped') return false;

      // Zeitraum-Filter — FIX: shippedAt bevorzugt, Fallback auf orderDate
      DateTime? relevantDate;
      final shippedAtRaw = sale['shippedAt'];
      final orderDateRaw = sale['orderDate'];
      if (shippedAtRaw is Timestamp) {
        relevantDate = shippedAtRaw.toDate();
      } else if (orderDateRaw is Timestamp) {
        relevantDate = orderDateRaw.toDate();
      } else {
        final metadata = sale['metadata'] as Map<String, dynamic>? ?? {};
        final metaTimestamp = metadata['timestamp'];
        if (metaTimestamp is Timestamp) relevantDate = metaTimestamp.toDate();
      }

      if (relevantDate != null) {
        DateTime? filterStart = filter.startDate;
        DateTime? filterEnd = filter.endDate;

        if (filter.timeRange != null) {
          final now = DateTime.now();
          filterEnd = now;
          switch (filter.timeRange) {
            case 'week':
              filterStart = now.subtract(Duration(days: now.weekday - 1));
              filterStart = DateTime(filterStart!.year, filterStart.month, filterStart.day);
              break;
            case 'month':
              filterStart = DateTime(now.year, now.month, 1);
              break;
            case 'quarter':
              final qm = ((now.month - 1) ~/ 3) * 3 + 1;
              filterStart = DateTime(now.year, qm, 1);
              break;
            case 'year':
              filterStart = DateTime(now.year, 1, 1);
              break;
          }
        }

        if (filterStart != null && relevantDate.isBefore(filterStart)) return false;
        if (filterEnd != null && relevantDate.isAfter(
            DateTime(filterEnd.year, filterEnd.month, filterEnd.day, 23, 59, 59)
        )) return false;
      }

      // Kunden-Filter
      if (filter.selectedCustomers != null && filter.selectedCustomers!.isNotEmpty) {
        final customer = sale['customer'] as Map<String, dynamic>? ?? {};
        final customerId = customer['id']?.toString() ?? '';
        if (!filter.selectedCustomers!.contains(customerId)) return false;
      }

      // Messe-Filter
      if (filter.selectedFairs != null && filter.selectedFairs!.isNotEmpty) {
        final fair = sale['fair'] as Map<String, dynamic>?;
        final fairId = fair?['id']?.toString() ?? '';
        if (!filter.selectedFairs!.contains(fairId)) return false;
      }

      // Länder-Filter
      if (filter.countries != null && filter.countries!.isNotEmpty) {
        final customer = sale['customer'] as Map<String, dynamic>? ?? {};
        final countryCode = customer['countryCode']?.toString() ??
            customer['country']?.toString() ?? '';
        if (!filter.countries!.contains(countryCode)) return false;
      }

      // Kostenstellen-Filter
      if (filter.costCenters != null && filter.costCenters!.isNotEmpty) {
        final costCenter = sale['costCenter'] as Map<String, dynamic>?;
        if (costCenter == null) return false;
        final code = costCenter['code']?.toString() ?? '';
        final id = costCenter['id']?.toString() ?? '';
        if (!filter.costCenters!.any((f) => f == id || f == code)) return false;
      }

      // Bestellart-Filter
      if (filter.distributionChannels != null && filter.distributionChannels!.isNotEmpty) {
        final metadata = sale['metadata'] as Map<String, dynamic>? ?? {};
        final distChannel = metadata['distributionChannel'] as Map<String, dynamic>?;
        if (distChannel == null) return false;
        final name = distChannel['name']?.toString() ?? '';
        final id = distChannel['id']?.toString() ?? '';
        if (!filter.distributionChannels!.any((f) => f == id || f == name)) return false;
      }

      // Item-Level Filter
      if (_hasItemLevelFilters(filter)) {
        final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final hasMatch = items.any((item) => _itemMatchesFilter(item, filter));
        if (!hasMatch) return false;
      }

      // Betrags-Filter
      if (filter.minAmount != null || filter.maxAmount != null) {
        final calculations = sale['calculations'] as Map<String, dynamic>? ?? {};
        final subtotal = (calculations['subtotal'] as num?)?.toDouble() ?? 0;
        if (filter.minAmount != null && subtotal < filter.minAmount!) return false;
        if (filter.maxAmount != null && subtotal > filter.maxAmount!) return false;
      }

      return true;
    }).toList();
  }

  static bool _hasItemLevelFilters(SalesFilter filter) {
    return (filter.selectedProducts?.isNotEmpty ?? false) ||
        (filter.woodTypes?.isNotEmpty ?? false) ||
        (filter.qualities?.isNotEmpty ?? false) ||
        (filter.parts?.isNotEmpty ?? false) ||
        (filter.instruments?.isNotEmpty ?? false);
  }

  static bool _itemMatchesFilter(Map<String, dynamic> item, SalesFilter filter) {
    if (filter.woodTypes != null && filter.woodTypes!.isNotEmpty) {
      final woodCode = item['wood_code']?.toString();
      if (woodCode == null || !filter.woodTypes!.contains(woodCode)) return false;
    }
    if (filter.qualities != null && filter.qualities!.isNotEmpty) {
      final qualityCode = item['quality_code']?.toString();
      if (qualityCode == null || !filter.qualities!.contains(qualityCode)) return false;
    }
    if (filter.parts != null && filter.parts!.isNotEmpty) {
      final partCode = item['part_code']?.toString();
      if (partCode == null || !filter.parts!.contains(partCode)) return false;
    }
    if (filter.instruments != null && filter.instruments!.isNotEmpty) {
      final instrumentCode = item['instrument_code']?.toString();
      if (instrumentCode == null || !filter.instruments!.contains(instrumentCode)) return false;
    }
    if (filter.selectedProducts != null && filter.selectedProducts!.isNotEmpty) {
      final productId = item['product_id']?.toString();
      if (productId == null || !filter.selectedProducts!.contains(productId)) return false;
    }
    return true;
  }

  static String _getCustomerDisplayName(Map<String, dynamic> customer) {
    final company = customer['company']?.toString().trim() ?? '';
    if (company.isNotEmpty) return company;
    final first = customer['firstName']?.toString().trim() ?? '';
    final last = customer['lastName']?.toString().trim() ?? '';
    final fullName = '$first $last'.trim();
    if (fullName.isNotEmpty) return fullName;
    return customer['fullName']?.toString() ?? '-';
  }

  /// Ob ein expliziter Datumsfilter (kein timeRange-Shortcut) gesetzt ist
  static bool _hasDateFilter(SalesFilter? filter) {
    if (filter == null) return false;
    return filter.startDate != null || filter.endDate != null || filter.timeRange != null;
  }

  /// Label für den gefilterten Zeitraum (kurz, für Tabellenzeile)
  static String _filterPeriodLabel(SalesFilter? filter) {
    if (filter == null) return 'Gesamtzeitraum';
    if (filter.timeRange != null) return _getFilterTimeRange(filter);
    if (filter.startDate != null && filter.endDate != null) {
      return '${_dateFormat.format(filter.startDate!)} - ${_dateFormat.format(filter.endDate!)}';
    }
    if (filter.startDate != null) return 'ab ${_dateFormat.format(filter.startDate!)}';
    if (filter.endDate != null) return 'bis ${_dateFormat.format(filter.endDate!)}';
    return 'Gesamtzeitraum';
  }

  /// KPI-Zeilen Warenwert — filterbewusst
  static List<List<String>> _buildRevenueRows(SalesAnalytics analytics, SalesFilter? filter) {
    final now = DateTime.now();
    final rev = analytics.revenue;

    if (_hasDateFilter(filter)) {
      return [
        ['Warenwert ${_filterPeriodLabel(filter)}',  _formatCurrency(rev.totalRevenue), ''],
        if (rev.totalServiceRevenue > 0)
          ['+ Dienstleistungen',                     _formatCurrency(rev.totalServiceRevenue),  ''],
        if (rev.totalFreight > 0)
          ['+ Fracht',                               _formatCurrency(rev.totalFreight),         ''],
        if (rev.totalPhytosanitary > 0)
          ['+ Phytosanitary',                        _formatCurrency(rev.totalPhytosanitary),   ''],
        if (rev.totalDeductions > 0)
          ['- Abschläge',                            _formatCurrency(rev.totalDeductions),      ''],
        if (rev.totalSurcharges > 0)
          ['+ Zuschläge',                            _formatCurrency(rev.totalSurcharges),      ''],
        ['Anzahl Aufträge',                          analytics.orderCount.toString(),           ''],
        ['Ø Warenwert / Auftrag',                    _formatCurrency(analytics.averageOrderValue), ''],

      ];
    }

    return [
      ['Warenwert ${now.year}',                      _formatCurrency(rev.yearRevenue),
        '${_changeStr(rev.yearChangePercent)} vs. Vorjahr'],
      ['Warenwert ${_monthName(now.month)}',         _formatCurrency(rev.monthRevenue),
        '${_changeStr(rev.monthChangePercent)} vs. Vormonat'],
      if (rev.yearServiceRevenue > 0)
        ['+ Dienstleistungen ${now.year}',           _formatCurrency(rev.yearServiceRevenue),  ''],
      if (rev.yearFreight > 0)
        ['+ Fracht ${now.year}',                     _formatCurrency(rev.yearFreight),         ''],
      if (rev.yearPhytosanitary > 0)
        ['+ Phytosanitary ${now.year}',              _formatCurrency(rev.yearPhytosanitary),   ''],
      if (rev.yearDeductions > 0)
        ['- Abschläge ${now.year}',                  _formatCurrency(rev.yearDeductions),      ''],
      if (rev.yearSurcharges > 0)
        ['+ Zuschläge ${now.year}',                  _formatCurrency(rev.yearSurcharges),      ''],
      ['Anzahl Aufträge',                            analytics.orderCount.toString(),           ''],
      ['Ø Warenwert / Auftrag',                      _formatCurrency(analytics.averageOrderValue), ''],

    ];
  }
  /// KPI-Zeilen Gesamtbetrag — filterbewusst
  static List<List<String>> _buildRevenueGrossRows(SalesAnalytics analytics, SalesFilter? filter) {
    final now = DateTime.now();
    if (_hasDateFilter(filter)) {
      return [
        ['Gesamtbetrag ${_filterPeriodLabel(filter)}', _formatCurrency(analytics.revenue.totalRevenueGross), ''],
        ['Ø Gesamtbetrag / Auftrag', _formatCurrency(analytics.averageOrderValueGross), ''],
      ];
    }
    return [
      ['Gesamtbetrag ${now.year}', _formatCurrency(analytics.revenue.yearRevenueGross),
        '${_changeStr(analytics.revenue.yearChangePercentGross)} vs. Vorjahr'],
      ['Gesamtbetrag ${_monthName(now.month)}', _formatCurrency(analytics.revenue.monthRevenueGross),
        '${_changeStr(analytics.revenue.monthChangePercentGross)} vs. Vormonat'],
      ['Ø Gesamtbetrag / Auftrag', _formatCurrency(analytics.averageOrderValueGross), ''],
    ];
  }

  static String _changeStr(double pct) => '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%';

  static String _monthName(int month) {
    const names = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];
    return names[month - 1];
  }

  static String _formatMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final m = int.tryParse(parts[1]) ?? 1;
    const short = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return '${short[m - 1]} ${parts[0]}';
  }
}