// lib/analytics/sales/services/sales_csv_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_analytics_models.dart';
import '../models/sales_filter.dart';
import '../helpers/tax_helper.dart';

class SalesCsvService {

  // ============================================================
  // 1) DETAIL-EXPORT: Eine Zeile pro Artikel (für Buchhaltung/Excel)
  // ============================================================

  static Future<List<int>> generateSalesDetailList(
      List<Map<String, dynamic>> sales, {
        SalesFilter? filter,
      }) async {
    final filteredSales = filter != null ? _filterSales(sales, filter) : List<Map<String, dynamic>>.from(sales);

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

    final csvData = [
      [
        'Datum',
        'Belegnummer',
        'Kunde',
        'Land',
        'Bestellart',
        'Kostenstelle',
        'Steuerart',
        'Artikel',
        'Holzart',
        'Qualität',
        'Instrument',
        'Bauteil',
        'Thermo',
        'Gratisartikel',
        'Menge',
        'Einheit',
        'Einzelpreis',
        'Rabatt %',
        'Rabatt CHF',
        'Artikeltotal',
      ].join(';'),
    ];

    for (final sale in filteredSales) {
      final customer = sale['customer'] as Map<String, dynamic>? ?? {};
      final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final metadata = sale['metadata'] as Map<String, dynamic>? ?? {};
      final costCenter = sale['costCenter'] as Map<String, dynamic>?;
      final distChannel = metadata['distributionChannel'] as Map<String, dynamic>?;

      DateTime? timestamp;
      final shippedAtRaw = sale['shippedAt'];
      final orderDateRaw = sale['orderDate'];
      if (shippedAtRaw is Timestamp) {
        timestamp = shippedAtRaw.toDate();
      } else if (orderDateRaw is Timestamp) {
        timestamp = orderDateRaw.toDate();
      } else {
        final metaTimestamp = metadata['timestamp'];
        if (metaTimestamp is Timestamp) timestamp = metaTimestamp.toDate();
      }

      final dateStr = timestamp != null
          ? DateFormat('dd.MM.yyyy').format(timestamp)
          : '-';

      final orderNumber = sale['orderNumber'] ?? sale['receipt_number'] ?? '-';
      final companyName = customer['company']?.toString().trim() ?? '';
      final customerName = companyName.isNotEmpty
          ? companyName
          : '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim().isNotEmpty
          ? '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim()
          : customer['fullName'] ?? '-';
      final countryCode = customer['countryCode'] ?? customer['country'] ?? '';
      final costCenterStr = costCenter != null
          ? '${costCenter['code'] ?? ''} - ${costCenter['name'] ?? ''}'
          : '';
      final distChannelStr = distChannel?['name'] ?? '';

      // NEU: Steuerart aus Metadaten
      final taxOptionCode = TaxHelper.getTaxOptionCode(TaxHelper.getTaxOption(sale));

      for (final item in items) {
        if (sale['status'] == 'cancelled') continue;

        final isGratis = item['is_gratisartikel'] == true;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        final pricePerUnit = (item['custom_price_per_unit'] as num?)?.toDouble()
            ?? (item['price_per_unit'] as num?)?.toDouble() ?? 0;
        final discount = item['discount'] as Map<String, dynamic>?;
        final discountPct = (discount?['percentage'] as num?)?.toDouble() ?? 0;
        final discountAbs = (discount?['absolute'] as num?)?.toDouble() ?? 0;
        // Vor der Item-Loop (nach Zeile ~99):
        final taxOption = TaxHelper.getTaxOption(sale);
        final vatRate = TaxHelper.getVatRate(sale);

// In der Item-Loop:
        double itemTotal = isGratis
            ? 0.0
            : quantity * pricePerUnit - (quantity * pricePerUnit * discountPct / 100) - discountAbs;
        if (taxOption == 2 && !isGratis) {
          itemTotal = TaxHelper.netFromGross(itemTotal, vatRate);
        }
        final row = [
          dateStr,
          orderNumber,
          _escapeCsv(customerName),
          countryCode,
          _escapeCsv(distChannelStr),
          _escapeCsv(costCenterStr),
          taxOptionCode,
          _escapeCsv(item['product_name'] ?? ''),
          _escapeCsv(item['wood_name'] ?? ''),
          _escapeCsv(item['quality_name'] ?? ''),
          _escapeCsv(item['instrument_name'] ?? ''),
          _escapeCsv(item['part_name'] ?? ''),
          item['has_thermal_treatment'] == true ? 'Ja' : 'Nein',
          isGratis ? 'Ja' : 'Nein',
          quantity.toString(),
          item['unit'] ?? 'Stk',
          pricePerUnit.toStringAsFixed(2),
          discountPct.toStringAsFixed(1),
          discountAbs.toStringAsFixed(2),
          itemTotal.toStringAsFixed(2),
        ].join(';');

        csvData.add(row);
      }
    }

    return _addBom(csvData.join('\n'));
  }

