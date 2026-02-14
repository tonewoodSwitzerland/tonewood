// lib/analytics/sales/services/sales_analytics_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/countries.dart';
import '../models/sales_filter.dart';
import '../models/sales_analytics_models.dart';

class SalesAnalyticsService {
  final _db = FirebaseFirestore.instance;

  Map<String, String>? _distributionChannelNames;
  Map<String, String>? _costCenterCodes;

  Future<void> _loadDistributionChannelNames() async {
    final snapshot = await _db.collection('distribution_channel').get();
    _distributionChannelNames = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      _distributionChannelNames![doc.id] = data['name']?.toString() ?? '';
    }
  }

  Future<void> _loadCostCenterCodes() async {
    final snapshot = await _db.collection('cost_centers').get();
    _costCenterCodes = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      _costCenterCodes![doc.id] = data['code']?.toString() ?? '';
    }
  }

  /// Haupt-Stream für alle Analytics-Daten
  Stream<SalesAnalytics> getAnalyticsStream(SalesFilter filter) {
    Query query = _db.collection('orders');

    // Serverseitige Filter (Firestore erlaubt nur einen whereIn)
    if (filter.selectedCustomers != null && filter.selectedCustomers!.isNotEmpty) {
      query = query.where('customer.id', whereIn: filter.selectedCustomers);
    } else if (filter.selectedFairs != null && filter.selectedFairs!.isNotEmpty) {
      query = query.where('fair.id', whereIn: filter.selectedFairs);
    }

    return query.snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        return SalesAnalytics.empty();
      }

      // Zeiträume definieren
      final now = DateTime.now();
      final currentYearStart = DateTime(now.year, 1, 1);
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final previousYearStart = DateTime(now.year - 1, 1, 1);
      final previousYearEnd = DateTime(now.year - 1, 12, 31, 23, 59, 59);
      final previousMonthStart = DateTime(now.year, now.month - 1, 1);
      final previousMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

      // Zeitraum-Filter berechnen
      DateTime? filterStartDate = filter.startDate;
      DateTime? filterEndDate = filter.endDate;

      if (filter.timeRange != null) {
        switch (filter.timeRange) {
          case 'week':
            filterStartDate = now.subtract(Duration(days: now.weekday - 1));
            filterStartDate = DateTime(filterStartDate!.year, filterStartDate.month, filterStartDate.day);
            filterEndDate = now;
            break;
          case 'month':
            filterStartDate = DateTime(now.year, now.month, 1);
            filterEndDate = now;
            break;
          case 'quarter':
            final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
            filterStartDate = DateTime(now.year, quarterMonth, 1);
            filterEndDate = now;
            break;
          case 'year':
            filterStartDate = DateTime(now.year, 1, 1);
            filterEndDate = now;
            break;
        }
      }

      // Aggregations-Variablen — Warenwert (subtotal)
      double totalRevenue = 0;
      double yearRevenue = 0;
      double monthRevenue = 0;
      double previousYearRevenue = 0;
      double previousMonthRevenue = 0;
      Map<String, double> monthlyRevenue = {};

      // Aggregations-Variablen — Brutto/Gesamtbetrag (total)
      double totalRevenueGross = 0;
      double yearRevenueGross = 0;
      double monthRevenueGross = 0;
      double previousYearRevenueGross = 0;
      double previousMonthRevenueGross = 0;
      Map<String, double> monthlyRevenueGross = {};

      int orderCount = 0;

      int thermoItemCount = 0;
      int totalItemCount = 0;
      double thermoRevenue = 0;

      Map<String, CountryStats> countryStats = {};
      Map<String, WoodTypeStats> woodTypeStats = {};
      Map<String, ProductComboStats> productCombos = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Order-Datum parsen
        final orderDateRaw = data['orderDate'];
        DateTime? orderDate;
        if (orderDateRaw is Timestamp) {
          orderDate = orderDateRaw.toDate();
        } else if (orderDateRaw is String) {
          orderDate = DateTime.tryParse(orderDateRaw);
        }
        if (orderDate == null) continue;

        // Stornierte Aufträge überspringen
        if (data['status'] == 'cancelled') continue;

        // FIX: Nur versendete Aufträge zählen
        if (data['status'] != 'shipped') continue;

        // ============================================================
        // ORDER-LEVEL FILTER (clientseitig)
        // ============================================================

        // Zeitraum-Filter
        if (filterStartDate != null && orderDate.isBefore(filterStartDate)) continue;
        if (filterEndDate != null && orderDate.isAfter(
            DateTime(filterEndDate.year, filterEndDate.month, filterEndDate.day, 23, 59, 59)
        )) continue;

        // Messe-Filter (clientseitig falls Kunde serverseitig gefiltert wird)
        if (filter.selectedFairs != null && filter.selectedFairs!.isNotEmpty) {
          if (filter.selectedCustomers != null && filter.selectedCustomers!.isNotEmpty) {
            final fairData = data['fair'] as Map<String, dynamic>?;
            final fairId = fairData?['id']?.toString();
            if (fairId == null || !filter.selectedFairs!.contains(fairId)) continue;
          }
        }

        // Kostenstellen-Filter
        if (filter.costCenters != null && filter.costCenters!.isNotEmpty) {
          final costCenterData = data['costCenter'] as Map<String, dynamic>?;
          if (costCenterData == null) continue;
          final costCenterCode = costCenterData['code']?.toString() ?? '';
          final costCenterId = costCenterData['id']?.toString() ?? '';
          if (_costCenterCodes == null) {
            await _loadCostCenterCodes();
          }
          final matched = filter.costCenters!.any((filterDocId) {
            final resolvedCode = _costCenterCodes?[filterDocId];
            return filterDocId == costCenterId ||
                filterDocId == costCenterCode ||
                (resolvedCode != null && resolvedCode == costCenterCode);
          });
          if (!matched) continue;
        }

        // Bestellart-Filter
        if (filter.distributionChannels != null && filter.distributionChannels!.isNotEmpty) {
          final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
          final distChannel = metadata['distributionChannel'] as Map<String, dynamic>?;
          if (distChannel == null) continue;
          final channelName = distChannel['name']?.toString() ?? '';
          final channelId = distChannel['id']?.toString() ?? '';
          if (_distributionChannelNames == null) {
            await _loadDistributionChannelNames();
          }
          final matched = filter.distributionChannels!.any((filterDocId) {
            final resolvedName = _distributionChannelNames?[filterDocId];
            return filterDocId == channelId ||
                filterDocId == channelName ||
                (resolvedName != null && resolvedName == channelName);
          });
          if (!matched) continue;
        }

        // Länder-Filter
        if (filter.countries != null && filter.countries!.isNotEmpty) {
          final customer = data['customer'] as Map<String, dynamic>? ?? {};
          final countryCode = customer['countryCode']?.toString() ??
              customer['country']?.toString() ?? '';
          if (!filter.countries!.contains(countryCode)) continue;
        }

        // ============================================================
        // ITEM-LEVEL VERARBEITUNG
        // ============================================================

        final customer = data['customer'] as Map<String, dynamic>? ?? {};
        final countryCode = customer['countryCode']?.toString() ??
            customer['country']?.toString() ?? 'XX';
        final country = Countries.getCountryByCode(countryCode);

        final items = data['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) continue;

        // FIX: Umsatz aus calculations statt aus qty * price_per_unit
        final calculations = data['calculations'] as Map<String, dynamic>? ?? {};
        final orderSubtotal = (calculations['subtotal'] as num?)?.toDouble() ?? 0;
        final orderTotal = (calculations['total'] as num?)?.toDouble() ?? 0;

        bool hasMatchingItems = false;
        int orderItemCount = 0;

        for (var item in items) {
          final itemData = item as Map<String, dynamic>;

          // Item-Filter prüfen
          if (!_itemMatchesFilter(itemData, filter)) continue;
          hasMatchingItems = true;

          final quantity = (itemData['quantity'] as num?)?.toInt() ?? 0;
          final pricePerUnit = (itemData['price_per_unit'] as num?)?.toDouble() ?? 0;
          final itemRevenue = quantity * pricePerUnit;
          final volumePerUnit = (itemData['volume_per_unit'] as num?)?.toDouble() ?? 0;
          final itemVolume = quantity * volumePerUnit; // m³ pro Item

          final woodCode = itemData['wood_code']?.toString() ?? '';
          final woodName = itemData['wood_name']?.toString() ?? 'Unbekannt';
          final instrumentCode = itemData['instrument_code']?.toString() ?? '';
          final instrumentName = itemData['instrument_name']?.toString() ?? 'Unbekannt';
          final partCode = itemData['part_code']?.toString() ?? '';
          final partName = itemData['part_name']?.toString() ?? 'Unbekannt';
          final hasThermal = itemData['has_thermal_treatment'] == true;

          orderItemCount++;
          totalItemCount++;

          // Thermo-Stats
          if (hasThermal) {
            thermoItemCount++;
            thermoRevenue += itemRevenue;
          }

          // Holzart-Stats — NEU: mit Volume
          if (woodCode.isNotEmpty) {
            if (!woodTypeStats.containsKey(woodCode)) {
              woodTypeStats[woodCode] = WoodTypeStats(
                woodCode: woodCode,
                woodName: woodName,
                revenue: 0,
                itemCount: 0,
                quantity: 0,
                volume: 0,
              );
            }
            woodTypeStats[woodCode] = woodTypeStats[woodCode]!.copyWithAdded(
              addRevenue: itemRevenue,
              addItems: 1,
              addQuantity: quantity,
              addVolume: itemVolume,
            );
          }

          // Produkt-Kombination Stats
          if (instrumentCode.isNotEmpty && partCode.isNotEmpty) {
            final comboKey = '${instrumentCode}_$partCode';
            if (!productCombos.containsKey(comboKey)) {
              productCombos[comboKey] = ProductComboStats(
                instrumentCode: instrumentCode,
                instrumentName: instrumentName,
                partCode: partCode,
                partName: partName,
                revenue: 0,
                quantity: 0,
              );
            }
            productCombos[comboKey] = productCombos[comboKey]!.copyWithAdded(
              addRevenue: itemRevenue,
              addQuantity: quantity,
            );
          }
        }

        if (!hasMatchingItems) continue;

        // Betrags-Filter auf Warenwert prüfen
        if (filter.minAmount != null && orderSubtotal < filter.minAmount!) continue;
        if (filter.maxAmount != null && orderSubtotal > filter.maxAmount!) continue;

        // Order zählen — mit BEIDEN Umsatz-Werten
        orderCount++;
        totalRevenue += orderSubtotal;
        totalRevenueGross += orderTotal;

        // Zeitraum-Umsätze
        if (orderDate.isAfter(currentYearStart) || orderDate.isAtSameMomentAs(currentYearStart)) {
          yearRevenue += orderSubtotal;
          yearRevenueGross += orderTotal;
        }
        if (orderDate.isAfter(currentMonthStart) || orderDate.isAtSameMomentAs(currentMonthStart)) {
          monthRevenue += orderSubtotal;
          monthRevenueGross += orderTotal;
        }
        if (orderDate.isAfter(previousYearStart) && orderDate.isBefore(previousYearEnd)) {
          previousYearRevenue += orderSubtotal;
          previousYearRevenueGross += orderTotal;
        }
        if (orderDate.isAfter(previousMonthStart) && orderDate.isBefore(previousMonthEnd)) {
          previousMonthRevenue += orderSubtotal;
          previousMonthRevenueGross += orderTotal;
        }

        // Monatliche Umsätze
        final monthKey = '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}';
        monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + orderSubtotal;
        monthlyRevenueGross[monthKey] = (monthlyRevenueGross[monthKey] ?? 0) + orderTotal;

        // Länder-Stats
        if (!countryStats.containsKey(countryCode)) {
          countryStats[countryCode] = CountryStats(
            countryCode: countryCode,
            countryName: country.name,
            revenue: 0,
            revenueGross: 0,
            orderCount: 0,
            itemCount: 0,
          );
        }
        countryStats[countryCode] = countryStats[countryCode]!.copyWithAdded(
          addRevenue: orderSubtotal,
          addRevenueGross: orderTotal,
          addOrders: 1,
          addItems: orderItemCount,
        );
      }

      // Top 10 Produkt-Kombis sortieren
      final sortedCombos = productCombos.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      return SalesAnalytics(
        revenue: RevenueStats(
          totalRevenue: totalRevenue,
          yearRevenue: yearRevenue,
          monthRevenue: monthRevenue,
          previousYearRevenue: previousYearRevenue,
          previousMonthRevenue: previousMonthRevenue,
          monthlyRevenue: monthlyRevenue,
          totalRevenueGross: totalRevenueGross,
          yearRevenueGross: yearRevenueGross,
          monthRevenueGross: monthRevenueGross,
          previousYearRevenueGross: previousYearRevenueGross,
          previousMonthRevenueGross: previousMonthRevenueGross,
          monthlyRevenueGross: monthlyRevenueGross,
        ),
        orderCount: orderCount,
        averageOrderValue: orderCount > 0 ? totalRevenue / orderCount : 0,
        averageOrderValueGross: orderCount > 0 ? totalRevenueGross / orderCount : 0,
        thermoStats: ThermoStats(
          thermoItemCount: thermoItemCount,
          totalItemCount: totalItemCount,
          thermoRevenue: thermoRevenue,
          totalRevenue: totalRevenue,
        ),
        countryStats: countryStats,
        woodTypeStats: woodTypeStats,
        topProductCombos: sortedCombos.take(10).toList(),
      );
    });
  }

  bool _itemMatchesFilter(Map<String, dynamic> item, SalesFilter filter) {
    final woodCode = item['wood_code']?.toString();
    final qualityCode = item['quality_code']?.toString();
    final partCode = item['part_code']?.toString();
    final instrumentCode = item['instrument_code']?.toString();
    final productId = item['product_id']?.toString();

    if (filter.woodTypes != null && filter.woodTypes!.isNotEmpty) {
      if (woodCode == null || !filter.woodTypes!.contains(woodCode)) return false;
    }
    if (filter.qualities != null && filter.qualities!.isNotEmpty) {
      if (qualityCode == null || !filter.qualities!.contains(qualityCode)) return false;
    }
    if (filter.parts != null && filter.parts!.isNotEmpty) {
      if (partCode == null || !filter.parts!.contains(partCode)) return false;
    }
    if (filter.instruments != null && filter.instruments!.isNotEmpty) {
      if (instrumentCode == null || !filter.instruments!.contains(instrumentCode)) return false;
    }
    if (filter.selectedProducts != null && filter.selectedProducts!.isNotEmpty) {
      if (productId == null || !filter.selectedProducts!.contains(productId)) return false;
    }

    return true;
  }
}