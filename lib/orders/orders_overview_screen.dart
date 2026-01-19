import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_details_sheet.dart';
import 'order_filter_favorites_sheet.dart';
import 'order_filter_service.dart';
import 'order_model.dart';
import '../services/icon_helper.dart';
import '../services/orders_document_manager.dart';
import '../services/order_document_preview_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File; // Nur für Mobile
// Zentrale Farbdefinitionen
class OrderColors {
  static const pending = Color(0xFFEF9A3C);      // Warmes Gelb-Orange
  static const processing = Color(0xFF2196F3);    // Material Blue
  static const shipped = Color(0xFF7C4DFF);       // Material Deep Purple
  static const delivered = Color(0xFF4CAF50);     // Material Green
  static const cancelled = Color(0xFF757575);     // Material Grey

  static const paymentPending = Color(0xFFFF7043);  // Deep Orange
  static const paymentPartial = Color(0xFFFFA726);  // Orange
  static const paymentPaid = Color(0xFF66BB6A);     // Light Green
}

class OrdersOverviewScreen extends StatefulWidget {
  const OrdersOverviewScreen({Key? key}) : super(key: key);

  @override
  State<OrdersOverviewScreen> createState() => _OrdersOverviewScreenState();
}

class _OrdersOverviewScreenState extends State<OrdersOverviewScreen> {

  String _searchQuery = '';
  OrderStatus? _filterStatus;

  Map<String, dynamic> _activeFilters = OrderFilterService.createEmptyFilter();
  StreamSubscription<Map<String, dynamic>>? _filterSubscription;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingFilters = true;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            const Text('Aufträge', style: TextStyle(fontWeight: FontWeight.w600)),
            if (OrderFilterService.hasActiveFilters(_activeFilters))
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_getFilteredOrdersCount()} gefiltert',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        actions: [

          // Filter-Button
          IconButton(
            icon: Badge(
              isLabelVisible: OrderFilterService.hasActiveFilters(_activeFilters),
              label: const Text('!'),
              child: getAdaptiveIcon(
                iconName: 'filter_list',
                defaultIcon: Icons.filter_list,
              ),
            ),
            onPressed: _showFilterDialog,
          ),
          // Favoriten
          IconButton(
            icon: getAdaptiveIcon(
              iconName: 'star',
              defaultIcon: Icons.star,
              color: OrderFilterService.hasActiveFilters(_activeFilters)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _showFilterFavorites,
            tooltip: 'Filter-Favoriten',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: StatefulBuilder(
              builder: (context, setSearchState) {
                return TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Suche nach Kunde, Auftragsnummer...',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setSearchState(() {});
                              setState(() {
                                _activeFilters['searchText'] = '';
                              });
                              OrderFilterService.saveFilters(_activeFilters);
                            },
                          ),
                        IconButton(
                          icon: getAdaptiveIcon(
                            iconName: 'search',
                            defaultIcon: Icons.search,
                            color: _searchController.text.toLowerCase() != (_activeFilters['searchText'] ?? '').toString().toLowerCase()
                                ? Colors.orange
                                : Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _activeFilters['searchText'] = _searchController.text;
                            });
                            OrderFilterService.saveFilters(_activeFilters);
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setSearchState(() {});
                  },
                );
              },
            ),
          ),

          // Kompakte Statistik-Karten
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildCompactStatistics(),
          ),

          // Auftragsliste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildOrdersQuery(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Fehler: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Wende Client-seitige Filter an
                final allOrders = snapshot.data!.docs
                    .map((doc) => OrderX.fromFirestore(doc))
                    .toList();

                final filteredOrders = OrderFilterService.applyClientSideFilters(
                    allOrders,
                    _activeFilters
                );

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        getAdaptiveIcon(
                          iconName: 'inbox_outlined',
                          defaultIcon: Icons.inbox_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          OrderFilterService.hasActiveFilters(_activeFilters)
                              ? 'Keine Aufträge gefunden'
                              : 'Noch keine Aufträge vorhanden',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        if (OrderFilterService.hasActiveFilters(_activeFilters)) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon:  getAdaptiveIcon(iconName: 'clear', defaultIcon:Icons.clear),
                            label: const Text('Filter zurücksetzen'),
                            onPressed: () async {
                              await OrderFilterService.resetFilters();
                              _searchController.clear();
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Zeige aktive Filter
                return Column(
                  children: [
                    if (OrderFilterService.hasActiveFilters(_activeFilters))
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    getAdaptiveIcon(iconName: 'filter_list', defaultIcon:
                                      Icons.filter_list,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      OrderFilterService.getFilterSummary(_activeFilters),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await OrderFilterService.resetFilters();
                                _searchController.clear();
                              },
                              child: const Text('Zurücksetzen', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          return _buildCompactOrderCard(order);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Neue Methode für die Suchfunktion:
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufträge durchsuchen'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Kunde, Auftragsnummer...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            Navigator.pop(context);
            _performSearch();
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchController.clear();
                _performSearch();
                Navigator.pop(context);
              },
              child: const Text('Löschen'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _performSearch();
            },
            child: const Text('Suchen'),
          ),
        ],
      ),
    );
  }