  // ============================================================
  // 2) ANALYTICS-EXPORT: Zusammenfassung
  // ============================================================

  static List<int> generateAnalyticsSummary(SalesAnalytics analytics) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final rev = analytics.revenue;

    buffer.writeln('Verkaufsanalyse - Zusammenfassung');
    buffer.writeln('Exportiert am;${DateFormat('dd.MM.yyyy HH:mm').format(now)}');
    buffer.writeln('');

    // Warenwert Aufschlüsselung
    buffer.writeln('Warenwert (netto Ware)');
    buffer.writeln('Kennzahl;Wert;Veränderung');
    buffer.writeln('Warenwert (nach Rabatten) ${now.year};${rev.yearRevenue.toStringAsFixed(2)};${_changeStr(rev.yearChangePercent)}');
    buffer.writeln('Warenwert (nach Rabatten) ${_monthName(now.month)};${rev.monthRevenue.toStringAsFixed(2)};${_changeStr(rev.monthChangePercent)}');
    if (rev.yearGratisValue > 0)
      buffer.writeln('* Gratisartikel bereits abgezogen;${rev.yearGratisValue.toStringAsFixed(2)};');
    buffer.writeln('Vorjahres-Warenwert;${rev.previousYearRevenue.toStringAsFixed(2)};');
    buffer.writeln('');

    // Rechnungsbetrag netto Aufschlüsselung
    buffer.writeln('Rechnungsbetrag netto (Aufschlüsselung)');
    buffer.writeln('Kennzahl;Wert');
    buffer.writeln('Warenwert (nach Rabatten) ${now.year};${rev.yearRevenue.toStringAsFixed(2)}');
    if (rev.yearServiceRevenue > 0)
      buffer.writeln('+ Dienstleistungen;${rev.yearServiceRevenue.toStringAsFixed(2)}');
    if (rev.yearFreight > 0)
      buffer.writeln('+ Fracht;${rev.yearFreight.toStringAsFixed(2)}');
    if (rev.yearPhytosanitary > 0)
      buffer.writeln('+ Phytosanitary;${rev.yearPhytosanitary.toStringAsFixed(2)}');
    if (rev.yearDeductions > 0)
      buffer.writeln('- Abschläge;${rev.yearDeductions.toStringAsFixed(2)}');
    if (rev.yearSurcharges > 0)
      buffer.writeln('+ Zuschläge;${rev.yearSurcharges.toStringAsFixed(2)}');
    final netRevenue = rev.yearRevenue + rev.yearServiceRevenue + rev.yearFreight
        + rev.yearPhytosanitary - rev.yearDeductions + rev.yearSurcharges;
    buffer.writeln('= Rechnungsbetrag netto;${netRevenue.toStringAsFixed(2)}');
    buffer.writeln('');

    // Gesamtbetrag (Brutto)
    buffer.writeln('Gesamtbetrag (inkl. MwSt)');
    buffer.writeln('Kennzahl;Wert;Veränderung');
    buffer.writeln('Gesamtbetrag ${now.year};${rev.yearRevenueGross.toStringAsFixed(2)};${_changeStr(rev.yearChangePercentGross)}');
    buffer.writeln('Gesamtbetrag ${_monthName(now.month)};${rev.monthRevenueGross.toStringAsFixed(2)};${_changeStr(rev.monthChangePercentGross)}');
    buffer.writeln('Ø Gesamtbetrag / Auftrag;${analytics.averageOrderValueGross.toStringAsFixed(2)};');
    buffer.writeln('Anzahl Aufträge;${analytics.orderCount};');
    buffer.writeln('Ø Warenwert / Auftrag;${analytics.averageOrderValue.toStringAsFixed(2)};');
    buffer.writeln('');

    // Thermo
    buffer.writeln('Thermobehandlung');
    buffer.writeln('Kennzahl;Wert;Detail');
    buffer.writeln('Anteil Artikel;${analytics.thermoStats.itemSharePercent.toStringAsFixed(1)}%;${analytics.thermoStats.thermoItemCount} von ${analytics.thermoStats.totalItemCount}');
    buffer.writeln('Anteil Umsatz;${analytics.thermoStats.revenueSharePercent.toStringAsFixed(1)}%;${analytics.thermoStats.thermoRevenue.toStringAsFixed(2)}');
    buffer.writeln('');

    // Monatliche Umsätze
    buffer.writeln('Monatliche Umsätze');
    buffer.writeln('Monat;Warenwert CHF;Gesamtbetrag CHF');
    final sortedMonths = rev.monthlyRevenue.keys.toList()..sort();
    for (final month in sortedMonths) {
      final subtotal = rev.monthlyRevenue[month]?.toStringAsFixed(2) ?? '0.00';
      final total = rev.monthlyRevenueGross[month]?.toStringAsFixed(2) ?? '0.00';
      buffer.writeln('${_formatMonthKey(month)};$subtotal;$total');
    }
    buffer.writeln('');

