// lib/analytics/production/services/production_cache_service.dart
//
// Cache-Service für Produktionsauswertungen.
// Logik: Jeder neue Batch setzt last_batch_at auf serverTimestamp().
// Beim Laden wird geprüft ob calculated_at > last_batch_at → Cache gültig.
// Sonst: neu berechnen + Cache schreiben.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/production/production_batch_service.dart';

class ProductionCacheService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cacheCollection = 'production_cache';

  // ============================================================
  // CACHE INVALIDIEREN (beim Buchen aufrufen)
  // ============================================================

  /// Setzt last_batch_at auf jetzt – macht den Cache für dieses Jahr ungültig.
  /// Wird in createBatch() aufgerufen.
  static Future<void> invalidateYear(int year) async {
    try {
      await _firestore.collection(_cacheCollection).doc(year.toString()).set({
        'last_batch_at': FieldValue.serverTimestamp(),
        'year': year,
      }, SetOptions(merge: true));
    } catch (e) {
      // Cache-Fehler sind nicht kritisch – Produktion trotzdem speichern
      print('Cache invalidation failed: $e');
    }
  }

  // ============================================================
  // ÜBERSICHT: getOrCalculateOverview
  // ============================================================

  /// Gibt gecachte Übersichts-Daten zurück, oder berechnet neu falls Cache veraltet.
  static Future<Map<String, dynamic>> getOrCalculateOverview(
      int year,
      ProductionBatchService service,
      ) async {
    try {
      final cacheDoc = await _firestore
          .collection(_cacheCollection)
          .doc(year.toString())
          .get();

      if (cacheDoc.exists) {
        final data = cacheDoc.data()!;
        final lastBatchAt = data['last_batch_at'] as Timestamp?;
        final overviewCalculatedAt = data['overview_calculated_at'] as Timestamp?;

        // Cache gültig wenn overview_calculated_at NACH last_batch_at
        if (lastBatchAt != null &&
            overviewCalculatedAt != null &&
            overviewCalculatedAt.compareTo(lastBatchAt) >= 0 &&
            data['overview_data'] != null) {
          return Map<String, dynamic>.from(data['overview_data']);
        }
      }
    } catch (e) {
      print('Cache read failed, calculating fresh: $e');
    }

    // Cache veraltet oder nicht vorhanden → neu berechnen
    return await _calculateAndCacheOverview(year, service);
  }

  static Future<Map<String, dynamic>> _calculateAndCacheOverview(
      int year,
      ProductionBatchService service,
      ) async {
    // Alle Batches einmal laden
    final batches = await service.getBatchesForYear(year);

    // Volumen-Map aus standardized_products laden (für Stück-Buchungen)
    final volumeMap = await _loadVolumeMap(batches);

    // Alle Aggregationen berechnen
    final summary = _calculateSummary(year, batches, volumeMap);
    final topProducts = _calculateTopProducts(batches);
    final qualityDistribution = _calculateQualityDistribution(batches);
    final woodTypeStats = _calculateWoodTypeStats(batches, volumeMap);
    final logYieldStats = _calculateLogYieldStats(batches);

    final overviewData = {
      'summary': summary,
      'top_products': topProducts,
      'quality_distribution': qualityDistribution,
      'wood_type_stats': woodTypeStats,
      'log_yield_stats': logYieldStats,
    };

    // In Firestore cachen
    try {
      // Erst prüfen ob last_batch_at schon existiert
      final existing = await _firestore
          .collection(_cacheCollection)
          .doc(year.toString())
          .get();

      final Map<String, dynamic> writeData = {
        'overview_calculated_at': FieldValue.serverTimestamp(),
        'overview_data': overviewData,
        'year': year,
      };

      // last_batch_at nur setzen wenn noch nicht vorhanden
      // (sonst würde Cache sofort wieder ungültig)
      if (existing.data()?['last_batch_at'] == null) {
        writeData['last_batch_at'] = Timestamp.fromDate(DateTime(2000));
      }

      await _firestore
          .collection(_cacheCollection)
          .doc(year.toString())
          .set(writeData, SetOptions(merge: true));
    } catch (e) {
      print('Cache write failed: $e');
    }

    return overviewData;
  }

  // ============================================================
  // STÄMME: getOrCalculateLogs
  // ============================================================

  /// Gibt gecachte Stamm-Daten zurück, oder berechnet neu falls Cache veraltet.
  static Future<Map<String, dynamic>> getOrCalculateLogs(
      int year,
      ProductionBatchService service,
      ) async {
    try {
      final cacheDoc = await _firestore
          .collection(_cacheCollection)
          .doc(year.toString())
          .get();

      if (cacheDoc.exists) {
        final data = cacheDoc.data()!;
        final lastBatchAt = data['last_batch_at'] as Timestamp?;
        final logsCalculatedAt = data['logs_calculated_at'] as Timestamp?;

        if (lastBatchAt != null &&
            logsCalculatedAt != null &&
            logsCalculatedAt.compareTo(lastBatchAt) >= 0 &&
            data['logs_data'] != null) {
          return Map<String, dynamic>.from(data['logs_data']);
        }
      }
    } catch (e) {
      print('Cache read failed, calculating fresh: $e');
    }

    return await _calculateAndCacheLogs(year, service);
  }

  static Future<Map<String, dynamic>> _calculateAndCacheLogs(
      int year,
      ProductionBatchService service,
      ) async {
    final batches = await service.getBatchesForYear(year);

    // Gruppiere nach Stamm
    final byLog = <String, List<Map<String, dynamic>>>{};
    final withoutLog = <Map<String, dynamic>>[];

    for (final batch in batches) {
      final logId = batch['roundwood_id'] as String?;
      if (logId != null && logId.isNotEmpty) {
        byLog.putIfAbsent(logId, () => []).add(batch);
      } else {
        withoutLog.add(batch);
      }
    }

    if (withoutLog.isNotEmpty) {
      byLog['_unassigned'] = withoutLog;
    }

    // Serialisierbare Zusammenfassung pro Stamm
    final logSummaries = <String, Map<String, dynamic>>{};
    for (final entry in byLog.entries) {
      double totalValue = 0;
      double totalQuantity = 0;
      for (final b in entry.value) {
        totalValue += (b['value'] as num?)?.toDouble() ?? 0;
        totalQuantity += (b['quantity'] as num?)?.toDouble() ?? 0;
      }
      logSummaries[entry.key] = {
        'total_value': totalValue,
        'total_quantity': totalQuantity,
        'batch_count': entry.value.length,
        'batches': entry.value,
      };
    }

    final logsData = {
      'total_batches': batches.length,
      'log_count': byLog.keys.where((k) => k != '_unassigned').length,
      'log_summaries': logSummaries,
    };

    try {
      final existing = await _firestore
          .collection(_cacheCollection)
          .doc(year.toString())
          .get();

      final Map<String, dynamic> writeData = {
        'logs_calculated_at': FieldValue.serverTimestamp(),
        'logs_data': logsData,
        'year': year,
      };

      if (existing.data()?['last_batch_at'] == null) {
        writeData['last_batch_at'] = Timestamp.fromDate(DateTime(2000));
      }

      await _firestore
          .collection(_cacheCollection)
          .doc(year.toString())
          .set(writeData, SetOptions(merge: true));
    } catch (e) {
      print('Cache write failed: $e');
    }

    return logsData;
  }

  // ============================================================
  // VOLUMEN: Aus standardized_products laden
  // ============================================================

  /// Lädt Volumen-Daten für alle Stück-Buchungen aus standardized_products.
  /// Gibt Map zurück: articleNumber → volumeInM3 (pro Stück)
  static Future<Map<String, double>> _loadVolumeMap(
      List<Map<String, dynamic>> batches) async {
    // Alle unique articleNumbers aus Stück-Buchungen sammeln
    final articleNumbers = <String>{};
    for (final batch in batches) {
      final unit = batch['unit'] as String? ?? 'Stück';
      if (unit == 'Stück' || unit == 'Stk') {
        final instrCode = batch['instrument_code'] as String?;
        final partCode = batch['part_code'] as String?;
        if (instrCode != null && partCode != null) {
          articleNumbers.add(instrCode + partCode);
        }
      }
    }

    if (articleNumbers.isEmpty) return {};

    final volumeMap = <String, double>{};

    // In Chunks à 30 laden (Firestore whereIn-Limit)
    final chunks = <List<String>>[];
    final list = articleNumbers.toList();
    for (int i = 0; i < list.length; i += 30) {
      chunks.add(list.sublist(i, i + 30 > list.length ? list.length : i + 30));
    }

    for (final chunk in chunks) {
      try {
        final snapshot = await _firestore
            .collection('standardized_products')
            .where('articleNumber', whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final articleNumber = data['articleNumber'] as String?;
          if (articleNumber == null) continue;

          final mm3 = data['volume']?['mm3_withAddition'];
          final dm3 = data['volume']?['dm3_withAddition'];

          if (mm3 != null && (mm3 as num) > 0) {
            volumeMap[articleNumber] = (mm3 as num).toDouble() / 1000000000.0;
          } else if (dm3 != null && (dm3 as num) > 0) {
            volumeMap[articleNumber] = (dm3 as num).toDouble() / 1000.0;
          }
        }
      } catch (e) {
        print('Volume lookup failed for chunk: $e');
      }
    }

    return volumeMap;
  }

  // ============================================================
  // LOKALE AGGREGATIONEN (keine weiteren Firestore-Reads)
  // ============================================================

  static Map<String, dynamic> _calculateSummary(
      int year,
      List<Map<String, dynamic>> batches,
      Map<String, double> volumeMap) {
    double totalValue = 0.0;
    double totalQuantity = 0.0;
    final roundwoodIds = <String>{};
    final quantitiesByUnit = <String, double>{};
    double totalVolumeM3 = 0.0;
    double volumeFromDirectM3 = 0.0;
    double volumeFromPieces = 0.0;
    int pieceBatchesTotal = 0;
    int pieceBatchesWithVolume = 0;
    double piecesWithVolume = 0.0;
    double piecesWithoutVolume = 0.0;
    // Dedupliziert nach articleNumber: pro Produkt eine Zeile mit kumulierter Menge
    final missingVolumeMap = <String, Map<String, dynamic>>{};

    for (final batch in batches) {
      final qty = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      final unit = batch['unit'] as String? ?? 'Stück';

      totalValue += (batch['value'] as num?)?.toDouble() ?? 0.0;
      totalQuantity += qty;
      quantitiesByUnit[unit] = (quantitiesByUnit[unit] ?? 0.0) + qty;

      if (unit == 'm\u00b3') {
        totalVolumeM3 += qty;
        volumeFromDirectM3 += qty;
      } else if (unit == 'Stück' || unit == 'Stk') {
        pieceBatchesTotal++;
        final instrCode = batch['instrument_code'] as String?;
        final partCode = batch['part_code'] as String?;
        if (instrCode != null && partCode != null) {
          final articleNumber = instrCode + partCode;
          final volumePerPiece = volumeMap[articleNumber];
          if (volumePerPiece != null) {
            final vol = qty * volumePerPiece;
            totalVolumeM3 += vol;
            volumeFromPieces += vol;
            pieceBatchesWithVolume++;
            piecesWithVolume += qty;
          } else {
            piecesWithoutVolume += qty;
            if (missingVolumeMap.containsKey(articleNumber)) {
              missingVolumeMap[articleNumber]!['total_quantity'] =
                  (missingVolumeMap[articleNumber]!['total_quantity'] as double) + qty;
              missingVolumeMap[articleNumber]!['batch_count'] =
                  (missingVolumeMap[articleNumber]!['batch_count'] as int) + 1;
            } else {
              missingVolumeMap[articleNumber] = {
                'article_number': articleNumber,
                'instrument_name': batch['instrument_name'] ?? '',
                'part_name': batch['part_name'] ?? '',
                'wood_name': batch['wood_name'] ?? '',
                'quality_name': batch['quality_name'] ?? '',
                'total_quantity': qty,
                'batch_count': 1,
              };
            }
          }
        } else {
          piecesWithoutVolume += qty;
        }
      }

      final roundwoodId = batch['roundwood_id'] as String?;
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
      'total_volume_m3': totalVolumeM3,
      'volume_from_direct_m3': volumeFromDirectM3,
      'volume_from_pieces': volumeFromPieces,
      'piece_batches_total': pieceBatchesTotal,
      'piece_batches_with_volume': pieceBatchesWithVolume,
      'pieces_with_volume': piecesWithVolume,
      'pieces_without_volume': piecesWithoutVolume,
      'missing_volume_products': missingVolumeMap.values.toList(),
      'unique_logs_count': roundwoodIds.length,
    };
  }

  static List<Map<String, dynamic>> _calculateTopProducts(
      List<Map<String, dynamic>> batches, {int limit = 10}) {
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
      productMap[key]!['total_quantity'] =
          (productMap[key]!['total_quantity'] as double) +
              ((batch['quantity'] as num?)?.toDouble() ?? 0.0);
      productMap[key]!['total_value'] =
          (productMap[key]!['total_value'] as double) +
              ((batch['value'] as num?)?.toDouble() ?? 0.0);
      productMap[key]!['batch_count'] =
          (productMap[key]!['batch_count'] as int) + 1;
    }

    final sorted = productMap.values.toList()
      ..sort((a, b) => (b['total_quantity'] as double)
          .compareTo(a['total_quantity'] as double));
    return sorted.take(limit).toList();
  }

  static Map<String, dynamic> _calculateQualityDistribution(
      List<Map<String, dynamic>> batches) {
    const instruments = ['10', '11', '16', '20', '22', '23'];
    const deckCode = '10';

    final relevant = batches.where((b) =>
    instruments.contains(b['instrument_code']) &&
        b['part_code'] == deckCode).toList();

    final result = <String, dynamic>{};

    for (final instrumentCode in instruments) {
      final iBatches =
      relevant.where((b) => b['instrument_code'] == instrumentCode).toList();
      if (iBatches.isEmpty) continue;

      final instrumentName = iBatches.first['instrument_name'] as String? ?? '';
      final qualityMap = <String, Map<String, dynamic>>{};
      double totalQuantity = 0.0;

      for (final batch in iBatches) {
        final qCode = batch['quality_code'] as String? ?? 'unknown';
        final qName = batch['quality_name'] as String? ?? qCode;
        final qty = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
        qualityMap.putIfAbsent(qCode, () => {'quantity': 0.0, 'quality_name': qName});
        qualityMap[qCode]!['quantity'] =
            (qualityMap[qCode]!['quantity'] as double) + qty;
        totalQuantity += qty;
      }

      final qualities = <String, dynamic>{};
      for (final entry in qualityMap.entries) {
        final qty = entry.value['quantity'] as double;
        qualities[entry.key] = {
          'quantity': qty,
          'quality_name': entry.value['quality_name'],
          'percentage': totalQuantity > 0 ? (qty / totalQuantity * 100) : 0.0,
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

  static List<Map<String, dynamic>> _calculateWoodTypeStats(
      List<Map<String, dynamic>> batches,
      Map<String, double> volumeMap) {
    final woodMap = <String, Map<String, dynamic>>{};

    for (final batch in batches) {
      final woodCode = batch['wood_code'] as String? ?? 'unknown';
      woodMap.putIfAbsent(woodCode, () => {
        'wood_code': woodCode,
        'wood_name': batch['wood_name'] ?? '',
        'total_quantity': 0.0,
        'total_value': 0.0,
        'total_volume': 0.0,
        'batch_count': 0,
      });
      final qty = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      woodMap[woodCode]!['total_quantity'] =
          (woodMap[woodCode]!['total_quantity'] as double) + qty;
      woodMap[woodCode]!['total_value'] =
          (woodMap[woodCode]!['total_value'] as double) +
              ((batch['value'] as num?)?.toDouble() ?? 0.0);
      woodMap[woodCode]!['batch_count'] =
          (woodMap[woodCode]!['batch_count'] as int) + 1;

      // Volumen berechnen: direkte m³ oder Stück × Volumen pro Stück
      final unit = batch['unit'] as String? ?? 'Stück';
      if (unit == 'm\u00b3') {
        woodMap[woodCode]!['total_volume'] =
            (woodMap[woodCode]!['total_volume'] as double) + qty;
      } else if (unit == 'Stück' || unit == 'Stk') {
        final instrCode = batch['instrument_code'] as String?;
        final partCode = batch['part_code'] as String?;
        if (instrCode != null && partCode != null) {
          final articleNumber = instrCode + partCode;
          final volumePerPiece = volumeMap[articleNumber];
          if (volumePerPiece != null) {
            woodMap[woodCode]!['total_volume'] =
                (woodMap[woodCode]!['total_volume'] as double) +
                    (qty * volumePerPiece);
          }
        }
      }
    }

    return woodMap.values.toList()
      ..sort((a, b) =>
          (b['total_value'] as double).compareTo(a['total_value'] as double));
  }

  static List<Map<String, dynamic>> _calculateLogYieldStats(
      List<Map<String, dynamic>> batches) {
    final woodMap = <String, Map<String, dynamic>>{};

    for (final batch in batches) {
      final woodCode = batch['wood_code'] as String? ?? 'unknown';
      final roundwoodId = batch['roundwood_id'] as String?;
      woodMap.putIfAbsent(woodCode, () => {
        'wood_code': woodCode,
        'wood_name': batch['wood_name'] ?? '',
        'total_value': 0.0,
        'roundwood_ids': <String>[],
      });
      woodMap[woodCode]!['total_value'] =
          (woodMap[woodCode]!['total_value'] as double) +
              ((batch['value'] as num?)?.toDouble() ?? 0.0);
      if (roundwoodId != null && roundwoodId.isNotEmpty) {
        final ids = woodMap[woodCode]!['roundwood_ids'] as List<String>;
        if (!ids.contains(roundwoodId)) ids.add(roundwoodId);
      }
    }

    final result = <Map<String, dynamic>>[];
    for (final entry in woodMap.entries) {
      final totalValue = entry.value['total_value'] as double;
      final logCount = (entry.value['roundwood_ids'] as List<String>).length;
      result.add({
        'wood_code': entry.value['wood_code'],
        'wood_name': entry.value['wood_name'],
        'total_value': totalValue,
        'log_count': logCount,
        'average_yield_per_log': logCount > 0 ? totalValue / logCount : 0.0,
        'has_log_data': logCount > 0,
      });
    }

    result.sort((a, b) => (b['average_yield_per_log'] as double)
        .compareTo(a['average_yield_per_log'] as double));
    return result;
  }
}