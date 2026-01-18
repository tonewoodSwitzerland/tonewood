import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/country_dropdown_widget.dart';
import 'customer.dart';
import 'customer_export_service.dart';
import '../services/icon_helper.dart';

import 'package:intl/intl.dart';

import 'customer_filter_dialog.dart';
import 'customer_filter_favorite_sheet.dart';
import 'customer_filter_service.dart';
import 'customer_group/customer_group_management_screen.dart';
import 'customer_group/customer_group_selection_widget.dart';
import 'customer_group/customer_group_service.dart';
import 'customer_import_dialog.dart';
import 'customer_label_print_screen.dart';
import 'customer_selection.dart';

/// Vollbild-Screen zur Kundenverwaltung
class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({Key? key}) : super(key: key);

  @override
  CustomerManagementScreenState createState() => CustomerManagementScreenState();
}

class CustomerManagementScreenState extends State<CustomerManagementScreen> {
  // ============================================================================
  // STATE VARIABLES - Gruppiert nach Funktion
  // ============================================================================

  // --- UI Controllers ---
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // --- Data State ---
  List<DocumentSnapshot> _customerDocs = [];
  DocumentSnapshot? _lastDocument; // Für bessere Pagination

  // --- Loading State ---
  bool _isLoading = false;
  bool _isFilteredDataLoading = false;
  bool _hasMore = true;
  final int _pageSize = 20; // Erhöht von 10 auf 20

  // --- Search State ---
  String _lastSearchTerm = '';
  Timer? _debounce;
  static const _searchDebounceMs = 500;

  // --- Filter State ---
  Map<String, dynamic> _activeFilters = CustomerFilterService.createEmptyFilter();
  StreamSubscription<Map<String, dynamic>>? _filterSubscription;
  List<DocumentSnapshot>? _cachedFilterResults; // NEU: Cache für Filter


