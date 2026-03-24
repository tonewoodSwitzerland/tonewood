// lib/analytics/sales/models/customer_sales_stats.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Konfigurierbare Schwellenwerte für Kundensegmentierung
class CustomerSegmentConfig {
  final int vipMinOrders;
  final double vipMinYearRevenue;
  final int regularMinOrders;
  final double regularMinYearRevenue;
  final int inactiveDaysThreshold;

  const CustomerSegmentConfig({
    this.vipMinOrders = 5,
    this.vipMinYearRevenue = 5000,
    this.regularMinOrders = 3,
    this.regularMinYearRevenue = 2000,
    this.inactiveDaysThreshold = 365,
  });

  factory CustomerSegmentConfig.fromMap(Map<String, dynamic> map) {
    return CustomerSegmentConfig(
      vipMinOrders: map['vipMinOrders'] ?? 5,
      vipMinYearRevenue: (map['vipMinYearRevenue'] as num?)?.toDouble() ?? 5000,
      regularMinOrders: map['regularMinOrders'] ?? 3,
      regularMinYearRevenue: (map['regularMinYearRevenue'] as num?)?.toDouble() ?? 2000,
      inactiveDaysThreshold: map['inactiveDaysThreshold'] ?? 365,
    );
  }

  Map<String, dynamic> toMap() => {
    'vipMinOrders': vipMinOrders,
    'vipMinYearRevenue': vipMinYearRevenue,
    'regularMinOrders': regularMinOrders,
    'regularMinYearRevenue': regularMinYearRevenue,
    'inactiveDaysThreshold': inactiveDaysThreshold,
  };
}

/// Top-Produkt eines Kunden
class CustomerTopProduct {
  final String productId;
  final String productName;
  final int quantity;
  final double revenue;
  final String? instrumentCode;
  final String? instrumentName;
  final String? partCode;
  final String? partName;
  final String? woodCode;
  final String? woodName;

  CustomerTopProduct({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.revenue,
    this.instrumentCode,
    this.instrumentName,
    this.partCode,
    this.partName,
    this.woodCode,
    this.woodName,
  });

  factory CustomerTopProduct.fromMap(Map<String, dynamic> map) {
    return CustomerTopProduct(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0,
      instrumentCode: map['instrumentCode'],
      instrumentName: map['instrumentName'],
      partCode: map['partCode'],
      partName: map['partName'],
      woodCode: map['woodCode'],
      woodName: map['woodName'],
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'revenue': revenue,
    if (instrumentCode != null) 'instrumentCode': instrumentCode,
    if (instrumentName != null) 'instrumentName': instrumentName,
    if (partCode != null) 'partCode': partCode,
    if (partName != null) 'partName': partName,
    if (woodCode != null) 'woodCode': woodCode,
    if (woodName != null) 'woodName': woodName,
  };
}

/// Vorberechnete Verkaufsstatistiken pro Kunde
class CustomerSalesStats {
  // === LIFETIME STATS ===
  final double totalRevenue;
  final double totalRevenueGross;
  final double totalDiscount;
  final int totalOrders;
  final int totalItems;
  final int totalQuantity;

  // === ZEITRAUM-STATS ===
  final double yearRevenue;
  final double yearRevenueGross;
  final int yearOrders;
  final double previousYearRevenue;
  final double previousYearRevenueGross;
  final int previousYearOrders;

  // === MONATLICH ===
  final Map<String, double> monthlyRevenue; // 'YYYY-MM' → Umsatz
  final Map<String, int> monthlyOrders;     // 'YYYY-MM' → Anzahl

  // === DURCHSCHNITTE ===
  final double averageOrderValue;
  final double averageOrderValueGross;

  // === BESTELLVERHALTEN ===
  final DateTime? firstOrderDate;
  final DateTime? lastOrderDate;
  final double averageOrderFrequencyDays;
  final List<String> orderMonths; // Für Saisonalität

