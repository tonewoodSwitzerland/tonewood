
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/home/production_screen.dart';
import 'package:tonewood/home/roundwood_entry_screen.dart';
import 'package:tonewood/home/warehouse_screen.dart';
import '../constants.dart';
import 'add_product_screen.dart';
import 'package:intl/intl.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  ProductManagementScreenState createState() => ProductManagementScreenState();
}

class ProductManagementScreenState extends State<ProductManagementScreen> {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  Map<String, dynamic>? selectedProduct;  // Hinzugefügt
  String? selectedBarcode;




  void _showEditBarcodeInputDialog() {
    barcodeController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Preis / Bestand bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _scanBarcodeForEdit();
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scanner nutzen'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (barcodeController.text.isNotEmpty) {
                        Navigator.pop(context);
                        _searchProductAndEdit(barcodeController.text);
                      }
                    },
                    child: const Text('Weiter'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanBarcodeForEdit() async {
    try {
      String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Abbrechen',
        true,
        ScanMode.BARCODE,
      );

      print('Scanned barcode: $barcodeResult'); // Debug

      if (barcodeResult != '-1') {
        await _searchProductAndEdit(barcodeResult);
      }
    } catch (e) {
      print('Error during scan: $e'); // Debug
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Scannen'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchProductAndEdit(String barcode) async {
    try {
      print('Searching for product: $barcode'); // Debug
      final parts = barcode.split('.');
      String searchBarcode;
      if (parts.length >= 2) {
        // Wenn es mehr als 2 Teile gibt, nehme die ersten beiden
        searchBarcode = '${parts[0]}.${parts[1]}';
      } else {
        // Wenn es nur 1 oder 2 Teile gibt, nimm den originalen Barcode
        searchBarcode = barcode;
      }
print("sB:$searchBarcode");
      final docSnapshot = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(searchBarcode)
          .get();

      print('Document exists: ${docSnapshot.exists}'); // Debug
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        print('Found product data: $data'); // Debug

        if (!mounted) return;

        // Direkt zu AddProductScreen navigieren mit den geladenen Daten
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProductScreen(
              isProduction: false,
              editMode: true,
              barcode:  searchBarcode,
              productData: data, // Die kompletten Daten übergeben
              onSave: () {
                setState(() {
                  selectedProduct = null;
                  selectedBarcode = null;
                  barcodeController.clear();
                });
              },
            ),
          ),
        );
      } else {
        print('Product not found in Firestore'); // Debug
        if (!mounted) return;
        AppToast.show(message: "Produkt nicht gefunden", height: h);


      }
    } catch (e) {
      print('Error searching product: $e'); // Debug
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Suche: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBarcodeInputDialog() {
    barcodeController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Artikelnummer eingeben'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Artikelnummer',
                  border: OutlineInputBorder(),
                  helperText: '(z.B. 1819.2024.1100.14)',
                ),
                keyboardType: TextInputType.text,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _scanBarcode();
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scanner nutzen'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (barcodeController.text.isNotEmpty) {
                        if (!_isValidProductionBarcode(barcodeController.text)) {
                          Navigator.pop(context); // Dialog schließen
                          return; // Die Fehlermeldung wird bereits in _isValidProductionBarcode angezeigt
                        }
                        Navigator.pop(context);
                        _checkProductAndShowQuantity(barcodeController.text);
                      }
                    },
                    child: const Text('Weiter'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanBarcode() async {
    try {
      String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Abbrechen',
        true,
        ScanMode.BARCODE,
      );

      if (barcodeResult != '-1') {
        print("bc:$barcodeResult");
        // Prüfe und validiere das Barcode-Format
        if (!_isValidProductionBarcode(barcodeResult)) {
          return; // Die Fehlermeldung wird bereits in _isValidProductionBarcode angezeigt
        }

        _checkProductAndShowQuantity(barcodeResult);
      }
    } on PlatformException {
      if (!mounted) return;
      AppToast.show(message: 'Fehler beim Scannen', height: h);
    }
  }

  void _showProductionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: SizedBox(  // SizedBox statt Container für bessere Lesbarkeit
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ProductionScreen(
                isDialog: true,
                onProductSelected: (productId) {
                  Navigator.pop(context);
                  _checkProductAndShowQuantity(productId);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isValidProductionBarcode(String barcode) {
    // Prüfe zuerst, ob es ein Verkaufsbarcode ist (Format: XXXX.YYYY)
    final salesRegex = RegExp(r'^[A-Z0-9]{4}\.[A-Z0-9]{4}$');
    if (salesRegex.hasMatch(barcode)) {
      AppToast.show(
          message: "Du hast einen Verkaufsbarcode eingegeben. Bitte Produktionsbarcode verwenden",
          height: h
      );
      return false;
    }

    // Teile den Barcode am letzten Punkt, falls eine Charge angehängt ist
    final parts = barcode.split('.');
    // Nehme nur die ersten 4 Teile für die Validierung
    final baseBarcode = parts.length > 4 ? parts.sublist(0, 4).join('.') : barcode;

    // Validiere den Basis-Barcode (ohne Charge)
    final productionRegex = RegExp(r'^[A-Z0-9]{4}\.[A-Z0-9]{4}\.\d{4}\.\d{2}$');
    final isValid = productionRegex.hasMatch(baseBarcode);

    if (!isValid) {
      AppToast.show(
          message: "Ungültiges Format. Bitte gültigen Produktionsbarcode eingeben",
          height: h
      );
    }

    return isValid;
  }
// Optional: Hilfsmethode zum Extrahieren des Basis-Barcodes
  String _getBaseBarcode(String fullBarcode) {
    final parts = fullBarcode.split('.');
    return parts.length > 4 ? parts.sublist(0, 4).join('.') : fullBarcode;
  }

// Im _checkProductAndShowQuantity dann entsprechend anpassen:
  Future<void> _checkProductAndShowQuantity(String productId) async {
    try {
      // Extrahiere den Basis-Barcode ohne Charge
      final baseProductId = _getBaseBarcode(productId);

      final doc = await FirebaseFirestore.instance
          .collection('production')
          .doc(baseProductId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        _showQuantityDialog(baseProductId, doc.data() as Map<String, dynamic>);
      } else {
        AppToast.show(message: 'Produkt nicht gefunden', height: h);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Suche: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  void _saveStockEntry(String productId, Map<String, dynamic> productData, int quantity) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final parts = productId.split('.');
      final shortBarcode = '${parts[0]}.${parts[1]}'; // z.B. 1718.2022 aus 1718.2022.1011

      // 1. Update production collection
      final productionRef = FirebaseFirestore.instance.collection('production').doc(productId);

      // Update Hauptprodukt
      batch.update(productionRef, {
        'quantity': FieldValue.increment(quantity),
        'last_stock_entry': FieldValue.serverTimestamp(),
        'last_stock_change': quantity,
      });

      // 2. Update inventory collection
      final inventoryRef = FirebaseFirestore.instance.collection('inventory').doc(shortBarcode);

      batch.set(inventoryRef, {
        'quantity': FieldValue.increment(quantity),
        'last_stock_entry': FieldValue.serverTimestamp(),
        'last_stock_change': quantity,

      }, SetOptions(merge: true));

      // 2. Get next batch number
      final batchesSnapshot = await productionRef
          .collection('batch')
          .orderBy('batch_number', descending: true)
          .limit(1)
          .get();

      int nextBatchNumber = 1;
      if (batchesSnapshot.docs.isNotEmpty) {
        nextBatchNumber = (batchesSnapshot.docs.first.data()['batch_number'] as int) + 1;
      }

      // 3. Create new batch entry
      final batchRef = productionRef
          .collection('batch')
          .doc(nextBatchNumber.toString().padLeft(4, '0'));

      batch.set(batchRef, {
        'batch_number': nextBatchNumber,
        'quantity': quantity,
        'stock_entry_date': DateTime.now(),

      });

      // 4. Add stock entry for history
      final entryRef = FirebaseFirestore.instance
          .collection('stock_entries')
          .doc();

      batch.set(entryRef, {
        'product_id': productId,
        'batch_number': nextBatchNumber,
        'product_name': productData['product_name'],
        'quantity_change': quantity,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'entry',
        'entry_type': 'manual',
        'instrument_name': productData['instrument_name'],
        'part_name': productData['part_name'],
        'wood_name': productData['wood_name'],
        'quality_name': productData['quality_name'],
      });

      // Commit all changes
      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      AppToast.show(
          message: 'Wareneingang von $quantity ${productData['unit'] ?? 'Stück'} gebucht',
          height: h
      );

    } catch (e) {
      print('Error saving stock entry: $e');
      if (!mounted) return;
      AppToast.show(
          message: 'Fehler beim Speichern: $e',
          height: h
      );
    }
  }
  void _showQuantityDialog(String productId, Map<String, dynamic> productData) {
    quantityController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Artikelnummer', productId),
                        _buildInfoRow('Produkt', productData['product_name']),
                        const Divider(),
                        // Grundinformationen ExpansionTile
                        ExpansionTile(
                          title: const Text(
                            'Grundinformationen',
                            style: smallHeadline,
                          ),
                          initiallyExpanded: false,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Column(
                                children: [
                                  _buildInfoRow('Instrument', '${productData['instrument_name']} (${productData['instrument_code']})'),
                                  _buildInfoRow('Bauteil', '${productData['part_name']} (${productData['part_code']})'),
                                  _buildInfoRow('Holzart', '${productData['wood_name']} (${productData['wood_code']})'),
                                  _buildInfoRow('Qualität', '${productData['quality_name']} (${productData['quality_code']})'),
                                  _buildInfoRow('Jahrgang', '${productData['year']}'),
                                  _buildInfoRow('Preis', '${productData['price_CHF']} CHF'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ExpansionTile(
                          title: const Text(
                            'Eigenschaften',
                            style: smallHeadline,
                          ),
                          initiallyExpanded: false,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Column(
                                children: [
                                  _buildBooleanRow('Thermobehandelt', productData['thermally_treated'] ?? false),
                                  _buildBooleanRow('Haselfichte', productData['haselfichte'] ?? false),
                                  _buildBooleanRow('Mondholz', productData['moonwood'] ?? false),
                                  _buildBooleanRow('FSC 100%', productData['FSC_100'] ?? false),
                                ],
                              ),
                            ),
                          ],
                        ),
                     //   const Divider(),
                    //    _buildInfoRow('Aktueller Bestand', '${productData['quantity']} ${productData['unit']}'),

                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Menge',
                    border: OutlineInputBorder(),
                    helperText: 'Positive Zahl für Zugang eingeben',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
        if (quantityController.text.isNotEmpty) {
        final quantity = int.parse(quantityController.text);
         _saveStockEntry(productId, productData, quantity);
        }

              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style:  kLabelTextStyleT1small,
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A',style: kLabelTextStyleT1small,),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style:  kLabelTextStyleT1small,
            ),
          ),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(value ? 'Ja' : 'Nein',style: kLabelTextStyleT1small,),
        ],
      ),
    );
  }
  String selectedAction = ''; // Speichert die aktuelle Aktion (Wareneingang, Bearbeiten, etc.)

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;

    return Scaffold(
      body: isDesktopLayout ? _buildDesktopLayout() : Center(child: _buildMobileLayout()),
    );
  }

  void _navigateToNewProduct(BuildContext context) {
    if (kIsWeb) {
      // Für Web: Verwende verzögerte Navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              body: AddProductScreen(
                editMode: false,
                isProduction: true,
              ),
            ),
          ),
        );
      });
    } else {
      // Für mobile Plattformen: Direkte Navigation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddProductScreen(
            editMode: false,
            isProduction: true,
          ),
        ),
      );
    }
  }
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Linke Seite - Aktionsmenü
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
                child: Text(
                  'Produktverwaltung',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  children: [
                    _buildActionButton(
                      icon: Icons.add_shopping_cart,
                      title: 'Produktionseingang buchen',
                      subtitle: 'Neue Produktion dem Bestand hinzufügen',
                      onTap: () => setState(() => selectedAction = 'wareneingang'),
                      isSelected: selectedAction == 'wareneingang',
                    ),
                    _buildActionButton(
                      icon: Icons.edit,
                      title: 'Preis / Bestand bearbeiten',
                      subtitle: 'Produktdaten ändern',
                      onTap: () => setState(() => selectedAction = 'bearbeiten'),
                      isSelected: selectedAction == 'bearbeiten',
                    ),
                _buildActionButton(
                  icon: Icons.add_circle_outline,
                  title: 'Neues Produkt',
                  subtitle: 'Produkt erstellen',
                  onTap: () => _navigateToNewProduct(context),
                  isSelected: selectedAction == 'neu',
                ),
                    _buildActionButton(
                      icon: Icons.forest,
                      title: 'Einschnitt Rundholz',
                      subtitle: 'Rundholz erfassen und bearbeiten',
                      onTap: () => setState(() => selectedAction = 'rundholz'),
                      isSelected: selectedAction == 'rundholz',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Rechte Seite - Aktionsbereich
        Expanded(
          child: _buildRightPanel(),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Material(
        color: isSelected ? Colors.grey.shade100 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon,
                    size: 24,
                    color: isSelected ? primaryAppColor : Colors.grey.shade700),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? primaryAppColor : Colors.black,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
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

  Widget _buildRightPanel() {
    switch (selectedAction) {
      case 'neu':
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AddProductScreen(
              isProduction: true,
              editMode: false,
              onSave: () {
                setState(() {
                  selectedAction = '';
                });
              },
            ),
          ),
        );
      case 'wareneingang':
        return _buildWareneingangPanel();
      case 'bearbeiten':
        return _buildBearbeitenPanel();
      case 'rundholz':
        return _buildRundholzPanel();
      default:
        return const Center(
          child: Text('Bitte wähle eine Aktion aus'),
        );
    }
  }
  Widget _buildWareneingangPanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produktion buchen',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: barcodeController,
                          decoration: const InputDecoration(
                            labelText: 'Barcode',
                            border: OutlineInputBorder(),
                            helperText: 'Gib den Barcode des Produkts ein',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          // IconButton(
                          //   onPressed: () => _scanBarcode(),
                          //   icon: const Icon(Icons.qr_code_scanner),
                          //   tooltip: 'Barcode scannen',
                          // ),
                          IconButton(
                            onPressed: _showProductionSearchDialog,
                            icon: const Icon(Icons.search),
                            tooltip: 'Produkte durchsuchen',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (barcodeController.text.isNotEmpty) {
                        _checkProductAndShowQuantity(barcodeController.text);
                      }
                    },
                    child: const Text('Produkt suchen'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductionSearchDialog() {
    final searchController = TextEditingController();
    String searchTerm = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: 900,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Produkte durchsuchen',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Suchen',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        helperText: 'Suche nach Artikelnummer, Produkt, Instrument oder Holzart',
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchTerm = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('production')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Fehler: ${snapshot.error}'),
                            );
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final docs = snapshot.data?.docs ?? [];
                          final filteredDocs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return doc.id.toLowerCase().contains(searchTerm) ||
                                (data['product_name']?.toString().toLowerCase() ?? '').contains(searchTerm) ||
                                (data['instrument_name']?.toString().toLowerCase() ?? '').contains(searchTerm) ||
                                (data['wood_name']?.toString().toLowerCase() ?? '').contains(searchTerm) ||
                                (data['quality_name']?.toString().toLowerCase() ?? '').contains(searchTerm);
                          }).toList();

                          if (filteredDocs.isEmpty) {
                            return const Center(
                              child: Text('Keine Produkte gefunden'),
                            );
                          }

                          return SingleChildScrollView(
                            child: DataTable(
                              showCheckboxColumn: false,  // Entfernt die Checkbox-Spalte
                              columns: const [
                                DataColumn(label: Text('Artikelnummer')),
                                DataColumn(label: Text('Produkt')),
                                DataColumn(label: Text('Instrument')),
                                DataColumn(label: Text('Holzart')),
                                DataColumn(label: Text('Qualität')),
                                DataColumn(label: Text('')),
                              ],
                              rows: filteredDocs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(doc.id)),
                                    DataCell(Text(data['product_name'] ?? '')),
                                    DataCell(Text(data['instrument_name'] ?? '')),
                                    DataCell(Text(data['wood_name'] ?? '')),
                                    DataCell(Text(data['quality_name'] ?? '')),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () async {
                                          try {
                                            Navigator.pop(context);
                                            await _checkProductAndShowQuantity(doc.id);
                                          } catch (e) {
                                            if (!mounted) return;
                                            AppToast.show(
                                              message: 'Fehler beim Laden des Produkts: $e',
                                              height: h,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                  onSelectChanged: (selected) async {
                                    if (selected == true) {
                                      try {
                                        Navigator.pop(context);
                                        await _checkProductAndShowQuantity(doc.id);
                                      } catch (e) {
                                        if (!mounted) return;
                                        AppToast.show(
                                          message: 'Fehler beim Laden des Produkts: $e',
                                          height: h,
                                        );
                                      }
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
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

  Widget _buildBearbeitenPanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(  // Kein Container oder SingleChildScrollView mehr auf dieser Ebene
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preis / Bestand bearbeiten',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Barcode',
                      border: OutlineInputBorder(),
                      helperText: 'Gib den Barcode des zu bearbeitenden Produkts ein',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (barcodeController.text.isNotEmpty) {
                        _searchProduct(barcodeController.text);
                      }
                    },
                    child: const Text('Produkt suchen'),
                  ),
                ],
              ),
            ),
          ),
          if (selectedProduct != null) ...[
            const SizedBox(height: 24),
            Expanded(  // Expanded für den AddProductScreen
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AddProductScreen(
                    isProduction: true,
                    editMode: true,
                    productData: selectedProduct!,
                    barcode: selectedBarcode!,
                    onSave: () {
                      setState(() {
                        selectedProduct = null;
                        selectedBarcode = null;
                        barcodeController.clear();
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }











  Future<void> _searchProduct(String barcode) async {
    try {
      print('Searching for product with barcode: $barcode');

      final doc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(barcode)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final productData = doc.data();
        print('Product found: $productData');

        // Direkt zum AddProductScreen navigieren mit den geladenen Daten
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProductScreen(
              isProduction: true,
              editMode: true,
              barcode: barcode,
              productData: productData,
              onSave: () {
                setState(() {
                  selectedProduct = null;
                  selectedBarcode = null;
                  barcodeController.clear();
                });
              },
            ),
          ),
        );
      } else {
        print('Product not found');
        AppToast.show(message: "Produkt nicht gefunden", height: h);

      }
    } catch (e) {
      print('Error searching product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Suche: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }









  Widget _buildRundholzPanel() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('roundwood')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Einschnitt Rundholz',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RoundwoodEntryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Neuer Eintrag'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!snapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
                  child: Card(
                    child: ListView(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Interne Nr.')),
                              DataColumn(label: Text('Stammnummer')),
                              DataColumn(label: Text('Holzart')),
                              DataColumn(label: Text('Verwendung')),
                              DataColumn(label: Text('Mondholz')),
                              DataColumn(label: Text('m³')),
                              DataColumn(label: Text('Qualität')),
                              DataColumn(label: Text('Einschnitt')),
                              DataColumn(label: Text('Farbe')),
                              DataColumn(label: Text('Herkunft')),
                              DataColumn(label: Text('Aktionen')),
                            ],
                            rows: snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DataRow(
                                cells: [
                                  DataCell(Text(data['internal_number'] ?? '')),
                                  DataCell(Text(data['original_number'] ?? '')),
                                  DataCell(Text(data['wood_type'] ?? '')),
                                  DataCell(Text(data['purpose'] ?? '')),
                                  DataCell(Icon(
                                    data['is_moonwood'] == true
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: data['is_moonwood'] == true
                                        ? Colors.green
                                        : Colors.red,
                                  )),
                                  DataCell(Text(data['volume']?.toString() ?? '')),
                                  DataCell(Text(data['quality'] ?? '')),
                                  DataCell(Text(data['cutting_date'] != null
                                      ? DateFormat('dd.MM.yyyy').format(
                                      (data['cutting_date'] as Timestamp)
                                          .toDate())
                                      : '')),
                                  DataCell(Text(data['color'] ?? '')),
                                  DataCell(Text(data['origin'] ?? '')),
                                  DataCell(Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  RoundwoodEntryScreen(
                                                    editMode: true,
                                                    roundwoodData: data,
                                                    documentId: doc.id,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () {
                                          _showDeleteConfirmationDialog(doc.id);
                                        },
                                      ),
                                    ],
                                  )),
                                ],
                              );
                            }).toList(),
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
  }
  Future<void> _showDeleteConfirmationDialog(String documentId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Löschen bestätigen'),
          content: const Text(
              'Möchtest du diesen Rundholz-Eintrag wirklich löschen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('roundwood')
                    .doc(documentId)
                    .delete();
                if (!mounted) return;
                Navigator.pop(context);

                AppToast.show(message:'Eintrag erfolgreich gelöscht', height: h);


              },
              child: const Text('Löschen'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }




  void _showWarehouseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: WarehouseScreen(
                key: UniqueKey(),
                isDialog: true,
                onBarcodeSelected: (barcode) {
                  Navigator.pop(context);
                  _checkProductAndShowQuantity(barcode);
                },
              ),
            ),
          ),
        );
      },
    );
  }


