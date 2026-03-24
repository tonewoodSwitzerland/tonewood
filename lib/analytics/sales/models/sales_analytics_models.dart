// lib/analytics/sales/models/sales_analytics_models.dart

/// Haupt-Statistik-Container für die Übersicht
class SalesAnalytics {
  final RevenueStats revenue;
  final int orderCount;
  final double averageOrderValue;
  final double averageOrderValueGross;
  final ThermoStats thermoStats;
  final ServiceStats serviceStats;
  final Map<String, CountryStats> countryStats;
  final Map<String, WoodTypeStats> woodTypeStats;
  final List<ProductComboStats> topProductCombos;
  final List<OrderSummary> orders; // Alle gefilterten Aufträge für Detailtabelle

  SalesAnalytics({
    required this.revenue,
    required this.orderCount,
    required this.averageOrderValue,
    this.averageOrderValueGross = 0,
    required this.thermoStats,
    required this.serviceStats,
    required this.countryStats,
    required this.woodTypeStats,
    required this.topProductCombos,
    this.orders = const [],
  });

  factory SalesAnalytics.empty() => SalesAnalytics(
    revenue: RevenueStats.empty(),
    orderCount: 0,
    averageOrderValue: 0,
    averageOrderValueGross: 0,
    thermoStats: ThermoStats.empty(),
    serviceStats: ServiceStats.empty(),
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

  // --- Rabatt (subtotal - net_amount) ---
  final double totalDiscount;
  final double yearDiscount;
  final double monthDiscount;

  // --- Gratisartikel ---
  final double totalGratisValue;
  final double yearGratisValue;
  final double monthGratisValue;

  // --- Fracht ---
  final double totalFreight;
  final double yearFreight;
  final double monthFreight;

  // --- Phytosanitary ---
  final double totalPhytosanitary;
  final double yearPhytosanitary;
  final double monthPhytosanitary;

  // --- MwSt ---
  final double totalVat;
  final double yearVat;
  final double monthVat;

  // --- Abschläge & Zuschläge ---
  final double totalDeductions;
  final double yearDeductions;
  final double monthDeductions;
  final double totalSurcharges;
  final double yearSurcharges;
  final double monthSurcharges;

  // --- Dienstleistungen ---
  final double totalServiceRevenue;
  final double yearServiceRevenue;
  final double monthServiceRevenue;

  // --- Order Counts pro Zeitraum ---
  final Map<String, int> monthlyOrderCount;
  final int yearOrderCount;
  final int monthOrderCount;
  final int previousYearOrderCount;
  final int previousMonthOrderCount;

  // --- Vorjahr monatlich (subtotal) ---
  final Map<String, double> monthlyRevenueLastYear;

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
    this.totalDiscount = 0,
    this.yearDiscount = 0,
    this.monthDiscount = 0,
    this.totalGratisValue = 0,
    this.yearGratisValue = 0,
    this.monthGratisValue = 0,
    this.totalFreight = 0,
    this.yearFreight = 0,
    this.monthFreight = 0,
    this.totalPhytosanitary = 0,
    this.yearPhytosanitary = 0,
    this.monthPhytosanitary = 0,
    this.totalVat = 0,
    this.yearVat = 0,
    this.monthVat = 0,
    this.totalDeductions = 0,
    this.yearDeductions = 0,
    this.monthDeductions = 0,
    this.totalSurcharges = 0,
    this.yearSurcharges = 0,
    this.monthSurcharges = 0,
    this.totalServiceRevenue = 0,
    this.yearServiceRevenue = 0,
    this.monthServiceRevenue = 0,
    this.monthlyOrderCount = const {},
    this.yearOrderCount = 0,
    this.monthOrderCount = 0,
    this.previousYearOrderCount = 0,
    this.previousMonthOrderCount = 0,
    this.monthlyRevenueLastYear = const {},
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
    totalDiscount: 0,
    yearDiscount: 0,
    monthDiscount: 0,
    totalGratisValue: 0,
    yearGratisValue: 0,
    monthGratisValue: 0,
    totalFreight: 0,
    yearFreight: 0,
    monthFreight: 0,
    totalPhytosanitary: 0,
    yearPhytosanitary: 0,
    monthPhytosanitary: 0,
    totalVat: 0,
    yearVat: 0,
    monthVat: 0,
    totalDeductions: 0,
    yearDeductions: 0,
    monthDeductions: 0,
    totalSurcharges: 0,
    yearSurcharges: 0,
    monthSurcharges: 0,
    totalServiceRevenue: 0,
    yearServiceRevenue: 0,
    monthServiceRevenue: 0,
    monthlyOrderCount: {},
    yearOrderCount: 0,
    monthOrderCount: 0,
    previousYearOrderCount: 0,
    previousMonthOrderCount: 0,
    monthlyRevenueLastYear: {},
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

  double get yearOrderChangePercent {
    if (previousYearOrderCount == 0) return 0;
    return ((yearOrderCount - previousYearOrderCount) / previousYearOrderCount) * 100;
  }

  double get monthOrderChangePercent {
    if (previousMonthOrderCount == 0) return 0;
    return ((monthOrderCount - previousMonthOrderCount) / previousMonthOrderCount) * 100;
  }
}

/// Thermo-Behandlung Statistiken
class ThermoStats {
  final int thermoItemCount;
  final int totalItemCount;
  final double thermoRevenue;
  final double totalRevenue;
  final List<Map<String, dynamic>> details;

  ThermoStats({
    required this.thermoItemCount,
    required this.totalItemCount,
    required this.thermoRevenue,
    required this.totalRevenue,
    this.details = const [],
  });

  factory ThermoStats.empty() => ThermoStats(
    thermoItemCount: 0,
    totalItemCount: 0,
    thermoRevenue: 0,
    totalRevenue: 0,
    details: [],
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

/// Dienstleistungs-Statistiken
class ServiceStats {
  final int serviceItemCount;
  final int totalItemCount;
  final double serviceRevenue;
  final double totalRevenue;
  final List<Map<String, dynamic>> details;

  ServiceStats({
    required this.serviceItemCount,
    required this.totalItemCount,
    required this.serviceRevenue,
    required this.totalRevenue,
    this.details = const [],
  });

  factory ServiceStats.empty() => ServiceStats(
    serviceItemCount: 0,
    totalItemCount: 0,
    serviceRevenue: 0,
    totalRevenue: 0,
    details: [],
  );

  double get itemSharePercent {
    if (totalItemCount == 0) return 0;
    return (serviceItemCount / totalItemCount) * 100;
  }

  double get revenueSharePercent {
    if (totalRevenue == 0) return 0;
    return (serviceRevenue / totalRevenue) * 100;
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

/// Einzelner Auftrag für die Detailtabelle
class OrderSummary {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String countryCode;
  final DateTime relevantDate; // shippedAt ?? orderDate
  final double subtotal;       // Warenwert nach Rabatt
  final double total;          // Gesamtbetrag (Brutto)
  final double discount;
  final int itemCount;
  final String currency;
  final double freight;
  final double phytosanitary;
  final double serviceRevenue;
  final double vat;
  final double deductions;
  final double surcharges;
// Nach surcharges:
  final double netAmount;  // = net_amount direkt aus Firestore
  OrderSummary({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.countryCode,
    required this.relevantDate,
    required this.subtotal,
    required this.total,
    required this.discount,
    required this.itemCount,
    required this.currency,
    this.freight = 0,
    this.phytosanitary = 0,
    this.serviceRevenue = 0,
    this.vat = 0,
    this.deductions = 0,
    this.surcharges = 0,
    this.netAmount = 0,
  });
}