  @override
  void initState() {
    super.initState();
    _loadFilters(); // NEU
    CustomerGroupService.initializeDefaultGroups();
    _loadInitialCustomers();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore &&
          !CustomerFilterService.hasActiveFilters(_activeFilters)) { // NEU: Check für aktive Filter
        _loadMoreCustomers();
      }
    });

    _searchController.addListener(_onSearchChanged);
  }
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: _searchDebounceMs), () { // ← Nutze Konstante
      if (_searchController.text != _lastSearchTerm) {
        _lastSearchTerm = _searchController.text;

        if (_lastSearchTerm.isEmpty) {
          // If search is cleared, reload initial data
          setState(() {
            _customerDocs = [];
            _hasMore = true;
          });
          _loadInitialCustomers();
        } else {
          // With search text, we'll do a client-side search with improved loading
          _performSearch();
        }
      }
    });
  }
  void _loadFilters() {
    _filterSubscription = CustomerFilterService.loadSavedFilters().listen((filters) {
      if (mounted) {
        setState(() {
          _activeFilters = filters;
          _searchController.text = filters['searchText'] ?? '';
        });
        _applyFilters();
      }
    });
  }





  Future<void> _applyFilters() async {
    if (!CustomerFilterService.hasActiveFilters(_activeFilters)) {
      // Wenn keine Filter aktiv sind, lade normale Daten
      _cachedFilterResults = null; // Cache löschen
      _loadInitialCustomers();
      return;
    }

    // NEU: Check Cache first!
    if (_cachedFilterResults != null) {
      setState(() {
        _customerDocs = _cachedFilterResults!;
        _hasMore = false;
        _isFilteredDataLoading = false;
      });
      return; // Fertig! Keine neue Query nötig
    }

    setState(() {
      _isFilteredDataLoading = true;
    });

    try {
      // Lade alle Kunden für die Filterung
      final allCustomersSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .get();

      final allCustomers = allCustomersSnapshot.docs
          .map((doc) => {
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      })
          .toList();

      // Wende Filter an
      final filteredCustomers = await CustomerFilterService.applyClientSideFilters(
        allCustomers,
        _activeFilters,
      );

      // NEU: Speichere im Cache!
      _cachedFilterResults = filteredCustomers.map((customerData) {
        return _MockDocumentSnapshot(customerData);
      }).toList();

      // Konvertiere zurück zu DocumentSnapshots für die Anzeige
      setState(() {
        _customerDocs = _cachedFilterResults!;
        _hasMore = false; // Bei gefilterten Daten kein weiteres Laden
        _isFilteredDataLoading = false;
      });
    } catch (e) {
      print('Fehler beim Anwenden der Filter: $e');
      setState(() {
        _isFilteredDataLoading = false;
      });
    }
  }
  void _showFilterDialog() {
    CustomerFilterDialog.show(
      context,
      currentFilters: _activeFilters,
      onApply: (filters) {
        setState(() {
          _activeFilters = filters;
        });
        CustomerFilterService.saveFilters(filters);
      },
    );
  }

  void _showFilterFavorites() {
    CustomerFilterFavoritesSheet.show(
      context,
      onFavoriteSelected: (favoriteData) {
        setState(() {
          _activeFilters = Map<String, dynamic>.from(favoriteData['filters']);
          _searchController.text = _activeFilters['searchText'] ?? '';
        });
        CustomerFilterService.saveFilters(_activeFilters);
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
            hintText: 'z.B. Premium-Kunden',
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
        await CustomerFilterService.saveFavorite(name, _activeFilters);

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
  void _performSearch() {
    setState(() {
      _isLoading = true;
    });

    // If we have enough customers loaded already, filter them client-side
    if (_customerDocs.length > 20) {
      _filterExistingResults();
    } else {
      // If we don't have many customers loaded, get more from Firestore
      _loadAllCustomersForSearch();
    }
  }

  void _filterExistingResults() {
    // Filter the already loaded customers
    final filteredDocs = _customerDocs.where((doc) {
      final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      final searchTerm = _lastSearchTerm.toLowerCase();

      return customer.company.toLowerCase().contains(searchTerm) ||
          customer.firstName.toLowerCase().contains(searchTerm) ||
          customer.lastName.toLowerCase().contains(searchTerm) ||
          customer.city.toLowerCase().contains(searchTerm) ||
          customer.email.toLowerCase().contains(searchTerm);
    }).toList();

    setState(() {
      _customerDocs = filteredDocs;
      _hasMore = false; // No more to load when filtering
      _isLoading = false;
    });
  }

  Future<void> _loadAllCustomersForSearch() async {
    final searchTerm = _lastSearchTerm.toLowerCase();

    // SCHRITT 1: Suche in bereits geladenen Daten (instant!)
    final localResults = _customerDocs.where((doc) {
      final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      return customer.company.toLowerCase().contains(searchTerm) ||
          customer.firstName.toLowerCase().contains(searchTerm) ||
          customer.lastName.toLowerCase().contains(searchTerm) ||
          customer.city.toLowerCase().contains(searchTerm) ||
          customer.email.toLowerCase().contains(searchTerm);
    }).toList();

    // Zeige lokale Ergebnisse sofort an
    if (localResults.isNotEmpty) {
      setState(() {
        _customerDocs = localResults;
        _isLoading = true; // Weiter laden im Hintergrund
      });
    }

    // SCHRITT 2: Lade zusätzliche Ergebnisse vom Server (max 50)
    try {
      final serverSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .limit(50) // Nur 50 statt 800!
          .get();

      // Filtere Server-Ergebnisse
      final Map<String, DocumentSnapshot> allResults = {};

      // Füge lokale Ergebnisse hinzu
      for (final doc in localResults) {
        allResults[doc.id] = doc;
      }

      // Füge Server-Ergebnisse hinzu (ohne Duplikate)
      for (var doc in serverSnapshot.docs) {
        final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);

        if (customer.company.toLowerCase().contains(searchTerm) ||
            customer.firstName.toLowerCase().contains(searchTerm) ||
            customer.lastName.toLowerCase().contains(searchTerm) ||
            customer.city.toLowerCase().contains(searchTerm) ||
            customer.email.toLowerCase().contains(searchTerm)) {
          allResults[doc.id] = doc;
        }
      }

      setState(() {
        _customerDocs = allResults.values.toList();
        _hasMore = false;
        _isLoading = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInitialCustomers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .limit(_pageSize)
          .get();

      setState(() {
        _customerDocs = querySnapshot.docs;
        // DIESE ZEILE GELÖSCHT!
        _hasMore = querySnapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading customers: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _loadMoreCustomers() async {
    if (_isLoading || !_hasMore || _customerDocs.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final lastDoc = _customerDocs.last;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .startAfterDocument(lastDoc)
          .limit(_pageSize)
          .get();

      if (mounted) {
        setState(() {
          _customerDocs.addAll(querySnapshot.docs);
          // DIESE ZEILE GELÖSCHT!
          _hasMore = querySnapshot.docs.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading more customers: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunden'),
        actions: [
          // Filter-Button (bleibt prominent)
          IconButton(
            icon: Badge(
              isLabelVisible: CustomerFilterService.hasActiveFilters(_activeFilters),
              label: const Text('!'),
              child: getAdaptiveIcon(
                iconName: 'filter_list',
                defaultIcon: Icons.filter_list,
              ),
            ),
            onPressed: _showFilterDialog,
          ),
          // Favoriten-Button (bleibt prominent)
          IconButton(
            icon: getAdaptiveIcon(
              iconName: 'star',
              defaultIcon: Icons.star,
              color: CustomerFilterService.hasActiveFilters(_activeFilters)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _showFilterFavorites,
            tooltip: 'Filter-Favoriten',
          ),
          // NEU: Mehr-Menü für weitere Aktionen
          PopupMenuButton<String>(
            icon: getAdaptiveIcon(iconName: 'more_vert', defaultIcon: Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'groups':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerGroupManagementScreen(),
                    ),
                  );
                  break;
                case 'print':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerLabelPrintScreen(),
                    ),
                  );
                  break;
                case 'import':
                  _showImportDialog();
                  break;
                case 'export':
                  CustomerExportService.exportCustomersCsv(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'groups',
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'group', defaultIcon: Icons.group, size: 20),
                    const SizedBox(width: 12),
                    const Text('Kundengruppen'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'print', defaultIcon: Icons.print, size: 20),
                    const SizedBox(width: 12),
                    const Text('Adressetiketten drucken'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'upload_file', defaultIcon: Icons.upload_file, size: 20),
                    const SizedBox(width: 12),
                    const Text('Kundenimport'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download, size: 20),
                    const SizedBox(width: 12),
                    const Text('CSV exportieren'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Suchfeld
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Suchen',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: getAdaptiveIcon(
                  iconName: 'search',
                  defaultIcon: Icons.search,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'clear',
                    defaultIcon: Icons.clear,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.5),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(height:8),
// Filter-Chips anzeigen
          if (CustomerFilterService.hasActiveFilters(_activeFilters))
            Container(
              height: 40,
              margin: const EdgeInsets.only(top: 0,),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Umsatz-Chip
                  if (_activeFilters['minRevenue'] != null || _activeFilters['maxRevenue'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'Umsatz: ${_activeFilters['minRevenue'] != null ? 'ab CHF ${_activeFilters['minRevenue']}' : ''}${_activeFilters['minRevenue'] != null && _activeFilters['maxRevenue'] != null ? ' - ' : ''}${_activeFilters['maxRevenue'] != null ? 'bis CHF ${_activeFilters['maxRevenue']}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['minRevenue'] = null;
                            _activeFilters['maxRevenue'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Zeitraum-Chip
                  if (_activeFilters['revenueStartDate'] != null || _activeFilters['revenueEndDate'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'Zeitraum: ${_activeFilters['revenueStartDate'] != null ? DateFormat('dd.MM.yy').format(_activeFilters['revenueStartDate']) : ''}${_activeFilters['revenueStartDate'] != null && _activeFilters['revenueEndDate'] != null ? ' - ' : ''}${_activeFilters['revenueEndDate'] != null ? DateFormat('dd.MM.yy').format(_activeFilters['revenueEndDate']) : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon:  getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['revenueStartDate'] = null;
                            _activeFilters['revenueEndDate'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Aufträge-Chip
                  if (_activeFilters['minOrderCount'] != null || _activeFilters['maxOrderCount'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'Aufträge: ${_activeFilters['minOrderCount'] ?? ''}${_activeFilters['minOrderCount'] != null && _activeFilters['maxOrderCount'] != null ? '-' : ''}${_activeFilters['maxOrderCount'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon:  getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['minOrderCount'] = null;
                            _activeFilters['maxOrderCount'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Weihnachtskarte-Chip
                  if (_activeFilters['wantsChristmasCard'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'Weihnachtskarte: ${_activeFilters['wantsChristmasCard'] ? 'JA' : 'NEIN'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon:getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['wantsChristmasCard'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // MwSt-Nummer-Chip
                  if (_activeFilters['hasVatNumber'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'MwSt-Nr: ${_activeFilters['hasVatNumber'] ? 'Vorhanden' : 'Fehlt'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon:  getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['hasVatNumber'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // EORI-Nummer-Chip
                  if (_activeFilters['hasEoriNumber'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'EORI-Nr: ${_activeFilters['hasEoriNumber'] ? 'Vorhanden' : 'Fehlt'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon:   getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['hasEoriNumber'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Länder-Chip
                  if ((_activeFilters['countries'] as List?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${(_activeFilters['countries'] as List).length} Länder',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon:   getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['countries'] = [];
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Sprachen-Chip
                  if ((_activeFilters['languages'] as List?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${(_activeFilters['languages'] as List).length} Sprachen',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon:   getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['languages'] = [];
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  if ((_activeFilters['customerGroups'] as List?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${(_activeFilters['customerGroups'] as List).length} Kundengruppen',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['customerGroups'] = [];
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                ],
              ),
            ),
          // Search status
          if (_lastSearchTerm.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    'Suchergebnisse für "${_lastSearchTerm}"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_customerDocs.length} Ergebnisse',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 8,),
          // Kundenliste mit Lazy Loading
          Expanded(
            child: _isLoading && _customerDocs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _customerDocs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getAdaptiveIcon(
                    iconName: 'search_off',
                    defaultIcon: Icons.search_off,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _lastSearchTerm.isEmpty
                        ? 'Keine Kunden gefunden'
                        : 'Keine Ergebnisse für "${_lastSearchTerm}"',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _customerDocs.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _customerDocs.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final doc = _customerDocs[index];
                final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        _getInitial(customer),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.company.isNotEmpty ? customer.company : customer.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Zeige Name nur wenn Firma vorhanden ist
                        if (customer.company.isNotEmpty && customer.fullName.isNotEmpty)
                          Text(customer.fullName),
                        Text('${customer.zipCode} ${customer.city}'),
                        // NEU: Kundengruppen-Chips anzeigen
                        if (customer.customerGroupIds.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          CustomerGroupChips(
                            groupIds: customer.customerGroupIds,
                            wrap: true,
                          ),
                        ],
                      ],
                    ),
                    isThreeLine: customer.company.isNotEmpty || customer.customerGroupIds.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
                          onPressed: () async {
                            final wasUpdated = await CustomerSelectionSheet.showEditCustomerDialog(context, customer);
                            if (wasUpdated) {
                              // NEU: Cache invalidieren!
                              _cachedFilterResults = null;
                              if (_lastSearchTerm.isEmpty) {
                                _loadInitialCustomers();
                              } else {
                                _performSearch();
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
                          onPressed: () {
                            _showDeleteConfirmation(context, customer);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      _showCustomerDetails(context, customer);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final newCustomer = await CustomerSelectionSheet.showNewCustomerDialog(context);
            if (newCustomer != null) {
              // NEU: Cache invalidieren!
              _cachedFilterResults = null;
              // Reload customers to include the new one
              setState(() {
                _customerDocs = [];
                _hasMore = true;
                _lastSearchTerm = '';
                _searchController.clear();
              });
              _loadInitialCustomers();
            }
          },
        child: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
        tooltip: 'Neuer Kunde',
      ),
    );
  }
  String _getInitial(Customer customer) {
    // Versuche zuerst Firma
    if (customer.company.isNotEmpty) {
      return customer.company.substring(0, 1).toUpperCase();
    }

    // Dann Vorname
    if (customer.firstName.isNotEmpty) {
      return customer.firstName.substring(0, 1).toUpperCase();
    }

    // Dann Nachname
    if (customer.lastName.isNotEmpty) {
      return customer.lastName.substring(0, 1).toUpperCase();
    }

    // Fallback
    return '?';
  }
  void _showImportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomerImportDialog(
        onImportComplete: () {
          // NEU: Cache invalidieren!
          _cachedFilterResults = null;
          // Liste neu laden nach erfolgreichem Import
          _loadInitialCustomers();
        },
      ),
    );
  }
  // Löschbestätigung anzeigen
  void _showDeleteConfirmation(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kunde löschen'),
        content: Text(
          'Möchtest du den Kunden "${customer.company}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await CustomerSelectionSheet.deleteCustomer(context, customer.id);
              if (success && context.mounted) {
                Navigator.pop(context);
                // NEU: Cache invalidieren!
                _cachedFilterResults = null;
                _loadInitialCustomers(); // Liste neu laden
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kunde wurde gelöscht'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('customers')
            .doc(customer.id)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'error',
                      defaultIcon: Icons.error,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text('Kunde nicht gefunden'),
                  ],
                ),
              ),
            );
          }

          // Erstelle Customer-Objekt mit aktuellen Daten
          final currentCustomer = Customer.fromMap(
            snapshot.data!.data() as Map<String, dynamic>,
            snapshot.data!.id,
          );

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            currentCustomer.name.isNotEmpty
                                ? currentCustomer.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentCustomer.name.isNotEmpty ? currentCustomer.name : 'Unbenannter Kunde',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (currentCustomer.countryCode?.isNotEmpty == true)
                                Text(
                                  'Länderkürzel: ${currentCustomer.countryCode}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                        ),
                      ],
                    ),
                  ),

                  // Tab-Bar
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      tabs: [
                        Tab(
                          icon: getAdaptiveIcon(iconName: 'person', defaultIcon: Icons.person),
                          text: 'Details',
                        ),
                        Tab(
                          icon: getAdaptiveIcon(iconName: 'shopping_bag', defaultIcon: Icons.shopping_bag),
                          text: 'Kaufhistorie',
                        ),
                      ],
                    ),
                  ),

                  // Tab-Views
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Kundendetails
                        _buildCustomerDetailsTab(context, currentCustomer),

                        // Tab 2: Kaufhistorie
                        _buildPurchaseHistoryTab(context, currentCustomer),
                      ],
                    ),
                  ),

                  // Aktionsbuttons
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child:
                            OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                final wasUpdated = await CustomerSelectionSheet.showEditCustomerDialog(context, currentCustomer);
                                if (wasUpdated) {
                                  // NEU: Cache invalidieren und neu laden!
                                  _cachedFilterResults = null;
                                  _loadInitialCustomers();
                                }
                              },
                              icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
                              label: const Text('Bearbeiten'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showDeleteConfirmation(context, currentCustomer);
                              },
                              icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
                              label: const Text('Löschen'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
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
        },
      ),
    );
  }

// Tab 1: Kundendetails (dein bestehender Code)
  Widget _buildCustomerDetailsTab(BuildContext context, Customer customer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grunddaten
          _buildDetailSection(
            context,
            'Grunddaten',
            [
              _buildDetailRow('Kunden-ID', customer.id.isNotEmpty ? customer.id : 'Noch nicht vergeben'),
              _buildDetailRow('Name/Firma', customer.name),
              if (customer.company?.isNotEmpty == true)
                _buildDetailRow('Firma', customer.company!),
              if (customer.firstName?.isNotEmpty == true)
                _buildDetailRow('Vorname', customer.firstName!),
              if (customer.lastName?.isNotEmpty == true)
                _buildDetailRow('Name', customer.lastName!),
            ],
          ),

          const SizedBox(height: 16),

          // Kontaktdaten
          _buildDetailSection(
            context,
            'Kontaktdaten',
            [
              if (customer.email?.isNotEmpty == true)
                _buildDetailRow('E-Mail', customer.email!),
              if (customer.phone1?.isNotEmpty == true)
                _buildDetailRow('Telefon 1', customer.phone1!),
              if (customer.phone2?.isNotEmpty == true)
                _buildDetailRow('Telefon 2', customer.phone2!),
            ],
          ),

          const SizedBox(height: 16),

          // Rechnungsadresse
          _buildDetailSection(
            context,
            'RechnungsadresseX',
            [
              if (customer.street?.isNotEmpty == true)
                _buildDetailRow('Straße', '${customer.street}'),
              if (customer.street?.isNotEmpty == true)
                _buildDetailRow('Hausnummer', '${customer.houseNumber}'),

              if (customer.addressSupplement?.isNotEmpty == true)
                _buildDetailRow('Adresszusatz', customer.addressSupplement!),
              if (customer.districtPOBox?.isNotEmpty == true)
                _buildDetailRow('Bezirk/Postfach', customer.districtPOBox!),
              if (customer.zipCode?.isNotEmpty == true || customer.city?.isNotEmpty == true)
                _buildDetailRow('Ort', '${customer.zipCode ?? ''} ${customer.city ?? ''}'),
              if (customer.country?.isNotEmpty == true)
                _buildDetailRow('Land', '${customer.country}${customer.countryCode?.isNotEmpty == true ? ' (${customer.countryCode})' : ''}'),
            ],
          ),

          const SizedBox(height: 16),

          // Steuerliche Angaben
          // Steuerliche Angaben
          if (customer.vatNumber?.isNotEmpty == true ||
              customer.eoriNumber?.isNotEmpty == true ||
              (customer.customFieldTitle?.isNotEmpty == true && customer.customFieldValue?.isNotEmpty == true))
            _buildDetailSection(
              context,
              'Steuerliche Angaben',
              [
                if (customer.vatNumber?.isNotEmpty == true)
                  _buildDetailRow(
                      'MwSt-Nummer / UID',
                      '${customer.vatNumber}${customer.showVatOnDocuments ? ' ✓' : ''}'
                  ),
                if (customer.eoriNumber?.isNotEmpty == true)
                  _buildDetailRow(
                      'EORI-Nummer',
                      '${customer.eoriNumber}${customer.showEoriOnDocuments ? ' ✓' : ''}'
                  ),
                if (customer.customFieldTitle?.isNotEmpty == true &&
                    customer.customFieldValue?.isNotEmpty == true)
                  _buildDetailRow(
                      customer.customFieldTitle!,
                      '${customer.customFieldValue}${customer.showCustomFieldOnDocuments ? ' ✓' : ''}'
                  ),
                // Hinweis-Zeile
                if (customer.showVatOnDocuments || customer.showEoriOnDocuments || customer.showCustomFieldOnDocuments)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '✓ = Wird in Dokumenten angezeigt',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (customer.vatNumber?.isNotEmpty == true ||
              customer.eoriNumber?.isNotEmpty == true ||
              (customer.customFieldTitle?.isNotEmpty == true && customer.customFieldValue?.isNotEmpty == true))
            const SizedBox(height: 16),

          // Lieferadresse (falls abweichend)
          if (customer.hasDifferentShippingAddress) ...[
            _buildDetailSection(
              context,
              'Lieferadresse',
              [
                if (customer.shippingCompany?.isNotEmpty == true)
                  _buildDetailRow('Firma', customer.shippingCompany!),
                if (customer.shippingFirstName?.isNotEmpty == true || customer.shippingLastName?.isNotEmpty == true)
                  _buildDetailRow('Name', '${customer.shippingFirstName ?? ''} ${customer.shippingLastName ?? ''}'),
                if (customer.shippingStreet?.isNotEmpty == true)
                  _buildDetailRow('Straße', '${customer.shippingStreet}${customer.shippingHouseNumber?.isNotEmpty == true ? ' ${customer.shippingHouseNumber}' : ''}'),
                if (customer.shippingZipCode?.isNotEmpty == true || customer.shippingCity?.isNotEmpty == true)
                  _buildDetailRow('Ort', '${customer.shippingZipCode ?? ''} ${customer.shippingCity ?? ''}'),
                if (customer.shippingCountry?.isNotEmpty == true)
                  _buildDetailRow('Land', '${customer.shippingCountry}${customer.shippingCountryCode?.isNotEmpty == true ? ' (${customer.shippingCountryCode})' : ''}'),
                if (customer.shippingEmail?.isNotEmpty == true)
                  _buildDetailRow('E-Mail', customer.shippingEmail!),
                if (customer.shippingPhone?.isNotEmpty == true)
                  _buildDetailRow('Telefon', customer.shippingPhone!),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Weitere Informationen
          _buildDetailSection(
            context,
            'Weitere Informationen',
            [
              _buildDetailRow('Sprache', customer.language == 'DE' ? 'Deutsch' :
              customer.language == 'EN' ? 'Englisch' :
              customer.language ?? 'Nicht angegeben'),
              _buildDetailRow('Weihnachtskarte', customer.wantsChristmasCard ? 'JA' : 'NEIN'),
              _buildDetailRow('Abweichende Lieferadresse', customer.hasDifferentShippingAddress ? 'JA' : 'NEIN'),
              if (customer.notes?.isNotEmpty == true)
                _buildDetailRow('Notizen', customer.notes!),
            ],
          ),

// Kundengruppen
          if (customer.customerGroupIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDetailSection(
              context,
              'Kundengruppen',
              [
                CustomerGroupChips(
                  groupIds: customer.customerGroupIds,
                  wrap: true,
                ),
              ],
            ),
          ],



        ],
      ),
    );
  }

// In der _buildPurchaseHistoryTab Methode, ersetze den StreamBuilder mit:

  Widget _buildPurchaseHistoryTab(BuildContext context, Customer customer) {
    return Column(
      children: [
        // Statistiken-Header bleibt gleich
        FutureBuilder<Map<String, dynamic>>(
          future: _getCustomerStats(customer.id),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final stats = snapshot.data!;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${stats['totalQuotes']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Angebote'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${stats['totalOrders']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Aufträge'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'CHF ${stats['totalSpent'].toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Gesamt'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Info-Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        getAdaptiveIcon(iconName: 'info', defaultIcon:
                        Icons.info,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Alle Beträge in CHF (Basis-Währung)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
            return const SizedBox(height: 80);
          },
        ),

        // Tab-Ansicht für Angebote und Aufträge
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'Aufträge'),
                    Tab(text: 'Angebote'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Aufträge Tab
                      _buildOrdersList(customer),
                      // Angebote Tab
                      _buildQuotesList(customer),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// Neue Methode für Aufträge
  Widget _buildOrdersList(Customer customer) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customer.id', isEqualTo: customer.id)
          .orderBy('orderDate', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'error', defaultIcon: Icons.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Fehler beim Laden der Aufträge',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'shopping_bag_outlined', defaultIcon: Icons.shopping_bag_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Noch keine Aufträge',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dieser Kunde hat noch keine Aufträge',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final order = orderDoc.data() as Map<String, dynamic>;
            return _buildOrderListTile(context, orderDoc.id, order);
          },
        );
      },
    );
  }

// Neue Methode für Angebote
  Widget _buildQuotesList(Customer customer) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('quotes')
          .where('customer.id', isEqualTo: customer.id)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'error', defaultIcon: Icons.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Fehler beim Laden der Angebote',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final quotes = snapshot.data?.docs ?? [];

        if (quotes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'description_outlined', defaultIcon: Icons.description_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Noch keine Angebote',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dieser Kunde hat noch keine Angebote erhalten',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: quotes.length,
          itemBuilder: (context, index) {
            final quoteDoc = quotes[index];
            final quote = quoteDoc.data() as Map<String, dynamic>;
            return _buildQuoteListTile(context, quoteDoc.id, quote);
          },
        );
      },
    );
  }

// Für Orders
  Widget _buildOrderListTile(BuildContext context, String orderId, Map<String, dynamic> order) {
    final calculations = order['calculations'] as Map<String, dynamic>? ?? {};
    final items = order['items'] as List<dynamic>? ?? [];
    final orderDate = (order['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Der total ist in CHF gespeichert
    final totalInCHF = (calculations['total'] as num?)?.toDouble() ?? 0;

    // Hole Währung und Exchange Rates
    final currency = order['metadata']?['currency'] ?? 'CHF';
    final exchangeRates = order['metadata']?['exchangeRates'] as Map<String, dynamic>? ?? {};
    final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;

    // Rechne um falls nicht CHF
    final displayTotal = currency == 'CHF' ? totalInCHF : totalInCHF * rate;

    final orderNumber = order['orderNumber'] as String? ?? orderId;
    final status = order['status'] as String? ?? 'pending';
    final paymentStatus = order['paymentStatus'] as String? ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: getAdaptiveIcon(iconName: 'shopping_bag', defaultIcon: Icons.shopping_bag),
        ),
        title: Text(
          'Auftrag $orderNumber',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd.MM.yyyy HH:mm').format(orderDate)),
            Text('${items.length} Artikel'),
            Row(
              children: [
                _buildStatusChip(status),
                const SizedBox(width: 8),
                _buildPaymentStatusChip(paymentStatus),
              ],
            ),
          ],
        ),
        trailing: Text(
          '$currency ${displayTotal.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => _showOrderDetails(context, orderId, order),
      ),
    );
  }

// Für Quotes
  Widget _buildQuoteListTile(BuildContext context, String quoteId, Map<String, dynamic> quote) {
    final calculations = quote['calculations'] as Map<String, dynamic>? ?? {};
    final items = quote['items'] as List<dynamic>? ?? [];
    final createdAt = (quote['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final validUntil = (quote['validUntil'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Der total ist in CHF gespeichert
    final totalInCHF = (calculations['total'] as num?)?.toDouble() ?? 0;

    // Hole Währung und Exchange Rates
    final currency = quote['metadata']?['currency'] ?? 'CHF';
    final exchangeRates = quote['metadata']?['exchangeRates'] as Map<String, dynamic>? ?? {};
    final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;

    // Rechne um falls nicht CHF
    final displayTotal = currency == 'CHF' ? totalInCHF : totalInCHF * rate;

    final quoteNumber = quote['quoteNumber'] as String? ?? quoteId;
    final status = quote['status'] as String? ?? 'open';

    // Prüfe ob Angebot abgelaufen ist
    final isExpired = validUntil.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
        ),
        title: Text(
          'Angebot $quoteNumber',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd.MM.yyyy').format(createdAt)),
            Text('${items.length} Artikel'),
            Row(
              children: [
                _buildQuoteStatusChip(status, isExpired),
                const SizedBox(width: 8),
                if (!isExpired && status == 'open')
                  Text(
                    'Gültig bis ${DateFormat('dd.MM.yyyy').format(validUntil)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Text(
          '$currency ${displayTotal.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => _showQuoteDetails(context, quoteId, quote),
      ),
    );
  }
  void _showOrderDetails(BuildContext context, String orderId, Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'shopping_bag', defaultIcon: Icons.shopping_bag),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auftrag ${order['orderNumber']}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('dd.MM.yyyy').format(
                              (order['orderDate'] as Timestamp).toDate()
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Dokumente Liste
            Expanded(
              child: (order['documents'] as Map<String, dynamic>?)?.isNotEmpty ?? false
                  ? ListView(
                padding: const EdgeInsets.all(16),
                children: (order['documents'] as Map<String, dynamic>).entries.map((entry) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        child:

                        getAdaptiveIcon(iconName: 'picture_as_pdf', defaultIcon:
                        Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                      ),
                      title: Text(_getDocumentTypeName(entry.key)),
                      trailing: IconButton(
                        icon: getAdaptiveIcon(
                          iconName: 'open_in_new',
                          defaultIcon: Icons.open_in_new,
                        ),
                        onPressed: () => _openDocument(entry.value),
                      ),
                    ),
                  );
                }).toList(),
              )
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'description',
                      defaultIcon: Icons.description,
                      size: 48,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDocumentTypeName(String key) {
    switch (key) {
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
      case 'veranlagungsverfuegung_pdf':
        return 'Veranlagungsverfügung';
      default:
        return key.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
    }
  }


  void _showQuoteDetails(BuildContext context, String quoteId, Map<String, dynamic> quote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Angebot ${quote['quoteNumber']}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('dd.MM.yyyy').format(
                              (quote['createdAt'] as Timestamp).toDate()
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Dokumente Liste
            Expanded(
              child: (quote['documents'] as Map<String, dynamic>?)?.isNotEmpty ?? false
                  ? ListView(
                padding: const EdgeInsets.all(16),
                children: (quote['documents'] as Map<String, dynamic>).entries.map((entry) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        child:  getAdaptiveIcon(iconName: 'picture_as_pdf', defaultIcon:
                        Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                      ),
                      title: Text(_getDocumentTypeName(entry.key)),
                      trailing: IconButton(
                        icon: getAdaptiveIcon(
                          iconName: 'open_in_new',
                          defaultIcon: Icons.open_in_new,
                        ),
                        onPressed: () => _openDocument(entry.value),
                      ),
                    ),
                  );
                }).toList(),
              )
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'picture_as_pdf',
                      defaultIcon: Icons.picture_as_pdf,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kein PDF verfügbar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

// Hilfsmethode zum Öffnen von Dokumenten (aus deinem orders_overview_screen)
  Future<void> _openDocument(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      }
    } catch (e) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link wurde in die Zwischenablage kopiert'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }


// Helper für Status-Chips
  Widget _buildStatusChip(String status) {
    Color color;
    String displayText;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        displayText = 'Ausstehend';
        break;
      case 'processing':
        color = Colors.blue;
        displayText = 'In Bearbeitung';
        break;
      case 'shipped':
        color = Colors.purple;
        displayText = 'Versendet';
        break;
      case 'delivered':
        color = Colors.green;
        displayText = 'Geliefert';
        break;
      case 'cancelled':
        color = Colors.red;
        displayText = 'Storniert';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPaymentStatusChip(String status) {
    Color color;
    String displayText;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        displayText = 'Offen';
        break;
      case 'partial':
        color = Colors.blue;
        displayText = 'Teilweise';
        break;
      case 'paid':
        color = Colors.green;
        displayText = 'Bezahlt';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          getAdaptiveIcon(iconName: 'money_bag', defaultIcon: Icons.savings, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteStatusChip(String status, bool isExpired) {
    Color color;
    String displayText;

    if (isExpired && status == 'open') {
      color = Colors.grey;
      displayText = 'Abgelaufen';
    } else {
      switch (status) {
        case 'open':
          color = Colors.blue;
          displayText = 'Offen';
          break;
        case 'accepted':
          color = Colors.green;
          displayText = 'Angenommen';
          break;
        case 'rejected':
          color = Colors.red;
          displayText = 'Abgelehnt';
          break;
        default:
          color = Colors.grey;
          displayText = status;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

// Aktualisierte Statistiken-Methode
  Future<Map<String, dynamic>> _getCustomerStats(String customerId) async {
    try {
      // Hole Aufträge
      final orders = await FirebaseFirestore.instance
          .collection('orders')
          .where('customer.id', isEqualTo: customerId)
          .get();

      // Hole Angebote
      final quotes = await FirebaseFirestore.instance
          .collection('quotes')
          .where('customer.id', isEqualTo: customerId)
          .get();

      // Gruppiere Beträge nach Währung
      Map<String, double> totalsByurrency = {
        'CHF': 0.0,
        'EUR': 0.0,
        'USD': 0.0,
      };

      DateTime? lastActivity;

      // Verarbeite Aufträge
      for (var doc in orders.docs) {
        final data = doc.data();
        final calculations = data['calculations'] as Map<String, dynamic>?;
        final currency = data['metadata']?['currency'] ?? 'CHF';

        if (calculations != null) {
          final total = (calculations['total'] as num?)?.toDouble() ?? 0;
          totalsByurrency[currency] = (totalsByurrency[currency] ?? 0) + total;
        }

        final orderDate = (data['orderDate'] as Timestamp?)?.toDate();
        if (orderDate != null) {
          if (lastActivity == null || orderDate.isAfter(lastActivity)) {
            lastActivity = orderDate;
          }
        }
      }

      // Bestimme Hauptwährung (die am häufigsten verwendet wird)
      String primaryCurrency = 'CHF';
      double maxAmount = 0;

      totalsByurrency.forEach((currency, amount) {
        if (amount > maxAmount) {
          maxAmount = amount;
          primaryCurrency = currency;
        }
      });

      return {
        'totalOrders': orders.docs.length,
        'totalQuotes': quotes.docs.length,
        'totalSpent': totalsByurrency[primaryCurrency] ?? 0.0,
        'currency': primaryCurrency,
        'totalsByCurrency': totalsByurrency, // Falls du alle Währungen anzeigen möchtest
        'lastActivity': lastActivity,
      };
    } catch (e) {
      print('Fehler beim Berechnen der Kundenstatistiken: $e');
      return {
        'totalOrders': 0,
        'totalQuotes': 0,
        'totalSpent': 0.0,
        'currency': 'CHF',
        'totalsByCurrency': {'CHF': 0.0},
        'lastActivity': null,
      };
    }
  }
// Einzelner Kauf in der Liste
  Widget _buildPurchaseListTile(BuildContext context, String receiptId, Map<String, dynamic> purchase) {
    final calculations = purchase['calculations'] as Map<String, dynamic>;
    final items = purchase['items'] as List<dynamic>;
    final metadata = purchase['metadata'] as Map<String, dynamic>;

    final timestamp = metadata['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();

    final total = calculations['total'] as num? ?? 0;
    final receiptNumber = purchase['receiptNumber'] as String? ?? receiptId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: getAdaptiveIcon(iconName: 'receipt', defaultIcon: Icons.receipt),
        ),
        title: Text(
          'LS-$receiptNumber',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DateFormat('dd.MM.yyyy HH:mm').format(date)}'),
            Text('${items.length} Artikel'),
            if (metadata['fairName'] != null)
              Text(
                'Messe: ${metadata['fairName']}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Text(
          '${total.toStringAsFixed(2)} CHF',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => _showPurchaseDetails(context, receiptId, purchase),
      ),
    );
  }

// Details eines einzelnen Kaufs anzeigen
  void _showPurchaseDetails(BuildContext context, String receiptId, Map<String, dynamic> purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'receipt_long', defaultIcon: Icons.receipt_long),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lieferschein LS-${purchase['receiptNumber']}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            // Artikel-Liste
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: (purchase['items'] as List).length,
                itemBuilder: (context, index) {
                  final item = (purchase['items'] as List)[index];
                  return Card(
                    child: ListTile(
                      title: Text(item['product_name'] ?? 'Unbekanntes Produkt'),
                      subtitle: Text(
                        '${item['quantity']} ${item['unit']} × ${(item['price_per_unit'] as num).toStringAsFixed(2)} CHF',
                      ),
                      trailing: Text(
                        '${(item['total'] as num).toStringAsFixed(2)} CHF',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Gesamtsumme
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gesamtbetrag:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(purchase['calculations']['total'] as num).toStringAsFixed(2)} CHF',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

  // Hilfsmethode für Abschnittsdarstellung
  Widget _buildDetailSection(
      BuildContext context,
      String title,
      List<Widget> children,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // Hilfsmethode für Detailzeile
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// Hilfsklasse für gefilterte Daten
class _MockDocumentSnapshot implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;

  _MockDocumentSnapshot(Map<String, dynamic> data)
      : _data = Map<String, dynamic>.from(data),
        _id = data['id'] ?? '';

  @override
  Map<String, dynamic> data() => _data;

  @override
  String get id => _id;

  @override
  bool get exists => true;

  @override
  dynamic get(Object field) => _data[field];

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference get reference => throw UnimplementedError();
}