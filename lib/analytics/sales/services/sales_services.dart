import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_filter.dart';
import '../models/sales_models.dart';

class SalesService {
  final _db = FirebaseFirestore.instance;

  Stream<SalesStats> getSalesStatsStream(SalesFilter filter) {
    DateTime? startDate;
    DateTime? endDate;

    // Zeitraum aus Filter bestimmen
    if (filter.timeRange != null) {
      endDate = DateTime.now();
      switch (filter.timeRange) {
        case 'week':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        case 'quarter':
          startDate = endDate.subtract(const Duration(days: 90));
          break;
        case 'year':
          startDate = endDate.subtract(const Duration(days: 365));
          break;
      }
    } else {
      startDate = filter.startDate;
      endDate = filter.endDate;
    }

    // Basis-Query erstellen
    Query salesQuery = _db.collection('sales_receipts');

    // Zeitraum-Filter anwenden
    if (startDate != null) {
      salesQuery = salesQuery.where('metadata.timestamp', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      salesQuery = salesQuery.where('metadata.timestamp', isLessThanOrEqualTo: endDate);
    }

    // Kunden-Filter anwenden
    if (filter.selectedCustomers != null && filter.selectedCustomers!.isNotEmpty) {
      salesQuery = salesQuery.where('customer.id', whereIn: filter.selectedCustomers);
    }

    print("Messe");
    print(filter.selectedFairs);

    print("Customer");
    print(filter.selectedCustomers);


    // Messe-Filter anwenden
    if (filter.selectedFairs != null && filter.selectedFairs!.isNotEmpty) {
      salesQuery = salesQuery.where('fair.id', whereIn: filter.selectedFairs);
    }

    return salesQuery.snapshots().asyncMap((snapshot) async {

      print('Number of documents: ${snapshot.docs.length}');
      double totalRevenue = 0;
      Map<String, TopCustomer> customerStats = {};
      Map<String, ProductStats> productStats = {};
      Map<String, double> woodTypeDistribution = {};
      Map<String, double> monthlyRevenue = {};

      // Dokumente filtern und verarbeiten
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Prüfen ob der Verkauf die Filter-Kriterien erfüllt
        if (!_meetsCriteria(data, filter)) continue;

        final calculations = data['calculations'] as Map<String, dynamic>?;
        if (calculations == null) continue;

        final total = (calculations['total'] as num?)?.toDouble() ?? 0;
        final netAmount = (calculations['net_amount'] as num?)?.toDouble() ?? 0;

        // Kunden-Informationen
        final customerData = data['customer'] as Map<String, dynamic>?;
        print(customerData);
        if (customerData == null) continue;

        final customerId = customerData['id']?.toString();
        final firstName = customerData['firstName'] as String? ?? '';
        final lastName = customerData['lastName'] as String? ?? '';
        final company = customerData['company'] as String? ?? '';
        final customerName = company.isNotEmpty ? company : '$firstName $lastName'.trim();
// DEBUG: Print customer details
        print('Processing customer: ID=$customerId, Company=$company, Name=$customerName');
        // Items verarbeiten
        final itemsList = data['items'] as List<dynamic>?;
        if (itemsList == null) continue;

        bool hasMatchingProduct = false;
        double receiptTotal = 0;

        for (var item in itemsList) {
          final itemData = item as Map<String, dynamic>;

          final productId = itemData['product_id']?.toString();
          final productName = itemData['product_name']?.toString();
          final quantity = itemData['quantity'] as num?;
          final itemSubtotal = (itemData['subtotal'] as num?)?.toDouble();
          final woodCode = itemData['wood_code']?.toString();
          final quality = itemData['quality']?.toString();
          final part = itemData['part']?.toString();

          if (productId == null || productName == null ||
              quantity == null || itemSubtotal == null || woodCode == null) {
            continue;
          }

          // Produkt-Filter prüfen
          if (filter.selectedProducts != null && filter.selectedProducts!.isNotEmpty) {
            if (!filter.selectedProducts!.contains(productId)) continue;
            hasMatchingProduct = true;
          }

          // Holzart-Filter prüfen
          if (filter.woodTypes != null && filter.woodTypes!.isNotEmpty) {
            if (!filter.woodTypes!.contains(woodCode)) continue;
            hasMatchingProduct = true;
          }

          // Qualitäts-Filter prüfen
          if (filter.qualities != null && filter.qualities!.isNotEmpty) {
            if (!filter.qualities!.contains(quality)) continue;
            hasMatchingProduct = true;
          }

          // Bauteil-Filter prüfen
          if (filter.parts != null && filter.parts!.isNotEmpty) {
            if (!filter.parts!.contains(part)) continue;
            hasMatchingProduct = true;
          }

          // Wenn keine Produkt-bezogenen Filter aktiv sind, alle Produkte einbeziehen
          if (!_hasProductFilters(filter)) {
            hasMatchingProduct = true;
          }

          // Statistiken nur für passende Produkte aktualisieren
          if (hasMatchingProduct) {
            receiptTotal += itemSubtotal;

            // Produktstatistiken aktualisieren
            if (!productStats.containsKey(productId)) {
              productStats[productId] = ProductStats(
                id: productId,
                name: productName,
                quantity: 0,
                revenue: 0,
              );
            }
            productStats[productId]!.quantity += quantity.toInt();
            productStats[productId]!.revenue += itemSubtotal;

            // Holzart-Verteilung aktualisieren
            woodTypeDistribution[woodCode] =
                (woodTypeDistribution[woodCode] ?? 0) + itemSubtotal;
          }
        }

        // Nur Belege mit passenden Produkten einbeziehen
        if (hasMatchingProduct) {
          // Betrags-Filter prüfen
          if (filter.minAmount != null && receiptTotal < filter.minAmount!) continue;
          if (filter.maxAmount != null && receiptTotal > filter.maxAmount!) continue;

          totalRevenue += receiptTotal;

          // Kundenstatistiken aktualisieren
          if (customerId != null) {
            if (!customerStats.containsKey(customerId)) {
              customerStats[customerId] = TopCustomer(
                id: customerId,
                name: customerName.isEmpty ? 'Unbekannter Kunde' : customerName,
                revenue: 0,
                orderCount: 0,
              );
            }
            customerStats[customerId]!.revenue += total;
            customerStats[customerId]!.orderCount++;
          }

          // Monatlichen Umsatz aktualisieren
          final metadata = data['metadata'] as Map<String, dynamic>?;
          final timestamp = metadata?['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + receiptTotal;
          }
        }
      }

      // Fallback für leere Daten
      if (customerStats.isEmpty) {
        customerStats[''] = TopCustomer(
          id: '',
          name: 'Keine Verkäufe',
          revenue: 0,
          orderCount: 0,
        );
      }

      if (productStats.isEmpty) {
        productStats[''] = ProductStats(
          id: '',
          name: 'Keine Produkte',
          quantity: 0,
          revenue: 0,
        );
      }

      // Statistiken erstellen
      final topCustomer = customerStats.values
          .reduce((a, b) => a.revenue > b.revenue ? a : b);

      final bestProduct = productStats.values
          .reduce((a, b) => b.revenue > a.revenue ? b : a);

      final topProduct = TopProduct(
        id: bestProduct.id,
        name: bestProduct.name,
        quantity: bestProduct.quantity,
        revenue: bestProduct.revenue,
      );

      final sortedProducts = productStats.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      return SalesStats(
        totalRevenue: totalRevenue,
        topCustomer: topCustomer,
        topProduct: topProduct,
        averageOrderValue: snapshot.docs.isEmpty ? 0 : totalRevenue / snapshot.docs.length,
        orderValueTrend: _calculateTrend(monthlyRevenue),
        topProducts: sortedProducts.take(10).toList(),
        woodTypeDistribution: woodTypeDistribution,
        revenueTrend: _calculateTrend(monthlyRevenue),
      );
    });
  }

  bool _meetsCriteria(Map<String, dynamic> data, SalesFilter filter) {
    // Basis-Kriterien prüfen (z.B. Timestamp, Customer ID etc.)
    return true; // Implementiere weitere Basis-Kriterien nach Bedarf
  }

  bool _hasProductFilters(SalesFilter filter) {
    return (filter.selectedProducts?.isNotEmpty ?? false) ||
        (filter.woodTypes?.isNotEmpty ?? false) ||
        (filter.qualities?.isNotEmpty ?? false) ||
        (filter.parts?.isNotEmpty ?? false);
  }

  double _calculateTrend(Map<String, double> revenueByMonth) {
    if (revenueByMonth.length < 2) return 0;

    final sortedMonths = revenueByMonth.keys.toList()..sort();
    final currentMonth = revenueByMonth[sortedMonths.last] ?? 0;
    final previousMonth = revenueByMonth[sortedMonths[sortedMonths.length - 2]] ?? 0;

    if (previousMonth == 0) return 0;
    return ((currentMonth - previousMonth) / previousMonth) * 100;
  }
}