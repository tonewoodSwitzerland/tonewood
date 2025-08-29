import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';


class CustomerFilterService {
  static const String _filterDocId = 'customer_filter_settings';
  static const String _favoritesCollection = 'customer_filter_favorites';

  // Filter Model
  static Map<String, dynamic> createEmptyFilter() {
    return {
      'searchText': '',
      'minRevenue': null,
      'maxRevenue': null,
      'revenueStartDate': null,
      'revenueEndDate': null,
      'minOrderCount': null,
      'maxOrderCount': null,
      'wantsChristmasCard': null, // null = alle, true = JA, false = NEIN
      'hasVatNumber': null,
      'hasEoriNumber': null,
      'countries': <String>[],
      'languages': <String>[],
    };
  }

  // Lade gespeicherte Filter
  static Stream<Map<String, dynamic>> loadSavedFilters() {
    return FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        // Konvertiere Timestamps zurück zu DateTime
        if (data['revenueStartDate'] != null) {
          data['revenueStartDate'] = (data['revenueStartDate'] as Timestamp).toDate();
        }
        if (data['revenueEndDate'] != null) {
          data['revenueEndDate'] = (data['revenueEndDate'] as Timestamp).toDate();
        }
        return data;
      }
      return createEmptyFilter();
    });
  }

  // Speichere Filter
  static Future<void> saveFilters(Map<String, dynamic> filters) async {
    final saveData = Map<String, dynamic>.from(filters);

    // Konvertiere DateTime zu Timestamp für Firestore
    if (saveData['revenueStartDate'] != null) {
      saveData['revenueStartDate'] = Timestamp.fromDate(saveData['revenueStartDate'] as DateTime);
    }
    if (saveData['revenueEndDate'] != null) {
      saveData['revenueEndDate'] = Timestamp.fromDate(saveData['revenueEndDate'] as DateTime);
    }

    await FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .set({
      ...saveData,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Reset Filter
  static Future<void> resetFilters() async {
    await FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .delete();
  }

  // Favoriten Management
  static Future<void> saveFavorite(String name, Map<String, dynamic> filters) async {
    final saveData = Map<String, dynamic>.from(filters);

    // Konvertiere DateTime zu Timestamp
    if (saveData['revenueStartDate'] != null) {
      saveData['revenueStartDate'] = Timestamp.fromDate(saveData['revenueStartDate'] as DateTime);
    }
    if (saveData['revenueEndDate'] != null) {
      saveData['revenueEndDate'] = Timestamp.fromDate(saveData['revenueEndDate'] as DateTime);
    }

    await FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .collection(_favoritesCollection)
        .add({
      'name': name,
      'filters': saveData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> getFavorites() {
    return FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .collection(_favoritesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> deleteFavorite(String favoriteId) async {
    await FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .collection(_favoritesCollection)
        .doc(favoriteId)
        .delete();
  }

  // Berechne Kundenstatistiken
  static Future<Map<String, dynamic>> calculateCustomerStats(
      String customerId,
      DateTime? startDate,
      DateTime? endDate,
      ) async {
    Query<Map<String, dynamic>> ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('customer.id', isEqualTo: customerId);

    Query<Map<String, dynamic>> quotesQuery = FirebaseFirestore.instance
        .collection('quotes')
        .where('customer.id', isEqualTo: customerId);

    // Wenn Zeitraum definiert ist, filtere danach
    if (startDate != null) {
      ordersQuery = ordersQuery.where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      quotesQuery = quotesQuery.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      ordersQuery = ordersQuery.where('orderDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      quotesQuery = quotesQuery.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final ordersSnapshot = await ordersQuery.get();
    final quotesSnapshot = await quotesQuery.get();

    double totalRevenue = 0.0;
    int orderCount = 0;

    for (final doc in ordersSnapshot.docs) {
      final data = doc.data();
      final calculations = data['calculations'] as Map<String, dynamic>?;
      if (calculations != null) {
        totalRevenue += (calculations['total'] as num?)?.toDouble() ?? 0.0;
      }
      orderCount++;
    }

    return {
      'totalRevenue': totalRevenue,
      'orderCount': orderCount,
      'quoteCount': quotesSnapshot.docs.length,
    };
  }

  // Client-seitige Filter
  static Future<List<Map<String, dynamic>>> applyClientSideFilters(
      List<Map<String, dynamic>> customers,
      Map<String, dynamic> filters,
      ) async {
    var filteredCustomers = customers;

    // Suchtext Filter
    final searchText = (filters['searchText'] ?? '').toString().toLowerCase();
    if (searchText.isNotEmpty) {
      final searchTerms = searchText.split(' ').where((term) => term.isNotEmpty).toList();

      filteredCustomers = filteredCustomers.where((customer) {
        final searchableContent = [
          customer['company'] ?? '',
          customer['firstName'] ?? '',
          customer['lastName'] ?? '',
          customer['email'] ?? '',
          customer['city'] ?? '',
          customer['vatNumber'] ?? '',
          customer['eoriNumber'] ?? '',
        ].join(' ').toLowerCase();

        return searchTerms.every((term) => searchableContent.contains(term));
      }).toList();
    }

    // Weihnachtskarte Filter
    if (filters['wantsChristmasCard'] != null) {
      filteredCustomers = filteredCustomers.where((customer) {
        return customer['wantsChristmasCard'] == filters['wantsChristmasCard'];
      }).toList();
    }

    // VAT Number Filter
    if (filters['hasVatNumber'] != null) {
      filteredCustomers = filteredCustomers.where((customer) {
        final hasVat = customer['vatNumber'] != null && customer['vatNumber'].toString().isNotEmpty;
        return hasVat == filters['hasVatNumber'];
      }).toList();
    }

    // EORI Number Filter
    if (filters['hasEoriNumber'] != null) {
      filteredCustomers = filteredCustomers.where((customer) {
        final hasEori = customer['eoriNumber'] != null && customer['eoriNumber'].toString().isNotEmpty;
        return hasEori == filters['hasEoriNumber'];
      }).toList();
    }

    // Land Filter
    final countries = List<String>.from(filters['countries'] ?? []);
    if (countries.isNotEmpty) {
      filteredCustomers = filteredCustomers.where((customer) {
        return countries.contains(customer['countryCode']);
      }).toList();
    }

    // Sprache Filter
    final languages = List<String>.from(filters['languages'] ?? []);
    if (languages.isNotEmpty) {
      filteredCustomers = filteredCustomers.where((customer) {
        return languages.contains(customer['language']);
      }).toList();
    }

    // Revenue und Order Count Filter
    // Diese müssen async berechnet werden
    if (filters['minRevenue'] != null ||
        filters['maxRevenue'] != null ||
        filters['minOrderCount'] != null ||
        filters['maxOrderCount'] != null) {

      final List<Map<String, dynamic>> customersWithStats = [];

      for (final customer in filteredCustomers) {
        final stats = await calculateCustomerStats(
          customer['id'],
          filters['revenueStartDate'] as DateTime?,
          filters['revenueEndDate'] as DateTime?,
        );

        // Revenue Filter
        if (filters['minRevenue'] != null && stats['totalRevenue'] < filters['minRevenue']) continue;
        if (filters['maxRevenue'] != null && stats['totalRevenue'] > filters['maxRevenue']) continue;

        // Order Count Filter
        if (filters['minOrderCount'] != null && stats['orderCount'] < filters['minOrderCount']) continue;
        if (filters['maxOrderCount'] != null && stats['orderCount'] > filters['maxOrderCount']) continue;

        customersWithStats.add({
          ...customer,
          '_stats': stats, // Füge Stats für spätere Verwendung hinzu
        });
      }

      filteredCustomers = customersWithStats;
    }

    return filteredCustomers;
  }

  // Helper: Prüfe ob Filter aktiv sind
  static bool hasActiveFilters(Map<String, dynamic> filters) {
    return (filters['searchText'] ?? '').toString().isNotEmpty ||
        filters['minRevenue'] != null ||
        filters['maxRevenue'] != null ||
        filters['revenueStartDate'] != null ||
        filters['revenueEndDate'] != null ||
        filters['minOrderCount'] != null ||
        filters['maxOrderCount'] != null ||
        filters['wantsChristmasCard'] != null ||
        filters['hasVatNumber'] != null ||
        filters['hasEoriNumber'] != null ||
        (filters['countries'] as List?)?.isNotEmpty == true ||
        (filters['languages'] as List?)?.isNotEmpty == true;
  }

  // Helper: Erstelle Filter-Zusammenfassung für Anzeige
  static String getFilterSummary(Map<String, dynamic> filters) {
    final parts = <String>[];

    if ((filters['searchText'] ?? '').toString().isNotEmpty) {
      parts.add('Suche: "${filters['searchText']}"');
    }

    if (filters['minRevenue'] != null || filters['maxRevenue'] != null) {
      final min = filters['minRevenue']?.toString() ?? '';
      final max = filters['maxRevenue']?.toString() ?? '';
      parts.add('Umsatz: ${min.isEmpty ? '' : 'ab CHF $min'}${min.isNotEmpty && max.isNotEmpty ? ' - ' : ''}${max.isEmpty ? '' : 'bis CHF $max'}');
    }

    if (filters['revenueStartDate'] != null || filters['revenueEndDate'] != null) {
      final start = filters['revenueStartDate'] != null
          ? DateFormat('dd.MM.yy').format(filters['revenueStartDate'] as DateTime)
          : '';
      final end = filters['revenueEndDate'] != null
          ? DateFormat('dd.MM.yy').format(filters['revenueEndDate'] as DateTime)
          : '';
      parts.add('Zeitraum: ${start.isEmpty ? '' : 'ab $start'}${start.isNotEmpty && end.isNotEmpty ? ' - ' : ''}${end.isEmpty ? '' : 'bis $end'}');
    }

    if (filters['minOrderCount'] != null || filters['maxOrderCount'] != null) {
      final min = filters['minOrderCount']?.toString() ?? '';
      final max = filters['maxOrderCount']?.toString() ?? '';
      parts.add('Aufträge: ${min.isEmpty ? '' : 'ab $min'}${min.isNotEmpty && max.isNotEmpty ? ' - ' : ''}${max.isEmpty ? '' : 'bis $max'}');
    }

    if (filters['wantsChristmasCard'] != null) {
      parts.add('Weihnachtskarte: ${filters['wantsChristmasCard'] ? 'JA' : 'NEIN'}');
    }

    final countryCount = (filters['countries'] as List?)?.length ?? 0;
    if (countryCount > 0) {
      parts.add('$countryCount Länder');
    }

    final languageCount = (filters['languages'] as List?)?.length ?? 0;
    if (languageCount > 0) {
      parts.add('$languageCount Sprachen');
    }

    return parts.join(', ');
  }
}