    // Länder
    final countries = analytics.countryStats.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final totalRevenue = countries.fold<double>(0, (sum, c) => sum + c.revenue);

    buffer.writeln('Umsatz nach Land');
    buffer.writeln('Land;Ländercode;Warenwert CHF;Anteil;Aufträge;Artikel');
    for (final c in countries) {
      final pct = totalRevenue > 0
          ? '${(c.revenue / totalRevenue * 100).toStringAsFixed(1)}%'
          : '0.0%';
      buffer.writeln('${_escapeCsv(c.countryName)};${c.countryCode};${c.revenue.toStringAsFixed(2)};$pct;${c.orderCount};${c.itemCount}');
    }
    buffer.writeln('');

    // Holzarten
    final woodTypes = analytics.woodTypeStats.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    buffer.writeln('Umsatz nach Holzart');
    buffer.writeln('Holzart;Code;Stück;m³;Umsatz CHF');
    for (final w in woodTypes) {
      final volumeStr = w.volume > 0 ? w.volume.toStringAsFixed(4) : '0.0000';
      buffer.writeln('${_escapeCsv(w.woodName)};${w.woodCode};${w.quantity};$volumeStr;${w.revenue.toStringAsFixed(2)}');
    }

    return _addBom(buffer.toString());
  }

  // ============================================================
  // HILFSFUNKTIONEN
  // ============================================================

  static List<int> _addBom(String csv) {
    final bom = [0xEF, 0xBB, 0xBF];
    return bom + utf8.encode(csv);
  }

  static String _escapeCsv(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _changeStr(double pct) {
    return '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%';
  }

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

  static List<Map<String, dynamic>> _filterSales(
      List<Map<String, dynamic>> sales, SalesFilter filter) {
    return sales.where((sale) {
      if (sale['status'] == 'cancelled') return false;
      if (sale['status'] != 'shipped') return false;

      DateTime? orderDate;
      final shippedAtRaw = sale['shippedAt'];
      final orderDateRaw = sale['orderDate'];
      if (shippedAtRaw is Timestamp) {
        orderDate = shippedAtRaw.toDate();
      } else if (orderDateRaw is Timestamp) {
        orderDate = orderDateRaw.toDate();
      } else {
        final metadata = sale['metadata'] as Map<String, dynamic>? ?? {};
        final metaTimestamp = metadata['timestamp'];
        if (metaTimestamp is Timestamp) orderDate = metaTimestamp.toDate();
      }

      if (orderDate != null) {
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

        if (filterStart != null && orderDate.isBefore(filterStart)) return false;
        if (filterEnd != null && orderDate.isAfter(
            DateTime(filterEnd.year, filterEnd.month, filterEnd.day, 23, 59, 59)
        )) return false;
      }

      if (filter.selectedCustomers != null && filter.selectedCustomers!.isNotEmpty) {
        final customer = sale['customer'] as Map<String, dynamic>? ?? {};
        final customerId = customer['id']?.toString() ?? '';
        if (!filter.selectedCustomers!.contains(customerId)) return false;
      }

      if (filter.selectedFairs != null && filter.selectedFairs!.isNotEmpty) {
        final fair = sale['fair'] as Map<String, dynamic>?;
        final fairId = fair?['id']?.toString() ?? '';
        if (!filter.selectedFairs!.contains(fairId)) return false;
      }

      if (filter.countries != null && filter.countries!.isNotEmpty) {
        final customer = sale['customer'] as Map<String, dynamic>? ?? {};
        final countryCode = customer['countryCode']?.toString() ??
            customer['country']?.toString() ?? '';
        if (!filter.countries!.contains(countryCode)) return false;
      }

      if (filter.costCenters != null && filter.costCenters!.isNotEmpty) {
        final costCenter = sale['costCenter'] as Map<String, dynamic>?;
        if (costCenter == null) return false;
        final code = costCenter['code']?.toString() ?? '';
        final id = costCenter['id']?.toString() ?? '';
        if (!filter.costCenters!.any((f) => f == id || f == code)) return false;
      }

      if (filter.distributionChannels != null && filter.distributionChannels!.isNotEmpty) {
        final metadata = sale['metadata'] as Map<String, dynamic>? ?? {};
        final distChannel = metadata['distributionChannel'] as Map<String, dynamic>?;
        if (distChannel == null) return false;
        final name = distChannel['name']?.toString() ?? '';
        final id = distChannel['id']?.toString() ?? '';
        if (!filter.distributionChannels!.any((f) => f == id || f == name)) return false;
      }

      if (_hasItemLevelFilters(filter)) {
        final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final hasMatch = items.any((item) => _itemMatchesFilter(item, filter));
        if (!hasMatch) return false;
      }

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
}