// Optional: Eine spezifische Methode für die Bearbeitung
  Future<void> _searchProductForEdit(String barcode) async {
    await _searchProduct(barcode);
    if (selectedProduct != null) {
      // Hier könnten noch spezifische Vorbereitungen für die Bearbeitung stattfinden
    }
  }
  Widget _buildMobileLayout() {
    return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight, // Wichtig für volle Höhe
                ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [


            SizedBox(
              width: double.infinity,
              child: Card(
                margin: const EdgeInsets.fromLTRB(16,8,16,8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.add_shopping_cart, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'Produktion buchen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed:  _showProductionDialog,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Icon(Icons.search),

                          ),
                          ElevatedButton(
                            onPressed: () => _scanBarcode(),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                              child: const Icon(Icons.qr_code_scanner),

                          ),
                          ElevatedButton(
                            onPressed: _showBarcodeInputDialog,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Icon(Icons.keyboard),

                          ),
                        ],
                      ),

                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Card(
                margin: const EdgeInsets.fromLTRB(16,8,16,8),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RoundwoodEntryScreen(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.forest, size: 40),
                        SizedBox(height: 16),
                        Text(
                          'Einschnitt Rundholz',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Card(
                margin: const EdgeInsets.fromLTRB(16,8,16,8),
                child: InkWell(
                  onTap: _showEditBarcodeInputDialog,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.edit, size: 40),
                        SizedBox(height: 16),
                        Text(
                          'Preis / Bestand bearbeiten',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Card(
                margin:const EdgeInsets.fromLTRB(16,8,16,8),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddProductScreen(editMode: false, isProduction: true,),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.add_circle_outline, size: 40),
                        SizedBox(height: 16),
                        Text(
                          'Neues Produkt anlegen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      ],
                    ),
                  ),
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

  @override
  void dispose() {
    quantityController.dispose();
    barcodeController.dispose();
    super.dispose();
  }
}