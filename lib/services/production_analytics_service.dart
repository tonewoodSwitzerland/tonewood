// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
//
// class ProductionAnalyticsService {
//   // Allgemeine Produktionsstatistiken
//   static Future<Map<String, dynamic>> getProductionStats(String timeRange) async {
//     try {
//       final startDate = getStartDateForRange(timeRange);
//
//       print('Fetching production stats from $startDate'); // Debug
//
//       // Hole alle Produkte
//       final QuerySnapshot productionDocs = await FirebaseFirestore.instance
//           .collection('production')
//           .get(); // Erstmal ohne Filter um zu sehen ob überhaupt Daten da sind
//
//       print('Found ${productionDocs.docs.length} production documents'); // Debug
//
//       // Hole alle Batches für jedes Produkt
//       int totalBatches = 0;
//       double totalQuantity = 0;
//       Map<String, int> batchSizes = {
//         '1-10': 0,
//         '11-25': 0,
//         '26-50': 0,
//         '51-100': 0,
//         '100+': 0,
//       };
//
//       for (var doc in productionDocs.docs) {
//         print('Processing document ${doc.id}'); // Debug
//
//         // Hole Batches für dieses Produkt
//         final batchSnapshot = await doc.reference
//             .collection('batch')
//             .get();
//
//         print('Found ${batchSnapshot.docs.length} batches for ${doc.id}'); // Debug
//
//         totalBatches += batchSnapshot.docs.length;
//
//         // Verarbeite jede Charge
//         for (var batch in batchSnapshot.docs) {
//           final data = batch.data();
//           final quantity = data['quantity'] as double? ?? 0;
//           totalQuantity += quantity;
//
//           // Kategorisiere die Chargengröße
//           if (quantity <= 10) batchSizes['1-10'] = (batchSizes['1-10'] ?? 0) + 1;
//           else if (quantity <= 25) batchSizes['11-25'] = (batchSizes['11-25'] ?? 0) + 1;
//           else if (quantity <= 50) batchSizes['26-50'] = (batchSizes['26-50'] ?? 0) + 1;
//           else if (quantity <= 100) batchSizes['51-100'] = (batchSizes['51-100'] ?? 0) + 1;
//           else batchSizes['100+'] = (batchSizes['100+'] ?? 0) + 1;
//
//           print('Processed batch: quantity=$quantity'); // Debug
//         }
//       }
//
//       final stats = {
//         'total_products': productionDocs.docs.length,
//         'total_batches': totalBatches,
//         'total_quantity': totalQuantity,
//         'average_batch_size': totalBatches > 0 ? totalQuantity / totalBatches : 0,
//         'batch_sizes': batchSizes,
//       };
//
//       print('Final stats: $stats'); // Debug
//
//       return stats;
//
//     } catch (e, stackTrace) {
//       print('Error in getProductionStats: $e');
//       print('Stack trace: $stackTrace');
//       rethrow;
//     }
//   }
//
//   static Future<Map<String, dynamic>> getBatchEfficiencyStats(String timeRange) async {
//     try {
//       final startDate = getStartDateForRange(timeRange);
//
//       print('Fetching batch efficiency stats from $startDate'); // Debug
//
//       // Hole alle Produkte
//       final products = await FirebaseFirestore.instance
//           .collection('production')
//           .get(); // Erstmal ohne Filter
//
//       print('Found ${products.docs.length} products'); // Debug
//
//       Map<String, dynamic> batchStats = {
//         'total_batches': 0,
//         'avg_time_between_batches': 0.0,
//         'batches_by_weekday': {
//           'Montag': 0,
//           'Dienstag': 0,
//           'Mittwoch': 0,
//           'Donnerstag': 0,
//           'Freitag': 0,
//           'Samstag': 0,
//           'Sonntag': 0,
//         },
//         'batches_by_size': {
//           '1-10': 0,
//           '11-25': 0,
//           '26-50': 0,
//           '51-100': 0,
//           '100+': 0,
//         },
//       };
//
//       List<DateTime> allBatchDates = [];
//
//       for (var product in products.docs) {
//         print('Processing product ${product.id}'); // Debug
//
//         final batches = await product.reference
//             .collection('batch')
//             .get();
//
//         print('Found ${batches.docs.length} batches for ${product.id}'); // Debug
//
//         batchStats['total_batches'] += batches.docs.length;
//
//         for (var batch in batches.docs) {
//           final data = batch.data();
//           print('Batch data: $data'); // Debug
//
//           // Verarbeite Datum
//           if (data['stock_entry_date'] != null) {
//             final date = (data['stock_entry_date'] as Timestamp).toDate();
//             allBatchDates.add(date);
//
//             final weekday = DateFormat('EEEE', 'de_DE').format(date);
//             batchStats['batches_by_weekday'][weekday] =
//                 (batchStats['batches_by_weekday'][weekday] ?? 0) + 1;
//
//             print('Added batch for $weekday'); // Debug
//           }
//
//           // Verarbeite Menge
//           final quantity = data['quantity'] as double? ?? 0;
//           final sizeKey = _getBatchSizeKey(quantity);
//           batchStats['batches_by_size'][sizeKey] =
//               (batchStats['batches_by_size'][sizeKey] ?? 0) + 1;
//         }
//       }
//
//       print('Final batch stats: $batchStats'); // Debug
//       return batchStats;
//
//     } catch (e, stackTrace) {
//       print('Error in getBatchEfficiencyStats: $e');
//       print('Stack trace: $stackTrace');
//       rethrow;
//     }
//
//
//   }
//
// // Hilfsmethode für die Kategorisierung der Chargengrößen
//   static String _getBatchSizeKey(double quantity) {
//     if (quantity <= 10) return '1-10';
//     if (quantity <= 25) return '11-25';
//     if (quantity <= 50) return '26-50';
//     if (quantity <= 100) return '51-100';
//     return '100+';
//   }
//
//   // Spezielle Analysen für Haselfichte & Mondholz
//   static Future<Map<String, dynamic>> getSpecialWoodStats() async {
//     final QuerySnapshot docs = await FirebaseFirestore.instance
//         .collection('production')
//         .where('haselfichte', isEqualTo: true)
//         .get();
//
//     final moonwoodDocs = await FirebaseFirestore.instance
//         .collection('production')
//         .where('moonwood', isEqualTo: true)
//         .get();
//
//     // Grupiere nach Instrumenten/Bauteilen
//     Map<String, int> haselfichteByInstrument = {};
//     Map<String, int> moonwoodByInstrument = {};
//
//     for (var doc in docs.docs) {
//       final data = doc.data() as Map<String, dynamic>;
//       final instrument = data['instrument_name'] as String;
//       haselfichteByInstrument[instrument] =
//           (haselfichteByInstrument[instrument] ?? 0) + 1;
//     }
//
//     for (var doc in moonwoodDocs.docs) {
//       final data = doc.data() as Map<String, dynamic>;
//       final instrument = data['instrument_name'] as String;
//       moonwoodByInstrument[instrument] =
//           (moonwoodByInstrument[instrument] ?? 0) + 1;
//     }
//
//     return {
//       'haselfichte_total': docs.docs.length,
//       'moonwood_total': moonwoodDocs.docs.length,
//       'haselfichte_by_instrument': haselfichteByInstrument,
//       'moonwood_by_instrument': moonwoodByInstrument,
//     };
//   }
//
//   // Produktionseffizienz: Analysiert Chargengrößen und -häufigkeit
//
//
// // Hilfsmethode für die Startdatum-Berechnung
//   static DateTime getStartDateForRange(String timeRange) {
//     final now = DateTime.now();
//     switch (timeRange) {
//       case 'week':
//         return now.subtract(const Duration(days: 7));
//       case 'month':
//         return now.subtract(const Duration(days: 30));
//       case 'quarter':
//         return now.subtract(const Duration(days: 90));
//       case 'year':
//         return now.subtract(const Duration(days: 365));
//       default:
//         return now.subtract(const Duration(days: 30));
//     }
//   }
//
//   // FSC-Analyse
//   static Future<Map<String, dynamic>> getFSCStats() async {
//     final QuerySnapshot docs = await FirebaseFirestore.instance
//         .collection('production')
//         .where('FSC_100', isEqualTo: true)
//         .get();
//
//     Map<String, int> fscByInstrument = {};
//     Map<String, int> fscByWoodType = {};
//
//     for (var doc in docs.docs) {
//       final data = doc.data() as Map<String, dynamic>;
//       final instrument = data['instrument_name'] as String;
//       final woodType = data['wood_name'] as String;
//
//       fscByInstrument[instrument] = (fscByInstrument[instrument] ?? 0) + 1;
//       fscByWoodType[woodType] = (fscByWoodType[woodType] ?? 0) + 1;
//     }
//
//     return {
//       'fsc_total': docs.docs.length,
//       'fsc_by_instrument': fscByInstrument,
//       'fsc_by_wood_type': fscByWoodType,
//     };
//   }
//
//
//
//
// }
//
// class ProductionKPIs {
//   final int totalProducts;
//   final int totalBatches;
//   final int totalQuantity;
//   final double avgBatchSize;
//   final Map<String, int> batchSizes;
//   final DateTime lastBatchDate;
//
//   ProductionKPIs({
//     required this.totalProducts,
//     required this.totalBatches,
//     required this.totalQuantity,
//     required this.avgBatchSize,
//     required this.batchSizes,
//     required this.lastBatchDate,
//   });
//
//   factory ProductionKPIs.fromMap(Map<String, dynamic> map) {
//     return ProductionKPIs(
//       totalProducts: map['total_products'] ?? 0,
//       totalBatches: map['total_batches'] ?? 0,
//       totalQuantity: map['total_quantity'] ?? 0,
//       avgBatchSize: map['average_batch_size'] ?? 0.0,
//       batchSizes: Map<String, int>.from(map['batch_sizes'] ?? {}),
//       lastBatchDate: (map['last_batch_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
//     );
//   }
// }