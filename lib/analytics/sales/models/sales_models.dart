// lib/screens/analytics/sales/models/sales_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String id;
  final String productName;
  final String instrumentName;
  final double price;
  final int quantity;
  final DateTime timestamp;
  final Map<String, dynamic> customer;
  final Map<String, dynamic>? fair;
  final Map<String, dynamic> calculations;

  SaleItem({
    required this.id,
    required this.productName,
    required this.instrumentName,
    required this.price,
    required this.quantity,
    required this.timestamp,
    required this.customer,
    this.fair,
    required this.calculations,
  });

  factory SaleItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SaleItem(
      id: doc.id,
      productName: data['product_name'] ?? '',
      instrumentName: data['instrument_name'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      quantity: data['quantity'] ?? 0,
      timestamp: (data['metadata']['timestamp'] as Timestamp).toDate(),
      customer: Map<String, dynamic>.from(data['customer'] ?? {}),
      fair: data['fair'] != null ? Map<String, dynamic>.from(data['fair']) : null,
      calculations: Map<String, dynamic>.from(data['calculations'] ?? {}),
    );
  }
}



class InventoryStats {
  final int totalItems;
  final int lowStockItems;
  final List<Map<String, dynamic>> recentMovements;
  final Map<String, int> stockByProduct;
  final Map<String, double> valueByCategory;

  InventoryStats({
    required this.totalItems,
    required this.lowStockItems,
    required this.recentMovements,
    required this.stockByProduct,
    required this.valueByCategory,
  });

  factory InventoryStats.fromMap(Map<String, dynamic> data) {
    return InventoryStats(
      totalItems: data['total_items'] ?? 0,
      lowStockItems: data['low_stock_items'] ?? 0,
      recentMovements: List<Map<String, dynamic>>.from(data['recent_movements'] ?? []),
      stockByProduct: Map<String, int>.from(data['stock_by_product'] ?? {}),
      valueByCategory: Map<String, double>.from(data['value_by_category'] ?? {}),
    );
  }
}

class CustomerStats {
  final int totalCustomers;
  final double averageCustomerValue;
  final Map<String, double> customerLifetimeValue;
  final Map<String, int> ordersByRegion;
  final List<Map<String, dynamic>> topCustomers;

  CustomerStats({
    required this.totalCustomers,
    required this.averageCustomerValue,
    required this.customerLifetimeValue,
    required this.ordersByRegion,
    required this.topCustomers,
  });

  factory CustomerStats.fromMap(Map<String, dynamic> data) {
    return CustomerStats(
      totalCustomers: data['total_customers'] ?? 0,
      averageCustomerValue: (data['average_customer_value'] ?? 0.0).toDouble(),
      customerLifetimeValue: Map<String, double>.from(data['customer_lifetime_value'] ?? {}),
      ordersByRegion: Map<String, int>.from(data['orders_by_region'] ?? {}),
      topCustomers: List<Map<String, dynamic>>.from(data['top_customers'] ?? []),
    );
  }
}

// lib/analytics/sales/models/sales_models.dart

// lib/analytics/sales/models/sales_stats.dart

// lib/analytics/sales/models/sales_stats.dart

class ProductStats {
  final String id;
  final String name;
  int quantity;  // Mutable für Aggregation
  double revenue;  // Mutable für Aggregation

  ProductStats({
    required this.id,
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

class TopCustomer {
  final String id;
  final String name;
  double revenue;  // Mutable für Aggregation
  int orderCount;  // Mutable für Aggregation

  TopCustomer({
    required this.id,
    required this.name,
    required this.revenue,
    required this.orderCount,
  });
}

class TopProduct extends ProductStats {
  TopProduct({
    required String id,
    required String name,
    required int quantity,
    required double revenue,
  }) : super(
    id: id,
    name: name,
    quantity: quantity,
    revenue: revenue,
  );
}

class SalesStats {
  final double totalRevenue;
  final TopCustomer topCustomer;
  final TopProduct topProduct;
  final double averageOrderValue;
  final double orderValueTrend;
  final List<ProductStats> topProducts;
  final Map<String, double> woodTypeDistribution;
  final double revenueTrend;

  SalesStats({
    required this.totalRevenue,
    required this.topCustomer,
    required this.topProduct,
    required this.averageOrderValue,
    required this.orderValueTrend,
    required this.topProducts,
    required this.woodTypeDistribution,
    required this.revenueTrend,
  });
}