// Helper Methode für gefilterte Anzahl:
  int _getFilteredOrdersCount() {
    // Diese Zahl wird später durch einen StreamBuilder aktualisiert
    return 0;
  }




  Widget _buildCompactStatistics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 60);

        final orders = snapshot.data!.docs
            .map((doc) => OrderX.fromFirestore(doc))
            .toList();

        // Nur noch "In Bearbeitung" zählen (nicht versendet, nicht storniert)
        final openOrders = orders.where((o) =>
        o.status == OrderStatus.processing
        ).length;

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  'In Bearbeitung',
                  openOrders.toString(),
                  Icons.schedule,
                  'schedule',
                  OrderColors.processing,
                ),
              ),
              // ENTFERNT: Zweite Karte "Unbezahlt"
            ],
          ),
        );
      },
    );
  }
  Widget _buildCompactStatCard(String title, String value, IconData icon,String iconName, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(
              iconName: iconName,
              defaultIcon:icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _loadFilters() {
    _filterSubscription = OrderFilterService.loadSavedFilters().listen((filters) {
      if (mounted) {
        setState(() {
          _activeFilters = filters;
          _searchController.text = filters['searchText'] ?? '';
          _isLoadingFilters = false;
        });
      }
    });
  }

  void _performSearch() {
    setState(() {
      _activeFilters['searchText'] = _searchController.text;
    });
    OrderFilterService.saveFilters(_activeFilters);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => OrderFilterDialog(
        currentFilters: _activeFilters,
        onApply: (filters) {
          setState(() {
            _activeFilters = filters;
          });
          OrderFilterService.saveFilters(filters);
        },
      ),
    );
  }

  void _showFilterFavorites() {
    OrderFilterFavoritesSheet.show(
      context,
      onFavoriteSelected: (favoriteData) {
        setState(() {
          _activeFilters = Map<String, dynamic>.from(favoriteData['filters']);
          _searchController.text = _activeFilters['searchText'] ?? '';
        });
        OrderFilterService.saveFilters(_activeFilters);
      },
      onCreateNew: () => _saveCurrentFilterAsFavorite(),
    );
  }

  Future<void> _saveCurrentFilterAsFavorite() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter-Favorit speichern'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name für diesen Filter',
            border: OutlineInputBorder(),
            hintText: 'z.B. Offene Aufträge',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await OrderFilterService.saveFavorite(name, _activeFilters);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Filter-Favorit "$name" gespeichert'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Speichern: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  Stream<QuerySnapshot> _buildOrdersQuery() {
    return OrderFilterService.buildFilteredQuery(_activeFilters).snapshots();
  }


  Widget _buildCompactOrderCard(OrderX order) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDarkMode ? 2 : 1,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Erste Zeile: Auftragsnummer, Datum, Status
              Row(
                children: [
                  // Auftragsnummer & Datum
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auftrag ${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              DateFormat('dd.MM.yy').format(order.orderDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            // Zeige Angebotsnummer wenn vorhanden
                            if (order.quoteNumber != null && order.quoteNumber!.isNotEmpty) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                              Row(
                                children: [
                                  getAdaptiveIcon(
                                    iconName: 'description',
                                    defaultIcon:
                                    Icons.description,
                                    size: 11,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Angebot ${order.quoteNumber}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status-Chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildCompactStatusChip(order.status),

                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Zweite Zeile: Kunde & Betrag
              Row(
                children: [
                  // Kunde
                  Expanded(
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                            iconName: 'business',
                            defaultIcon:
                            Icons.business,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (order.customer['company']?.toString().trim().isNotEmpty == true)
                                ? order.customer['company']
                                : (order.customer['firstName']?.toString().trim().isNotEmpty == true ||
                                order.customer['lastName']?.toString().trim().isNotEmpty == true)
                                ? '${order.customer['firstName'] ?? ''} ${order.customer['lastName'] ?? ''}'.trim()
                                : order.customer['fullName']?.toString().trim().isNotEmpty == true
                                ? order.customer['fullName']
                                : 'Unbekannter Kunde',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Betrag
                  // Betrag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: OrderColors.delivered.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${order.metadata?['currency'] ?? 'CHF'} ${_convertPrice((order.calculations['total'] as num? ?? 0).toDouble(), order).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OrderColors.delivered,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Aktionen
              // Aktionen
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  // NEU: Veranlagungsverfügung Icon (als erstes in der Reihe)
                  if (_needsVeranlagungsverfuegung(order)) ...[

                    _buildCompactActionButton(
                      icon: _hasVeranlagungsnummer(order)
                          ? Icons.assignment_turned_in
                          : Icons.assignment_late,
                      iconName: _hasVeranlagungsnummer(order)
                          ? 'assignment_turned_in'
                          : 'assignment_late',
                      onPressed: () => _showVeranlagungsverfuegungDialog(order),
                      tooltip: 'Veranlagungsverfügung Ausfuhr',
                      color: _hasVeranlagungsnummer(order)
                          ? Colors.green
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(width: 4),
                  ],

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.metadata?['language'] ?? 'DE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),

                  // Status ändern
                  const SizedBox(width: 4),
                  _buildCompactActionButton(
                    icon: Icons.edit,
                    iconName: 'edit',
                    onPressed: () => _showQuickStatusMenu(order),
                    tooltip: 'Status ändern',
                  ),
                  const SizedBox(width: 4),
                  // History
                  _buildCompactActionButton(
                    icon: Icons.history,
                    iconName: 'history',
                    onPressed: () => _showOrderHistory(order),
                    tooltip: 'Verlauf',
                  ),
                  const SizedBox(width: 4),
                  // Dokumente
                  _buildCompactActionButton(
                    icon: Icons.folder,
                    iconName:'folder',
                    onPressed: () => _viewOrderDocuments(order),
                    tooltip: 'Dokumente',
                  ),
                  const SizedBox(width: 4),
                  // Teilen
                  _buildCompactActionButton(
                    icon: Icons.share,
                    iconName:'share',
                    onPressed: () => _shareOrder(order),
                    tooltip: 'Teilen',
                  ),
                  if ( order.status == OrderStatus.processing) ...[
                    const SizedBox(width: 4),
                    _buildCompactActionButton(
                      icon: Icons.cancel,
                      iconName:'cancel',
                      onPressed: () => _releaseOrder(order),
                      tooltip: 'Stornieren',
                      color: Colors.red,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// Diese Hilfsfunktionen werden nicht mehr benötigt, da wir direkt auf order.quoteNumber zugreifen können

// Hilfsfunktionen für sicheren Zugriff auf die Angebotsnummer
  bool _hasQuoteNumber(OrderX order) {
    // Prüfe verschiedene Möglichkeiten
    if (order.quoteNumber != null && order.quoteNumber!.isNotEmpty) {
      return true;
    }

    // Prüfe in metadata
    if (order.metadata != null &&
        order.metadata!['quoteNumber'] != null &&
        order.metadata!['quoteNumber'].toString().isNotEmpty) {
      return true;
    }

    // Prüfe ob quoteId vorhanden ist
    if (order.quoteId != null && order.quoteId!.isNotEmpty) {
      return true;
    }

    return false;
  }

  String _getQuoteNumberFromOrder(OrderX order) {
    // Versuche zuerst direkt auf quoteNumber zuzugreifen
    if (order.quoteNumber != null && order.quoteNumber!.isNotEmpty) {
      return order.quoteNumber!;
    }

    // Dann in metadata
    if (order.metadata != null && order.metadata!['quoteNumber'] != null) {
      return order.metadata!['quoteNumber'].toString();
    }

    // Falls nur quoteId vorhanden ist, extrahiere die Nummer daraus
    // QuoteId Format: Q-YYYY-NNNN
    if (order.quoteId != null && order.quoteId!.startsWith('Q-')) {
      return order.quoteId!.substring(2); // Entferne "Q-" Präfix
    }

    return 'Unbekannt';
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required String iconName,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(8),
            child:
            getAdaptiveIcon(
              iconName: iconName,
              defaultIcon:icon,
              size: 18,
              color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatusChip(OrderStatus status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  Color _getStatusColor(OrderStatus status) {
    switch (status) {

      case OrderStatus.processing:
        return OrderColors.processing;
      case OrderStatus.shipped:
        return OrderColors.shipped;

      case OrderStatus.cancelled:
        return OrderColors.cancelled;
    }
  }


  void _showOrderDetails(OrderX order) {
    OrderDetailsSheet.show(
      context,
      order: order,
      onStatusChange: _showQuickStatusMenu,
      onViewDocuments: _viewOrderDocuments,
      onShowHistory: _showOrderHistory,
      onShare: _shareOrder,
      onCancel: _releaseOrder,
      onEditItemMeasurements: (order, item, index) {
        _showEditItemMeasurementsDialog(context, order, item, index);
      },
      onVeranlagung: _showVeranlagungsverfuegungDialog,
    );
  }

  void _showEditItemMeasurementsDialog(BuildContext context, OrderX order, Map<String, dynamic> item, int itemIndex) {
    // Controller für die Eingabefelder
    final lengthController = TextEditingController(
      text: item['custom_length']?.toString() ?? '',
    );
    final widthController = TextEditingController(
      text: item['custom_width']?.toString() ?? '',
    );
    final thicknessController = TextEditingController(
      text: item['custom_thickness']?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'straighten',
                        defaultIcon:
                        Icons.straighten,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Maße bearbeiten',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['product_name']?.toString() ?? 'Produkt',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:  getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            getAdaptiveIcon(
                              iconName: 'info',
                              defaultIcon:
                              Icons.info,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Gib die exakten Maße des Artikels ein. Diese Angaben erscheinen auf den Dokumenten.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Maße Eingabefelder
                      Row(
                        children: [
                          // Länge
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Länge (mm)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: lengthController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    prefixIcon:
                                    getAdaptiveIcon(iconName: 'arrow_right_alt', defaultIcon:
                                      Icons.arrow_right_alt,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Breite
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Breite (mm)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: widthController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    prefixIcon:
                                    getAdaptiveIcon(iconName: 'swap_horiz', defaultIcon:
                                      Icons.swap_horiz,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Dicke
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dicke (mm)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: thicknessController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    prefixIcon:getAdaptiveIcon(iconName: 'height', defaultIcon:
                                      Icons.height,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Abbrechen'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Validiere und parse die Eingaben
                                final length = double.tryParse(lengthController.text);
                                final width = double.tryParse(widthController.text);
                                final thickness = double.tryParse(thicknessController.text);

                                try {
                                  // Update das Item in der Liste
                                  final updatedItems = List<Map<String, dynamic>>.from(order.items);

                                  // Update direkt am korrekten Index
                                  updatedItems[itemIndex] = {
                                    ...updatedItems[itemIndex],
                                    'custom_length': length,
                                    'custom_width': width,
                                    'custom_thickness': thickness,
                                  };

                                  // Update in Firestore
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(order.id)
                                      .update({
                                    'items': updatedItems,
                                    'updated_at': FieldValue.serverTimestamp(),
                                  });

                                  // Erstelle History-Eintrag
                                  final user = FirebaseAuth.instance.currentUser;
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(order.id)
                                      .collection('history')
                                      .add({
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'user_id': user?.uid ?? 'unknown',
                                    'user_email': user?.email ?? 'Unknown User',
                                    'user_name': user?.email ?? 'Unknown',
                                    'action': 'measurements_updated',
                                    'product_name': item['product_name'],
                                    'item_index': itemIndex,
                                    'measurements': {
                                      'length': length,
                                      'width': width,
                                      'thickness': thickness,
                                    },
                                  });

                                  if (mounted) {
                                    Navigator.pop(context); // Schließe nur Maße-Dialog

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Maße für ${item['product_name']} wurden aktualisiert'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Fehler beim Aktualisieren: $e'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon:  getAdaptiveIcon(
                                  iconName: 'save',
                                  defaultIcon:Icons.save),
                              label: const Text('Speichern'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : null,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickStatusMenu(OrderX order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header mit Overflow-Schutz
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Status ändern',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      'Auftrag ${order.orderNumber}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Warnung wenn Auftrag storniert ist
            if (order.status == OrderStatus.cancelled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'info',
                        defaultIcon: Icons.info,
                        size: 20,
                        color: Colors.red[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stornierte Aufträge können nicht mehr geändert werden',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Scrollbare Liste für viele Einträge
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Auftragsstatus
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          getAdaptiveIcon(
                              iconName: 'assignment',
                              defaultIcon:Icons.assignment, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Auftragsstatus',
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...OrderStatus.values.map((status) {
                      // Prüfe ob der Status änderbar ist
                      final isOrderCancelled = order.status == OrderStatus.cancelled;
                      final isCancelledStatus = status == OrderStatus.cancelled;
                      final isSelectable = !isOrderCancelled && !isCancelledStatus;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        dense: true,
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          status.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelectable
                                ? null
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                        subtitle: !isSelectable && !isOrderCancelled && isCancelledStatus
                            ? Text(
                          'Verwende den Stornieren-Button',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        )
                            : null,
                        trailing: order.status == status
                            ? getAdaptiveIcon(
                            iconName: 'check_circle',
                            defaultIcon: Icons.check_circle,
                            color: _getStatusColor(status),
                            size: 20
                        )
                            : !isSelectable
                            ? getAdaptiveIcon(
                          iconName: 'lock',
                          defaultIcon: Icons.lock,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          size: 16,
                        )
                            : null,
                        enabled: isSelectable,
                        onTap: isSelectable
                            ? () async {
                          Navigator.pop(context);
                          await _updateOrderStatusValue(order, status);
                        }
                            : null,
                      );
                    }),

                    const Divider(height: 24, indent: 20, endIndent: 20),

                    // Zahlungsstatus
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          getAdaptiveIcon(
                              iconName: 'payments',
                              defaultIcon:Icons.payments, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Zahlungsstatus',
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600
                            ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateOrderStatusValue(OrderX order, OrderStatus status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();

      // Update Order
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id);

      batch.update(orderRef, {
        'status': status.name,
        'status_updated_at': FieldValue.serverTimestamp(),
      });

      // Create History Entry
      final historyRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .collection('history')
          .doc();

      batch.set(historyRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': user?.uid ?? 'unknown',
        'user_email': user?.email ?? 'Unknown User',
        'user_name': user?.email ?? 'Unknown',
        'action': 'status_change',
        'changes': {
          'field': 'status',
          'old_value': order.status.name,
          'new_value': status.name,
          'old_display': order.status.displayName,
          'new_display': status.displayName,
        },
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auftragsstatus wurde auf ${status.displayName} geändert'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }


  void _showOrderHistory(OrderX order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  getAdaptiveIcon(
                      iconName: 'history',
                      defaultIcon:Icons.history),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verlauf - ${order.orderNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon:     getAdaptiveIcon(
                        iconName: 'close',
                        defaultIcon:Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(),

            // History List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .doc(order.id)
                    .collection('history')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    // Zeige die Erstellung des Auftrags als ersten Eintrag
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildHistoryEntry(
                          icon: Icons.add_circle,
                          iconName: 'add_circle',
                          color: Colors.green,
                          title: 'Auftrag erstellt',
                          subtitle: 'Initiale Erstellung des Auftrags',
                          timestamp: order.orderDate,
                          userName: 'System',
                        ),
                      ],
                    );
                  }

                  final historyEntries = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: historyEntries.length + 1, // +1 für Erstellungs-Eintrag
                    itemBuilder: (context, index) {
                      // Erster Eintrag ist immer die Erstellung
                      if (index == historyEntries.length) {
                        return _buildHistoryEntry(
                          icon: Icons.add_circle,
                          iconName:'add_circle',
                          color: Colors.green,
                          title: 'Auftrag erstellt',
                          subtitle: 'Initiale Erstellung des Auftrags',
                          timestamp: order.orderDate,
                          userName: 'System',
                        );
                      }

                      final data = historyEntries[index].data() as Map<String, dynamic>;
                      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final userName = data['user_name'] ?? 'Unknown';
                      final action = data['action'] ?? '';
                      final changes = data['changes'] as Map<String, dynamic>? ?? {};

                      // Bestimme Icon und Farbe basierend auf der Aktion
                      IconData icon;
                      String iconName;
                      Color color;
                      String title;
                      String subtitle;

                      switch (action) {
                        case 'status_change':
                          icon = Icons.swap_horiz;
                          iconName='swap_horiz';
                          color = _getStatusColor(OrderStatus.values.firstWhere(
                                (s) => s.name == changes['new_value'],
                            orElse: () => OrderStatus.processing,
                          ));
                          title = 'Status geändert';
                          subtitle = '${changes['old_display']} → ${changes['new_display']}';
                          break;

                        case 'order_cancelled':
                          icon = Icons.cancel;
                          iconName='cancel';
                          color = Colors.red;
                          title = 'Auftrag storniert';
                          subtitle = data['reason'] ?? 'Manuell storniert';
                          break;
                        default:
                          icon = Icons.info;
                          iconName='info';
                          color = Colors.grey;
                          title = 'Änderung';
                          subtitle = action;
                      }

                      return _buildHistoryEntry(
                        icon: icon,
                        iconName:iconName,
                        color: color,
                        title: title,
                        subtitle: subtitle,
                        timestamp: timestamp,
                        userName: userName,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

// Prüfe ob Veranlagungsverfügung benötigt wird (Warenwert > 1000 CHF)
  bool _needsVeranlagungsverfuegung(OrderX order) {
    final total = (order.calculations['total'] as num? ?? 0).toDouble();

    // Bei anderen Währungen in CHF umrechnen
    final currency = order.metadata?['currency'] ?? 'CHF';
    if (currency != 'CHF') {
      final exchangeRates = order.metadata?['exchangeRates'] as Map<String, dynamic>? ?? {};
      final rate = (exchangeRates['CHF'] as num?)?.toDouble() ?? 1.0;
      return (total / rate) > 1000.0;
    }

    return total > 1000.0;
  }

// Prüfe ob Veranlagungsnummer bereits vorhanden ist
  bool _hasVeranlagungsnummer(OrderX order) {
    return order.metadata?['veranlagungsnummer'] != null &&
        order.metadata!['veranlagungsnummer'].toString().isNotEmpty;
  }


  void _showVeranlagungsverfuegungDialog(OrderX order) {
    final veranlagungsnummerController = TextEditingController(
      text: order.metadata?['veranlagungsnummer']?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      getAdaptiveIcon(iconName: 'assignment', defaultIcon:
                        Icons.assignment,
                        color: _hasVeranlagungsnummer(order)
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Veranlagungsverfügung Ausfuhr',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Auftrag ${order.orderNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:  getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                 getAdaptiveIcon(iconName: 'info', defaultIcon:Icons.info, color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Warenwert: CHF ${_convertPrice((order.calculations['total'] as num? ?? 0).toDouble(), order).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Bei Lieferungen mit einem Warenwert über CHF 1\'000.00 muss die Veranlagungsverfügung Ausfuhr gespeichert werden.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _hasVeranlagungsnummer(order)
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _hasVeranlagungsnummer(order)
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                          getAdaptiveIcon(iconName: _hasVeranlagungsnummer(order)?'check_circle':'warning', defaultIcon: _hasVeranlagungsnummer(order)
                            ? Icons.check_circle
                            : Icons.warning,

                              color: _hasVeranlagungsnummer(order)
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _hasVeranlagungsnummer(order)
                                    ? 'Veranlagungsnummer erfasst'
                                    : 'Veranlagungsnummer fehlt',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _hasVeranlagungsnummer(order)
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Eingabefeld für Veranlagungsnummer
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Veranlagungsnummer',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: veranlagungsnummerController,
                            decoration: InputDecoration(
                              hintText: 'z.B. 25CH04EXA83JFTR0N8',
                              hintStyle: TextStyle(fontSize: 14),
                              prefixIcon:  getAdaptiveIcon(iconName: 'pin',defaultIcon:Icons.pin),
                              suffixIcon: _hasVeranlagungsnummer(order)
                                  ?  getAdaptiveIcon(iconName: 'check',defaultIcon:Icons.check, color: Colors.green)
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ],
                      ),

                      if (_hasVeranlagungsnummer(order)) ...[
                        const SizedBox(height: 16),
                        // Dokument-Upload Status
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              getAdaptiveIcon(iconName: 'picture_as_pdf', defaultIcon:
                                Icons.picture_as_pdf,
                                size: 20,
                                color: order.documents.containsKey('veranlagungsverfuegung_pdf')
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PDF-Dokument',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      order.documents.containsKey('veranlagungsverfuegung_pdf')
                                          ? 'Dokument hochgeladen'
                                          : 'Noch kein Dokument hochgeladen',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Im _showVeranlagungsverfuegungDialog, ersetze die PDF-Status Row mit:

                              if (order.documents.containsKey('veranlagungsverfuegung_pdf'))
                                Row(
                                  children: [
                                    IconButton(
                                      icon:  getAdaptiveIcon(iconName: 'delete',defaultIcon:Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('PDF löschen'),
                                            content: Text('Möchten Sie die Veranlagungsverfügung wirklich löschen?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: Text('Abbrechen'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: Text('Löschen'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed == true) {
                                          await _deleteDocument(order, 'veranlagungsverfuegung_pdf');
                                          Navigator.pop(context);
                                        }
                                      },
                                      tooltip: 'PDF löschen',
                                    ),
                                    IconButton(
                                      icon:  getAdaptiveIcon(iconName: 'visibility',defaultIcon:Icons.visibility, size: 20),
                                      onPressed: () => _openDocument(order.documents['veranlagungsverfuegung_pdf']!),
                                      tooltip: 'Dokument anzeigen',
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Schließen'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final nummer = veranlagungsnummerController.text.trim();

                                if (nummer.isEmpty && !_hasVeranlagungsnummer(order)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Bitte Veranlagungsnummer eingeben'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  // Update Firestore
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(order.id)
                                      .update({
                                    'metadata.veranlagungsnummer': nummer.isNotEmpty ? nummer : FieldValue.delete(),
                                    'metadata.veranlagungsnummer_updated_at': FieldValue.serverTimestamp(),
                                    'updated_at': FieldValue.serverTimestamp(),
                                  });

                                  // History Entry
                                  final user = FirebaseAuth.instance.currentUser;
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(order.id)
                                      .collection('history')
                                      .add({
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'user_id': user?.uid ?? 'unknown',
                                    'user_email': user?.email ?? 'Unknown User',
                                    'user_name': user?.email ?? 'Unknown',
                                    'action': 'veranlagungsnummer_updated',
                                    'veranlagungsnummer': nummer,
                                    'old_value': order.metadata?['veranlagungsnummer'],
                                    'new_value': nummer.isNotEmpty ? nummer : null,
                                  });

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(nummer.isNotEmpty
                                            ? 'Veranlagungsnummer gespeichert'
                                            : 'Veranlagungsnummer entfernt'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Fehler: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon:  getAdaptiveIcon(iconName: 'save',defaultIcon:Icons.save),
                              label: const Text('Speichern'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Upload Button für PDF
                      if (_hasVeranlagungsnummer(order) && !order.documents.containsKey('veranlagungsverfuegung_pdf')) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _uploadVeranlagungsPDF(order),
                            icon:  getAdaptiveIcon(iconName: 'upload_file',defaultIcon:Icons.upload_file),
                            label: const Text('PDF hochladen'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              foregroundColor: Theme.of(context).colorScheme.onSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// 4. Füge diese neue Methode für den PDF-Upload hinzu:

  Future<void> _uploadVeranlagungsPDF(OrderX order) async {
    try {
      // Importiere diese am Anfang der Datei:
      // import 'package:file_picker/file_picker.dart';

      // Wähle PDF-Datei
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        // Zeige Ladeindikator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animiertes Upload Icon
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child:  getAdaptiveIcon(iconName: 'cloud_upload', defaultIcon:
                            Icons.cloud_upload,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Veranlagungsverfügung',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dokument wird hochgeladen...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Subtiler Progress Indicator
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Hole Datei-Bytes
        Uint8List? fileBytes = result.files.first.bytes;
        String fileName = result.files.first.name;

        // Falls Web, verwende bytes, sonst path
        if (fileBytes == null) {
          final path = result.files.first.path;
          if (path != null) {
            final file = await File(path).readAsBytes();
            fileBytes = file;
          }
        }

        if (fileBytes != null) {
          // Erstelle Storage-Referenz
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('orders')
              .child(order.id)
              .child('veranlagungsverfuegung')
              .child('veranlagungsverfuegung_${DateTime.now().millisecondsSinceEpoch}.pdf');

          // Lade Datei hoch
          final uploadTask = await storageRef.putData(
            fileBytes,
            SettableMetadata(
              contentType: 'application/pdf',
              customMetadata: {
                'orderNumber': order.orderNumber,
                'documentType': 'Veranlagungsverfügung',
                'veranlagungsnummer': order.metadata?['veranlagungsnummer'] ?? '',
                'uploadedAt': DateTime.now().toIso8601String(),
                'originalFileName': fileName,
              },
            ),
          );

          // Hole Download-URL
          final downloadUrl = await uploadTask.ref.getDownloadURL();

          // Update Firestore
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .update({
            'documents.veranlagungsverfuegung_pdf': downloadUrl,
            'metadata.veranlagungsverfuegung_uploaded_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

          // Erstelle History-Eintrag
          final user = FirebaseAuth.instance.currentUser;
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .collection('history')
              .add({
            'timestamp': FieldValue.serverTimestamp(),
            'user_id': user?.uid ?? 'unknown',
            'user_email': user?.email ?? 'Unknown User',
            'user_name': user?.email ?? 'Unknown',
            'action': 'veranlagungsverfuegung_uploaded',
            'document_type': 'Veranlagungsverfügung Ausfuhr',
            'file_name': fileName,
            'veranlagungsnummer': order.metadata?['veranlagungsnummer'] ?? '',
          });

          if (mounted) {
            Navigator.pop(context); // Schließe Ladeindikator
            Navigator.pop(context); // Schließe Modal

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Veranlagungsverfügung wurde erfolgreich hochgeladen'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Schließe Ladeindikator falls offen

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Upload: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

// 5. Erweitere _getDocumentTypeName um den neuen Dokumenttyp:
// In der _getDocumentTypeName Methode, füge diesen Fall hinzu:

  String _getDocumentTypeName(String docType) {
    switch (docType) {
      case 'quote_pdf':
        return 'Angebot';
      case 'invoice_pdf':
        return 'Rechnung';
      case 'delivery_note_pdf':
        return 'Lieferschein';
      case 'commercial_invoice_pdf':
        return 'Handelsrechnung';
      case 'packing_list_pdf':
        return 'Packliste';
      case 'veranlagungsverfuegung_pdf':  // NEU
        return 'Veranlagungsverfügung Ausfuhr';
      default:
        return docType.replaceAll('_', ' ').replaceAll('-', ' ');
    }
  }


  Widget _buildHistoryEntry({
    required IconData icon,
    required String iconName,
    required Color color,
    required String title,
    required String subtitle,
    required DateTime timestamp,
    required String userName,
  }) {
    final timeAgo = _getTimeAgo(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
                child:  getAdaptiveIcon(
                    iconName: iconName,
                    defaultIcon:icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'person',
                      defaultIcon:
                      Icons.person,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('dd.MM.yyyy HH:mm').format(timestamp);
    } else if (difference.inDays > 0) {
      return 'vor ${difference.inDays} Tag${difference.inDays == 1 ? '' : 'en'}';
    } else if (difference.inHours > 0) {
      return 'vor ${difference.inHours} Stunde${difference.inHours == 1 ? '' : 'n'}';
    } else if (difference.inMinutes > 0) {
      return 'vor ${difference.inMinutes} Minute${difference.inMinutes == 1 ? '' : 'n'}';
    } else {
      return 'gerade eben';
    }
  }



  void _viewOrderDocuments(OrderX order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id)
            .snapshots(),
        builder: (context, snapshot) {
          final currentOrder = snapshot.hasData && snapshot.data!.exists
              ? OrderX.fromFirestore(snapshot.data!)
              : order;

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      getAdaptiveIcon(iconName: 'folder_open', defaultIcon: Icons.folder_open),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dokumente - ${currentOrder.orderNumber}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Content
                Expanded(
                  child: currentOrder.documents.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        getAdaptiveIcon(
                          iconName: 'description',
                          defaultIcon:
                          Icons.description,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Keine Dokumente verfügbar',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: currentOrder.documents.length,
                    itemBuilder: (context, index) {
                      final entry = currentOrder.documents.entries.elementAt(index);
                      final docType = entry.key;
                      final docUrl = entry.value;

                      // Prüfe ob das Dokument löschbar ist
                      final isDeletable = ['delivery_note_pdf', 'commercial_invoice_pdf', 'packing_list_pdf']
                          .contains(docType);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getDocumentTypeColor(docType).withOpacity(0.1),
                            child: _buildAdaptiveDocumentIcon(docType),
                          ),
                          title: Text(_getDocumentTypeName(docType),style: TextStyle(fontSize:12),),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:   getAdaptiveIcon(
                                    iconName: 'visibility',
                                    defaultIcon:Icons.visibility, size: 20),
                                onPressed: () => _openDocument(docUrl),
                                tooltip: 'Öffnen',
                              ),
                              IconButton(
                                icon:   getAdaptiveIcon(
                                    iconName: 'share',
                                    defaultIcon:Icons.share, size: 20),
                                onPressed: () => _shareDocument(docUrl, docType, currentOrder.orderNumber),
                                tooltip: 'Weiterleiten',
                              ),
                              if (isDeletable)
                                IconButton(
                                  icon:  getAdaptiveIcon(
                                      iconName: 'delete',
                                      defaultIcon:Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () => _deleteDocument(currentOrder, docType),
                                  tooltip: 'Löschen',
                                ),
                              if (!isDeletable)
                               SizedBox(width: 20,)
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Button zum Erstellen weiterer Dokumente
                if (!currentOrder.documents.containsKey('invoice_pdf') ||
                    !currentOrder.documents.containsKey('delivery_note_pdf') ||
                    !currentOrder.documents.containsKey('commercial_invoice_pdf') ||
                    !currentOrder.documents.containsKey('packing_list_pdf'))
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context); // Schließe zuerst das aktuelle Modal
                        await OrderDocumentManager.showCreateDocumentsDialog(context, currentOrder);
                      },
                      icon:   getAdaptiveIcon(
                          iconName: 'add',
                          defaultIcon:Icons.add),
                      label: const Text('Dokumente erstellen'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }

// Neue Methode zum Löschen von Dokumenten
  Future<void> _deleteDocument(OrderX order, String docType) async {
    // Bestätigungsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dokument löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie "${_getDocumentTypeName(docType)}" wirklich löschen?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [

                      getAdaptiveIcon(
                          iconName: 'warning',
                          defaultIcon:Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Hinweis:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Das PDF-Dokument wird gelöscht\n'
                        '• Die Einstellungen werden zurückgesetzt\n'
                        '• Sie können das Dokument jederzeit neu erstellen',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Zeige Ladeindikator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final batch = FirebaseFirestore.instance.batch();

        // 1. Lösche das Dokument aus Firebase Storage
        if (order.documents[docType] != null) {
          try {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('orders')
                .child(order.id)
                .child('$docType.pdf');
            await storageRef.delete();
          } catch (e) {
            print('Fehler beim Löschen aus Storage: $e');
          }
        }

        // 2. Entferne die Dokument-URL aus dem Order-Dokument
        final orderRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id);

        batch.update(orderRef, {
          'documents.$docType': FieldValue.delete(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // 3. Lösche spezifische Einstellungen je nach Dokumenttyp
        switch (docType) {
          case 'packing_list_pdf':
          // Lösche Packlisten-Einstellungen
            final packingListRef = FirebaseFirestore.instance
                .collection('orders')
                .doc(order.id)
                .collection('packing_list')
                .doc('settings');
            batch.delete(packingListRef);
            break;

          case 'delivery_note_pdf':
          // Lösche Lieferschein-Einstellungen (falls vorhanden)
            final deliverySettingsRef = FirebaseFirestore.instance
                .collection('orders')
                .doc(order.id)
                .collection('settings')
                .doc('delivery_settings');
            batch.delete(deliverySettingsRef);
            break;

          case 'commercial_invoice_pdf':
          // Lösche Handelsrechnung-Einstellungen (falls vorhanden)
            final commercialSettingsRef = FirebaseFirestore.instance
                .collection('orders')
                .doc(order.id)
                .collection('settings')
                .doc('tara_settings');
            batch.delete(commercialSettingsRef);
            break;
        }

        // 4. Erstelle History-Eintrag
        final user = FirebaseAuth.instance.currentUser;
        final historyRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id)
            .collection('history')
            .doc();

        batch.set(historyRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'user_id': user?.uid ?? 'unknown',
          'user_email': user?.email ?? 'Unknown User',
          'user_name': user?.email ?? 'Unknown',
          'action': 'document_deleted',
          'document_type': _getDocumentTypeName(docType),
          'document_key': docType,
        });

        // Commit aller Änderungen
        await batch.commit();

        if (mounted) {
          Navigator.pop(context); // Schließe Ladeindikator

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_getDocumentTypeName(docType)} wurde gelöscht'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Schließe Ladeindikator

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Löschen: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  Color _getDocumentTypeColor(String docType) {
    if (docType.contains('quote')) return Colors.blue;
    if (docType.contains('invoice')) return Colors.green;
    if (docType.contains('delivery')) return Colors.purple;
    if (docType.contains('packing')) return Colors.orange;
    return Colors.grey;
  }

// Kombinierte Funktion
  Widget _buildAdaptiveDocumentIcon(String docType) {
    String iconName;
    IconData defaultIcon;

    if (docType.contains('pdf')) {
      iconName = 'picture_as_pdf';
      defaultIcon = Icons.picture_as_pdf;
    } else if (docType.contains('csv')) {
      iconName = 'table_chart';
      defaultIcon = Icons.table_chart;
    } else {
      iconName = 'description';
      defaultIcon = Icons.description;
    }

    return getAdaptiveIcon(
      iconName: iconName,
      defaultIcon: defaultIcon,
      color: _getDocumentTypeColor(docType),
    );
  }



  String _getDocumentTypeDescription(String docType) {
    switch (docType) {
      case 'quote_pdf':
        return 'PDF-Dokument des ursprünglichen Angebots';
      case 'invoice_pdf':
        return 'PDF-Dokument der Rechnung';
      case 'delivery-note_pdf':
        return 'PDF-Dokument des Lieferscheins';
      case 'commercial-invoice_pdf':
        return 'PDF-Dokument der Handelsrechnung';
      case 'packing-list_pdf':
        return 'PDF-Dokument der Packliste';
      default:
        return 'Dokument';
    }
  }

  Future<void> _openDocument(String url) async {
    try {
      final uri = Uri.parse(url);

      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        if (!await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        )) {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link wurde in die Zwischenablage kopiert. Sie können ihn in Ihrem Browser einfügen.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _shareDocument(String url, String docType, String orderNumber) async {
    try {
      final documentName = '${_getDocumentTypeName(docType)} - Auftrag $orderNumber';

      await Share.share(
        url,
        subject: documentName,
      );
    } catch (e) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link kopiert: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _shareOrder(OrderX order) async {
    final String orderInfo = '''
Auftrag ${order.orderNumber}
Datum: ${DateFormat('dd.MM.yyyy').format(order.orderDate)}
Kunde: ${order.customer['company'] ?? order.customer['fullName']}
Betrag: CHF ${(order.calculations['total'] as num? ?? 0).toStringAsFixed(2)}
Status: ${order.status.displayName}

''';

    await Share.share(orderInfo, subject: 'Auftrag ${order.orderNumber}');
  }

  Future<void> _releaseOrder(OrderX order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auftrag stornieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie den Auftrag ${order.orderNumber} stornieren?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      getAdaptiveIcon(
                          iconName: 'warning',
                          defaultIcon:Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Wichtiger Hinweis:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Alle Produktreservierungen werden aufgehoben\n'
                        '• Die Produkte werden wieder für andere Aufträge verfügbar\n'
                        '• Der Auftrag wird als storniert markiert\n'
                        '• Diese Aktion kann nicht rückgängig gemacht werden',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stornieren'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );





        final batch = FirebaseFirestore.instance.batch();

        // NEU: Wenn der Auftrag aus einem Angebot erstellt wurde,
        // markiere das Angebot als "nachträglich storniert"
        if (order.quoteId != null && order.quoteId!.isNotEmpty) {
          final quoteRef = FirebaseFirestore.instance
              .collection('quotes')
              .doc(order.quoteId);

          batch.update(quoteRef, {
            'isOrderCancelled': true,
            'orderCancelledAt': FieldValue.serverTimestamp(),
          });


          print("quoteID:${order.quoteId}");
          // Erstelle auch einen History-Eintrag im Angebot
          final quoteHistoryRef = FirebaseFirestore.instance
              .collection('quotes')
              .doc(order.quoteId)
              .collection('history')
              .doc();
          final user = FirebaseAuth.instance.currentUser;
          batch.set(quoteHistoryRef, {
            'timestamp': FieldValue.serverTimestamp(),
            'user_id': user?.uid ?? 'unknown',
            'user_email': user?.email ?? 'Unknown User',
            'user_name': user?.email ?? 'Unknown',
            'action': 'order_cancelled',
            'order_number': order.orderNumber,
            'reason': 'Zugehöriger Auftrag wurde storniert',
          });
        }




        for (final item in order.items) {
          if (item['is_manual_product'] == true) continue;

          final inventoryRef = FirebaseFirestore.instance
              .collection('inventory')
              .doc(item['product_id']);

          batch.update(inventoryRef, {
            'quantity': FieldValue.increment(item['quantity'] as double),
            'last_modified': FieldValue.serverTimestamp(),
          });

          final stockEntryRef = FirebaseFirestore.instance
              .collection('stock_entries')
              .doc();

          // Create History Entry for cancellation
          final user = FirebaseAuth.instance.currentUser;
          final historyRef = FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .collection('history')
              .doc();

          batch.set(historyRef, {
            'timestamp': FieldValue.serverTimestamp(),
            'user_id': user?.uid ?? 'unknown',
            'user_email': user?.email ?? 'Unknown User',
            'user_name': user?.email ?? 'Unknown',
            'action': 'order_cancelled',
            'reason': 'Manuell storniert - Reservierungen aufgehoben',
            'changes': {
              'field': 'status',
              'old_value': order.status.name,
              'new_value': OrderStatus.cancelled.name,
              'old_display': order.status.displayName,
              'new_display': OrderStatus.cancelled.displayName,
            },
          });
        }






        final orderRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id);

        batch.update(orderRef, {
          'status': OrderStatus.cancelled.name,
          'cancelled_at': FieldValue.serverTimestamp(),
          'cancellation_reason': 'Manuell storniert - Reservierungen aufgehoben',
        });

        await batch.commit();

        if (mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auftrag ${order.orderNumber} wurde erfolgreich storniert'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Stornieren des Auftrags: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _filterSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  double _convertPrice(double priceInCHF, OrderX order) {
    final currency = order.metadata['currency'] ?? 'CHF';
    if (currency == 'CHF') return priceInCHF;

    final exchangeRates = order.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
    final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;
    return priceInCHF * rate;
  }
}