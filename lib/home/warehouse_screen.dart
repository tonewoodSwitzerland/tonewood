
import 'dart:async';
import 'filter_favorites_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/icon_helper.dart';
import 'barcode_scanner.dart';

class WarehouseScreen extends StatefulWidget {
  final bool isDialog;
  final Function(String)? onBarcodeSelected;  // Nur der Barcode wird übergeben
  final String mode;

  const WarehouseScreen({
    required Key key,
    this.isDialog = false,
    this.onBarcodeSelected,
    this.mode = 'lookup',
  }) : super(key: key);

  @override
  WarehouseScreenState createState() => WarehouseScreenState();
}

class WarehouseScreenState extends State<WarehouseScreen> {
  // Filter states
  List<String> selectedInstrumentCodes = [];
  List<String> selectedPartCodes = [];
  List<String> selectedWoodCodes = [];
  List<String> selectedQualityCodes = [];

  String? selectedUnit;
  final TextEditingController _searchController = TextEditingController();

// Dropdown data from Firestore
  List<QueryDocumentSnapshot>? instruments;
  List<QueryDocumentSnapshot>? parts;
  List<QueryDocumentSnapshot>? woodTypes;
  List<QueryDocumentSnapshot>? qualities;
  List<String> units = ['Stück', 'Kg', 'Palette', 'm³'];

  StreamSubscription<DocumentSnapshot>? _filterSubscription;
  bool _isLoadingFilters = true;
  bool _hasUnsearchedChanges = false;

  Stream<QuerySnapshot>? _productStream;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    _loadSavedFilters();
    _updateProductStream();
  }
  @override
  void dispose() {

    _searchController.dispose();
    _filterSubscription?.cancel();
    super.dispose();
  }
  bool _showEnglishNames = false; // Neue Variable für Sprachwechsel
  bool isQuickFilterActive = false;
  String? _shopFilter; // null = alle, 'sold' = verkauft, 'available' = nicht verkauft
  bool _isOnlineShopView = false;
  String _activeSearchText = '';

  void _updateProductStream() {
    setState(() {
      _productStream = buildQuery().snapshots();
    });
  }
// Neue Methoden in WarehouseScreenState:

  Future<void> _saveCurrentFilterAsFavorite() async {
    // Name Dialog zeigen
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter-Favorit speichern'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Name für diesen Filter',
            border: OutlineInputBorder(),
            hintText: 'z.B. Gitarrendecken-Serie',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text('Speichern'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        final favoriteData = <String, dynamic>{  // Expliziter Typ
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
          'isSearch': _activeSearchText.isNotEmpty,
        };

        if (_activeSearchText.isNotEmpty) {  // Hier ändern
          favoriteData['searchText'] = _activeSearchText;  // Hier ändern
        } else {
          favoriteData['instrumentCodes'] = selectedInstrumentCodes;
          favoriteData['partCodes'] = selectedPartCodes;
          favoriteData['woodCodes'] = selectedWoodCodes;
          favoriteData['qualityCodes'] = selectedQualityCodes;
          if (selectedUnit != null) {  // Nur hinzufügen wenn nicht null
            favoriteData['unit'] = selectedUnit;
          }
        }

        await FirebaseFirestore.instance
            .collection('general_data')
            .doc('filter_settings')
            .collection('favorites')
            .add(favoriteData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Filter-Favorit "$name" gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFavoriteFilter(Map<String, dynamic> favoriteData) {
    setState(() {
      if (favoriteData['isSearch'] == true) {
        // Suchfilter anwenden
        _searchController.text = favoriteData['searchText'] ?? '';
        selectedInstrumentCodes.clear();
        selectedPartCodes.clear();
        selectedWoodCodes.clear();
        selectedQualityCodes.clear();
        selectedUnit = null;

        // Wichtig: Suche direkt ausführen
        _performSearch();
      } else {
        // Manuelle Filter anwenden
       _searchController.clear();
       _hasUnsearchedChanges = false;
    _activeSearchText = '';
        selectedInstrumentCodes = List<String>.from(favoriteData['instrumentCodes'] ?? []);
        selectedPartCodes = List<String>.from(favoriteData['partCodes'] ?? []);
        selectedWoodCodes = List<String>.from(favoriteData['woodCodes'] ?? []);
        selectedQualityCodes = List<String>.from(favoriteData['qualityCodes'] ?? []);
        selectedUnit = favoriteData['unit'];
       _updateProductStream();
      }
    });
    _saveFilters();
    // Gefilterte Produkte neu laden

  }

  void _showFilterFavorites() {
    FilterFavoritesSheet.show(
      context,
      onFavoriteSelected: _applyFavoriteFilter,
      onCreateNew: _saveCurrentFilterAsFavorite,
    );
  }












  void _toggleQuickFilter() {
    setState(() {
      isQuickFilterActive = !isQuickFilterActive;
     _searchController.clear();
    _activeSearchText = '';
      if (isQuickFilterActive) {
        // Clear existing filters first
        selectedInstrumentCodes.clear();
        selectedPartCodes.clear();
        selectedWoodCodes.clear();
        selectedQualityCodes.clear();
      // Add the instrument codes for quick filtering
      selectedInstrumentCodes.addAll([
        '10',  // Steelstring Gitarre
        '11',  // Klassische Gitarre
        '12',  // Parlor Gitarre
        '16', // Bouzuki/Mandoline flach
        '20', // Violine
        '22', // Cello
      ]);

        // Add the part code for Decke
        selectedPartCodes.add('10'); // Decke
      } else {
        // Clear all filters when deactivating
        selectedInstrumentCodes.clear();
        selectedPartCodes.clear();
        selectedWoodCodes.clear();
        selectedQualityCodes.clear();
      }
    });
    _saveFilters();
    _updateProductStream();
  }


  void _loadSavedFilters() {
    _filterSubscription = FirebaseFirestore.instance
        .collection('general_data')
        .doc('filter_settings')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;

        // Suchtext laden
        final savedSearchText = data['searchText'] ?? '';
        if (_searchController.text != savedSearchText) {
          _searchController.text = savedSearchText;
        }

        setState(() {
          // Wenn Suchtext vorhanden ist, überschreibt er die manuellen Filter
          if (savedSearchText.isNotEmpty) {
            selectedInstrumentCodes.clear();
            selectedPartCodes.clear();
            selectedWoodCodes.clear();
            selectedQualityCodes.clear();
            selectedUnit = null;

            // NEU: Setze auch den aktiven Suchtext
            _activeSearchText = savedSearchText;
            _hasUnsearchedChanges = false;
          } else {
            // Nur manuelle Filter laden wenn kein Suchtext
            selectedInstrumentCodes = List<String>.from(data['instrumentCodes'] ?? []);
            selectedPartCodes = List<String>.from(data['partCodes'] ?? []);
            selectedWoodCodes = List<String>.from(data['woodCodes'] ?? []);
            selectedQualityCodes = List<String>.from(data['qualityCodes'] ?? []);
            selectedUnit = data['unit'];

            // NEU: Stelle sicher, dass kein aktiver Suchtext gesetzt ist
            _activeSearchText = '';
            _hasUnsearchedChanges = false;
          }
          _isLoadingFilters = false;
        });
      } else {
        setState(() {
          _isLoadingFilters = false;
        });
      }
    });
  }
