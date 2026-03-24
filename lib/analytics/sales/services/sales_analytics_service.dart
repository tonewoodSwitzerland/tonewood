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

      // Aggregations-Variablen — Warenwert (net_amount, nach Rabatten)
      double totalRevenue = 0;
      double yearRevenue = 0;
      double monthRevenue = 0;
      double previousYearRevenue = 0;
      double previousMonthRevenue = 0;
      Map<String, double> monthlyRevenue = {};

      // Aggregations-Variablen — Rabatt (subtotal - net_amount)
      double totalDiscount = 0;
      double yearDiscount = 0;
      double monthDiscount = 0;

      double totalGratisValue = 0;
      double yearGratisValue = 0;
      double monthGratisValue = 0;

      // Aggregations-Variablen — Fracht
      double totalFreight = 0;
      double yearFreight = 0;
      double monthFreight = 0;

      // Aggregations-Variablen — Phytosanitary
      double totalPhytosanitary = 0;
      double yearPhytosanitary = 0;
      double monthPhytosanitary = 0;

      // Aggregations-Variablen — MwSt
      double totalVat = 0;
      double yearVat = 0;
      double monthVat = 0;

      // Aggregations-Variablen — Abschläge & Zuschläge
      double totalDeductions = 0;
      double yearDeductions = 0;
      double monthDeductions = 0;
      double totalSurcharges = 0;
      double yearSurcharges = 0;
      double monthSurcharges = 0;

      // Aggregations-Variablen — Dienstleistungen
      double totalServiceRevenue = 0;
      double yearServiceRevenue = 0;
      double monthServiceRevenue = 0;

      // Aggregations-Variablen — Brutto/Gesamtbetrag (total)
      double totalRevenueGross = 0;
      double yearRevenueGross = 0;
      double monthRevenueGross = 0;
      double previousYearRevenueGross = 0;
      double previousMonthRevenueGross = 0;
      Map<String, double> monthlyRevenueGross = {};

      int orderCount = 0;
      Map<String, int> monthlyOrderCount = {};
      int yearOrderCount = 0;
      int monthOrderCount = 0;
      int previousYearOrderCount = 0;
      int previousMonthOrderCount = 0;

      final List<OrderSummary> orders = []; // Detailtabelle

      int thermoItemCount = 0;
      int totalItemCount = 0;
      double thermoRevenue = 0;

      int serviceItemCount = 0;
      double serviceRevenue = 0;
      List<Map<String, dynamic>> thermoDetails = [];
      List<Map<String, dynamic>> serviceDetails = [];

      Map<String, CountryStats> countryStats = {};
      Map<String, WoodTypeStats> woodTypeStats = {};
      Map<String, ProductComboStats> productCombos = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Order-Datum parsen
        // Auswertungsdatum: shippedAt bevorzugt, Fallback auf orderDate
        final shippedAtRaw = data['shippedAt'];
        final orderDateRaw = data['orderDate'];
        DateTime? relevantDate;
        if (shippedAtRaw is Timestamp) {
          relevantDate = shippedAtRaw.toDate();
        } else if (orderDateRaw is Timestamp) {
          relevantDate = orderDateRaw.toDate();
        } else if (orderDateRaw is String) {
          relevantDate = DateTime.tryParse(orderDateRaw);
        }
        // orderDate für Detailinfos (Thermo/Service History-Einträge)
        DateTime? orderDate;
        if (orderDateRaw is Timestamp) {
          orderDate = orderDateRaw.toDate();
        } else if (orderDateRaw is String) {
          orderDate = DateTime.tryParse(orderDateRaw);
        }
        if (relevantDate == null) continue;

        // Stornierte Aufträge überspringen
        if (data['status'] == 'cancelled') continue;

        // FIX: Nur versendete Aufträge zählen
        if (data['status'] != 'shipped') continue;

        // ============================================================
        // ORDER-LEVEL FILTER (clientseitig)
        // ============================================================

        // Zeitraum-Filter
        if (filterStartDate != null && relevantDate.isBefore(filterStartDate)) continue;
        if (filterEndDate != null && relevantDate.isAfter(
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

        // Warenwert item-level — identisch zum CSV-Export
        final calculations = data['calculations'] as Map<String, dynamic>? ?? {};
        final orderTotal = (calculations['total'] as num?)?.toDouble() ?? 0;
        final orderFreight = (calculations['freight'] as num?)?.toDouble() ?? 0;
        final orderPhytosanitary = (calculations['phytosanitary'] as num?)?.toDouble() ?? 0;
        final orderVat = (calculations['vat_amount'] as num?)?.toDouble() ?? 0;
        final orderDeductions = (calculations['total_deductions'] as num?)?.toDouble() ?? 0;
        final orderSurcharges = (calculations['total_surcharges'] as num?)?.toDouble() ?? 0;
        final orderTotalDiscountAmount = (calculations['total_discount_amount'] as num?)?.toDouble() ?? 0;
        double orderSubtotal = 0;
        double orderItemDiscount = 0;
        double orderServiceRev = 0;
        double orderGratisValue = 0;
        for (final rawItem in items) {
          final it = rawItem as Map<String, dynamic>;
          final qty      = (it['quantity']              as num?)?.toDouble() ?? 0;
          final price    = (it['custom_price_per_unit'] as num?)?.toDouble()
              ?? (it['price_per_unit']                  as num?)?.toDouble() ?? 0;
          final disc     = it['discount'] as Map<String, dynamic>?;
          final discPct  = (disc?['percentage']         as num?)?.toDouble() ?? 0;
          final discAbs  = (disc?['absolute']           as num?)?.toDouble() ?? 0;
          final lineDiscount = qty * price * discPct / 100 + discAbs;

          if (it['is_service'] == true) {
            orderServiceRev += qty * price - lineDiscount;
          } else if (it['is_gratisartikel'] == true) {
            // Gratisartikel: nicht in Warenwert
            final gratisLineTotal = qty * price - lineDiscount;
            orderGratisValue += gratisLineTotal;
          } else {
            orderSubtotal     += qty * price - lineDiscount;
            orderItemDiscount += lineDiscount;
          }
        }
// Order-Level Rabatt abziehen
        final orderDiscount = orderItemDiscount + orderTotalDiscountAmount;
        orderSubtotal -= orderTotalDiscountAmount;
        totalGratisValue += orderGratisValue;





        bool hasMatchingItems = false;
        int orderItemCount = 0;

        for (var item in items) {
          final itemData = item as Map<String, dynamic>;

          // Item-Filter prüfen
          if (!_itemMatchesFilter(itemData, filter)) continue;
          hasMatchingItems = true;

          final quantity = (itemData['quantity'] as num?)?.toInt() ?? 0;
          final pricePerUnit = (itemData['custom_price_per_unit'] as num?)?.toDouble()
              ?? (itemData['price_per_unit'] as num?)?.toDouble() ?? 0;
          final itemDisc = itemData['discount'] as Map<String, dynamic>?;
          final itemDiscPct = (itemDisc?['percentage'] as num?)?.toDouble() ?? 0;
          final itemDiscAbs = (itemDisc?['absolute'] as num?)?.toDouble() ?? 0;
          // Umsatz für Stats: Gratisartikel mit 0 CHF
          final itemRevenue = (itemData['is_gratisartikel'] == true)
              ? 0.0
              : quantity * pricePerUnit
              - (quantity * pricePerUnit * itemDiscPct / 100)
              - itemDiscAbs;
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
            thermoDetails.add({
              'orderNumber': data['orderNumber'] ?? '',
              'productName': itemData['product_name']?.toString() ?? 'Unbekannt',
              'quantity': quantity,
              'revenue': itemRevenue,
              'orderDate': orderDate,
            });
          }

          // Service-Stats
          final isService = itemData['is_service'] == true;
          if (isService) {
            serviceItemCount++;
            serviceRevenue += itemRevenue;
            serviceDetails.add({
              'orderNumber': data['orderNumber'] ?? '',
              'productName': itemData['name']?.toString() ?? 'Unbekannt',
              'quantity': quantity,
              'revenue': itemRevenue,
              'orderDate': orderDate,
            });
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
        totalDiscount += orderDiscount;
        totalFreight += orderFreight;
        totalPhytosanitary += orderPhytosanitary;
        totalVat += orderVat;
        totalDeductions += orderDeductions;
        totalSurcharges += orderSurcharges;
        totalServiceRevenue += orderServiceRev;

        // Detailtabelle befüllen
        final firstName = customer['firstName'] as String? ?? '';
        final lastName = customer['lastName'] as String? ?? '';
        final company = customer['company'] as String? ?? '';
        final customerName = company.isNotEmpty ? company : '$firstName $lastName'.trim();
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        orders.add(OrderSummary(
          orderId: doc.id,
          orderNumber: data['orderNumber']?.toString() ?? '',
          customerName: customerName.isEmpty ? 'Unbekannt' : customerName,
          countryCode: countryCode,
          relevantDate: relevantDate,
          subtotal: orderSubtotal,
          total: orderTotal,
          discount: orderDiscount,
          itemCount: orderItemCount,
          currency: metadata['currency']?.toString() ?? 'CHF',
          freight: orderFreight,
          phytosanitary: orderPhytosanitary,
          serviceRevenue: orderServiceRev,
          vat: orderVat,
          deductions: orderDeductions,
          surcharges: orderSurcharges,
          netAmount: (calculations['net_amount'] as num?)?.toDouble() ?? 0,
        ));

        // Zeitraum-Umsätze + Order-Counts
        if (relevantDate.isAfter(currentYearStart) || relevantDate.isAtSameMomentAs(currentYearStart)) {
          yearRevenue += orderSubtotal;
          yearRevenueGross += orderTotal;
          yearDiscount += orderDiscount;
          yearFreight += orderFreight;
          yearPhytosanitary += orderPhytosanitary;
          yearVat += orderVat;
          yearDeductions += orderDeductions;
          yearSurcharges += orderSurcharges;
          yearServiceRevenue += orderServiceRev;
          yearOrderCount++;
          yearGratisValue += orderGratisValue;
        }
        if (relevantDate.isAfter(currentMonthStart) || relevantDate.isAtSameMomentAs(currentMonthStart)) {
          monthRevenue += orderSubtotal;
          monthRevenueGross += orderTotal;
          monthDiscount += orderDiscount;
          monthFreight += orderFreight;
          monthPhytosanitary += orderPhytosanitary;
          monthVat += orderVat;
          monthDeductions += orderDeductions;
          monthSurcharges += orderSurcharges;
          monthServiceRevenue += orderServiceRev;
          monthOrderCount++;
          monthGratisValue += orderGratisValue;
        }
        if (relevantDate.isAfter(previousYearStart) && relevantDate.isBefore(previousYearEnd)) {
          previousYearRevenue += orderSubtotal;
          previousYearRevenueGross += orderTotal;
          previousYearOrderCount++;
        }
        if (relevantDate.isAfter(previousMonthStart) && relevantDate.isBefore(previousMonthEnd)) {
          previousMonthRevenue += orderSubtotal;
          previousMonthRevenueGross += orderTotal;
          previousMonthOrderCount++;
        }

        // Monatliche Umsätze + Order-Counts
        final monthKey = '${relevantDate.year}-${relevantDate.month.toString().padLeft(2, '0')}';
        monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + orderSubtotal;
        monthlyRevenueGross[monthKey] = (monthlyRevenueGross[monthKey] ?? 0) + orderTotal;
        monthlyOrderCount[monthKey] = (monthlyOrderCount[monthKey] ?? 0) + 1;

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
          totalDiscount: totalDiscount,
          yearDiscount: yearDiscount,
          monthDiscount: monthDiscount,
          totalGratisValue: totalGratisValue,
          yearGratisValue: yearGratisValue,
          monthGratisValue: monthGratisValue,
          totalFreight: totalFreight,
          yearFreight: yearFreight,
          monthFreight: monthFreight,
          totalPhytosanitary: totalPhytosanitary,
          yearPhytosanitary: yearPhytosanitary,
          monthPhytosanitary: monthPhytosanitary,
          totalVat: totalVat,
          yearVat: yearVat,
          monthVat: monthVat,
          totalDeductions: totalDeductions,
          yearDeductions: yearDeductions,
          monthDeductions: monthDeductions,
          totalSurcharges: totalSurcharges,
          yearSurcharges: yearSurcharges,
          monthSurcharges: monthSurcharges,
          totalServiceRevenue: totalServiceRevenue,
          yearServiceRevenue: yearServiceRevenue,
          monthServiceRevenue: monthServiceRevenue,
          totalRevenueGross: totalRevenueGross,
          yearRevenueGross: yearRevenueGross,
          monthRevenueGross: monthRevenueGross,
          previousYearRevenueGross: previousYearRevenueGross,
          previousMonthRevenueGross: previousMonthRevenueGross,
          monthlyRevenueGross: monthlyRevenueGross,
          monthlyOrderCount: monthlyOrderCount,
          yearOrderCount: yearOrderCount,
          monthOrderCount: monthOrderCount,
          previousYearOrderCount: previousYearOrderCount,
          previousMonthOrderCount: previousMonthOrderCount,
        ),
        orderCount: orderCount,
        averageOrderValue: orderCount > 0 ? totalRevenue / orderCount : 0,
        averageOrderValueGross: orderCount > 0 ? totalRevenueGross / orderCount : 0,
        thermoStats: ThermoStats(
          thermoItemCount: thermoItemCount,
          totalItemCount: totalItemCount,
          thermoRevenue: thermoRevenue,
          totalRevenue: totalRevenue,
          details: thermoDetails,
        ),
        serviceStats: ServiceStats(
          serviceItemCount: serviceItemCount,
          totalItemCount: totalItemCount,
          serviceRevenue: serviceRevenue,
          totalRevenue: totalRevenue,
          details: serviceDetails,
        ),
        countryStats: countryStats,
        woodTypeStats: woodTypeStats,
        topProductCombos: sortedCombos.take(10).toList(),
        orders: orders..sort((a, b) => b.relevantDate.compareTo(a.relevantDate)),
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