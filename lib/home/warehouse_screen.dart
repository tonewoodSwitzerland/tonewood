import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class WarehouseScreen extends StatefulWidget {
  final bool isDialog;
  final Function(String)? onBarcodeSelected;  // Nur der Barcode wird übergeben


  const WarehouseScreen({
    required Key key,
    this.isDialog = false,
    this.onBarcodeSelected,
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

// Dropdown data from Firestore
  List<QueryDocumentSnapshot>? instruments;
  List<QueryDocumentSnapshot>? parts;
  List<QueryDocumentSnapshot>? woodTypes;
  List<QueryDocumentSnapshot>? qualities;
  List<String> units = ['Stück', 'Kg', 'Palette', 'm³'];


  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  bool isQuickFilterActive = false;
  String? _shopFilter; // null = alle, 'sold' = verkauft, 'available' = nicht verkauft
  bool _isOnlineShopView = false;
  void _toggleQuickFilter() {
    setState(() {
      isQuickFilterActive = !isQuickFilterActive;

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
  }

  Future<int> _getAvailableQuantity(String shortBarcode) async {
    // Aktuellen Bestand aus inventory collection abrufen
    final inventoryDoc = await FirebaseFirestore.instance
        .collection('inventory')
        .doc(shortBarcode)
        .get();

    final currentStock = (inventoryDoc.data()?['quantity'] ?? 0) as int;

    // Temporär gebuchte Menge abrufen
    final tempBasketDoc = await FirebaseFirestore.instance
        .collection('temporary_basket')
        .where('product_id', isEqualTo: shortBarcode)
        .get();

    final reservedQuantity = tempBasketDoc.docs.fold<int>(
      0,
          (sum, doc) => sum + (doc.data()['quantity'] as int),
    );

    return currentStock - reservedQuantity;
  }


  Future<void> _addToTemporaryBasket(Map<String, dynamic> productData, int quantity) async {
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
    });
  }

  void _showOnlineShopDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4A29).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shopping_cart,
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
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection(
                          title: 'Barcode',
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

                        _buildDetailSection(
                          title: 'Status',
                          icon: Icons.info_outline,
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

                        _buildDetailSection(
                          title: 'Produktinformationen',
                          icon: Icons.info_outline,
                          content: Column(
                            children: [
                              _buildDetailRow(
                                'Instrument',
                                '${data['instrument_name']} (${data['instrument_code']})',
                                icon: Icons.piano,
                              ),
                              _buildDetailRow(
                                'Bauteil',
                                '${data['part_name']} (${data['part_code']})',
                                icon: Icons.construction,
                              ),
                              _buildDetailRow(
                                'Holzart',
                                '${data['wood_name']} (${data['wood_code']})',
                                icon: Icons.forest,
                              ),
                              _buildDetailRow(
                                'Qualität',
                                '${data['quality_name']} (${data['quality_code']})',
                                icon: Icons.stars,
                              ),
                            ],
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!data['sold'])
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
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
                                      icon: const Icon(Icons.delete),
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
                            ),
                            icon: const Icon(Icons.remove_shopping_cart),
                            label: const Text('Entfernen'),
                          ),
                        ),
                      if (!data['sold'])
                        const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: data['sold'] ? null : () async {
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
                                    icon: const Icon(Icons.check),
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
                          ),
                          icon: const Icon(Icons.sell),
                          label: const Text('Als verkauft markieren'),
                        ),
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
  }

  Future<void> _removeFromOnlineShop(Map<String, dynamic> data) async {
    try {
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4A29).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
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
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Artikelnummer Sektion
                        _buildDetailSection(
                          title: 'Artikelnummer',
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

                        // Produktinformationen
                        _buildDetailSection(
                          title: 'Produktinformationen',
                          icon: Icons.info_outline,
                          content: Column(
                            children: [
                              _buildDetailRow(
                                'Instrument',
                                '${data['instrument_name']} (${data['instrument_code']})',
                                icon: Icons.piano,
                              ),
                              _buildDetailRow(
                                'Bauteil',
                                '${data['part_name']} (${data['part_code']})',
                                icon: Icons.construction,
                              ),
                              _buildDetailRow(
                                'Holzart',
                                '${data['wood_name']} (${data['wood_code']})',
                                icon: Icons.forest,
                              ),
                              _buildDetailRow(
                                'Qualität',
                                '${data['quality_name']} (${data['quality_code']})',
                                icon: Icons.stars,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Bestand und Preis
                        _buildDetailSection(
                          title: 'Bestand & Preis',
                          icon: Icons.inventory,
                          content: Column(
                            children: [
                              // Bestandsanzeige
                              FutureBuilder<int>(
                                future: _getAvailableQuantity(data['short_barcode']),
                                builder: (context, snapshot) {
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
                                              ? '${snapshot.data} ${data['unit'] ?? 'Stück'}'
                                              : 'Wird geladen...',
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

                        const SizedBox(height: 24),

                        // Warenkorb Sektion
                        _buildDetailSection(
                          title: 'In den Warenkorb',
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
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Abbrechen'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text('In den Warenkorb'),
                        onPressed: () async {
                          if (quantityController.text.isEmpty) return;

                          final quantity = int.parse(quantityController.text);
                          final availableQuantity = await _getAvailableQuantity(data['short_barcode']);

                          if (quantity <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bitte geben Sie eine gültige Menge ein'),
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
                          backgroundColor: const Color(0xFF0F4A29),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
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
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
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
                Icon(icon, size: 20, color: const Color(0xFF0F4A29)),
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
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey[600]),
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

      setState(() {
        instruments = instrumentsSnapshot.docs;
        parts = partsSnapshot.docs;
        woodTypes = woodTypesSnapshot.docs;
        qualities = qualitiesSnapshot.docs;
      });
    } catch (e) {
      print('Fehler beim Laden der Filterdaten: $e');
    }
  }
  // Query builder based on filters
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
              title: Container(
                height: 36,  // Etwas kleiner
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],  // Hellerer Hintergrund
                  borderRadius: BorderRadius.circular(8),  // Weniger gerundet
                  border: Border.all(
                    color: Colors.grey[300]!,  // Subtile Umrandung
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isOnlineShopView = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !_isOnlineShopView ? primaryAppColor.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Lager',
                            style: TextStyle(
                              fontSize: 14,  // Kleinere Schrift
                              color: !_isOnlineShopView ? primaryAppColor : Colors.grey[600],
                              fontWeight: !_isOnlineShopView ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                      child: VerticalDivider(
                        color: Colors.grey[300],
                        thickness: 1,
                        width: 1,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isOnlineShopView = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isOnlineShopView ? primaryAppColor.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
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
              ), centerTitle: true,
              // Nur für Mobile den Filter-Button zeigen
              actions: !isDesktopLayout ? [
                IconButton(
                  icon: Icon(
                    isQuickFilterActive ? Icons.star : Icons.star_outline,
                    color: isQuickFilterActive ? const Color(0xFF0F4A29) : null,
                  ),
                  onPressed: _toggleQuickFilter,
                  tooltip: isQuickFilterActive
                      ? 'Schnellfilter deaktivieren'
                      : 'Schnellfilter für Decken aktivieren',
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterDialog(),
                ),
              ] : null,
            ),
            body: isDesktopLayout
                ? _buildDesktopLayout()
                : _buildMobileLayout(),
          );
        }
    );
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
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    selectedInstrumentCodes.remove(code);
                  });
                },
              ),
            )),
          if (parts != null)
            ...selectedPartCodes.map((code) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('${getNameForCode(parts!, code)} ($code)'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    selectedPartCodes.remove(code);
                  });
                },
              ),
            )),
          if (woodTypes != null)
            ...selectedWoodCodes.map((code) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('${getNameForCode(woodTypes!, code)} ($code)'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    selectedWoodCodes.remove(code);
                  });
                },
              ),
            )),
          if (qualities != null)
            ...selectedQualityCodes.map((code) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('${getNameForCode(qualities!, code)} ($code)'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    selectedQualityCodes.remove(code);
                  });
                },
              ),
            )),

          if (selectedUnit != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                label: Text('Einheit: $selectedUnit'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    selectedUnit = null;
                  });
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
        if (_hasActiveFilters())
          _buildActiveFiltersChips(),
        Expanded(
          child: _buildProductList(),
        ),
      ],
    );
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
              'Verfeinern Sie Ihre Suche',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            if (instruments != null) ...[
              _buildFilterCategory(
                icon: Icons.piano,
                title: 'Instrument',
                child: _buildMultiSelectDropdown(
                  label: 'Instrument auswählen',
                  options: instruments!,
                  selectedValues: selectedInstrumentCodes,
                  onChanged: (newSelection) {
                    setState(() {
                      selectedInstrumentCodes = newSelection;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (parts != null) ...[
              _buildFilterCategory(
                icon: Icons.construction,
                title: 'Bauteil',
                child: _buildMultiSelectDropdown(
                  label: 'Bauteil auswählen',
                  options: parts!,
                  selectedValues: selectedPartCodes,
                  onChanged: (newSelection) {
                    setState(() {
                      selectedPartCodes = newSelection;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (woodTypes != null) ...[
              _buildFilterCategory(
                icon: Icons.forest,
                title: 'Holzart',
                child: _buildMultiSelectDropdown(
                  label: 'Holzart auswählen',
                  options: woodTypes!,
                  selectedValues: selectedWoodCodes,
                  onChanged: (newSelection) {
                    setState(() {
                      selectedWoodCodes = newSelection;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (qualities != null) ...[
              _buildFilterCategory(
                icon: Icons.stars,
                title: 'Qualität',
                child: _buildMultiSelectDropdown(
                  label: 'Qualität auswählen',
                  options: qualities!,
                  selectedValues: selectedQualityCodes,
                  onChanged: (newSelection) {
                    setState(() {
                      selectedQualityCodes = newSelection;
                    });
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
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Zurücksetzen'),
                    onPressed: () {
                      setState(() {
                        selectedInstrumentCodes.clear();
                        selectedPartCodes.clear();
                        selectedWoodCodes.clear();
                        selectedQualityCodes.clear();
                        selectedUnit = null;
                      });
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
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
              color: const Color(0xFF0F4A29).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0F4A29),
              size: 24,
            ),
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
      deleteIcon: const Icon(Icons.close, size: 16),
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

  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Keine Produkte gefunden',
                  style: TextStyle(color: Colors.grey[700]),
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
            Expanded(
              child: ListView.builder(
                itemCount: snapshot.data!.docs.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
              
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
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
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _isOnlineShopView
                                            ? 'Barcode: ${data['barcode']?.toString() ?? ''}'
                                            : 'Art.Nr: ${data['short_barcode']?.toString() ?? ''}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Bestand/Status Anzeige
                                if (_isOnlineShopView)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (data['sold'] == true ? Colors.red : Colors.green).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      data['sold'] == true ? 'Verkauft' : 'Im Shop',
                                      style: TextStyle(
                                        color: data['sold'] == true ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F4A29).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          'Lager: ${data['quantity']?.toString() ?? '0'} ${data['unit']?.toString() ?? ''}',
                                          style: const TextStyle(
                                            color: Color(0xFF0F4A29),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
              
              
              
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('temporary_basket')
                                            .where('product_id', isEqualTo: data['short_barcode'])
                                            .snapshots(),
                                        builder: (context, cartSnapshot) {
                                          int cartQuantity = 0;
                                          if (cartSnapshot.hasData) {
                                            cartQuantity = cartSnapshot.data!.docs.fold(0,
                                                    (sum, doc) => sum + (doc.data() as Map<String, dynamic>)['quantity'] as int);
                                          }
                                          if (cartQuantity > 0) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  'Warenkorb: $cartQuantity',
                                                  style: const TextStyle(
                                                    color: Colors.orange,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                      const SizedBox(height: 8),
              
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          'Online: ${data['quantity_online_shop']?.toString() ?? '0'} ${data['unit']?.toString() ?? ''}',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Instrument: ${data['instrument_name']} (${data['instrument_code']})',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                            Text(
                              'Bauteil: ${data['part_name']} (${data['part_code']})',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                            Text(
                              'Holzart: ${data['wood_name']} (${data['wood_code']})',
                              style: TextStyle(color: Colors.grey[800]),
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

  Widget _buildMultiSelectDropdown({
    required String label,
    required List<QueryDocumentSnapshot> options,
    required List<String> selectedValues,
    required Function(List<String>) onChanged,
  }) {
    String getNameForCode(String code) {
      try {
        final doc = options.firstWhere(
              (doc) => (doc.data() as Map<String, dynamic>)['code'] == code,
        );
        return (doc.data() as Map<String, dynamic>)['name'] as String;
      } catch (e) {
        return code; // Fallback zum Code falls kein Name gefunden wird
      }
    }

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


  bool _hasActiveFilters() {
    return selectedInstrumentCodes.isNotEmpty ||
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
                                child: const Icon(
                                  Icons.filter_list,
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
                            icon: const Icon(Icons.close),
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
                                  icon: Icons.piano,
                                  title: 'Instrument',
                                  child: _buildMultiSelectDropdown(
                                    label: 'Instrument auswählen',
                                    options: instruments!,
                                    selectedValues: selectedInstrumentCodes,
                                    onChanged: (newSelection) {
                                      setState(() {
                                        selectedInstrumentCodes = newSelection;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (parts != null) ...[
                                _buildFilterCategory(
                                  icon: Icons.construction,
                                  title: 'Bauteil',
                                  child: _buildMultiSelectDropdown(
                                    label: 'Bauteil auswählen',
                                    options: parts!,
                                    selectedValues: selectedPartCodes,
                                    onChanged: (newSelection) {
                                      setState(() {
                                        selectedPartCodes = newSelection;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (woodTypes != null) ...[
                                _buildFilterCategory(
                                  icon: Icons.forest,
                                  title: 'Holzart',
                                  child: _buildMultiSelectDropdown(
                                    label: 'Holzart auswählen',
                                    options: woodTypes!,
                                    selectedValues: selectedWoodCodes,
                                    onChanged: (newSelection) {
                                      setState(() {
                                        selectedWoodCodes = newSelection;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (qualities != null) ...[
                                _buildFilterCategory(
                                  icon: Icons.stars,
                                  title: 'Qualität',
                                  child: _buildMultiSelectDropdown(
                                    label: 'Qualität auswählen',
                                    options: qualities!,
                                    selectedValues: selectedQualityCodes,
                                    onChanged: (newSelection) {
                                      setState(() {
                                        selectedQualityCodes = newSelection;
                                      });
                                    },
                                  ),
                                ),
                              ],

                              if (_hasActiveFilters()) ...[
                                const SizedBox(height: 24),
                                const Divider(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Aktive Filter',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.clear_all),
                                        label: const Text('Zurücksetzen'),
                                        onPressed: () {
                                          setState(() {
                                            selectedInstrumentCodes.clear();
                                            selectedPartCodes.clear();
                                            selectedWoodCodes.clear();
                                            selectedQualityCodes.clear();
                                            selectedUnit = null;
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                            child: const Text('Abbrechen'),
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            child: const Text('Anwenden'),
                            onPressed: () {
                              this.setState(() {});
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4A29),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
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