  // === TOP-PRODUKTE (Top 5) ===
  final List<CustomerTopProduct> topProducts;

  // === HOLZARTEN-VERTEILUNG ===
  final Map<String, double> woodTypeRevenue;
  final Map<String, int> woodTypeQuantity;
  final Map<String, double> woodTypeVolume;

  // === INSTRUMENTE-VERTEILUNG ===
  final Map<String, double> instrumentRevenue;
  final Map<String, int> instrumentQuantity;

  // === META ===
  final DateTime? lastUpdated;
  final String? lastOrderId;

  CustomerSalesStats({
    this.totalRevenue = 0,
    this.totalRevenueGross = 0,
    this.totalDiscount = 0,
    this.totalOrders = 0,
    this.totalItems = 0,
    this.totalQuantity = 0,
    this.yearRevenue = 0,
    this.yearRevenueGross = 0,
    this.yearOrders = 0,
    this.previousYearRevenue = 0,
    this.previousYearRevenueGross = 0,
    this.previousYearOrders = 0,
    this.monthlyRevenue = const {},
    this.monthlyOrders = const {},
    this.averageOrderValue = 0,
    this.averageOrderValueGross = 0,
    this.firstOrderDate,
    this.lastOrderDate,
    this.averageOrderFrequencyDays = 0,
    this.orderMonths = const [],
    this.topProducts = const [],
    this.woodTypeRevenue = const {},
    this.woodTypeQuantity = const {},
    this.woodTypeVolume = const {},
    this.instrumentRevenue = const {},
    this.instrumentQuantity = const {},
    this.lastUpdated,
    this.lastOrderId,
  });

  factory CustomerSalesStats.empty() => CustomerSalesStats();

  // === BERECHNETE FELDER ===

  double get yearChangePercent {
    if (previousYearRevenue == 0) return 0;
    return ((yearRevenue - previousYearRevenue) / previousYearRevenue) * 100;
  }

  double get yearChangePercentGross {
    if (previousYearRevenueGross == 0) return 0;
    return ((yearRevenueGross - previousYearRevenueGross) / previousYearRevenueGross) * 100;
  }

  int get yearOrderChangePercent {
    if (previousYearOrders == 0) return 0;
    return (((yearOrders - previousYearOrders) / previousYearOrders) * 100).round();
  }

  int get daysSinceLastOrder {
    if (lastOrderDate == null) return -1;
    return DateTime.now().difference(lastOrderDate!).inDays;
  }

  int get customerLifetimeDays {
    if (firstOrderDate == null) return 0;
    return DateTime.now().difference(firstOrderDate!).inDays;
  }

  /// Kundensegment basierend auf konfigurierbaren Schwellenwerten
  String getSegment(CustomerSegmentConfig config) {
    if (totalOrders >= config.vipMinOrders &&
        yearRevenue >= config.vipMinYearRevenue) {
      return 'VIP';
    }
    if (totalOrders >= config.regularMinOrders &&
        yearRevenue >= config.regularMinYearRevenue) {
      return 'Stammkunde';
    }
    if (daysSinceLastOrder > config.inactiveDaysThreshold) {
      return 'Inaktiv';
    }
    if (totalOrders == 1) {
      return 'Neukunde';
    }
    return 'Gelegentlich';
  }

  // === SERIALIZATION ===

