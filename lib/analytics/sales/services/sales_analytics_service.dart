// lib/analytics/sales/services/sales_analytics_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/countries.dart';
import '../models/sales_filter.dart';
import '../models/sales_analytics_models.dart';

class SalesAnalyticsService {
  final _db = FirebaseFirestore.instance;

  /// Haupt-Stream für alle Analytics-Daten
  Stream<SalesAnalytics> getAnalyticsStream(SalesFilter filter) {
    Query query = _db.collection('orders');

    // Filter anwenden
    if (filter.selectedCustomers != null && filter.selectedCustomers!.isNotEmpty) {
      query = query.where('customer.id', whereIn: filter.selectedCustomers);
    }
    if (filter.selectedFairs != null && filter.selectedFairs!.isNotEmpty) {
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

      // Aggregations-Variablen
      double totalRevenue = 0;
      double yearRevenue = 0;
      double monthRevenue = 0;
      double previousYearRevenue = 0;
      double previousMonthRevenue = 0;
      int orderCount = 0;

      // NEU: Monatliche Umsätze für die letzten 12 Monate
      Map<String, double> monthlyRevenue = {};

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

        // Kunden- und Länder-Daten
        final customer = data['customer'] as Map<String, dynamic>? ?? {};
        final countryCode = customer['countryCode']?.toString() ??
            customer['country']?.toString() ?? 'XX';
        final country = Countries.getCountryByCode(countryCode);

        // Items verarbeiten
        final items = data['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) continue;

        // Prüfe Item-Filter
        bool hasMatchingItems = false;
        double orderRevenue = 0;
        int orderItemCount = 0;

        for (var item in items) {
          final itemData = item as Map<String, dynamic>;

          // Filter prüfen
          if (!_itemMatchesFilter(itemData, filter)) continue;
          hasMatchingItems = true;

          final quantity = (itemData['quantity'] as num?)?.toInt() ?? 0;
          final pricePerUnit = (itemData['price_per_unit'] as num?)?.toDouble() ?? 0;
          final itemRevenue = quantity * pricePerUnit;

          final woodCode = itemData['wood_code']?.toString() ?? '';
          final woodName = itemData['wood_name']?.toString() ?? 'Unbekannt';
          final instrumentCode = itemData['instrument_code']?.toString() ?? '';
          final instrumentName = itemData['instrument_name']?.toString() ?? 'Unbekannt';
          final partCode = itemData['part_code']?.toString() ?? '';
          final partName = itemData['part_name']?.toString() ?? 'Unbekannt';
          final hasThermal = itemData['has_thermal_treatment'] == true;

          orderRevenue += itemRevenue;
          orderItemCount++;
          totalItemCount++;

          // Thermo-Stats
          if (hasThermal) {
            thermoItemCount++;
            thermoRevenue += itemRevenue;
          }

          // Holzart-Stats
          if (woodCode.isNotEmpty) {
            if (!woodTypeStats.containsKey(woodCode)) {
              woodTypeStats[woodCode] = WoodTypeStats(
                woodCode: woodCode,
                woodName: woodName,
                revenue: 0,
                itemCount: 0,
                quantity: 0,
              );
            }
            woodTypeStats[woodCode] = woodTypeStats[woodCode]!.copyWithAdded(
              addRevenue: itemRevenue,
              addItems: 1,
              addQuantity: quantity,
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

        // Betrags-Filter prüfen
        if (filter.minAmount != null && orderRevenue < filter.minAmount!) continue;
        if (filter.maxAmount != null && orderRevenue > filter.maxAmount!) continue;

        // Order zählen
        orderCount++;
        totalRevenue += orderRevenue;

        // Zeitraum-Umsätze
        if (orderDate.isAfter(currentYearStart) || orderDate.isAtSameMomentAs(currentYearStart)) {
          yearRevenue += orderRevenue;
        }
        if (orderDate.isAfter(currentMonthStart) || orderDate.isAtSameMomentAs(currentMonthStart)) {
          monthRevenue += orderRevenue;
        }
        if (orderDate.isAfter(previousYearStart) && orderDate.isBefore(previousYearEnd)) {
          previousYearRevenue += orderRevenue;
        }
        if (orderDate.isAfter(previousMonthStart) && orderDate.isBefore(previousMonthEnd)) {
          previousMonthRevenue += orderRevenue;
        }

        // NEU: Monatliche Umsätze aggregieren (letzte 24 Monate)
        final monthKey = '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}';
        monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + orderRevenue;

        // Länder-Stats
        if (!countryStats.containsKey(countryCode)) {
          countryStats[countryCode] = CountryStats(
            countryCode: countryCode,
            countryName: country.name,
            revenue: 0,
            orderCount: 0,
            itemCount: 0,
          );
        }
        countryStats[countryCode] = countryStats[countryCode]!.copyWithAdded(
          addRevenue: orderRevenue,
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
        ),
        orderCount: orderCount,
        averageOrderValue: orderCount > 0 ? totalRevenue / orderCount : 0,
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