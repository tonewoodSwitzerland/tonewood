// lib/analytics/sales/models/sales_analytics_models.dart

/// Haupt-Statistik-Container für die Übersicht
class SalesAnalytics {
  final RevenueStats revenue;
  final int orderCount;
  final double averageOrderValue;
  final ThermoStats thermoStats;
  final Map<String, CountryStats> countryStats;
  final Map<String, WoodTypeStats> woodTypeStats;
  final List<ProductComboStats> topProductCombos;

  SalesAnalytics({
    required this.revenue,
    required this.orderCount,
    required this.averageOrderValue,
    required this.thermoStats,
    required this.countryStats,
    required this.woodTypeStats,
    required this.topProductCombos,
  });

  factory SalesAnalytics.empty() => SalesAnalytics(
    revenue: RevenueStats.empty(),
    orderCount: 0,
    averageOrderValue: 0,
    thermoStats: ThermoStats.empty(),
    countryStats: {},
    woodTypeStats: {},
    topProductCombos: [],
  );
}

/// Umsatz-Statistiken
class RevenueStats {
  final double totalRevenue;
  final double yearRevenue;
  final double monthRevenue;
  final double previousYearRevenue;
  final double previousMonthRevenue;
  final Map<String, double> monthlyRevenue; // NEU: Monatliche Umsätze

  RevenueStats({
    required this.totalRevenue,
    required this.yearRevenue,
    required this.monthRevenue,
    required this.previousYearRevenue,
    required this.previousMonthRevenue,
    this.monthlyRevenue = const {},
  });

  factory RevenueStats.empty() => RevenueStats(
    totalRevenue: 0,
    yearRevenue: 0,
    monthRevenue: 0,
    previousYearRevenue: 0,
    previousMonthRevenue: 0,
    monthlyRevenue: {},
  );

  /// Prozentuale Veränderung zum Vorjahr
  double get yearChangePercent {
    if (previousYearRevenue == 0) return 0;
    return ((yearRevenue - previousYearRevenue) / previousYearRevenue) * 100;
  }

  /// Prozentuale Veränderung zum Vormonat
  double get monthChangePercent {
    if (previousMonthRevenue == 0) return 0;
    return ((monthRevenue - previousMonthRevenue) / previousMonthRevenue) * 100;
  }
}

/// Thermo-Behandlung Statistiken
class ThermoStats {
  final int thermoItemCount;
  final int totalItemCount;
  final double thermoRevenue;
  final double totalRevenue;

  ThermoStats({
    required this.thermoItemCount,
    required this.totalItemCount,
    required this.thermoRevenue,
    required this.totalRevenue,
  });

  factory ThermoStats.empty() => ThermoStats(
    thermoItemCount: 0,
    totalItemCount: 0,
    thermoRevenue: 0,
    totalRevenue: 0,
  );

  /// Anteil Thermo-Artikel in Prozent
  double get itemSharePercent {
    if (totalItemCount == 0) return 0;
    return (thermoItemCount / totalItemCount) * 100;
  }

  /// Anteil Thermo-Umsatz in Prozent
  double get revenueSharePercent {
    if (totalRevenue == 0) return 0;
    return (thermoRevenue / totalRevenue) * 100;
  }
}

/// Länder-Statistiken
class CountryStats {
  final String countryCode;
  final String countryName;
  final double revenue;
  final int orderCount;
  final int itemCount;

  CountryStats({
    required this.countryCode,
    required this.countryName,
    required this.revenue,
    required this.orderCount,
    required this.itemCount,
  });

  /// Für die Aggregation
  CountryStats copyWithAdded({
    double addRevenue = 0,
    int addOrders = 0,
    int addItems = 0,
  }) {
    return CountryStats(
      countryCode: countryCode,
      countryName: countryName,
      revenue: revenue + addRevenue,
      orderCount: orderCount + addOrders,
      itemCount: itemCount + addItems,
    );
  }
}

/// Holzart-Statistiken
class WoodTypeStats {
  final String woodCode;
  final String woodName;
  final double revenue;
  final int itemCount;
  final int quantity;

  WoodTypeStats({
    required this.woodCode,
    required this.woodName,
    required this.revenue,
    required this.itemCount,
    required this.quantity,
  });

  WoodTypeStats copyWithAdded({
    double addRevenue = 0,
    int addItems = 0,
    int addQuantity = 0,
  }) {
    return WoodTypeStats(
      woodCode: woodCode,
      woodName: woodName,
      revenue: revenue + addRevenue,
      itemCount: itemCount + addItems,
      quantity: quantity + addQuantity,
    );
  }
}

/// Produkt-Kombination (Instrument + Bauteil)
class ProductComboStats {
  final String instrumentCode;
  final String instrumentName;
  final String partCode;
  final String partName;
  final double revenue;
  final int quantity;

  ProductComboStats({
    required this.instrumentCode,
    required this.instrumentName,
    required this.partCode,
    required this.partName,
    required this.revenue,
    required this.quantity,
  });

  /// Kombinations-Key für Gruppierung
  String get comboKey => '${instrumentCode}_$partCode';

  /// Anzeigename (z.B. "Steelstring Gitarre - Decke")
  String get displayName => '$instrumentName - $partName';

  ProductComboStats copyWithAdded({
    double addRevenue = 0,
    int addQuantity = 0,
  }) {
    return ProductComboStats(
      instrumentCode: instrumentCode,
      instrumentName: instrumentName,
      partCode: partCode,
      partName: partName,
      revenue: revenue + addRevenue,
      quantity: quantity + addQuantity,
    );
  }
}