  factory CustomerSalesStats.fromMap(Map<String, dynamic> map) {
    return CustomerSalesStats(
      totalRevenue: (map['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalRevenueGross: (map['totalRevenueGross'] as num?)?.toDouble() ?? 0,
      totalDiscount: (map['totalDiscount'] as num?)?.toDouble() ?? 0,
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
      totalItems: (map['totalItems'] as num?)?.toInt() ?? 0,
      totalQuantity: (map['totalQuantity'] as num?)?.toInt() ?? 0,
      yearRevenue: (map['yearRevenue'] as num?)?.toDouble() ?? 0,
      yearRevenueGross: (map['yearRevenueGross'] as num?)?.toDouble() ?? 0,
      yearOrders: (map['yearOrders'] as num?)?.toInt() ?? 0,
      previousYearRevenue: (map['previousYearRevenue'] as num?)?.toDouble() ?? 0,
      previousYearRevenueGross: (map['previousYearRevenueGross'] as num?)?.toDouble() ?? 0,
      previousYearOrders: (map['previousYearOrders'] as num?)?.toInt() ?? 0,
      monthlyRevenue: _parseStringDoubleMap(map['monthlyRevenue']),
      monthlyOrders: _parseStringIntMap(map['monthlyOrders']),
      averageOrderValue: (map['averageOrderValue'] as num?)?.toDouble() ?? 0,
      averageOrderValueGross: (map['averageOrderValueGross'] as num?)?.toDouble() ?? 0,
      firstOrderDate: _parseDateTime(map['firstOrderDate']),
      lastOrderDate: _parseDateTime(map['lastOrderDate']),
      averageOrderFrequencyDays: (map['averageOrderFrequencyDays'] as num?)?.toDouble() ?? 0,
      orderMonths: List<String>.from(map['orderMonths'] ?? []),
      topProducts: (map['topProducts'] as List<dynamic>?)
          ?.map((p) => CustomerTopProduct.fromMap(Map<String, dynamic>.from(p)))
          .toList() ?? [],
      woodTypeRevenue: _parseStringDoubleMap(map['woodTypeRevenue']),
      woodTypeQuantity: _parseStringIntMap(map['woodTypeQuantity']),
      woodTypeVolume: _parseStringDoubleMap(map['woodTypeVolume']),
      instrumentRevenue: _parseStringDoubleMap(map['instrumentRevenue']),
      instrumentQuantity: _parseStringIntMap(map['instrumentQuantity']),
      lastUpdated: _parseDateTime(map['lastUpdated']),
      lastOrderId: map['lastOrderId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'totalRevenue': totalRevenue,
    'totalRevenueGross': totalRevenueGross,
    'totalDiscount': totalDiscount,
    'totalOrders': totalOrders,
    'totalItems': totalItems,
    'totalQuantity': totalQuantity,
    'yearRevenue': yearRevenue,
    'yearRevenueGross': yearRevenueGross,
    'yearOrders': yearOrders,
    'previousYearRevenue': previousYearRevenue,
    'previousYearRevenueGross': previousYearRevenueGross,
    'previousYearOrders': previousYearOrders,
    'monthlyRevenue': monthlyRevenue,
    'monthlyOrders': monthlyOrders,
    'averageOrderValue': averageOrderValue,
    'averageOrderValueGross': averageOrderValueGross,
    'firstOrderDate': firstOrderDate != null ? Timestamp.fromDate(firstOrderDate!) : null,
    'lastOrderDate': lastOrderDate != null ? Timestamp.fromDate(lastOrderDate!) : null,
    'averageOrderFrequencyDays': averageOrderFrequencyDays,
    'orderMonths': orderMonths,
    'topProducts': topProducts.map((p) => p.toMap()).toList(),
    'woodTypeRevenue': woodTypeRevenue,
    'woodTypeQuantity': woodTypeQuantity,
    'woodTypeVolume': woodTypeVolume,
    'instrumentRevenue': instrumentRevenue,
    'instrumentQuantity': instrumentQuantity,
    'lastUpdated': FieldValue.serverTimestamp(),
    'lastOrderId': lastOrderId,
  };

  // === HELPERS ===

  static Map<String, double> _parseStringDoubleMap(dynamic raw) {
    if (raw == null) return {};
    final map = Map<String, dynamic>.from(raw);
    return map.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0));
  }

  static Map<String, int> _parseStringIntMap(dynamic raw) {
    if (raw == null) return {};
    final map = Map<String, dynamic>.from(raw);
    return map.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
