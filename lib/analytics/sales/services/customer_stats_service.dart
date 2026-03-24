// lib/analytics/sales/services/customer_stats_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_sales_stats.dart';

/// Service für vorberechnete Kunden-Verkaufsstatistiken.
///
/// Stats werden in einer Subcollection gespeichert:
///   customers/{customerId}/customer_stats/summary
///
/// Aktualisierung erfolgt inkrementell bei:
///   - Status-Änderung zu 'shipped'  → addOrderToStats()
///   - Status-Änderung zu 'cancelled' → removeOrderFromStats()
class CustomerStatsService {
  static final _db = FirebaseFirestore.instance;

  // ============================================================
  // READ
  // ============================================================

  /// Stats für einen einzelnen Kunden laden
  static Future<CustomerSalesStats> getStats(String customerId) async {
    final doc = await _db
        .collection('customers')
        .doc(customerId)
        .collection('customer_stats')
        .doc('summary')
        .get();

    if (!doc.exists || doc.data() == null) {
      return CustomerSalesStats.empty();
    }
    return CustomerSalesStats.fromMap(doc.data()!);
  }

  /// Stream für Echtzeit-Updates
  static Stream<CustomerSalesStats> getStatsStream(String customerId) {
    return _db
        .collection('customers')
        .doc(customerId)
        .collection('customer_stats')
        .doc('summary')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return CustomerSalesStats.empty();
      }
      return CustomerSalesStats.fromMap(doc.data()!);
    });
  }

  /// Stats für mehrere Kunden laden (für Übersicht)
  static Future<Map<String, CustomerSalesStats>> getStatsForCustomers(
      List<String> customerIds,
      ) async {
    final result = <String, CustomerSalesStats>{};

    // Firestore erlaubt max 30 IDs pro Batch
    for (var i = 0; i < customerIds.length; i += 30) {
      final batchIds = customerIds.sublist(
        i,
        i + 30 > customerIds.length ? customerIds.length : i + 30,
      );

      // Parallel laden
      final futures = batchIds.map((id) async {
        final stats = await getStats(id);
        return MapEntry(id, stats);
      });

      final entries = await Future.wait(futures);
      result.addAll(Map.fromEntries(entries));
    }

    return result;
  }

  /// Alle Kunden-Stats laden (für Kunden-Analytics-Übersicht)
  static Future<Map<String, CustomerSalesStats>> getAllStats() async {
    final customers = await _db.collection('customers').get();
    final result = <String, CustomerSalesStats>{};

    for (final customerDoc in customers.docs) {
      final statsDoc = await _db
          .collection('customers')
          .doc(customerDoc.id)
          .collection('customer_stats')
          .doc('summary')
          .get();

      if (statsDoc.exists && statsDoc.data() != null) {
        result[customerDoc.id] = CustomerSalesStats.fromMap(statsDoc.data()!);
      }
    }

    return result;
  }

  // ============================================================
  // SEGMENT CONFIG
  // ============================================================

  /// Segmentierungs-Konfiguration laden
  static Future<CustomerSegmentConfig> getSegmentConfig() async {
    final doc = await _db
        .collection('settings')
        .doc('customer_segments')
        .get();

    if (!doc.exists || doc.data() == null) {
      // Default-Werte erstellen und speichern
      const config = CustomerSegmentConfig();
      await _db
          .collection('settings')
          .doc('customer_segments')
          .set(config.toMap());
      return config;
    }

    return CustomerSegmentConfig.fromMap(doc.data()!);
  }

  /// Segmentierungs-Konfiguration speichern
  static Future<void> saveSegmentConfig(CustomerSegmentConfig config) async {
    await _db
        .collection('settings')
        .doc('customer_segments')
        .set(config.toMap());
  }

  // ============================================================
  // INKREMENTELLES UPDATE (bei shipped)
  // ============================================================

  /// Wird aufgerufen wenn ein Auftrag auf 'shipped' gesetzt wird.
  /// Addiert die Order-Daten inkrementell zu den bestehenden Stats.
  static Future<void> addOrderToStats(
      String customerId,
      Map<String, dynamic> orderData,
      ) async {
    final statsRef = _db
        .collection('customers')
        .doc(customerId)
        .collection('customer_stats')
        .doc('summary');

    await _db.runTransaction((transaction) async {
      final statsDoc = await transaction.get(statsRef);
      final existing = statsDoc.exists && statsDoc.data() != null
          ? statsDoc.data()!
          : <String, dynamic>{};

      final updated = _applyOrderDelta(existing, orderData, add: true);
      transaction.set(statsRef, updated, SetOptions(merge: false));
    });
  }

  /// Wird aufgerufen wenn ein versendeter Auftrag storniert wird.
  /// Zieht die Order-Daten von den bestehenden Stats ab.
  static Future<void> removeOrderFromStats(
      String customerId,
      Map<String, dynamic> orderData,
      ) async {
    final statsRef = _db
        .collection('customers')
        .doc(customerId)
        .collection('customer_stats')
        .doc('summary');

    await _db.runTransaction((transaction) async {
      final statsDoc = await transaction.get(statsRef);

      if (!statsDoc.exists || statsDoc.data() == null) return;

      final existing = statsDoc.data()!;
      final updated = _applyOrderDelta(existing, orderData, add: false);
      transaction.set(statsRef, updated, SetOptions(merge: false));
    });
  }

  // ============================================================
  // DELTA BERECHNUNG
  // ============================================================

  /// Wendet eine Order inkrementell auf die Stats an.
  /// [add] = true → addieren (shipped), false → subtrahieren (cancelled)
  static Map<String, dynamic> _applyOrderDelta(
      Map<String, dynamic> existing,
      Map<String, dynamic> orderData, {
        required bool add,
      }) {
    final sign = add ? 1 : -1;

    // Order-Datum parsen
    final orderDateRaw = orderData['orderDate'];
    DateTime? orderDate;
    if (orderDateRaw is Timestamp) orderDate = orderDateRaw.toDate();
    if (orderDateRaw is String) orderDate = DateTime.tryParse(orderDateRaw);

    // Berechnungen
    final calculations = orderData['calculations'] as Map<String, dynamic>? ?? {};
    final subtotalRaw = (calculations['subtotal'] as num?)?.toDouble() ?? 0;
    final itemDiscounts = (calculations['item_discounts'] as num?)?.toDouble() ?? 0;
    final totalDiscountAmount = (calculations['total_discount_amount'] as num?)?.toDouble() ?? 0;
    final discount = itemDiscounts > 0 ? itemDiscounts : totalDiscountAmount;
    final netRevenue = subtotalRaw - discount;
    final grossTotal = (calculations['total'] as num?)?.toDouble() ?? 0;

    // Items analysieren
    final items = orderData['items'] as List<dynamic>? ?? [];
    int itemCount = 0;
    int totalQuantity = 0;

    // Produkt-Map für Top-Produkte
    Map<String, Map<String, dynamic>> productMap = {};
    // Bestehende Top-Produkte laden
    final existingTopProducts = existing['topProducts'] as List<dynamic>? ?? [];
    for (final p in existingTopProducts) {
      final pm = Map<String, dynamic>.from(p);
      productMap[pm['productId'] ?? ''] = pm;
    }

    // Verteilungen
    Map<String, double> woodRevenue = Map<String, double>.from(
        (existing['woodTypeRevenue'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
    );
    Map<String, int> woodQuantity = Map<String, int>.from(
        (existing['woodTypeQuantity'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
    );
    Map<String, double> woodVolume = Map<String, double>.from(
        (existing['woodTypeVolume'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
    );
    Map<String, double> instrumentRevenue = Map<String, double>.from(
        (existing['instrumentRevenue'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
    );
    Map<String, int> instrumentQuantity = Map<String, int>.from(
        (existing['instrumentQuantity'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
    );

    for (final item in items) {
      final itemData = Map<String, dynamic>.from(item);
      final qty = (itemData['quantity'] as num?)?.toInt() ?? 0;
      final pricePerUnit = (itemData['price_per_unit'] as num?)?.toDouble() ?? 0;
      final itemRevenue = qty * pricePerUnit;
      final volumePerUnit = (itemData['volume_per_unit'] as num?)?.toDouble() ?? 0;
      final itemVolume = qty * volumePerUnit;

      itemCount++;
      totalQuantity += qty;

      // Produkt-Stats
      final productId = itemData['product_id']?.toString() ?? '';
      if (productId.isNotEmpty) {
        if (!productMap.containsKey(productId)) {
          productMap[productId] = {
            'productId': productId,
            'productName': itemData['product_name']?.toString() ?? '',
            'quantity': 0,
            'revenue': 0.0,
            'instrumentCode': itemData['instrument_code'],
            'instrumentName': itemData['instrument_name'],
            'partCode': itemData['part_code'],
            'partName': itemData['part_name'],
            'woodCode': itemData['wood_code'],
            'woodName': itemData['wood_name'],
          };
        }
        productMap[productId]!['quantity'] =
            ((productMap[productId]!['quantity'] as num?) ?? 0) + (qty * sign);
        productMap[productId]!['revenue'] =
            ((productMap[productId]!['revenue'] as num?)?.toDouble() ?? 0) + (itemRevenue * sign);
      }

      // Holzart
      final woodCode = itemData['wood_code']?.toString() ?? '';
      if (woodCode.isNotEmpty) {
        woodRevenue[woodCode] = (woodRevenue[woodCode] ?? 0) + (itemRevenue * sign);
        woodQuantity[woodCode] = (woodQuantity[woodCode] ?? 0) + (qty * sign);
        woodVolume[woodCode] = (woodVolume[woodCode] ?? 0) + (itemVolume * sign);
      }

      // Instrument
      final instrumentCode = itemData['instrument_code']?.toString() ?? '';
      if (instrumentCode.isNotEmpty) {
        instrumentRevenue[instrumentCode] =
            (instrumentRevenue[instrumentCode] ?? 0) + (itemRevenue * sign);
        instrumentQuantity[instrumentCode] =
            (instrumentQuantity[instrumentCode] ?? 0) + (qty * sign);
      }
    }

    // Top 5 Produkte sortieren (nach Revenue)
    final sortedProducts = productMap.values
        .where((p) => ((p['revenue'] as num?)?.toDouble() ?? 0) > 0)
        .toList()
      ..sort((a, b) =>
          ((b['revenue'] as num?)?.toDouble() ?? 0)
              .compareTo((a['revenue'] as num?)?.toDouble() ?? 0));
    final top5Products = sortedProducts.take(5).toList();

    // Zeitraum berechnen
    final now = DateTime.now();
    final currentYearStart = DateTime(now.year, 1, 1);
    final previousYearStart = DateTime(now.year - 1, 1, 1);
    final previousYearEnd = DateTime(now.year - 1, 12, 31, 23, 59, 59);

    // Bestehende Werte
    final oldTotalOrders = (existing['totalOrders'] as num?)?.toInt() ?? 0;
    final oldTotalRevenue = (existing['totalRevenue'] as num?)?.toDouble() ?? 0;
    final oldTotalRevenueGross = (existing['totalRevenueGross'] as num?)?.toDouble() ?? 0;

    final newTotalOrders = oldTotalOrders + (1 * sign);
    final newTotalRevenue = oldTotalRevenue + (netRevenue * sign);
    final newTotalRevenueGross = oldTotalRevenueGross + (grossTotal * sign);

    // Monatliche Daten
    Map<String, double> monthlyRevenue = Map<String, double>.from(
        (existing['monthlyRevenue'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
    );
    Map<String, int> monthlyOrders = Map<String, int>.from(
        (existing['monthlyOrders'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
    );

    if (orderDate != null) {
      final monthKey = '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}';
      monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + (netRevenue * sign);
      monthlyOrders[monthKey] = (monthlyOrders[monthKey] ?? 0) + (1 * sign);
    }

    // Year-spezifische Werte
    double yearRevenueDelta = 0;
    double yearRevenueGrossDelta = 0;
    int yearOrdersDelta = 0;
    double prevYearRevenueDelta = 0;
    double prevYearRevenueGrossDelta = 0;
    int prevYearOrdersDelta = 0;

    if (orderDate != null) {
      if (orderDate.isAfter(currentYearStart) ||
          orderDate.isAtSameMomentAs(currentYearStart)) {
        yearRevenueDelta = netRevenue * sign;
        yearRevenueGrossDelta = grossTotal * sign;
        yearOrdersDelta = 1 * sign;
      }
      if (orderDate.isAfter(previousYearStart) &&
          orderDate.isBefore(previousYearEnd)) {
        prevYearRevenueDelta = netRevenue * sign;
        prevYearRevenueGrossDelta = grossTotal * sign;
        prevYearOrdersDelta = 1 * sign;
      }
    }

    // Order-Monate (Saisonalität)
    List<String> orderMonths = List<String>.from(existing['orderMonths'] ?? []);
    if (orderDate != null && add) {
      final monthStr = orderDate.month.toString().padLeft(2, '0');
      if (!orderMonths.contains(monthStr)) {
        orderMonths.add(monthStr);
        orderMonths.sort();
      }
    }

    // First/Last Order Dates
    DateTime? existingFirstDate;
    DateTime? existingLastDate;
    final rawFirst = existing['firstOrderDate'];
    final rawLast = existing['lastOrderDate'];
    if (rawFirst is Timestamp) existingFirstDate = rawFirst.toDate();
    if (rawLast is Timestamp) existingLastDate = rawLast.toDate();

    DateTime? newFirstDate = existingFirstDate;
    DateTime? newLastDate = existingLastDate;

    if (add && orderDate != null) {
      if (newFirstDate == null || orderDate.isBefore(newFirstDate)) {
        newFirstDate = orderDate;
      }
      if (newLastDate == null || orderDate.isAfter(newLastDate)) {
        newLastDate = orderDate;
      }
    }

    // Ø Bestellfrequenz berechnen
    double avgFrequency = 0;
    if (newFirstDate != null && newLastDate != null && newTotalOrders > 1) {
      final spanDays = newLastDate.difference(newFirstDate).inDays;
      avgFrequency = spanDays / (newTotalOrders - 1);
    }

    // Negative Werte verhindern
    final safeTotalOrders = newTotalOrders < 0 ? 0 : newTotalOrders;
    final safeTotalRevenue = newTotalRevenue < 0 ? 0.0 : newTotalRevenue;

    return {
      'totalRevenue': safeTotalRevenue,
      'totalRevenueGross': newTotalRevenueGross < 0 ? 0.0 : newTotalRevenueGross,
      'totalDiscount': ((existing['totalDiscount'] as num?)?.toDouble() ?? 0) + (discount * sign),
      'totalOrders': safeTotalOrders,
      'totalItems': ((existing['totalItems'] as num?)?.toInt() ?? 0) + (itemCount * sign),
      'totalQuantity': ((existing['totalQuantity'] as num?)?.toInt() ?? 0) + (totalQuantity * sign),
      'yearRevenue': ((existing['yearRevenue'] as num?)?.toDouble() ?? 0) + yearRevenueDelta,
      'yearRevenueGross': ((existing['yearRevenueGross'] as num?)?.toDouble() ?? 0) + yearRevenueGrossDelta,
      'yearOrders': ((existing['yearOrders'] as num?)?.toInt() ?? 0) + yearOrdersDelta,
      'previousYearRevenue': ((existing['previousYearRevenue'] as num?)?.toDouble() ?? 0) + prevYearRevenueDelta,
      'previousYearRevenueGross': ((existing['previousYearRevenueGross'] as num?)?.toDouble() ?? 0) + prevYearRevenueGrossDelta,
      'previousYearOrders': ((existing['previousYearOrders'] as num?)?.toInt() ?? 0) + prevYearOrdersDelta,
      'monthlyRevenue': monthlyRevenue,
      'monthlyOrders': monthlyOrders,
      'averageOrderValue': safeTotalOrders > 0 ? safeTotalRevenue / safeTotalOrders : 0,
      'averageOrderValueGross': safeTotalOrders > 0
          ? (newTotalRevenueGross < 0 ? 0.0 : newTotalRevenueGross) / safeTotalOrders
          : 0,
      'firstOrderDate': newFirstDate != null ? Timestamp.fromDate(newFirstDate) : null,
      'lastOrderDate': newLastDate != null ? Timestamp.fromDate(newLastDate) : null,
      'averageOrderFrequencyDays': avgFrequency,
      'orderMonths': orderMonths,
      'topProducts': top5Products,
      'woodTypeRevenue': woodRevenue,
      'woodTypeQuantity': woodQuantity,
      'woodTypeVolume': woodVolume,
      'instrumentRevenue': instrumentRevenue,
      'instrumentQuantity': instrumentQuantity,
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastOrderId': orderData['orderNumber']?.toString() ?? '',
    };
  }

  // ============================================================
  // VOLLSTÄNDIGE NEUBERECHNUNG
  // ============================================================

  /// Stats für einen einzelnen Kunden komplett neu berechnen
  static Future<void> rebuildStatsForCustomer(String customerId) async {
    final orders = await _db
        .collection('orders')
        .where('customer.id', isEqualTo: customerId)
        .where('status', isEqualTo: 'shipped')
        .get();

    if (orders.docs.isEmpty) {
      // Leere Stats schreiben
      await _db
          .collection('customers')
          .doc(customerId)
          .collection('customer_stats')
          .doc('summary')
          .set(CustomerSalesStats.empty().toMap());
      return;
    }

    // Starte mit leeren Stats und addiere jede Order
    Map<String, dynamic> stats = {};
    for (final doc in orders.docs) {
      stats = _applyOrderDelta(stats, doc.data(), add: true);
    }

    await _db
        .collection('customers')
        .doc(customerId)
        .collection('customer_stats')
        .doc('summary')
        .set(stats);
  }

  /// MIGRATION: Alle Kunden-Stats neu berechnen
  /// Gibt Fortschritt zurück via Callback
  static Future<int> rebuildAllCustomerStats({
    void Function(int processed, int total)? onProgress,
  }) async {
    // Alle shipped Orders laden
    final ordersSnapshot = await _db
        .collection('orders')
        .where('status', isEqualTo: 'shipped')
        .get();

    // Nach Kunde gruppieren
    final Map<String, List<Map<String, dynamic>>> ordersByCustomer = {};

    for (final doc in ordersSnapshot.docs) {
      final data = doc.data();
      final customerId = (data['customer'] as Map<String, dynamic>?)?['id']?.toString();
      if (customerId == null || customerId.isEmpty) continue;

      ordersByCustomer.putIfAbsent(customerId, () => []).add(data);
    }

    int processed = 0;
    final total = ordersByCustomer.length;

    // Batch-weise verarbeiten
    WriteBatch? batch;
    int batchCount = 0;
    const batchLimit = 400; // Firestore Batch-Limit ist 500, lassen Puffer

    for (final entry in ordersByCustomer.entries) {
      batch ??= _db.batch();

      // Stats berechnen
      Map<String, dynamic> stats = {};
      for (final orderData in entry.value) {
        stats = _applyOrderDelta(stats, orderData, add: true);
      }

      final statsRef = _db
          .collection('customers')
          .doc(entry.key)
          .collection('customer_stats')
          .doc('summary');

      batch.set(statsRef, stats);
      batchCount++;

      if (batchCount >= batchLimit) {
        await batch.commit();
        batch = null;
        batchCount = 0;
      }

      processed++;
      onProgress?.call(processed, total);
    }

    // Restliche Batch-Writes
    if (batch != null && batchCount > 0) {
      await batch.commit();
    }

    return processed;
  }

  // ============================================================
  // JAHRESWECHSEL
  // ============================================================

  /// Rotiert yearRevenue → previousYearRevenue für alle Kunden.
  /// Sollte einmal am 1. Januar ausgeführt werden oder beim ersten
  /// Zugriff im neuen Jahr geprüft werden.
  static Future<void> rotateYearStats() async {
    final customers = await _db.collection('customers').get();

    WriteBatch? batch;
    int batchCount = 0;

    for (final customerDoc in customers.docs) {
      batch ??= _db.batch();

      final statsRef = _db
          .collection('customers')
          .doc(customerDoc.id)
          .collection('customer_stats')
          .doc('summary');

      final statsDoc = await statsRef.get();
      if (!statsDoc.exists || statsDoc.data() == null) continue;

      final data = statsDoc.data()!;

      batch.update(statsRef, {
        'previousYearRevenue': data['yearRevenue'] ?? 0,
        'previousYearRevenueGross': data['yearRevenueGross'] ?? 0,
        'previousYearOrders': data['yearOrders'] ?? 0,
        'yearRevenue': 0,
        'yearRevenueGross': 0,
        'yearOrders': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      batchCount++;
      if (batchCount >= 400) {
        await batch.commit();
        batch = null;
        batchCount = 0;
      }
    }

    if (batch != null && batchCount > 0) {
      await batch.commit();
    }

    // Marker setzen, damit wir wissen dass die Rotation durchgeführt wurde
    await _db.collection('settings').doc('customer_stats_meta').set({
      'lastYearRotation': FieldValue.serverTimestamp(),
      'rotatedYear': DateTime.now().year,
    }, SetOptions(merge: true));
  }

  /// Prüft ob die Jahres-Rotation noch durchgeführt werden muss
  static Future<bool> needsYearRotation() async {
    final doc = await _db.collection('settings').doc('customer_stats_meta').get();
    if (!doc.exists || doc.data() == null) return true;

    final rotatedYear = doc.data()!['rotatedYear'] as int?;
    return rotatedYear != DateTime.now().year;
  }

  // ============================================================
  // HELPER: Order-Daten aus Firestore laden (für Trigger)
  // ============================================================

  /// Lädt die Order-Daten direkt aus Firestore anhand der Order-ID
  static Future<Map<String, dynamic>?> _loadOrderData(String orderId) async {
    final doc = await _db.collection('orders').doc(orderId).get();
    if (!doc.exists || doc.data() == null) return null;
    return doc.data();
  }

  /// Convenience-Methode: Wird vom Order-Screen aufgerufen
  /// Lädt die Order-Daten und aktualisiert die Stats
  static Future<void> handleOrderShipped(String orderId) async {
    final orderData = await _loadOrderData(orderId);
    if (orderData == null) return;

    final customerId = (orderData['customer'] as Map<String, dynamic>?)?['id']?.toString();
    if (customerId == null || customerId.isEmpty) return;

    await addOrderToStats(customerId, orderData);
  }

  /// Convenience-Methode: Wird aufgerufen wenn ein shipped Auftrag storniert wird
  static Future<void> handleOrderCancelled(String orderId) async {
    final orderData = await _loadOrderData(orderId);
    if (orderData == null) return;

    final customerId = (orderData['customer'] as Map<String, dynamic>?)?['id']?.toString();
    if (customerId == null || customerId.isEmpty) return;

    await removeOrderFromStats(customerId, orderData);
  }
}
