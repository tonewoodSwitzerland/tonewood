// lib/analytics/sales/models/sales_analytics_models.dart

/// Haupt-Statistik-Container für die Übersicht
class SalesAnalytics {
  final RevenueStats revenue;
  final int orderCount;
  final double averageOrderValue;
  final double averageOrderValueGross;
  final ThermoStats thermoStats;
  final Map<String, CountryStats> countryStats;
  final Map<String, WoodTypeStats> woodTypeStats;
  final List<ProductComboStats> topProductCombos;

  SalesAnalytics({
    required this.revenue,
    required this.orderCount,
    required this.averageOrderValue,
    this.averageOrderValueGross = 0,
    required this.thermoStats,
    required this.countryStats,
    required this.woodTypeStats,
    required this.topProductCombos,
  });

  factory SalesAnalytics.empty() => SalesAnalytics(
    revenue: RevenueStats.empty(),
    orderCount: 0,
    averageOrderValue: 0,
    averageOrderValueGross: 0,
    thermoStats: ThermoStats.empty(),
    countryStats: {},
    woodTypeStats: {},
    topProductCombos: [],
  );
}

/// Umsatz-Statistiken
/// Jeder Wert existiert in zwei Varianten:
///   - "normal" = Warenwert / subtotal (reine Ware nach Rabatten)
///   - "gross"  = Gesamtbetrag / total (inkl. Versand, MwSt, Zuschläge)
class RevenueStats {
  // --- Warenwert (subtotal) ---
  final double totalRevenue;
  final double yearRevenue;
  final double monthRevenue;
  final double previousYearRevenue;
  final double previousMonthRevenue;
  final Map<String, double> monthlyRevenue;

  // --- Gesamtbetrag / Brutto (total) ---
  final double totalRevenueGross;
  final double yearRevenueGross;
  final double monthRevenueGross;
  final double previousYearRevenueGross;
  final double previousMonthRevenueGross;
  final Map<String, double> monthlyRevenueGross;

  RevenueStats({
    required this.totalRevenue,
    required this.yearRevenue,
    required this.monthRevenue,
    required this.previousYearRevenue,
    required this.previousMonthRevenue,
    this.monthlyRevenue = const {},
    this.totalRevenueGross = 0,
    this.yearRevenueGross = 0,
    this.monthRevenueGross = 0,
    this.previousYearRevenueGross = 0,
    this.previousMonthRevenueGross = 0,
    this.monthlyRevenueGross = const {},
  });

  factory RevenueStats.empty() => RevenueStats(
    totalRevenue: 0,
    yearRevenue: 0,
    monthRevenue: 0,
    previousYearRevenue: 0,
    previousMonthRevenue: 0,
    monthlyRevenue: {},
    totalRevenueGross: 0,
    yearRevenueGross: 0,
    monthRevenueGross: 0,
    previousYearRevenueGross: 0,
    previousMonthRevenueGross: 0,
    monthlyRevenueGross: {},
  );

  double get yearChangePercent {
    if (previousYearRevenue == 0) return 0;
    return ((yearRevenue - previousYearRevenue) / previousYearRevenue) * 100;
  }

  double get monthChangePercent {
    if (previousMonthRevenue == 0) return 0;
    return ((monthRevenue - previousMonthRevenue) / previousMonthRevenue) * 100;
  }

  double get yearChangePercentGross {
    if (previousYearRevenueGross == 0) return 0;
    return ((yearRevenueGross - previousYearRevenueGross) / previousYearRevenueGross) * 100;
  }

  double get monthChangePercentGross {
    if (previousMonthRevenueGross == 0) return 0;
    return ((monthRevenueGross - previousMonthRevenueGross) / previousMonthRevenueGross) * 100;
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

  double get itemSharePercent {
    if (totalItemCount == 0) return 0;
    return (thermoItemCount / totalItemCount) * 100;
  }

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
  final double revenueGross;
  final int orderCount;
  final int itemCount;

  CountryStats({
    required this.countryCode,
    required this.countryName,
    required this.revenue,
    this.revenueGross = 0,
    required this.orderCount,
    required this.itemCount,
  });

  CountryStats copyWithAdded({
    double addRevenue = 0,
    double addRevenueGross = 0,
    int addOrders = 0,
    int addItems = 0,
  }) {
    return CountryStats(
      countryCode: countryCode,
      countryName: countryName,
      revenue: revenue + addRevenue,
      revenueGross: revenueGross + addRevenueGross,
      orderCount: orderCount + addOrders,
      itemCount: itemCount + addItems,
    );
  }
}

/// Holzart-Statistiken — mit volume (m³)
class WoodTypeStats {
  final String woodCode;
  final String woodName;
  final double revenue;
  final int itemCount;
  final int quantity;
  final double volume; // Gesamtvolumen in m³

  WoodTypeStats({
    required this.woodCode,
    required this.woodName,
    required this.revenue,
    required this.itemCount,
    required this.quantity,
    this.volume = 0,
  });

  WoodTypeStats copyWithAdded({
    double addRevenue = 0,
    int addItems = 0,
    int addQuantity = 0,
    double addVolume = 0,
  }) {
    return WoodTypeStats(
      woodCode: woodCode,
      woodName: woodName,
      revenue: revenue + addRevenue,
      itemCount: itemCount + addItems,
      quantity: quantity + addQuantity,
      volume: volume + addVolume,
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

  String get comboKey => '${instrumentCode}_$partCode';
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