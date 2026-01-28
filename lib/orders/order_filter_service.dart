import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'order_model.dart';
import '../services/icon_helper.dart';

class OrderFilterService {
  static const String _filterDocId = 'order_filter_settings';
  static const String _favoritesCollection = 'order_filter_favorites';

  // Filter Model
  static Map<String, dynamic> createEmptyFilter() {
    return {
      'orderStatus': <String>[],
      'minAmount': null,
      'maxAmount': null,
      'veranlagungStatus': null,
      'searchText': '',
      'quickStatus': null,  // NEU: Für Schnellfilter-Buttons
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
        return snapshot.data()!;
      }
      return createEmptyFilter();
    });
  }

  // Speichere Filter
  static Future<void> saveFilters(Map<String, dynamic> filters) async {
    await FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .set({
      ...filters,
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
    await FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .collection(_favoritesCollection)
        .add({
      'name': name,
      'filters': filters,
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

  // Query Builder
  static Query<Map<String, dynamic>> buildFilteredQuery(Map<String, dynamic> filters) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('orders');

    // Auftragsstatus Filter
    final orderStatusList = List<String>.from(filters['orderStatus'] ?? []);
    if (orderStatusList.isNotEmpty) {
      query = query.where('status', whereIn: orderStatusList);
    }

    // Sortierung
    query = query.orderBy('orderDate', descending: true);

    return query;
  }

  // Client-seitige Filter (für komplexere Logik)
  static List<OrderX> applyClientSideFilters(
      List<OrderX> orders,
      Map<String, dynamic> filters,
      ) {
    var filteredOrders = orders;

    // Suchtext Filter
    final searchText = (filters['searchText'] ?? '').toString().toLowerCase();
    if (searchText.isNotEmpty) {
      final searchTerms = searchText.split(' ').where((term) => term.isNotEmpty).toList();

      filteredOrders = filteredOrders.where((order) {
        final company = order.customer['company']?.toString().toLowerCase() ?? '';
        final fullName = order.customer['fullName']?.toString().toLowerCase() ?? '';
        final firstName = order.customer['firstName']?.toString().toLowerCase() ?? '';
        final lastName = order.customer['lastName']?.toString().toLowerCase() ?? '';
        final email = order.customer['email']?.toString().toLowerCase() ?? '';

        final searchableContent = [
          order.orderNumber.toLowerCase(),
          company,
          fullName,
          firstName,
          lastName,
          '$firstName $lastName',
          email,
          order.quoteNumber?.toLowerCase() ?? '',
        ].join(' ');

        return searchTerms.every((term) => searchableContent.contains(term));
      }).toList();
    }

    // Betrag Filter
    final minAmount = filters['minAmount'] as double?;
    final maxAmount = filters['maxAmount'] as double?;

    if (minAmount != null || maxAmount != null) {
      filteredOrders = filteredOrders.where((order) {
        final total = (order.calculations['total'] as num?)?.toDouble() ?? 0.0;

        if (minAmount != null && total < minAmount) return false;
        if (maxAmount != null && total > maxAmount) return false;

        return true;
      }).toList();
    }

    // Veranlagungsverfügung Filter
    final veranlagungStatus = filters['veranlagungStatus'];
    if (veranlagungStatus != null) {
      filteredOrders = filteredOrders.where((order) {
        final total = (order.calculations['total'] as num?)?.toDouble() ?? 0.0;
        final hasVeranlagungsnummer = order.metadata?['veranlagungsnummer'] != null &&
            order.metadata!['veranlagungsnummer'].toString().isNotEmpty;

        switch (veranlagungStatus) {
          case 'required':
            return total > 1000.0 && !hasVeranlagungsnummer;
          case 'completed':
            return total > 1000.0 && hasVeranlagungsnummer;
          default:
            return true;
        }
      }).toList();
    }

    // NEU: Quick-Status Filter (für die Schnellfilter-Buttons)
    final quickStatus = filters['quickStatus'] as String?;
    if (quickStatus != null && quickStatus.isNotEmpty) {
      filteredOrders = filteredOrders.where((order) {
        return order.status.name == quickStatus;
      }).toList();
    }

    return filteredOrders;
  }

  // Helper: Prüfe ob Filter aktiv sind
  static bool hasActiveFilters(Map<String, dynamic> filters) {
    return (filters['orderStatus'] as List?)?.isNotEmpty == true ||
        filters['minAmount'] != null ||
        filters['maxAmount'] != null ||
        filters['veranlagungStatus'] != null ||
        (filters['searchText'] ?? '').toString().isNotEmpty ||
        (filters['quickStatus'] != null && filters['quickStatus'].toString().isNotEmpty);  // NEU
  }

  // Helper: Erstelle Filter-Zusammenfassung für Anzeige
  static String getFilterSummary(Map<String, dynamic> filters) {
    final parts = <String>[];

    final orderStatusCount = (filters['orderStatus'] as List?)?.length ?? 0;
    if (orderStatusCount > 0) {
      parts.add('$orderStatusCount Auftragsstatus');
    }

    if (filters['minAmount'] != null || filters['maxAmount'] != null) {
      final min = filters['minAmount']?.toString() ?? '';
      final max = filters['maxAmount']?.toString() ?? '';
      parts.add('Betrag: ${min.isEmpty ? '' : 'ab $min'}${min.isNotEmpty && max.isNotEmpty ? ' - ' : ''}${max.isEmpty ? '' : 'bis $max'}');
    }

    if (filters['veranlagungStatus'] == 'required') {
      parts.add('Veranlagung offen');
    } else if (filters['veranlagungStatus'] == 'completed') {
      parts.add('Veranlagung vorhanden');
    }

    if ((filters['searchText'] ?? '').toString().isNotEmpty) {
      parts.add('Suche: "${filters['searchText']}"');
    }

    // NEU: Quick-Filter in Zusammenfassung
    final quickStatus = filters['quickStatus'] as String?;
    if (quickStatus != null && quickStatus.isNotEmpty) {
      final statusName = quickStatus == 'processing' ? 'In Bearbeitung' :
      quickStatus == 'shipped' ? 'Versendet' : quickStatus;
      parts.add('Schnellfilter: $statusName');
    }

    return parts.join(', ');
  }
}

// Filter Dialog Widget
class OrderFilterDialog extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApply;

  const OrderFilterDialog({
    Key? key,
    required this.currentFilters,
    required this.onApply,
  }) : super(key: key);

  @override
  State<OrderFilterDialog> createState() => _OrderFilterDialogState();
}

class _OrderFilterDialogState extends State<OrderFilterDialog> {
  late Map<String, dynamic> _filters;
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = Map<String, dynamic>.from(widget.currentFilters);
    _minAmountController.text = _filters['minAmount']?.toString() ?? '';
    _maxAmountController.text = _filters['maxAmount']?.toString() ?? '';
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'filter_list',
                    defaultIcon: Icons.filter_list,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Aufträge filtern',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Auftragsstatus
                    _buildFilterSection(
                      title: 'Auftragsstatus',
                      icon: Icons.assignment,
                      iconName: 'assignment',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: OrderStatus.values.map((status) {
                          final isSelected = (_filters['orderStatus'] as List).contains(status.name);
                          return FilterChip(
                            label: Text(status.displayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  (_filters['orderStatus'] as List).add(status.name);
                                } else {
                                  (_filters['orderStatus'] as List).remove(status.name);
                                }
                              });
                            },
                            avatar: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Auftragssumme
                    _buildFilterSection(
                      title: 'Auftragssumme (CHF)',
                      icon: Icons.savings,
                      iconName: 'money_bag',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Min',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixText: 'CHF ',
                              ),
                              onChanged: (value) {
                                _filters['minAmount'] = value.isEmpty ? null : double.tryParse(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Max',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixText: 'CHF ',
                              ),
                              onChanged: (value) {
                                _filters['maxAmount'] = value.isEmpty ? null : double.tryParse(value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Veranlagungsverfügung
                    _buildFilterSection(
                      title: 'Veranlagungsverfügung Ausfuhr',
                      icon: Icons.assignment_turned_in,
                      iconName: 'assignment_turned_in',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bei Lieferungen über CHF 1\'000',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Alle anzeigen'),
                                selected: _filters['veranlagungStatus'] == null,
                                onSelected: (selected) {
                                  setState(() {
                                    _filters['veranlagungStatus'] = null;
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    getAdaptiveIcon(iconName: 'warning', defaultIcon: Icons.warning, size: 16, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    const Text('Verfügung fehlt'),
                                  ],
                                ),
                                selected: _filters['veranlagungStatus'] == 'required',
                                onSelected: (selected) {
                                  setState(() {
                                    _filters['veranlagungStatus'] = selected ? 'required' : null;
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    getAdaptiveIcon(iconName: 'check_circle', defaultIcon: Icons.check_circle, size: 16, color: Colors.green),
                                    const SizedBox(width: 4),
                                    const Text('Verfügung vorhanden'),
                                  ],
                                ),
                                selected: _filters['veranlagungStatus'] == 'completed',
                                onSelected: (selected) {
                                  setState(() {
                                    _filters['veranlagungStatus'] = selected ? 'completed' : null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear),
                    label: const Text('Zurücksetzen'),
                    onPressed: () {
                      setState(() {
                        _filters = OrderFilterService.createEmptyFilter();
                        _minAmountController.clear();
                        _maxAmountController.clear();
                      });
                    },
                  ),
                  FilledButton(
                    onPressed: () {
                      widget.onApply(_filters);
                      Navigator.pop(context);
                    },
                    child: const Text('Anwenden'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required String iconName,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing:
        return const Color(0xFF2196F3);
      case OrderStatus.shipped:
        return const Color(0xFF7C4DFF);
      case OrderStatus.cancelled:
        return const Color(0xFF757575);
    }
  }
}