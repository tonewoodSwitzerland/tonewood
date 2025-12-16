import 'package:cloud_firestore/cloud_firestore.dart';

/// Service für die flache production_batches Collection
/// Ermöglicht performante Aggregationen ohne N+1 Queries
class ProductionBatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Konstanten für die relevanten Instrument-Codes (Qualitätsverteilung nur Decke)
  static const List<String> qualityDistributionInstruments = [
    '10', // Steelstring Gitarre
    '11', // Klassische Gitarre
    '16', // Bouzouki/Mandoline flach
    '20', // Violine
    '22', // Cello
    '23', // Kontrabass
  ];

  static const String deckPartCode = '10'; // Bauteil "Decke"

  // ===========================================
  // QUERIES
  // ===========================================

  /// Holt alle Batches für ein Jahr (Basis-Query)
  Future<List<Map<String, dynamic>>> getBatchesForYear(int year) async {
    final snapshot = await _firestore
        .collection('production_batches')
        .where('year', isEqualTo: year)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Stream für Echtzeit-Updates
  Stream<QuerySnapshot> getBatchesStream(int year) {
    return _firestore
        .collection('production_batches')
        .where('year', isEqualTo: year)
        .orderBy('stock_entry_date', descending: true)
        .snapshots();
  }

  /// Holt alle verfügbaren Jahre
  Future<List<int>> getAvailableYears() async {
    final snapshot = await _firestore
        .collection('production_batches')
        .orderBy('year', descending: true)
        .get();

    final years = <int>{};
    for (final doc in snapshot.docs) {
      final year = doc.data()['year'] as int?;
      if (year != null) years.add(year);
    }

    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  // ===========================================
  // AGGREGATIONEN
  // ===========================================

  /// Top 10 Produkte (Instrument + Bauteil Kombination)
  Future<List<Map<String, dynamic>>> getTopProducts(int year, {int limit = 10}) async {
    final batches = await getBatchesForYear(year);

    // Gruppiere nach Instrument + Bauteil
    final productMap = <String, Map<String, dynamic>>{};

    for (final batch in batches) {
      final key = '${batch['instrument_code']}_${batch['part_code']}';

      if (!productMap.containsKey(key)) {
        productMap[key] = {
          'instrument_code': batch['instrument_code'],
          'instrument_name': batch['instrument_name'],
          'part_code': batch['part_code'],
          'part_name': batch['part_name'],
          'total_quantity': 0.0,
          'total_value': 0.0,
          'batch_count': 0,
        };
      }

      final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      final value = (batch['value'] as num?)?.toDouble() ?? 0.0;

      productMap[key]!['total_quantity'] =
          (productMap[key]!['total_quantity'] as double) + quantity;
      productMap[key]!['total_value'] =
          (productMap[key]!['total_value'] as double) + value;
      productMap[key]!['batch_count'] =
          (productMap[key]!['batch_count'] as int) + 1;
    }

    // Sortiere nach Menge und nimm Top N
    final sorted = productMap.values.toList()
      ..sort((a, b) => (b['total_quantity'] as double)
          .compareTo(a['total_quantity'] as double));

    return sorted.take(limit).toList();
  }

  /// Qualitätsverteilung für die 6 spezifischen Instrumente (nur Decke)
  Future<Map<String, Map<String, dynamic>>> getQualityDistribution(int year) async {
    final batches = await getBatchesForYear(year);

    // Filtere nur relevante Batches (6 Instrumente + Decke)
    final relevantBatches = batches.where((b) =>
    qualityDistributionInstruments.contains(b['instrument_code']) &&
        b['part_code'] == deckPartCode
    ).toList();

    // Gruppiere nach Instrument
    final result = <String, Map<String, dynamic>>{};

    for (final instrumentCode in qualityDistributionInstruments) {
      final instrumentBatches = relevantBatches
          .where((b) => b['instrument_code'] == instrumentCode)
          .toList();

      if (instrumentBatches.isEmpty) continue;

      // Hole Instrument-Name aus erstem Batch
      final instrumentName = instrumentBatches.first['instrument_name'] as String? ?? '';

      // Gruppiere nach Qualität
      final qualityMap = <String, double>{};
      double totalQuantity = 0.0;

      for (final batch in instrumentBatches) {
        final qualityCode = batch['quality_code'] as String? ?? 'unknown';
        final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;

        qualityMap[qualityCode] = (qualityMap[qualityCode] ?? 0.0) + quantity;
        totalQuantity += quantity;
      }

      // Berechne Prozentsätze
      final qualities = <String, Map<String, dynamic>>{};
      for (final entry in qualityMap.entries) {
        qualities[entry.key] = {
          'quantity': entry.value,
          'percentage': totalQuantity > 0
              ? (entry.value / totalQuantity * 100)
              : 0.0,
        };
      }

      result[instrumentCode] = {
        'instrument_name': instrumentName,
        'total_quantity': totalQuantity,
        'qualities': qualities,
      };
    }

    return result;
  }

  /// Menge und Wert nach Holzart
  Future<List<Map<String, dynamic>>> getStatsByWoodType(int year) async {
    final batches = await getBatchesForYear(year);

    final woodMap = <String, Map<String, dynamic>>{};

    for (final batch in batches) {
      final woodCode = batch['wood_code'] as String? ?? 'unknown';

      if (!woodMap.containsKey(woodCode)) {
        woodMap[woodCode] = {
          'wood_code': woodCode,
          'wood_name': batch['wood_name'] ?? '',
          'total_quantity': 0.0,
          'total_value': 0.0,
          'batch_count': 0,
          'quantities_by_unit': <String, double>{},
        };
      }

      final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      final value = (batch['value'] as num?)?.toDouble() ?? 0.0;
      final unit = batch['unit'] as String? ?? 'Stk';

      woodMap[woodCode]!['total_quantity'] =
          (woodMap[woodCode]!['total_quantity'] as double) + quantity;
      woodMap[woodCode]!['total_value'] =
          (woodMap[woodCode]!['total_value'] as double) + value;
      woodMap[woodCode]!['batch_count'] =
          (woodMap[woodCode]!['batch_count'] as int) + 1;

      final unitMap = woodMap[woodCode]!['quantities_by_unit'] as Map<String, double>;
      unitMap[unit] = (unitMap[unit] ?? 0.0) + quantity;
    }

    // Sortiere nach Wert absteigend
    final sorted = woodMap.values.toList()
      ..sort((a, b) => (b['total_value'] as double)
          .compareTo(a['total_value'] as double));

    return sorted;
  }

  /// Durchschnittserlös pro Stamm nach Holzart
  Future<List<Map<String, dynamic>>> getAverageYieldPerLog(int year) async {
    final batches = await getBatchesForYear(year);

    // Gruppiere nach Holzart und zähle unique Stämme
    final woodMap = <String, Map<String, dynamic>>{};

    for (final batch in batches) {
      final woodCode = batch['wood_code'] as String? ?? 'unknown';
      final roundwoodId = batch['roundwood_id'] as String?;

      if (!woodMap.containsKey(woodCode)) {
        woodMap[woodCode] = {
          'wood_code': woodCode,
          'wood_name': batch['wood_name'] ?? '',
          'total_value': 0.0,
          'roundwood_ids': <String>{}, // Set für unique Stämme
        };
      }

      final value = (batch['value'] as num?)?.toDouble() ?? 0.0;
      woodMap[woodCode]!['total_value'] =
          (woodMap[woodCode]!['total_value'] as double) + value;

      // Nur Stämme zählen die zugeordnet sind
      if (roundwoodId != null && roundwoodId.isNotEmpty) {
        (woodMap[woodCode]!['roundwood_ids'] as Set<String>).add(roundwoodId);
      }
    }

    // Berechne Durchschnitt
    final result = <Map<String, dynamic>>[];

    for (final entry in woodMap.entries) {
      final totalValue = entry.value['total_value'] as double;
      final logCount = (entry.value['roundwood_ids'] as Set<String>).length;

      result.add({
        'wood_code': entry.value['wood_code'],
        'wood_name': entry.value['wood_name'],
        'total_value': totalValue,
        'log_count': logCount,
        'average_yield_per_log': logCount > 0 ? totalValue / logCount : 0.0,
        'has_log_data': logCount > 0,
      });
    }

    // Sortiere nach Durchschnittserlös absteigend
    result.sort((a, b) => (b['average_yield_per_log'] as double)
        .compareTo(a['average_yield_per_log'] as double));

    return result;
  }

  /// Gesamtstatistiken für ein Jahr
  Future<Map<String, dynamic>> getYearSummary(int year) async {
    final batches = await getBatchesForYear(year);

    double totalValue = 0.0;
    double totalQuantity = 0.0;
    final roundwoodIds = <String>{};
    final quantitiesByUnit = <String, double>{};

    for (final batch in batches) {
      final value = (batch['value'] as num?)?.toDouble() ?? 0.0;
      final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      final unit = batch['unit'] as String? ?? 'Stk';
      final roundwoodId = batch['roundwood_id'] as String?;

      totalValue += value;
      totalQuantity += quantity;
      quantitiesByUnit[unit] = (quantitiesByUnit[unit] ?? 0.0) + quantity;

      if (roundwoodId != null && roundwoodId.isNotEmpty) {
        roundwoodIds.add(roundwoodId);
      }
    }

    return {
      'year': year,
      'total_batches': batches.length,
      'total_value': totalValue,
      'total_quantity': totalQuantity,
      'quantities_by_unit': quantitiesByUnit,
      'unique_logs_count': roundwoodIds.length,
    };
  }

  // ===========================================
  // STAMM-DETAILS
  // ===========================================

  /// Holt alle Batches für einen bestimmten Stamm
  Future<List<Map<String, dynamic>>> getBatchesForLog(String roundwoodId) async {
    final snapshot = await _firestore
        .collection('production_batches')
        .where('roundwood_id', isEqualTo: roundwoodId)
        .orderBy('stock_entry_date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Berechnet den Gesamterlös für einen Stamm
  Future<Map<String, dynamic>> getLogYield(String roundwoodId) async {
    final batches = await getBatchesForLog(roundwoodId);

    double totalValue = 0.0;
    double totalQuantity = 0.0;
    final products = <String, Map<String, dynamic>>{};

    for (final batch in batches) {
      final value = (batch['value'] as num?)?.toDouble() ?? 0.0;
      final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      final productKey = '${batch['instrument_name']} ${batch['part_name']}';

      totalValue += value;
      totalQuantity += quantity;

      if (!products.containsKey(productKey)) {
        products[productKey] = {
          'name': productKey,
          'quantity': 0.0,
          'value': 0.0,
        };
      }
      products[productKey]!['quantity'] =
          (products[productKey]!['quantity'] as double) + quantity;
      products[productKey]!['value'] =
          (products[productKey]!['value'] as double) + value;
    }

    return {
      'roundwood_id': roundwoodId,
      'total_value': totalValue,
      'total_quantity': totalQuantity,
      'batch_count': batches.length,
      'products': products.values.toList(),
    };
  }

  // ===========================================
  // ROUNDWOOD HELPER
  // ===========================================

  /// Holt verfügbare Stämme für eine Holzart (für Stamm-Auswahl Dialog)
  Future<List<Map<String, dynamic>>> getAvailableRoundwood({
    required String woodCode,
    int? year,
  }) async {
    Query query = _firestore.collection('roundwood')
        .where('wood_type', isEqualTo: woodCode);

    if (year != null) {
      query = query.where('year', isEqualTo: year);
    }

    final snapshot = await query.orderBy('internal_number').get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'internal_number': data['internal_number'],
        'year': data['year'],
        'original_number': data['original_number'],
        'wood_name': data['wood_name'],
        'quality': data['quality'],
        'is_moonwood': data['is_moonwood'] ?? false,
        'is_fsc': data['is_fsc'] ?? false,
        'display_name': '${data['internal_number']}/${data['year']} - ${data['original_number'] ?? ''}',
      };
    }).toList();
  }

  // ===========================================
  // BATCH ERSTELLEN (wird von _saveStockEntry aufgerufen)
  // ===========================================

  /// Erstellt einen neuen Batch in der flachen Collection
  Future<DocumentReference> createBatch({
    required String productId,
    required int batchNumber,
    required int quantity,
    required Map<String, dynamic> productData,
    String? roundwoodId,
    Map<String, dynamic>? roundwoodData,
  }) async {
    final price = (productData['price_CHF'] as num?)?.toDouble() ?? 0.0;
    final value = quantity * price;

    final batchData = {
      // Referenzen
      'product_id': productId,
      'batch_number': batchNumber,
      'roundwood_id': roundwoodId,
      'roundwood_internal_number': roundwoodData?['internal_number'],
      'roundwood_year': roundwoodData?['year'],

      // Zeitdaten
      'stock_entry_date': FieldValue.serverTimestamp(),
      'year': productData['year'] ?? DateTime.now().year,

      // Mengen
      'quantity': quantity,
      'value': value,
      'unit': productData['unit'] ?? 'Stk',
      'price_CHF': price,

      // Produkt-Details (denormalisiert)
      'instrument_code': productData['instrument_code'],
      'instrument_name': productData['instrument_name'],
      'part_code': productData['part_code'],
      'part_name': productData['part_name'],
      'wood_code': productData['wood_code'],
      'wood_name': productData['wood_name'],
      'quality_code': productData['quality_code'],
      'quality_name': productData['quality_name'],

      // Spezial-Flags
      'moonwood': productData['moonwood'] ?? false,
      'haselfichte': productData['haselfichte'] ?? false,
      'thermally_treated': productData['thermally_treated'] ?? false,
      'FSC_100': productData['FSC_100'] ?? false,
    };

    return await _firestore.collection('production_batches').add(batchData);
  }

  /// Aktualisiert die Stamm-Zuordnung eines bestehenden Batches
  Future<void> updateBatchRoundwood({
    required String batchId,
    required String roundwoodId,
    required Map<String, dynamic> roundwoodData,
  }) async {
    await _firestore.collection('production_batches').doc(batchId).update({
      'roundwood_id': roundwoodId,
      'roundwood_internal_number': roundwoodData['internal_number'],
      'roundwood_year': roundwoodData['year'],
    });
  }
}