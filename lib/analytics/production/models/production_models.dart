// lib/screens/analytics/production/models/production_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionBatch {
  final String id;
  final String productName;
  final String instrumentName;
  final int quantity;
  final DateTime timestamp;
  final String status;
  final bool isSpecialWood;
  final bool isMoonwood;
  final bool isFSC;
  final double efficiency;
  final Map<String, dynamic>? additionalData;

  ProductionBatch({
    required this.id,
    required this.productName,
    required this.instrumentName,
    required this.quantity,
    required this.timestamp,
    required this.status,
    this.isSpecialWood = false,
    this.isMoonwood = false,
    this.isFSC = false,
    required this.efficiency,
    this.additionalData,
  });

  factory ProductionBatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductionBatch(
      id: doc.id,
      productName: data['product_name'] ?? '',
      instrumentName: data['instrument_name'] ?? '',
      quantity: data['quantity'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      status: data['status'] ?? '',
      isSpecialWood: data['is_special_wood'] ?? false,
      isMoonwood: data['is_moonwood'] ?? false,
      isFSC: data['is_fsc'] ?? false,
      efficiency: (data['efficiency'] ?? 0.0).toDouble(),
      additionalData: data['additional_data'],
    );
  }
}

class ProductionStats {
  final int totalProducts;
  final int totalBatches;
  final double averageBatchSize;
  final Map<String, int> batchSizes;
  final Map<String, double> efficiencyByDay;
  final double overallEfficiency;

  ProductionStats({
    required this.totalProducts,
    required this.totalBatches,
    required this.averageBatchSize,
    required this.batchSizes,
    required this.efficiencyByDay,
    required this.overallEfficiency,
  });

  factory ProductionStats.fromMap(Map<String, dynamic> data) {
    return ProductionStats(
      totalProducts: data['total_products'] ?? 0,
      totalBatches: data['total_batches'] ?? 0,
      averageBatchSize: (data['average_batch_size'] ?? 0.0).toDouble(),
      batchSizes: Map<String, int>.from(data['batch_sizes'] ?? {}),
      efficiencyByDay: Map<String, double>.from(data['efficiency_by_day'] ?? {}),
      overallEfficiency: (data['overall_efficiency'] ?? 0.0).toDouble(),
    );
  }
}

class SpecialWoodStats {
  final int haselfichteBatches;
  final int moonwoodBatches;
  final Map<String, int> haselfichteByInstrument;
  final Map<String, int> moonwoodByInstrument;
  final double haselfichteEfficiency;
  final double moonwoodEfficiency;

  SpecialWoodStats({
    required this.haselfichteBatches,
    required this.moonwoodBatches,
    required this.haselfichteByInstrument,
    required this.moonwoodByInstrument,
    required this.haselfichteEfficiency,
    required this.moonwoodEfficiency,
  });

  factory SpecialWoodStats.fromMap(Map<String, dynamic> data) {
    return SpecialWoodStats(
      haselfichteBatches: data['haselfichte_batches'] ?? 0,
      moonwoodBatches: data['moonwood_batches'] ?? 0,
      haselfichteByInstrument: Map<String, int>.from(data['haselfichte_by_instrument'] ?? {}),
      moonwoodByInstrument: Map<String, int>.from(data['moonwood_by_instrument'] ?? {}),
      haselfichteEfficiency: (data['haselfichte_efficiency'] ?? 0.0).toDouble(),
      moonwoodEfficiency: (data['moonwood_efficiency'] ?? 0.0).toDouble(),
    );
  }
}

class FSCStats {
  final int totalFSCProducts;
  final Map<String, int> fscByWoodType;
  final double fscPercentage;
  final Map<String, double> fscTrend;

  FSCStats({
    required this.totalFSCProducts,
    required this.fscByWoodType,
    required this.fscPercentage,
    required this.fscTrend,
  });

  factory FSCStats.fromMap(Map<String, dynamic> data) {
    return FSCStats(
      totalFSCProducts: data['total_fsc_products'] ?? 0,
      fscByWoodType: Map<String, int>.from(data['fsc_by_wood_type'] ?? {}),
      fscPercentage: (data['fsc_percentage'] ?? 0.0).toDouble(),
      fscTrend: Map<String, double>.from(data['fsc_trend'] ?? {}),
    );
  }
}
class ProductionItem {
  final String id;
  final String barcode;
  final DateTime created_at;
  final DateTime last_modified;
  final bool haselfichte;
  final String instrument_code;
  final String instrument_name;
//  final DateTime last_stock_entry;
  final int last_stock_change;
  final bool moonwood;
  final String part_code;
  final String part_name;
  final double price_CHF;
  final String product_name;
  final String quality_code;
  final String quality_name;
  final int quantity;
  final String short_barcode;
  final bool thermally_treated;
  final String unit;
  final String wood_code;
  final String wood_name;
  final int year;

  ProductionItem({
    required this.id,
    required this.barcode,
    required this.created_at,
    required this.last_modified,
    required this.haselfichte,
    required this.instrument_code,
    required this.instrument_name,
  //  required this.last_stock_entry,
    required this.last_stock_change,
    required this.moonwood,
    required this.part_code,
    required this.part_name,
    required this.price_CHF,
    required this.product_name,
    required this.quality_code,
    required this.quality_name,
    required this.quantity,
    required this.short_barcode,
    required this.thermally_treated,
    required this.unit,
    required this.wood_code,
    required this.wood_name,
    required this.year,
  });

  factory ProductionItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductionItem(
      id: doc.id,
      barcode: data['barcode'] ?? '',
      created_at: (data['created_at'] as Timestamp).toDate(),
      last_modified: (data['last_modified'] as Timestamp).toDate(),
      haselfichte: data['haselfichte'] ?? false,
      instrument_code: data['instrument_code'] ?? '',
      instrument_name: data['instrument_name'] ?? '',
   //   last_stock_entry: (data['last_stock_entry'] as Timestamp).toDate(),
      last_stock_change: data['last_stock_change'] ?? 0,
      moonwood: data['moonwood'] ?? false,
      part_code: data['part_code'] ?? '',
      part_name: data['part_name'] ?? '',
      price_CHF: (data['price_CHF'] as num).toDouble(),
      product_name: data['product_name'] ?? '',
      quality_code: data['quality_code'] ?? '',
      quality_name: data['quality_name'] ?? '',
      quantity: data['quantity'] ?? 0,
      short_barcode: data['short_barcode'] ?? '',
      thermally_treated: data['thermally_treated'] ?? false,
      unit: data['unit'] ?? '',
      wood_code: data['wood_code'] ?? '',
      wood_name: data['wood_name'] ?? '',
      year: data['year'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'created_at': Timestamp.fromDate(created_at),
      'last_modified': Timestamp.fromDate(last_modified),
      'haselfichte': haselfichte,
      'instrument_code': instrument_code,
      'instrument_name': instrument_name,
     // 'last_stock_entry': Timestamp.fromDate(last_stock_entry),
      'last_stock_change': last_stock_change,
      'moonwood': moonwood,
      'part_code': part_code,
      'part_name': part_name,
      'price_CHF': price_CHF,
      'product_name': product_name,
      'quality_code': quality_code,
      'quality_name': quality_name,
      'quantity': quantity,
      'short_barcode': short_barcode,
      'thermally_treated': thermally_treated,
      'unit': unit,
      'wood_code': wood_code,
      'wood_name': wood_name,
      'year': year,
    };
  }
}