import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/production_filter.dart';
import '../models/production_models.dart';

class ProductionService {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _collection = FirebaseFirestore.instance.collection('production');

  Future<List<DocumentSnapshot>> getFilteredDocuments(ProductionFilter filter) async {
    Query query = _collection.orderBy('created_at', descending: true);

    // Datum Filter
    if (filter.startDate != null) {
      query = query.where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(filter.startDate!));
    }
    if (filter.endDate != null) {
      final endOfDay = DateTime(
        filter.endDate!.year,
        filter.endDate!.month,
        filter.endDate!.day,
        23,
        59,
        59,
      );
      query = query.where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    // Parts Filter
    if (filter.parts?.isNotEmpty ?? false) {
      query = query.where('part_code', whereIn: filter.parts);
    }

    // Instrument Filter
    if (filter.instruments?.isNotEmpty ?? false) {
      query = query.where('instrument_code', whereIn: filter.instruments);
    }
    // Holzart Filter
    if (filter.woodTypes?.isNotEmpty ?? false) {
      query = query.where('wood_code', whereIn: filter.woodTypes);
    }

    // Qualität Filter
    if (filter.qualities?.isNotEmpty ?? false) {
      query = query.where('quality_code', whereIn: filter.qualities);
    }

    final snapshot = await query.get();
    final filteredDocs = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Prüfe alle aktiven Bool-Filter
      if (filter.isMoonwood == true && (data['moonwood'] != true)) {
        return false;
      }
      if (filter.isHaselfichte == true && (data['haselfichte'] != true)) {
        return false;
      }
      if (filter.isThermallyTreated == true && (data['thermally_treated'] != true)) {
        return false;
      }
      if (filter.isFSC == true && (data['FSC_100'] != true)) {
        return false;
      }

      return true;
    }).toList();

    print('Filtered ${snapshot.docs.length} docs to ${filteredDocs.length} docs');
    if (filteredDocs.length != snapshot.docs.length) {
      print('Active filters: ${filter.toMap()}');
    }

    return filteredDocs;
  }

  // Basis Stream für UI-Updates
  // In production_service.dart
  Stream<QuerySnapshot> getProductionStream(ProductionFilter filter) {
    Query query = _collection.orderBy('created_at', descending: true);

    // Datum Filter
    if (filter.startDate != null) {
      query = query.where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(filter.startDate!));
    }
    if (filter.endDate != null) {
      final endOfDay = DateTime(
        filter.endDate!.year,
        filter.endDate!.month,
        filter.endDate!.day,
        23,
        59,
        59,
      );
      query = query.where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    // Instrument Filter
    if (filter.instruments?.isNotEmpty ?? false) {
      query = query.where('instrument_code', whereIn: filter.instruments);
    }
    // Bauteil Filter
    if (filter.parts?.isNotEmpty ?? false) {
      query = query.where('part_code', whereIn: filter.parts);
    }
    // Holzart Filter
    if (filter.woodTypes?.isNotEmpty ?? false) {
      query = query.where('wood_code', whereIn: filter.woodTypes);
    }

    // Qualität Filter
    if (filter.qualities?.isNotEmpty ?? false) {
      query = query.where('quality_code', whereIn: filter.qualities);
    }

    // Spezialfilter über Stream-Transformation
    return query.snapshots().map((snapshot) {
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Prüfe alle aktiven Bool-Filter
        if (filter.isMoonwood == true && (data['moonwood'] != true)) {
          return false;
        }
        if (filter.isHaselfichte == true && (data['haselfichte'] != true)) {
          return false;
        }
        if (filter.isThermallyTreated == true && (data['thermally_treated'] != true)) {
          return false;
        }
        if (filter.isFSC == true && (data['FSC_100'] != true)) {
          return false;
        }

        return true;
      }).toList();

      print('Filtered ${snapshot.docs.length} docs to ${filteredDocs.length} docs');
      if (filteredDocs.length != snapshot.docs.length) {
        print('Active filters: ${filter.toMap()}');
      }

      return snapshot;
    });
  }



  Future<Map<String, dynamic>> getProductionTotals(ProductionFilter filter) async {
    try {
      print('Starting getProductionTotals');
      final docs = await getProductionWithBatches(filter);
      print('Got ${docs.length} documents with batches');

      // Map für die Normalisierung der Einheiten
      final unitNormalization = {
        'Stück': 'Stk',
        'Stk': 'Stk',
        'm³': 'M3',
        'M3': 'M3',
        'Kg': 'KG',
        'KG': 'KG',
        'PAL': 'PAL',
        'Palette': 'PAL',
      };

      final totals = {
        'quantities': <String, int>{
          'Stk': 0,
          'PAL': 0,
          'KG': 0,
          'M3': 0,
        },
        'total_value': 0.0,
        'batch_count': 0,
        'special_wood': {
          'moonwood': 0,
          'haselfichte': 0,
          'thermally_treated': 0,
        },
      };

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        var unit = data['unit'] as String? ?? 'Stk';

        // Normalisiere die Einheit
        unit = unitNormalization[unit] ?? unit;
        print('Processing document with normalized unit: $unit');

        final price = (data['price_CHF'] as num?)?.toDouble() ?? 0.0;

        // Spezialholz-Flags
        final moonwood = data['moonwood'] as bool? ?? false;
        final haselfichte = data['haselfichte'] as bool? ?? false;
        final thermallyTreated = data['thermally_treated'] as bool? ?? false;

        try {
          final batches = await doc.reference.collection('batch').get();
          print('Found ${batches.docs.length} batches for document');

          for (var batch in batches.docs) {
            try {
              final batchData = batch.data();
              if (batchData['stock_entry_date'] == null) continue;

              final batchDate = (batchData['stock_entry_date'] as Timestamp).toDate();
              if (!_isDateInRange(batchDate, filter)) continue;

              final quantity = batchData['quantity'] as int? ?? 0;
              if (quantity == 0) continue;

              print('Processing batch with quantity: $quantity for unit: $unit');

              // Sichere Addition der Mengen mit normalisierter Einheit
              final quantities = totals['quantities'] as Map<String, int>;
              quantities[unit] = (quantities[unit] ?? 0) + quantity;

              // Gesamtwert berechnen
              totals['total_value'] = (totals['total_value'] as double) + (quantity * price);

              // Batch zählen
              totals['batch_count'] = (totals['batch_count'] as int) + 1;

              // Spezialholz Mengen
              final specialWood = totals['special_wood'] as Map<String, int>;
              if (moonwood) {
                specialWood['moonwood'] = (specialWood['moonwood'] ?? 0) + quantity;
              }
              if (haselfichte) {
                specialWood['haselfichte'] = (specialWood['haselfichte'] ?? 0) + quantity;
              }
              if (thermallyTreated) {
                specialWood['thermally_treated'] = (specialWood['thermally_treated'] ?? 0) + quantity;
              }
            } catch (e, stackTrace) {
              print('Error processing batch: $e');
              print('StackTrace: $stackTrace');
            }
          }
        } catch (e, stackTrace) {
          print('Error processing document batches: $e');
          print('StackTrace: $stackTrace');
        }
      }

      print('Final quantities before normalization: ${totals['quantities']}');

      // Stelle sicher, dass nur die standardisierten Einheiten zurückgegeben werden
      final quantities = totals['quantities'] as Map<String, int>;
      final normalizedQuantities = <String, int>{
        'Stk': quantities['Stk'] ?? 0,
        'PAL': quantities['PAL'] ?? 0,
        'KG': quantities['KG'] ?? 0,
        'M3': quantities['M3'] ?? 0,
      };
      totals['quantities'] = normalizedQuantities;

      print('Final normalized quantities: ${totals['quantities']}');
      print('Completed getProductionTotals successfully');
      return totals;
    } catch (e, stackTrace) {
      print('Error in getProductionTotals: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }
// Die getProductionWithBatches Methode sollten wir auch anpassen:
  Future<List<DocumentSnapshot>> getProductionWithBatches(ProductionFilter filter) async {
    final snapshot = await getProductionStream(filter).first;
    final List<DocumentSnapshot> result = [];

    for (final doc in snapshot.docs) {
      // Batches für dieses Dokument holen
      final batchQuery = await doc.reference.collection('batch').get();
      var totalQuantity = 0;

      // Prüfen ob Batches im Zeitraum existieren und deren Mengen summieren
      for (final batch in batchQuery.docs) {
        final batchData = batch.data();
        final batchDate = (batchData['stock_entry_date'] as Timestamp).toDate();

        if (_isDateInRange(batchDate, filter)) {
          totalQuantity += (batchData['quantity'] as int? ?? 0);
        }
      }

      // Nur Dokumente mit tatsächlichen Mengen im Zeitraum hinzufügen
      if (totalQuantity > 0) {
        result.add(doc);
      }
    }

    return result;
  }
  Future<Map<String, Map<String, dynamic>>> getProductionByInstrument(ProductionFilter filter) async {
    try {
      final docs = await getProductionWithBatches(filter);
      print('Got ${docs.length} documents for instrument stats');

      final stats = <String, Map<String, dynamic>>{};

      final unitNormalization = {
        'Stück': 'Stk',
        'Stk': 'Stk',
        'm³': 'M3',
        'M3': 'M3',
        'Kg': 'KG',
        'KG': 'KG',
        'PAL': 'PAL',
        'Palette': 'PAL',
      };

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;

        final instrumentCode = data['instrument_code'] as String;
        final instrumentName = data['instrument_name'] as String;
        var unit = data['unit'] as String? ?? 'Stk';
        unit = unitNormalization[unit] ?? unit;
        final price = (data['price_CHF'] as num?)?.toDouble() ?? 0.0;

        print('Processing instrument type: $instrumentName ($instrumentCode) with unit: $unit');

        if (!stats.containsKey(instrumentCode)) {
          stats[instrumentCode] = {
            'name': instrumentName,
            'quantities': <String, int>{
              'Stk': 0,
              'PAL': 0,
              'KG': 0,
              'M3': 0,
            },
            'total_value': 0.0,
          };
        }

        // Batches summieren
        final batches = await doc.reference.collection('batch').get();
        print('Found ${batches.docs.length} batches for instrument type $instrumentName');

        for (var batch in batches.docs) {
          final batchData = batch.data();
          final batchDate = (batchData['stock_entry_date'] as Timestamp).toDate();

          if (_isDateInRange(batchDate, filter)) {
            final quantity = batchData['quantity'] as int;
            print('Adding quantity $quantity to instrument type $instrumentName with unit $unit');

            final quantities = stats[instrumentCode]!['quantities'] as Map<String, int>;
            quantities[unit] = (quantities[unit] ?? 0) + quantity;

            stats[instrumentCode]!['total_value'] =
                (stats[instrumentCode]!['total_value'] as double) + (quantity * price);

            print('New quantities for $instrumentName: ${quantities}');
          }
        }
      }

      print('Final wood type stats: $stats');
      return stats;
    } catch (e, stackTrace) {
      print('Error in getProductionByWoodType: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> getProductionByPart(ProductionFilter filter) async {
    try {
      final docs = await getProductionWithBatches(filter);
      print('Got ${docs.length} documents for wood type stats');

      final stats = <String, Map<String, dynamic>>{};

      final unitNormalization = {
        'Stück': 'Stk',
        'Stk': 'Stk',
        'm³': 'M3',
        'M3': 'M3',
        'Kg': 'KG',
        'KG': 'KG',
        'PAL': 'PAL',
        'Palette': 'PAL',
      };

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;

        final partCode = data['part_code'] as String;
        final partName = data['part_name'] as String;
        var unit = data['unit'] as String? ?? 'Stk';
        unit = unitNormalization[unit] ?? unit;
        final price = (data['price_CHF'] as num?)?.toDouble() ?? 0.0;

        print('Processing part type: $partName ($partCode) with unit: $unit');

        if (!stats.containsKey(partCode)) {
          stats[partCode] = {
            'name': partName,
            'quantities': <String, int>{
              'Stk': 0,
              'PAL': 0,
              'KG': 0,
              'M3': 0,
            },
            'total_value': 0.0,
          };
        }

        // Batches summieren
        final batches = await doc.reference.collection('batch').get();
        print('Found ${batches.docs.length} batches for part type $partName');

        for (var batch in batches.docs) {
          final batchData = batch.data();
          final batchDate = (batchData['stock_entry_date'] as Timestamp).toDate();

          if (_isDateInRange(batchDate, filter)) {
            final quantity = batchData['quantity'] as int;
            print('Adding quantity $quantity to part type $partName with unit $unit');

            final quantities = stats[partCode]!['quantities'] as Map<String, int>;
            quantities[unit] = (quantities[unit] ?? 0) + quantity;

            stats[partCode]!['total_value'] =
                (stats[partCode]!['total_value'] as double) + (quantity * price);

            print('New quantities for $partName: ${quantities}');
          }
        }
      }

      print('Final part type stats: $stats');
      return stats;
    } catch (e, stackTrace) {
      print('Error in getProductionByPart: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> getProductionByWoodType(ProductionFilter filter) async {
    try {
      final docs = await getProductionWithBatches(filter);
      print('Got ${docs.length} documents for wood type stats');

      final stats = <String, Map<String, dynamic>>{};

      final unitNormalization = {
        'Stück': 'Stk',
        'Stk': 'Stk',
        'm³': 'M3',
        'M3': 'M3',
        'Kg': 'KG',
        'KG': 'KG',
        'PAL': 'PAL',
        'Palette': 'PAL',
      };

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;

        final woodCode = data['wood_code'] as String;
        final woodName = data['wood_name'] as String;
        var unit = data['unit'] as String? ?? 'Stk';
        unit = unitNormalization[unit] ?? unit;
        final price = (data['price_CHF'] as num?)?.toDouble() ?? 0.0;

        print('Processing wood type: $woodName ($woodCode) with unit: $unit');

        if (!stats.containsKey(woodCode)) {
          stats[woodCode] = {
            'name': woodName,
            'quantities': <String, int>{
              'Stk': 0,
              'PAL': 0,
              'KG': 0,
              'M3': 0,
            },
            'total_value': 0.0,
          };
        }

        // Batches summieren
        final batches = await doc.reference.collection('batch').get();
        print('Found ${batches.docs.length} batches for wood type $woodName');

        for (var batch in batches.docs) {
          final batchData = batch.data();
          final batchDate = (batchData['stock_entry_date'] as Timestamp).toDate();

          if (_isDateInRange(batchDate, filter)) {
            final quantity = batchData['quantity'] as int;
            print('Adding quantity $quantity to wood type $woodName with unit $unit');

            final quantities = stats[woodCode]!['quantities'] as Map<String, int>;
            quantities[unit] = (quantities[unit] ?? 0) + quantity;

            stats[woodCode]!['total_value'] =
                (stats[woodCode]!['total_value'] as double) + (quantity * price);

            print('New quantities for $woodName: ${quantities}');
          }
        }
      }

      print('Final wood type stats: $stats');
      return stats;
    } catch (e, stackTrace) {
      print('Error in getProductionByWoodType: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> getProductionByQuality(ProductionFilter filter) async {
    try {
      final docs = await getProductionWithBatches(filter);
      print('Got ${docs.length} documents for quality stats');

      final stats = <String, Map<String, dynamic>>{};

      final unitNormalization = {
        'Stück': 'Stk',
        'Stk': 'Stk',
        'm³': 'M3',
        'M3': 'M3',
        'Kg': 'KG',
        'KG': 'KG',
        'PAL': 'PAL',
        'Palette': 'PAL',
      };

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final qualityCode = data['quality_code'] as String;
        final qualityName = data['quality_name'] as String;
        var unit = data['unit'] as String? ?? 'Stk';
        unit = unitNormalization[unit] ?? unit;
        final price = (data['price_CHF'] as num?)?.toDouble() ?? 0.0;

        print('Processing quality: $qualityName ($qualityCode) with unit: $unit');

        if (!stats.containsKey(qualityCode)) {
          stats[qualityCode] = {
            'name': qualityName,
            'quantities': <String, int>{
              'Stk': 0,
              'PAL': 0,
              'KG': 0,
              'M3': 0,
            },
            'total_value': 0.0,
          };
        }

        // Batches summieren
        final batches = await doc.reference.collection('batch').get();
        print('Found ${batches.docs.length} batches for quality $qualityName');

        for (var batch in batches.docs) {
          final batchData = batch.data();
          final batchDate = (batchData['stock_entry_date'] as Timestamp).toDate();

          if (_isDateInRange(batchDate, filter)) {
            final quantity = batchData['quantity'] as int;
            print('Adding quantity $quantity to quality $qualityName with unit $unit');

            final quantities = stats[qualityCode]!['quantities'] as Map<String, int>;
            quantities[unit] = (quantities[unit] ?? 0) + quantity;

            stats[qualityCode]!['total_value'] =
                (stats[qualityCode]!['total_value'] as double) + (quantity * price);

            print('New quantities for $qualityName: ${quantities}');
          }
        }
      }

      print('Final quality stats: $stats');
      return stats;
    } catch (e, stackTrace) {
      print('Error in getProductionByQuality: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  bool _isDateInRange(DateTime date, ProductionFilter filter) {
  if (filter.timeRange != null) {
  final now = DateTime.now();
  DateTime startDate;

  switch (filter.timeRange) {
  case 'week':
  startDate = now.subtract(const Duration(days: 7));
  break;
  case 'month':
  startDate = now.subtract(const Duration(days: 30));
  break;
  case 'quarter':
  startDate = now.subtract(const Duration(days: 90));
  break;
  case 'year':
  startDate = now.subtract(const Duration(days: 365));
  break;
  default:
  startDate = now.subtract(const Duration(days: 30));
  }

  return date.isAfter(startDate) && date.isBefore(now);
  } else if (filter.startDate != null || filter.endDate != null) {
  if (filter.startDate != null && date.isBefore(filter.startDate!)) {
  return false;
  }
  if (filter.endDate != null) {
  final endOfDay = DateTime(
  filter.endDate!.year,
  filter.endDate!.month,
  filter.endDate!.day,
  23,
  59,
  59,
  );
  if (date.isAfter(endOfDay)) {
  return false;
  }
  }
  return true;
  }

  return true;
  }

  // Hilfsmethoden für Filter-Dialog
  Stream<List<CodeNamePair>> getWoodTypes() {
  return _firestore
      .collection('wood_types')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => CodeNamePair(
  code: doc.id,
  name: (doc.data() as Map<String, dynamic>)['name'] as String,
  ))
      .toList());
  }

  Stream<List<CodeNamePair>> getQualities() {
  return _firestore
      .collection('qualities')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => CodeNamePair(
  code: doc.id,
  name: (doc.data() as Map<String, dynamic>)['name'] as String,
  ))
      .toList());
  }

  Future<List<Map<String, dynamic>>> getFilteredBatches(ProductionFilter filter) async {
    try {

      final docs = await getFilteredDocuments(filter);
      final List<Map<String, dynamic>> allBatches = [];
     // final docs = await getProductionStream(filter).first;
     // final List<Map<String, dynamic>> allBatches = [];

      print('Processing ${docs.length} documents for batch list');

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Hole alle relevanten Daten vom Hauptdokument
        final baseData = {
          'product_name': data['product_name'] as String? ?? '',
          'wood_name': data['wood_name'] as String? ?? '',
          'wood_code': data['wood_code'] as String? ?? '',
          'quality_name': data['quality_name'] as String? ?? '',
          'quality_code': data['quality_code'] as String? ?? '',
          'unit': data['unit'] as String? ?? 'Stk',
          'price_CHF': (data['price_CHF'] as num?)?.toDouble() ?? 0.0,
          'moonwood': data['moonwood'] as bool? ?? false,
          'haselfichte': data['haselfichte'] as bool? ?? false,
          'thermally_treated': data['thermally_treated'] as bool? ?? false,
          // Diese fehlten bisher:
          'instrument_name': data['instrument_name'] as String? ?? '',
          'instrument_code': data['instrument_code'] as String? ?? '',
          'part_name': data['part_name'] as String? ?? '',
          'part_code': data['part_code'] as String? ?? '',
          'barcode': data['barcode'] as String? ?? '',
          'short_barcode': data['short_barcode'] as String? ?? '',
        };

        // Hole alle Batches für dieses Dokument
        final batchesSnapshot = await doc.reference.collection('batch').get();
        print('Found ${batchesSnapshot.docs.length} batches for document ${doc.id}');

        for (var batchDoc in batchesSnapshot.docs) {
          final batchData = batchDoc.data();
          if (batchData['stock_entry_date'] == null) continue;

          final batchDate = (batchData['stock_entry_date'] as Timestamp).toDate();

          if (_isDateInRange(batchDate, filter)) {
            final quantity = batchData['quantity'] as int? ?? 0;
            final price = baseData['price_CHF'] as double;

            // Kombiniere Batch- und Basisdaten
            final batchInfo = {
              ...baseData,  // Alle Daten vom Hauptdokument
              'batch_number': batchData['batch_number'] as int? ?? 0,
              'stock_entry_date': batchDate,
              'quantity': quantity,
              'value': quantity * price,
            };

            print('Adding batch: ${batchInfo['batch_number']} for ${batchInfo['product_name']}');
            allBatches.add(batchInfo);
          }
        }
      }

      // Sortiere nach Datum, neueste zuerst
      allBatches.sort((a, b) => (b['stock_entry_date'] as DateTime)
          .compareTo(a['stock_entry_date'] as DateTime));

      print('Returning ${allBatches.length} filtered batches');
      return allBatches;
    } catch (e, stackTrace) {
      print('Error getting filtered batches: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, double>> getProductionValue(ProductionFilter filter) async {
  final snapshot = await getProductionStream(filter).first;
  double totalValue = 0;
  final valueByType = <String, double>{};

  for (var doc in snapshot.docs) {
  final data = doc.data() as Map<String, dynamic>;
  final woodCode = data['wood_code'] as String;
  final price = (data['price_CHF'] as num).toDouble();

  // Batches summieren
  final batches = await doc.reference.collection('batch').get();
  double batchValue = 0;

  for (var batch in batches.docs) {
  final batchData = batch.data();
  final batchDate = (batchData['stock_entry_date'] as Timestamp).toDate();

  if (_isDateInRange(batchDate, filter)) {
  final quantity = batchData['quantity'] as int;
  batchValue += quantity * price;
  }
  }

  if (batchValue > 0) {
  totalValue += batchValue;
  valueByType[woodCode] = (valueByType[woodCode] ?? 0) + batchValue;
  }
  }

  return {
  'total': totalValue,
  ...valueByType,
  };
  }


  }






// Hilfsklasse für Code-Name Paare
class CodeNamePair {
  final String code;
  final String name;

  CodeNamePair({
    required this.code,
    required this.name,
  });

  @override
  String toString() => name;  // Für einfachere Anzeige in Dropdown-Menüs
}