// Filter in Firebase speichern
  Future<void> _saveFilters() async {
    try {
      // Wenn Suchtext vorhanden, speichere nur diesen
      if (_activeSearchText.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('general_data')
            .doc('filter_settings')
            .set({
          'searchText': _activeSearchText,
          'instrumentCodes': [],
          'partCodes': [],
          'woodCodes': [],
          'qualityCodes': [],
          'unit': null,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Sonst speichere die manuellen Filter
        await FirebaseFirestore.instance
            .collection('general_data')
            .doc('filter_settings')
            .set({
          'searchText': '',
          'instrumentCodes': selectedInstrumentCodes,
          'partCodes': selectedPartCodes,
          'woodCodes': selectedWoodCodes,
          'qualityCodes': selectedQualityCodes,
          'unit': selectedUnit,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Fehler beim Speichern der Filter: $e');
    }
  }

  Future<void> _resetFilters() async {
    setState(() {
     _searchController.clear();
     _hasUnsearchedChanges = false;
    _activeSearchText = ''; // NEU
      selectedInstrumentCodes.clear();
      selectedPartCodes.clear();
      selectedWoodCodes.clear();
      selectedQualityCodes.clear();
      selectedUnit = null;
    });
    _updateProductStream();
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('filter_settings')
          .delete();
    } catch (e) {
      print('Fehler beim Zurücksetzen der Filter: $e');
    }
  }

  Future<double> _getAvailableQuantity(String shortBarcode) async {
    try {

      print('Getting available quantity for: $shortBarcode'); // Debug


      // Aktuellen Bestand aus inventory collection abrufen
      final inventoryDoc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(shortBarcode)
          .get();

      final currentStock = (inventoryDoc.data()?['quantity'] as num?)?.toDouble() ?? 0.0;
      print('Current stock: $currentStock'); // Debug

      // Temporär gebuchte Menge abrufen
      final tempBasketDoc = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .where('product_id', isEqualTo: shortBarcode)
          .get();

      final cartQuantity = tempBasketDoc.docs.fold<double>(
        0,
            (sum, doc) => sum + ((doc.data()['quantity'] as num?)?.toDouble() ?? 0.0),
      );

      // Reservierte Menge aus stock_movements abrufen
      final reservationsDoc = await FirebaseFirestore.instance
          .collection('stock_movements')
          .where('productId', isEqualTo: shortBarcode)
          .where('type', isEqualTo: 'reservation')
          .where('status', isEqualTo: 'reserved')
          .get();

      final reservedQuantity = reservationsDoc.docs.fold<double>(
        0,
            (sum, doc) => sum + (((doc.data()['quantity'] as num?)?.toDouble() ?? 0.0).abs()),
      );

    final result = currentStock - cartQuantity - reservedQuantity;
      print('Available quantity: $result'); // Debug
      return result;
    } catch (e) {
      print('Fehler beim Abrufen der verfügbaren Menge: $e');
      print('Stack trace: ${StackTrace.current}'); // Debug
      return 0;
    }
  }


  Future<bool> _isItemInCart(String barcode) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('temporary_basket')
        .where('online_shop_barcode', isEqualTo: barcode)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

// Alternative als Stream für reaktive UI-Updates
  Stream<bool> _itemInCartStream(String barcode) {
    return FirebaseFirestore.instance
        .collection('temporary_basket')
        .where('online_shop_barcode', isEqualTo: barcode)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<void> _addToTemporaryBasket(Map<String, dynamic> productData, double quantity) async {
    await FirebaseFirestore.instance
        .collection('temporary_basket')
        .add({
      'product_id': productData['short_barcode'],
      'product_name': productData['product_name'],
      'quantity': quantity,
      'timestamp': FieldValue.serverTimestamp(),
      'price_per_unit': productData['price_CHF'],
      'unit': productData['unit'],
      'instrument_name': productData['instrument_name'],
      'instrument_code': productData['instrument_code'],
      'part_name': productData['part_name'],
      'part_code': productData['part_code'],
      'wood_name': productData['wood_name'],
      'wood_code': productData['wood_code'],
      'quality_name': productData['quality_name'],
      'quality_code': productData['quality_code'],


      // NEU: Englische Bezeichnungen hinzufügen
      'instrument_name_en': productData['instrument_name_en'] ?? '',
      'part_name_en': productData['part_name_en'] ?? '',
      'wood_name_en': productData['wood_name_en'] ?? '',
      'product_name_en': productData['product_name_en'] ?? '',

    });
  }

// Füge diese Methode zur WarehouseScreenState Klasse hinzu
// Diese Methode zur WarehouseScreenState Klasse hinzufügen
  Stream<double> _getReservedQuantityStream(String shortBarcode) {
    return FirebaseFirestore.instance
        .collection('stock_movements')
        .where('productId', isEqualTo: shortBarcode)
        .where('type', isEqualTo: 'reservation')
        .where('status', isEqualTo: 'reserved')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.fold<double>(
        0,
            (sum, doc) => sum + ((doc.data()['quantity'] as double).abs()), // abs() weil die Menge negativ gespeichert wird
      );
    });
  }

  void _showOnlineShopDetails(Map<String, dynamic> data) {
    print(widget.isDialog);
    if (widget.mode == 'barcodePrinting' && widget.isDialog && widget.onBarcodeSelected != null) {
      widget.onBarcodeSelected!(data['barcode']);
      return;
    }
    // Nur für Shopping-Modus und als Dialog aufgerufen
    if (widget.mode == 'shopping' && widget.isDialog && widget.onBarcodeSelected != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Online-Shop Artikel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['product_name'] ?? 'Unbekanntes Produkt',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('${data['quality_name'] ?? 'N/A'}'),
              const SizedBox(height: 16),
              const Text(
                'Möchten Sie diesen Online-Shop Artikel zum Warenkorb hinzufügen?',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                widget.onBarcodeSelected!(data['barcode']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4A29),
                foregroundColor: Colors.white,
              ),
              child: const Text('In den Warenkorb'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StreamBuilder<bool>(
          stream: _itemInCartStream(data['barcode']),
          builder: (context, isInCartSnapshot) {
            final bool isInCart = isInCartSnapshot.data ?? false;

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
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F4A29).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: getAdaptiveIcon(
                            iconName: 'shopping_cart',
                            defaultIcon: Icons.shopping_cart,
                            color: Color(0xFF0F4A29),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            data['product_name']?.toString() ?? 'Produktdetails',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F4A29),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailSection(
                            title: 'Barcode',
                            iconName: 'qr_code',
                            icon: Icons.qr_code,
                            content: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.tag, color: Colors.grey[600], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    data['barcode']?.toString() ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Warenkorb-Status hinzufügen
                          if (isInCart)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  getAdaptiveIcon(
                                    iconName: 'shopping_cart',
                                    defaultIcon: Icons.shopping_cart,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Artikel ist im Warenkorb',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        Text(
                                          'Dieser Artikel kann erst als verkauft markiert werden, wenn er aus dem Warenkorb entfernt wurde.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          _buildDetailSection(
                            title: 'Status',
                            iconName: 'info',
                            icon: Icons.info,
                            content: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (data['sold'] == true ? Colors.red : Colors.green).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    data['sold'] == true ? Icons.sell : Icons.store,
                                    color: data['sold'] == true ? Colors.red : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    data['sold'] == true ? 'Verkauft' : 'Im Shop',
                                    style: TextStyle(
                                      color: data['sold'] == true ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),


                          // Produktinformationen
                          _buildDetailSection(
                            title: 'Produktinformationen',
                            iconName: 'info',
                            icon: Icons.info,
                            content: StatefulBuilder(
                              builder: (context, setInnerState) {
                                return Column(
                                  children: [
                                    // Switch in den Content-Bereich verschieben
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'DE',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: !_showEnglishNames ? const Color(0xFF0F4A29) : Colors.grey[400],
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: 0.7,
                                            child: Switch(
                                              value: _showEnglishNames,
                                              onChanged: (value) {
                                                setInnerState(() {
                                                  _showEnglishNames = value;
                                                });
                                              },
                                              activeColor: const Color(0xFF0F4A29),
                                            ),
                                          ),
                                          Text(
                                            'EN',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _showEnglishNames ? const Color(0xFF0F4A29) : Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildDetailRow(
                                      'Instrument',
                                      _showEnglishNames
                                          ? '${data['instrument_name_en'] ?? data['instrument_name']} (${data['instrument_code']})'
                                          : '${data['instrument_name']} (${data['instrument_code']})',
                                      iconName: 'music_note',
                                      icon: Icons.music_note,
                                    ),
                                    _buildDetailRow(
                                      'Bauteil',
                                      _showEnglishNames
                                          ? '${data['part_name_en'] ?? data['part_name']} (${data['part_code']})'
                                          : '${data['part_name']} (${data['part_code']})',
                                      iconName: 'category',
                                      icon: Icons.category,
                                    ),
                                    _buildDetailRow(
                                      'Holzart',
                                      _showEnglishNames
                                          ? '${data['wood_name_en'] ?? data['wood_name']} (${data['wood_code']})'
                                          : '${data['wood_name']} (${data['wood_code']})',
                                      iconName: 'forest',
                                      icon: Icons.forest,
                                    ),
                                    _buildDetailRow(
                                      'Qualität',
                                      _showEnglishNames
                                          ? '${data['quality_name_en'] ?? data['quality_name']} (${data['quality_code']})'
                                          : '${data['quality_name']} (${data['quality_code']})',
                                      iconName: 'star',
                                      icon: Icons.star,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer mit Aktionsbuttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!data['sold'])
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isInCart ? null : () async {
                                  // Sicherheitsdialog
                                  final bool? confirmDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.warning,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text('Produkt entfernen'),
                                        ],
                                      ),
                                      content: Text(
                                        'Möchtest du das Produkt "${data['product_name']}" wirklich aus dem Online-Shop entfernen? Der Eintrag wird gelöscht, der normale Warenbestand um +1 erhöht.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Abbrechen'),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
                                          label: const Text('Entfernen'),
                                        ),
                                      ],
                                    ),
                                  );

                                  // Nur wenn bestätigt wurde
                                  if (confirmDelete == true) {
                                    await _removeFromOnlineShop(data);
                                    Navigator.of(context).pop();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  disabledForegroundColor: Colors.grey.withOpacity(0.5),
                                  disabledBackgroundColor: Colors.grey.withOpacity(0.1),
                                ),
                                icon: const Icon(Icons.remove_shopping_cart),
                                label: Text(isInCart ? 'Im Warenkorb' : 'Entfernen'),
                              ),
                            ),
                          if (!data['sold'])
                            const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: (data['sold'] || isInCart) ? null : () async {
                                // Sicherheitsdialog
                                final bool? confirmSold = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F4A29).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.sell,
                                            color: Color(0xFF0F4A29),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Verkaufen'),
                                      ],
                                    ),
                                    content: Text(
                                      'Möchtest du das Produkt "${data['product_name']}" wirklich als verkauft markieren?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Abbrechen'),
                                      ),
                                      FilledButton.icon(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F4A29),
                                        ),
                                        icon: getAdaptiveIcon(
                                            iconName: 'check',
                                            defaultIcon:Icons.check),
                                        label: const Text('Als verkauft markieren'),
                                      ),
                                    ],
                                  ),
                                );

                                // Nur wenn bestätigt wurde
                                if (confirmSold == true) {
                                  await _markAsSold(data);
                                  Navigator.of(context).pop();
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F4A29),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              icon:  getAdaptiveIcon(
                              iconName: 'sell',
            defaultIcon:Icons.sell),
                              label: Text(
                                  isInCart ? 'Im Warenkorb - nicht verfügbar' :
                                  data['sold'] ? 'Bereits verkauft' : 'Als verkauft markieren'
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }







  Future<void> _addOnlineShopItemToBasket(Map<String, dynamic> data) async {
    // Für Online-Shop Items muss eine andere ID-Struktur verwendet werden
    // Wir verwenden den vollständigen Barcode als Produkt-ID
    await FirebaseFirestore.instance
        .collection('temporary_basket')
        .add({
      'product_id': data['short_barcode'],
      'product_name': data['product_name'],
      'quantity': 1, // Immer 1 für Online-Shop Items
      'timestamp': FieldValue.serverTimestamp(),
      'price_per_unit': data['price_CHF'],
      'unit': data['unit'] ?? 'Stück',
      'instrument_name': data['instrument_name'],
      'instrument_code': data['instrument_code'],
      'part_name': data['part_name'],
      'part_code': data['part_code'],
      'wood_name': data['wood_name'],
      'wood_code': data['wood_code'],
      'quality_name': data['quality_name'],
      'quality_code': data['quality_code'],
      'is_online_shop_item': true, // Markierung für Online-Shop Items
      'online_shop_barcode': data['barcode'], // Original Shop-Barcode speichern
    });

    // Optional: Markiere das Item als "im Warenkorb" in der Online-Shop-Collection
    // Dies verhindert, dass andere Benutzer es gleichzeitig in den Warenkorb legen
    await FirebaseFirestore.instance
        .collection('onlineshop')
        .doc(data['barcode'])
        .update({
      'in_cart': true,
      'cart_timestamp': FieldValue.serverTimestamp(),
    });
  }
  Future<void> _removeFromOnlineShop(Map<String, dynamic> data) async {
    try {
      // Zunächst prüfen, ob das Item im Warenkorb ist
      bool isInCart = await _isItemInCart(data['barcode']);

      if (isInCart) {
        throw Exception('Dieser Artikel ist im Warenkorb und kann nicht entfernt werden');
      }

      // Online-Shop Eintrag löschen
      await FirebaseFirestore.instance
          .collection('onlineshop')
          .doc(data['barcode'])
          .delete();

      // Lagerbestand erhöhen
      final inventoryRef = FirebaseFirestore.instance
          .collection('inventory')
          .doc(data['short_barcode']);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(inventoryRef);
        final currentQuantity = snapshot.data()?['quantity'] ?? 0;

        transaction.update(inventoryRef, {
          'quantity': currentQuantity + 1,
          'quantity_online_shop': FieldValue.increment(-1),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produkt erfolgreich aus dem Shop entfernt'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Fehler beim Entfernen aus dem Shop: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Entfernen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAsSold(Map<String, dynamic> data) async {
    try {
      // Zunächst prüfen, ob das Item im Warenkorb ist
      bool isInCart = await _isItemInCart(data['barcode']);

      if (isInCart) {
        throw Exception('Dieser Artikel ist im Warenkorb und kann nicht als verkauft markiert werden');
      }

      await FirebaseFirestore.instance
          .collection('onlineshop')
          .doc(data['barcode'])
          .update({
        'sold': true,
        'sold_at': FieldValue.serverTimestamp(),
      });

      // Online-Shop Menge im Inventory reduzieren
      await FirebaseFirestore.instance
          .collection('inventory')
          .doc(data['short_barcode'])
          .update({
        'quantity_online_shop': FieldValue.increment(-1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produkt als verkauft markiert'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Fehler beim Markieren als verkauft: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Markieren: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showProductDetails(Map<String, dynamic> data) {
    if (widget.isDialog && widget.onBarcodeSelected != null) {
      widget.onBarcodeSelected!(data['short_barcode']);
      return;
    }

    TextEditingController quantityController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4A29).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: getAdaptiveIcon(iconName: 'inventory', defaultIcon: Icons.inventory),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          data['product_name']?.toString() ?? 'Produktdetails',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F4A29),
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

                Divider(height: 1),

                // Scrollbarer Inhalt
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Artikelnummer Sektion
                        _buildDetailSection(
                          title: 'Artikelnummer',
                          iconName: 'qr_code',
                          icon: Icons.qr_code,
                          content: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                getAdaptiveIcon(
                                  iconName: 'tag',
                                  defaultIcon: Icons.tag,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  data['short_barcode']?.toString() ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // In der _showProductDetails Methode, ersetzen Sie die Produktinformationen Sektion mit:

                        // In der _buildDetailSection Methode anpassen:

                        // Produktinformationen
                        _buildDetailSection(
                          title: 'Produktinformationen',
                          iconName: 'info',
                          icon: Icons.info,
                          content: StatefulBuilder(
                            builder: (context, setInnerState) {
                              return Column(
                                children: [
                                  // Switch in den Content-Bereich verschieben
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'DE',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: !_showEnglishNames ? const Color(0xFF0F4A29) : Colors.grey[400],
                                          ),
                                        ),
                                        Transform.scale(
                                          scale: 0.7,
                                          child: Switch(
                                            value: _showEnglishNames,
                                            onChanged: (value) {
                                              setInnerState(() {
                                                _showEnglishNames = value;
                                              });
                                            },
                                            activeColor: const Color(0xFF0F4A29),
                                          ),
                                        ),
                                        Text(
                                          'EN',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _showEnglishNames ? const Color(0xFF0F4A29) : Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildDetailRow(
                                    'Instrument',
                                    _showEnglishNames
                                        ? '${data['instrument_name_en'] ?? data['instrument_name']} (${data['instrument_code']})'
                                        : '${data['instrument_name']} (${data['instrument_code']})',
                                    iconName: 'music_note',
                                    icon: Icons.music_note,
                                  ),
                                  _buildDetailRow(
                                    'Bauteil',
                                    _showEnglishNames
                                        ? '${data['part_name_en'] ?? data['part_name']} (${data['part_code']})'
                                        : '${data['part_name']} (${data['part_code']})',
                                    iconName: 'category',
                                    icon: Icons.category,
                                  ),
                                  _buildDetailRow(
                                    'Holzart',
                                    _showEnglishNames
                                        ? '${data['wood_name_en'] ?? data['wood_name']} (${data['wood_code']})'
                                        : '${data['wood_name']} (${data['wood_code']})',
                                    iconName: 'forest',
                                    icon: Icons.forest,
                                  ),
                                  _buildDetailRow(
                                    'Qualität',
                                    _showEnglishNames
                                        ? '${data['quality_name_en'] ?? data['quality_name']} (${data['quality_code']})'
                                        : '${data['quality_name']} (${data['quality_code']})',
                                    iconName: 'star',
                                    icon: Icons.star,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bestand und Preis
                        _buildDetailSection(
                          title: 'Bestand & Preis',
                          iconName: 'inventory',
                          icon: Icons.inventory,
                          content: Column(
                            children: [
                              // Bestandsanzeige
                              FutureBuilder<double>(
                                future: _getAvailableQuantity(data['short_barcode']),
                                builder: (context, snapshot) {
                                  // Debug-Ausgaben hinzufügen
                                  print('FutureBuilder - ConnectionState: ${snapshot.connectionState}');
                                  print('FutureBuilder - HasData: ${snapshot.hasData}');
                                  print('FutureBuilder - Data: ${snapshot.data}');
                                  print('FutureBuilder - Error: ${snapshot.error}');
                                  print('FutureBuilder - short_barcode: ${data['short_barcode']}');

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F4A29).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Verfügbarer Bestand:',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          snapshot.hasData
                                              ? '${data['unit'] == 'Stück'
                                              ? snapshot.data!.toInt().toString()
                                              : snapshot.data!.toStringAsFixed(2)} ${data['unit'] ?? 'Stück'}'
                                              : 'Wird Xgeladen...',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F4A29),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              // Preisanzeige
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Preis pro ${data['unit'] ?? 'Stück'}:',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(
                                          locale: 'de_DE',
                                          symbol: 'CHF',
                                          decimalDigits: 2
                                      ).format(data['price_CHF'] ?? 0.00),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          data: data,
                        ),

                        const SizedBox(height: 24),

                        // Warenkorb Sektion
                        _buildDetailSection(
                          title: 'In den Warenkorb',
                          iconName: 'shopping_cart',
                          icon: Icons.shopping_cart,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: quantityController,
                                decoration: InputDecoration(
                                  labelText: 'Menge',
                                  border: const OutlineInputBorder(),
                                  hintText: 'Menge eingeben',
                                  suffixText: data['unit'] ?? 'Stück',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: data['unit'] == 'Stück'
                                    ? [FilteringTextInputFormatter.digitsOnly]
                                    : [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                                  TextInputFormatter.withFunction((oldValue, newValue) {
                                    // Verhindert mehrere Dezimalpunkte
                                    final text = newValue.text;
                                    if (text.split('.').length > 2) {
                                      return oldValue;
                                    }
                                    return newValue;
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Abbrechen'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: getAdaptiveIcon(
                              color: Colors.white,
                              iconName: 'shopping_cart',
                              defaultIcon: Icons.shopping_cart,
                            ),
                            label: const Text('In den Warenkorb'),
                            onPressed: () async {
                              if (quantityController.text.isEmpty) return;

                              final quantity = data['unit'] == 'Stück'
                                  ? int.parse(quantityController.text).toDouble()
                                  : double.parse(quantityController.text);
                              final availableQuantity = await _getAvailableQuantity(data['short_barcode']);

                              if (quantity <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bitte gib eine gültige Menge ein'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              if (quantity > availableQuantity) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Nicht genügend Bestand verfügbar'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              await _addToTemporaryBasket(data, quantity);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Produkt wurde dem Warenkorb hinzugefügt'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: const Color(0xFF0F4A29),
                              foregroundColor: Colors.white,
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
    );
  }
// Fügen Sie diese neue Methode zur WarehouseScreenState Klasse hinzu
  Future<void> _adjustStock(String shortBarcode, double adjustment) async {
    try {
      final inventoryRef = FirebaseFirestore.instance.collection('inventory').doc(shortBarcode);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(inventoryRef);
        if (!doc.exists) {
          throw 'Produkt nicht gefunden';
        }

        final currentQuantity = (doc.data()?['quantity'] ?? 0).toDouble();
        final newQuantity = currentQuantity + adjustment;

        if (newQuantity < 0) {
          throw 'Bestand kann nicht negativ werden';
        }

        transaction.update(inventoryRef, {
          'quantity': newQuantity,
          'last_modified': FieldValue.serverTimestamp(),
          'last_stock_change': adjustment,
        });

        // Fügen Sie einen Eintrag in stock_entries hinzu
        final entryRef = FirebaseFirestore.instance.collection('stock_entries').doc();
        transaction.set(entryRef, {
          'product_id': shortBarcode,
          'quantity_change': adjustment,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'manual_adjustment',
          'entry_type': adjustment > 0 ? 'increase' : 'decrease',
        });
      });

    } catch (e) {
      AppToast.show(
        message: 'Fehler bei der Bestandsänderung: $e',
        height: h,
      );
    }
  }
// Fügen Sie diese neue Methode hinzu, die einen Stream zurückgibt
  Stream<double> _getAvailableQuantityStream(String shortBarcode) {
    return FirebaseFirestore.instance
        .collection('inventory')
        .doc(shortBarcode)
        .snapshots()
        .asyncMap((inventoryDoc) async {
      // Sichere Konvertierung des Bestands zu double
      final stockValue = inventoryDoc.data()?['quantity'] ?? 0;
      final stock = stockValue is int ? stockValue.toDouble() : (stockValue as double);

      // Warenkorb-Menge abrufen
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .where('product_id', isEqualTo: shortBarcode)
          .get();

      final cartQuantity = cartSnapshot.docs.fold<double>(
        0,
            (sum, doc) {
          final qty = doc.data()['quantity'] ?? 0;
          return sum + (qty is int ? qty.toDouble() : (qty as double));
        },
      );

      // Reservierte Menge aus stock_movements abrufen
      final reservedSnapshot = await FirebaseFirestore.instance
          .collection('stock_movements')
          .where('productId', isEqualTo: shortBarcode)
          .where('type', isEqualTo: 'reservation')
          .where('status', isEqualTo: 'reserved')
          .get();

      final reservedQuantity = reservedSnapshot.docs.fold<double>(
        0,
            (sum, doc) {
          final qty = doc.data()['quantity'] ?? 0;
          final qtyDouble = qty is int ? qty.toDouble() : (qty as double);
          return sum + qtyDouble.abs();
        },
      );

      return stock - cartQuantity - reservedQuantity;
    });
  }

// Aktualisieren Sie die buildDetailSection Methode
  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Widget content,
    Map<String, dynamic>? data,
    String? iconName,
    Widget? customTitleWidget, // NEU
  }) {
    if (title == 'Bestand & Preis' && data != null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  iconName != null
                      ? getAdaptiveIcon(
                    iconName: iconName,
                    defaultIcon: icon,
                    size: 20,
                    color: const Color(0xFF0F4A29),
                  )
                      : Icon(icon, size: 20, color: const Color(0xFF0F4A29)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Bestandsanzeige mit Anpassungsmöglichkeit
                  StreamBuilder<double>(
                    stream: _getAvailableQuantityStream(data['short_barcode']),
                    builder: (context, snapshot) {
                      print('Snapshot state: ${snapshot.connectionState}'); // Debug
                      print('Snapshot data: ${snapshot.data}'); // Debug
                      print('Snapshot error: ${snapshot.error}');
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4A29).withValues(
                              red: 15,
                              green: 74,
                              blue: 41,
                              alpha: 0.1
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Verfügbarer Bestand:',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  snapshot.hasData
                                      ? '${data['unit'] == 'Stück'
                                      ? snapshot.data!.toInt().toString()
                                      : snapshot.data!.toStringAsFixed(3)} ${data['unit'] ?? 'Stück'}'
                                      : 'Wird Xgeladen...',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F4A29),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: snapshot.hasData && snapshot.data! > 0
                                      ? () => _adjustStock(data['short_barcode'], -1.0)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[100],
                                    foregroundColor: Colors.red[900],
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                  child: getAdaptiveIcon(
                                    iconName: 'remove',
                                    defaultIcon: Icons.remove,
                                    color: Colors.red[900],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _adjustStock(data['short_barcode'], 1.0),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[100],
                                    foregroundColor: Colors.green[900],
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                  child: getAdaptiveIcon(
                                    iconName: 'add',
                                    defaultIcon: Icons.add,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Preisanzeige
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Preis pro ${data['unit'] ?? 'Stück'}:',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'CHF ${data['price_CHF']?.toString() ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Ursprüngliche Implementierung für andere Sektionen
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                iconName != null
                    ? getAdaptiveIcon(
                  iconName: iconName,
                  defaultIcon: icon,
                  size: 20,
                  color: const Color(0xFF0F4A29),
                )
                    : Icon(icon, size: 20, color: const Color(0xFF0F4A29)),
                const SizedBox(width: 8),
                Expanded(
                  child: customTitleWidget ?? Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon, String? iconName}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null || iconName != null) ...[
            iconName != null
                ? getAdaptiveIcon(
              iconName: iconName,
              defaultIcon: icon ?? Icons.info,
              size: 18,
              color: Colors.grey[600],
            )
                : Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _booleanRow(String label, bool? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value == true ? 'Ja' : 'Nein'),
          ),
        ],
      ),
    );
  }
  Future<void> _loadDropdownData() async {
    try {
      final instrumentsSnapshot = await FirebaseFirestore.instance
          .collection('instruments')
          .orderBy('code')
          .get();
      final partsSnapshot = await FirebaseFirestore.instance
          .collection('parts')
          .orderBy('code')
          .get();
      final woodTypesSnapshot = await FirebaseFirestore.instance
          .collection('wood_types')
          .orderBy('code')
          .get();
      final qualitiesSnapshot = await FirebaseFirestore.instance
          .collection('qualities')
          .orderBy('code')
          .get();

      // Prüfe ob Widget noch mounted ist bevor setState aufgerufen wird
      if (mounted) {
        setState(() {
          instruments = instrumentsSnapshot.docs;
          parts = partsSnapshot.docs;
          woodTypes = woodTypesSnapshot.docs;
          qualities = qualitiesSnapshot.docs;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Filterdaten: $e');
    }
  }

  Query<Map<String, dynamic>> buildQuery() {
    Query<Map<String, dynamic>> query;

    if (_isOnlineShopView) {
      query = FirebaseFirestore.instance
          .collection('onlineshop');

      // Online Shop spezifische Filter
      if (_shopFilter != null) {
        query = query.where('sold', isEqualTo: _shopFilter == 'sold');
      }

      // Gemeinsame Filter für beide Ansichten
      if (selectedInstrumentCodes.isNotEmpty) {
        query = query.where('instrument_code', whereIn: selectedInstrumentCodes);
      }
      if (selectedPartCodes.isNotEmpty) {
        query = query.where('part_code', whereIn: selectedPartCodes);
      }
      if (selectedWoodCodes.isNotEmpty) {
        query = query.where('wood_code', whereIn: selectedWoodCodes);
      }
      if (selectedQualityCodes.isNotEmpty) {
        query = query.where('quality_code', whereIn: selectedQualityCodes);
      }

      // Sortierung für Online Shop
      if (_shopFilter == 'sold') {
        query = query.orderBy('sold_at', descending: true);
      } else {
        query = query.orderBy('created_at', descending: true);
      }
    } else {
      // Standard Lager Query
      query = FirebaseFirestore.instance
          .collection('inventory');

      if (selectedInstrumentCodes.isNotEmpty) {
        query = query.where('instrument_code', whereIn: selectedInstrumentCodes);
      }
      if (selectedPartCodes.isNotEmpty) {
        query = query.where('part_code', whereIn: selectedPartCodes);
      }
      if (selectedWoodCodes.isNotEmpty) {
        query = query.where('wood_code', whereIn: selectedWoodCodes);
      }
      if (selectedQualityCodes.isNotEmpty) {
        query = query.where('quality_code', whereIn: selectedQualityCodes);
      }
      if (selectedUnit != null) {
        query = query.where('unit', isEqualTo: selectedUnit);
      }
    }

    return query;
  }

// Fügen Sie diese neue Methode hinzu, um die Suchergebnisse zu filtern:
  List<QueryDocumentSnapshot> _filterBySearch(List<QueryDocumentSnapshot> docs) {
    if (_activeSearchText.isEmpty) {  // Verwenden Sie _activeSearchText statt _searchController.text
      return docs;
    }

    // Teile den Suchtext in einzelne Begriffe auf
    final searchTerms = _activeSearchText.toLowerCase().split(' ')
        .where((term) => term.isNotEmpty)
        .toList();


    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Erstelle einen kombinierten String aus allen durchsuchbaren Feldern
      final searchableContent = [
        data['product_name'] ?? '',
        data['product_name_en'] ?? '',
        _isOnlineShopView ? (data['barcode'] ?? '') : (data['short_barcode'] ?? ''),
        data['instrument_name'] ?? '',
        data['instrument_name_en'] ?? '',
        data['part_name'] ?? '',
        data['part_name_en'] ?? '',
        data['wood_name'] ?? '',
        data['wood_name_en'] ?? '',
        data['quality_name'] ?? '',
        data['quality_name_en'] ?? '',
        data['instrument_code'] ?? '',
        data['part_code'] ?? '',
        data['wood_code'] ?? '',
        data['quality_code'] ?? '',
      ].join(' ').toLowerCase();

      // Prüfe ob ALLE Suchbegriffe im kombinierten Inhalt vorkommen
      return searchTerms.every((term) => searchableContent.contains(term));
    }).toList();
  }

// Aktualisieren Sie die _buildProductList() Methode:
  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _productStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print(snapshot.error);
          return const Center(child: Text('Ein Fehler ist aufgetreten'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                getAdaptiveIcon(iconName: 'inventory', defaultIcon: Icons.inventory, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Keine Produkte gefunden',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }

        // Filtere die Ergebnisse basierend auf dem Suchtext
        final filteredDocs = _filterBySearch(snapshot.data!.docs);

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                getAdaptiveIcon(iconName: 'search_off', defaultIcon: Icons.search_off, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Keine Produkte für "${_activeSearchText}" gefunden',  // Hier ändern
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                     _searchController.clear();
    _activeSearchText = '';
                     _hasUnsearchedChanges = false;
                    });
                  },
                  child: const Text('Suche zurücksetzen'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (_isOnlineShopView)
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('Alle'),
                      selected: _shopFilter == null,
                      onSelected: (selected) {
                        setState(() {
                          _shopFilter = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Im Shop'),
                      selected: _shopFilter == 'available',
                      onSelected: (selected) {
                        setState(() {
                          _shopFilter = selected ? 'available' : null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Verkauft'),
                      selected: _shopFilter == 'sold',
                      onSelected: (selected) {
                        setState(() {
                          _shopFilter = selected ? 'sold' : null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            // Zeige die Anzahl der gefilterten Ergebnisse an
            if (_activeSearchText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${filteredDocs.length} Ergebnis${filteredDocs.length == 1 ? '' : 'se'} für "${_activeSearchText}"',  // Hier auch ändern
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredDocs.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (_isOnlineShopView) {
                          _showOnlineShopDetails(data);
                        } else {
                          _showProductDetails(data);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['product_name']?.toString() ?? 'Unbenanntes Produkt',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              data['quality_name']?.toString() ?? '-',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isOnlineShopView
                                                ? data['barcode']?.toString() ?? ''
                                                : data['short_barcode']?.toString() ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Bestand/Status Anzeige
                                if (_isOnlineShopView)
                                  _buildOnlineShopStatus(data)
                                else
                                  _buildInventoryStatus(data),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;

    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Row(
                  children: [
                // Toggle Lager/Shop bleibt unverändert
                IntrinsicWidth(
                child: Container(
                height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _isOnlineShopView = false);
                            _updateProductStream(); // HIER hinzufügen
                          },
                          child: Container(
                            alignment: Alignment.center,
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: !_isOnlineShopView ? primaryAppColor.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(7)),
                            ),
                            child: Text(
                              'Lager',
                              style: TextStyle(
                                fontSize: 14,
                                color: !_isOnlineShopView ? primaryAppColor : Colors.grey[600],
                                fontWeight: !_isOnlineShopView ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isOnlineShopView = true),
                          child: Container(
                            alignment: Alignment.center,
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: _isOnlineShopView ? primaryAppColor.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
                            ),
                            child: Text(
                              'Shop',
                              style: TextStyle(
                                fontSize: 14,
                                color: _isOnlineShopView ? primaryAppColor : Colors.grey[600],
                                fontWeight: _isOnlineShopView ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                    if (isDesktopLayout) ...[
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          constraints: const BoxConstraints(maxWidth: 400),
                          height: 36,
                          child: TextFormField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Suche nach Produkten...',
                              hintStyle: TextStyle(fontSize: 14),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_activeSearchText.isNotEmpty)
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        size: 18,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                         _searchController.clear();
                                          _activeSearchText = '';
                                         _hasUnsearchedChanges = false;
                                        });
                                        _saveFilters(); // Filters zurücksetzen bei Clear
                                      },
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.search,
                                      color: _hasUnsearchedChanges ? Colors.orange : primaryAppColor,
                                    ),
                                    onPressed: () {
                                      FocusScope.of(context).unfocus();
                                      // Suche ausführen
                                      _performSearch();
                                    },
                                  ),
                                ],
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 14),
                            onFieldSubmitted: (value) {
                              FocusScope.of(context).unfocus();
                              _performSearch();
                            },
                            onChanged: (value) {
                              setState(() {
                                _hasUnsearchedChanges = value != _activeSearchText;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
          // centerTitle: true,
              actions: [
                if (!isDesktopLayout) ...[
                  IconButton(
                    icon: getAdaptiveIcon(iconName: 'qr_code_scanner', defaultIcon: Icons.qr_code_scanner),
                    onPressed: _scanAndShowProduct,
                    tooltip: 'Produkt scannen',
                  ),

                  IconButton(
                    icon:getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list,),

                    onPressed: () => _showFilterDialog(),
                  ),
                ],
                IconButton(
                  icon: Badge(
                    isLabelVisible: _hasActiveFilters(),
                    label: Text('!'),
                    child: getAdaptiveIcon(
                      iconName: 'star',
                      defaultIcon: Icons.star,
                      color: _hasActiveFilters() ? primaryAppColor : null,
                    ),
                  ),
                  onPressed: _showFilterFavorites,
                  tooltip: 'Filter-Favoriten',
                ),
                // Add the export button
                IconButton(
                  onPressed: _showExportDialog,
                  icon: getAdaptiveIcon(
                    iconName: 'download',
                    defaultIcon: Icons.download,
                  ),
                  tooltip: 'Exportieren',
                ),
              ],
            ),
            body: isDesktopLayout
                ? _buildDesktopLayout()
                : _buildMobileLayout(),
          );
        }
    );
  }
  Future<void> _scanAndShowProduct() async {
    try {
      final String? barcodeResult = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleBarcodeScannerPage(),
        ),
      );

      if (barcodeResult != '-1') {
        // Prüfe ob es ein Online-Shop Item ist
        if (_isOnlineShopView) {
          final onlineShopDoc = await FirebaseFirestore.instance
              .collection('onlineshop')
              .doc(barcodeResult)
              .get();

          if (onlineShopDoc.exists) {
            _showOnlineShopDetails(onlineShopDoc.data()!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Produkt nicht im Online-Shop gefunden'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          // Normales Lagerprodukt
          final inventoryDoc = await FirebaseFirestore.instance
              .collection('inventory')
              .doc(barcodeResult)
              .get();

          if (inventoryDoc.exists) {
            _showProductDetails(inventoryDoc.data()!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Produkt nicht im Lager gefunden'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } on PlatformException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Scannen'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Permanenter Filterbereich links
        Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: const Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _buildFilterSection(),
              ),
            ],
          ),
        ),
        // Produktliste rechts
        Expanded(
          child: _buildProductList(),
        ),
      ],
    );
  }
  Widget _buildActiveFiltersChips() {
    String getNameForCode(List<QueryDocumentSnapshot> docs, String code) {
      try {
        final doc = docs.firstWhere(
              (doc) => (doc.data() as Map<String, dynamic>)['code'] == code,
        );
        return (doc.data() as Map<String, dynamic>)['name'] as String;
      } catch (e) {
        return code;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (instruments != null)
            ...selectedInstrumentCodes.map((code) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
               backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('${getNameForCode(instruments!, code)} ($code)'),
                deleteIcon:getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                onDeleted: () {
                  setState(() {
                    selectedInstrumentCodes.remove(code);
                  });
                  _saveFilters();
                  _updateProductStream();
                },
              ),
            )),
          if (parts != null)
            ...selectedPartCodes.map((code) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('${getNameForCode(parts!, code)} ($code)'),
                deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                onDeleted: () {
                  setState(() {
                    selectedPartCodes.remove(code);
                  });
                  _saveFilters();
                  _updateProductStream();
                },
              ),
            )),
          if (woodTypes != null)
            ...selectedWoodCodes.map((code) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('${getNameForCode(woodTypes!, code)} ($code)'),
                deleteIcon:getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                onDeleted: () {
                  setState(() {
                    selectedWoodCodes.remove(code);
                  });
                  _saveFilters();
                  _updateProductStream();
                },
              ),
            )),
          if (qualities != null)
            ...selectedQualityCodes.map((code) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('${getNameForCode(qualities!, code)} ($code)'),
                deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                onDeleted: () {
                  setState(() {
                    selectedQualityCodes.remove(code);
                  });
                  _saveFilters();
                  _updateProductStream();
                },
              ),
            )),

          if (selectedUnit != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                label: Text('Einheit: $selectedUnit'),
                deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                onDeleted: () {
                  setState(() {
                    selectedUnit = null;
                  });
                  _saveFilters();
                  _updateProductStream();
                },
              ),
            ),


        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // NEU: Suchfeld für Mobile
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Suche nach Produkten...',
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_activeSearchText.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                         _searchController.clear();
                      _activeSearchText = '';
                         _hasUnsearchedChanges = false;
                        });
                        _saveFilters();
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color: _hasUnsearchedChanges ? Colors.orange : primaryAppColor,
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _performSearch();
                    },
                  ),
                ],
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onFieldSubmitted: (value) {
              _performSearch();
            },
            onChanged: (value) {
              setState(() {
                _hasUnsearchedChanges = value != _activeSearchText;

              });
            },
          ),
        ),
        if (_hasActiveFilters())
          _buildActiveFiltersChips(),
        Expanded(
          child: _buildProductList(),
        ),
      ],
    );
  }

  void _performSearch() {
    setState(() {
      _activeSearchText = _searchController.text;
      _hasUnsearchedChanges = false; // Zurücksetzen nach der Suche

      if (_activeSearchText.isNotEmpty) {
        selectedInstrumentCodes.clear();
        selectedPartCodes.clear();
        selectedWoodCodes.clear();
        selectedQualityCodes.clear();
        selectedUnit = null;
      }
    });
    _saveFilters();
    _updateProductStream();
  }
  Widget _buildFilterSection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produktfilter',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F4A29),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verfeinere die Suche',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            if (instruments != null) ...[
              _buildFilterCategory(
                iconName: 'music_note', // Neuer Parameter für das PNG im Web
                icon: Icons.music_note,
                title: 'Instrument',
                child: _buildMultiSelectDropdown(
                  label: 'Instrument auswählen',
                  options: instruments!,
                  selectedValues: selectedInstrumentCodes,
                  onChanged: (newSelection) {
                    setState(() {
                      selectedInstrumentCodes = newSelection;
                     _searchController.clear();
                     _activeSearchText = '';
                      _hasUnsearchedChanges = false;
                    });
                    _saveFilters();
                    _updateProductStream();
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (parts != null) ...[
              _buildFilterCategory(
                iconName: 'category',
                icon: Icons.category,
                title: 'Bauteil',
                child: _buildMultiSelectDropdown(
                  label: 'Bauteil auswählen',
                  options: parts!,
                  selectedValues: selectedPartCodes,
                  onChanged: (newSelection) {
                    setState(() {
                      selectedPartCodes = newSelection;
                     _searchController.clear();
    _activeSearchText = '';
                      _hasUnsearchedChanges = false;
                    });
                    _saveFilters();
                    _updateProductStream();
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (woodTypes != null) ...[
              _buildFilterCategory(
                iconName: 'forest',
                icon: Icons.forest,
                title: 'Holzart',
                child: _buildMultiSelectDropdown(
                  label: 'Holzart auswählen',
                  options: woodTypes!,
                  selectedValues: selectedWoodCodes,
                  onChanged: (newSelection) {
                    setState(() {
                      selectedWoodCodes = newSelection;
                     _searchController.clear();
    _activeSearchText = '';
                      _hasUnsearchedChanges = false;
                    });
                    _saveFilters();
                    _updateProductStream();
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (qualities != null) ...[
              _buildFilterCategory(
                iconName: 'star',
                icon: Icons.star,
                title: 'Qualität',
                child: _buildMultiSelectDropdown(
                  label: 'Qualität auswählen',
                  options: qualities!,
                  selectedValues: selectedQualityCodes,
                  onChanged: (newSelection) {
                    setState(() {
                      selectedQualityCodes = newSelection;
                     _searchController.clear();
    _activeSearchText = '';
                      _hasUnsearchedChanges = false;
                    });
                    _saveFilters();
                    _updateProductStream();
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),
            if (_hasActiveFilters()) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Aktive Filter:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  TextButton.icon(
                    icon: getAdaptiveIcon(iconName: 'clear_all', defaultIcon: Icons.clear_all,),
                    label: const Text('Zurücksetzen'),
                    onPressed: () {
                      setState(() {
                        selectedInstrumentCodes.clear();
                        selectedPartCodes.clear();
                        selectedWoodCodes.clear();
                        selectedQualityCodes.clear();
                        selectedUnit = null;
                      });
                      _saveFilters();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildActiveFiltersSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCategory({
    required dynamic icon,  // Kann IconData oder ein Widget von getAdaptiveIcon sein
    required String title,
    required Widget child,
    String? iconName,      // Optional: Für getAdaptiveIcon
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(
                red: 0,
                green: 0,
                blue: 0,
                alpha: 0.1,
            ),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4A29).withValues(
                  red: 15,    // 0x0F
                  green: 74,  // 0x4A
                  blue: 41,   // 0x29
                  alpha: 0.1
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: iconName != null
                ? getAdaptiveIcon(
              iconName: iconName,
              defaultIcon: icon is IconData ? icon : Icons.category,
              color: const Color(0xFF0F4A29),
              size: 24,
            )
                : icon is IconData
                ? Icon(
              icon,
              color: const Color(0xFF0F4A29),
              size: 24,
            )
                : icon, // Direkte Verwendung, wenn bereits ein Widget
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildActiveFiltersSummary() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...selectedInstrumentCodes.map((code) => _buildFilterChip(
          label: _getNameForCode(instruments!, code),
          onRemove: () => setState(() => selectedInstrumentCodes.remove(code)),
        )),
        ...selectedPartCodes.map((code) => _buildFilterChip(
          label: _getNameForCode(parts!, code),
          onRemove: () => setState(() => selectedPartCodes.remove(code)),
        )),
        ...selectedWoodCodes.map((code) => _buildFilterChip(
          label: _getNameForCode(woodTypes!, code),
          onRemove: () => setState(() => selectedWoodCodes.remove(code)),
        )),
        ...selectedQualityCodes.map((code) => _buildFilterChip(
          label: _getNameForCode(qualities!, code),
          onRemove: () => setState(() => selectedQualityCodes.remove(code)),
        )),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
      deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
      onDeleted: onRemove,
      deleteIconColor: const Color(0xFF0F4A29),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _getNameForCode(List<QueryDocumentSnapshot> docs, String code) {
    try {
      final doc = docs.firstWhere(
            (doc) => (doc.data() as Map<String, dynamic>)['code'] == code,
      );
      return '${(doc.data() as Map<String, dynamic>)['name']} ($code)';
    } catch (e) {
      return code;
    }
  }

  Widget _buildFilterCheckbox(String label, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }



// Neue Hilfsmethode für Online-Shop Status
  Widget _buildOnlineShopStatus(Map<String, dynamic> data) {
    final bool isSold = data['sold'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isSold ? Colors.red : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isSold ? Colors.red : Colors.green).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
isSold?
        getAdaptiveIcon(
        iconName: 'sell',
        defaultIcon:Icons.sell,color: Colors.red,size: 16)
          :
getAdaptiveIcon(
    iconName: 'storefront',
    defaultIcon:Icons.storefront,color: Colors.green,size: 16),

          const SizedBox(width: 6),
          Text(
            isSold ? 'Verkauft' : 'Verfügbar',
            style: TextStyle(
              color: isSold ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

// Neue Hilfsmethode für Lagerbestand Status
  Widget _buildInventoryStatus(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Hauptbestand mit verfügbarer Menge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(





            color: const Color(0xFF0F4A29).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF0F4A29).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: StreamBuilder<double>(
            stream: _getAvailableQuantityStream(data['short_barcode']),
            builder: (context, availableSnapshot) {
              final available = availableSnapshot.data ?? data['quantity'] ?? 0;
              final total = data['quantity'] ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  getAdaptiveIcon(
                  iconName: 'inventory',
                  defaultIcon:
                        Icons.inventory,
                        size: 14,
                        color: const Color(0xFF0F4A29),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$total',
                        style: const TextStyle(
                          color: Color(0xFF0F4A29),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (available != total) ...[
                    const SizedBox(height: 2),
                    Text(
                      'verfügbar: ${available % 1 == 0 ? available.toInt().toString() : available.toStringAsFixed(3)}',
                      style: TextStyle(
                        color: const Color(0xFF0F4A29).withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),

        // Status-Indikatoren in einer Zeile
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warenkorb Status
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('temporary_basket')
                    .where('product_id', isEqualTo: data['short_barcode'])
                    .snapshots(),
                builder: (context, cartSnapshot) {
                  double cartQuantity = 0;
                  if (cartSnapshot.hasData) {
                    cartQuantity = cartSnapshot.data!.docs.fold(0,
                            (sum, doc) => sum + (doc.data() as Map<String, dynamic>)['quantity'] as double);
                  }
                  if (cartQuantity > 0) {
                    return _buildStatusIndicator(
                      icon: Icons.shopping_cart,
                      iconName: 'shopping_cart',
                      value: cartQuantity,
                      color: Colors.orange,
                      tooltip: 'Im Warenkorb',
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Reservierungen Status
              StreamBuilder<double>(
                stream: _getReservedQuantityStream(data['short_barcode']),
                builder: (context, reservedSnapshot) {
                  final reservedQuantity = reservedSnapshot.data ?? 0;
                  if (reservedQuantity > 0) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _buildStatusIndicator(
                        icon: Icons.lock_clock,
                        iconName: 'lock_clock',
                        value: reservedQuantity,
                        color: Colors.purple,
                        tooltip: 'Reserviert',
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Online Shop Status
              if ((data['quantity_online_shop'] ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _buildStatusIndicator(
                    icon: Icons.language,
                    iconName: 'language',
                    value: (data['quantity_online_shop'] ?? 0).toDouble(), // Konvertiere zu double
                    color: Colors.blue,
                    tooltip: 'Online Shop',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

// Hilfsmethode für Status-Indikatoren
  Widget _buildStatusIndicator({
    required IconData icon,
    required String iconName,
    required double value,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            getAdaptiveIcon(
            iconName: iconName,
            defaultIcon:
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectDropdown({
    required String label,
    required List<QueryDocumentSnapshot> options,
    required List<String> selectedValues,
    required Function(List<String>) onChanged,
  }) {


    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child:
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: options.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final code = data['code'] as String;
                  final name = data['name'] as String;
                  return CheckboxListTile(
                    title: Text('$name ($code)'),
                    value: selectedValues.contains(code),
                    onChanged: (bool? checked) {
                      List<String> newSelection = List.from(selectedValues);
                      if (checked ?? false) {
                        if (!newSelection.contains(code)) {
                          newSelection.add(code);
                        }
                      } else {
                        newSelection.remove(code);
                      }
                      onChanged(newSelection);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                }).toList(),
              ),
            ),


      ),
    );
  }

  Future<void> _exportWarehouseCsv() async {
    try {
      final query = buildQuery();
      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) => doc.data()).toList();

      final fileName = _isOnlineShopView
          ? 'Onlineshop_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv'
          : 'Lagerbestand_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final StringBuffer csvContent = StringBuffer();

      // Headers - unterschiedlich je nach Modus
      final headers = _isOnlineShopView ? [
        'Artikelnummer',
        'Produkt',
        'Instrument',
        'Bauteil',
        'Holzart',
        'Qualität',
        'Status',
        'Preis CHF',
        'Eingestellt am',
        if (_shopFilter == 'sold') 'Verkauft am'
      ] : [
        'Artikelnummer',
        'Produkt',
        'Instrument',
        'Bauteil',
        'Holzart',
        'Qualität',
        'Bestand',
        'Einheit',
        'Preis CHF'
      ];

      csvContent.writeln(headers.join(';'));

      // Data rows
      for (final item in items) {
        final row = _isOnlineShopView ? [
          // Add apostrophe to force Excel to treat as text
          "'${item['barcode']}",
          item['product_name'],
          '${item['instrument_name']} (${item['instrument_code']})',
          '${item['part_name']} (${item['part_code']})',
          '${item['wood_name']} (${item['wood_code']})',
          '${item['quality_name']} (${item['quality_code']})',
          item['sold'] == true ? 'Verkauft' : 'Im Shop',
          NumberFormat.currency(locale: 'de_DE', symbol: 'CHF', decimalDigits: 2).format(item['price_CHF']),
          item['created_at'] != null
              ? DateFormat('dd.MM.yyyy HH:mm').format((item['created_at'] as Timestamp).toDate())
              : '',
          if (_shopFilter == 'sold' && item['sold_at'] != null)
            DateFormat('dd.MM.yyyy HH:mm').format((item['sold_at'] as Timestamp).toDate())
        ] : [
          // Add apostrophe to force Excel to treat as text
          "'${item['short_barcode']}",
          item['product_name'],
          '${item['instrument_name']} (${item['instrument_code']})',
          '${item['part_name']} (${item['part_code']})',
          '${item['wood_name']} (${item['wood_code']})',
          '${item['quality_name']} (${item['quality_code']})',
          item['quantity'].toString(),
          item['unit'],
          NumberFormat.currency(locale: 'de_DE', symbol: 'CHF', decimalDigits: 2).format(item['price_CHF'])
        ];
        csvContent.writeln(row.join(';'));
      }

      await file.writeAsBytes(csvContent.toString().codeUnits);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      Future.delayed(const Duration(minutes: 1), () => file.delete());
      AppToast.show(message: 'Export erfolgreich', height: h);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: 'Fehler beim Export: $e', height: h);
    }
  }

  Future<void> _exportWarehousePdf() async {
    try {
      final query = buildQuery();
      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) => doc.data()).toList();

      final fileName = _isOnlineShopView
          ? 'Onlineshop_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf'
          : 'Lagerbestand_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          orientation: pw.PageOrientation.landscape,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    _isOnlineShopView ? 'Onlineshop Übersicht' : 'Lagerbestand Übersicht',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Stand: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.center,
                6: pw.Alignment.centerRight,
              },
              headers: _isOnlineShopView ? [
                'Artikelnummer',
                'Produkt',
                'Instrument',
                'Holzart',
                'Qualität',
                'Status',
                'Preis CHF',
                'Eingestellt am',
                if (_shopFilter == 'sold') 'Verkauft am'
              ] : [
                'Artikelnummer',
                'Produkt',
                'Instrument',
                'Holzart',
                'Qualität',
                'Bestand',
                'Preis CHF'
              ],
              data: items.map((item) => _isOnlineShopView ? [
                item['barcode'],
                item['product_name'],
                '${item['instrument_name']} (${item['instrument_code']})',
                '${item['wood_name']} (${item['wood_code']})',
                '${item['quality_name']} (${item['quality_code']})',
                item['sold'] == true ? 'Verkauft' : 'Im Shop',
                NumberFormat.currency(locale: 'de_DE', symbol: 'CHF', decimalDigits: 2).format(item['price_CHF']),
                item['created_at'] != null
                    ? DateFormat('dd.MM.yyyy HH:mm').format((item['created_at'] as Timestamp).toDate())
                    : '',
                if (_shopFilter == 'sold' && item['sold_at'] != null)
                  DateFormat('dd.MM.yyyy HH:mm').format((item['sold_at'] as Timestamp).toDate())
              ] : [
                item['short_barcode'],
                item['product_name'],
                '${item['instrument_name']} (${item['instrument_code']})',
                '${item['wood_name']} (${item['wood_code']})',
                '${item['quality_name']} (${item['quality_code']})',
                '${item['quantity']} ${item['unit']}',
                NumberFormat.currency(locale: 'de_DE', symbol: 'CHF', decimalDigits: 2).format(item['price_CHF']),
              ]).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Footer(
              title: pw.Text(
                'Seite ',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ),
          ],
        ),
      );

      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      Future.delayed(const Duration(minutes: 1), () => file.delete());
      AppToast.show(message: 'Export erfolgreich', height: h);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: 'Fehler beim Export: $e', height: h);
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4A29).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
              getAdaptiveIcon(
                iconName: 'download',
                defaultIcon: Icons.download,
              ),

            ),
            const SizedBox(width: 12),
            Text(_isOnlineShopView ? 'Shop Export' : 'Lager Export'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                getAdaptiveIcon(iconName: 'table_chart', defaultIcon: Icons.table_chart,),

              ),
              title: const Text('CSV'),
              subtitle: const Text('Daten im CSV-Format'),
              onTap: () {
                Navigator.pop(context);
                _exportWarehouseCsv();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),

                child:
                getAdaptiveIcon(iconName: 'picture_as_pdf', defaultIcon: Icons.picture_as_pdf,),

              ),
              title: const Text('Als PDF exportieren'),
              subtitle: const Text('Übersicht als PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportWarehousePdf();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchController.text.isNotEmpty ||
        selectedInstrumentCodes.isNotEmpty ||
        selectedPartCodes.isNotEmpty ||
        selectedWoodCodes.isNotEmpty ||
        selectedQualityCodes.isNotEmpty ||
        selectedUnit != null;
  }
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F4A29).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list,
                                  color: Color(0xFF0F4A29),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Filter',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F4A29),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),

                            onPressed: () => Navigator.of(context).pop(),
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (instruments != null) ...[
                                _buildFilterCategory(
                                  iconName: 'music_note', // Neuer Parameter für das PNG im Web
                                  icon: Icons.music_note,
                                  title: 'Instrument',
                                  child: _buildMultiSelectDropdown(
                                    label: 'Instrument auswählen',
                                    options: instruments!,
                                    selectedValues: selectedInstrumentCodes,
                                    onChanged: (newSelection) {
                                      setState(() {
                                        selectedInstrumentCodes = newSelection;
                                       _searchController.clear();
    _activeSearchText = '';
                                        _hasUnsearchedChanges = false;
                                      });
                                      _saveFilters();
                                      _updateProductStream();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (parts != null) ...[
                                _buildFilterCategory(
                                  iconName: 'category',
                                  icon: Icons.category,
                                  title: 'Bauteil',
                                  child: _buildMultiSelectDropdown(
                                    label: 'Bauteil auswählen',
                                    options: parts!,
                                    selectedValues: selectedPartCodes,
                                    onChanged: (newSelection) {
                                      setState(() {
                                        selectedPartCodes = newSelection;
                                       _searchController.clear();
    _activeSearchText = '';
                                        _hasUnsearchedChanges = false;
                                      });
                                      _saveFilters();
                                      _updateProductStream();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (woodTypes != null) ...[
                                _buildFilterCategory(
                                  iconName: 'forest',
                                  icon: Icons.forest,
                                  title: 'Holzart',
                                  child: _buildMultiSelectDropdown(
                                    label: 'Holzart auswählen',
                                    options: woodTypes!,
                                    selectedValues: selectedWoodCodes,
                                    onChanged: (newSelection) {
                                      setState(() {
                                        selectedWoodCodes = newSelection;
                                       _searchController.clear();
    _activeSearchText = '';
                                        _hasUnsearchedChanges = false;
                                      });
                                      _saveFilters();
                                      _updateProductStream();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (qualities != null) ...[
                                _buildFilterCategory(
                                  iconName: 'star',
                                  icon: Icons.star,
                                  title: 'Qualität',
                                  child: _buildMultiSelectDropdown(
                                    label: 'Qualität auswählen',
                                    options: qualities!,
                                    selectedValues: selectedQualityCodes,
                                    onChanged: (newSelection) {
                                      setState(() {
                                        selectedQualityCodes = newSelection;
                                       _searchController.clear();
    _activeSearchText = '';
                                        _hasUnsearchedChanges = false;
                                      });
                                      _saveFilters();
                                      _updateProductStream();
                                    },
                                  ),
                                ),
                              ],
                              if (_hasActiveFilters()) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Aktive Filter:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: getAdaptiveIcon(
                                            iconName: 'favorite_border',
                                            defaultIcon: Icons.favorite_border,
                                            color: Colors.red,
                                          ),
                                          onPressed: _saveCurrentFilterAsFavorite,
                                          tooltip: 'Als Favorit speichern',
                                        ),
                                        TextButton.icon(
                                          icon: getAdaptiveIcon(iconName: 'clear_all', defaultIcon: Icons.clear_all,),
                                          label: const Text('Zurücksetzen'),
                                          onPressed: () {
                                            setState(() {
                                              selectedInstrumentCodes.clear();
                                              selectedPartCodes.clear();
                                              selectedWoodCodes.clear();
                                              selectedQualityCodes.clear();
                                              selectedUnit = null;
                                            });
                                            _saveFilters();
                                            _updateProductStream();
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...selectedInstrumentCodes.map((code) => _buildFilterChip(
                                    label: _getNameForCode(instruments!, code),
                                    onRemove: () => setState(() => selectedInstrumentCodes.remove(code)),
                                  )),
                                  ...selectedPartCodes.map((code) => _buildFilterChip(
                                    label: _getNameForCode(parts!, code),
                                    onRemove: () => setState(() => selectedPartCodes.remove(code)),
                                  )),
                                  ...selectedWoodCodes.map((code) => _buildFilterChip(
                                    label: _getNameForCode(woodTypes!, code),
                                    onRemove: () => setState(() => selectedWoodCodes.remove(code)),
                                  )),
                                  ...selectedQualityCodes.map((code) => _buildFilterChip(
                                    label: _getNameForCode(qualities!, code),
                                    onRemove: () => setState(() => selectedQualityCodes.remove(code)),
                                  )),
                                ],
                              ),

                            ],
                          ),
                        ),
                      ),
                    ),

                    // Footer mit Aktionsbuttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Abbrechen'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              this.setState(() {});
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4A29),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Anwenden'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  }