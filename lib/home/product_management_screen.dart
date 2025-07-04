
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/home/production_screen.dart';
import 'package:tonewood/home/roundwood_entry_screen.dart';
import 'package:tonewood/home/warehouse_screen.dart';
import '../constants.dart';
import '../services/icon_helper.dart';
import 'add_product_screen.dart';
import 'package:intl/intl.dart';
enum BarcodeType {
  sales,
  production,
}
class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  ProductManagementScreenState createState() => ProductManagementScreenState();
}

class ProductManagementScreenState extends State<ProductManagementScreen> {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();

  // Neue Controller für die Teile der Artikelnummer
  final TextEditingController partOneController = TextEditingController();
  final TextEditingController partTwoController = TextEditingController();
  Map<String, dynamic>? selectedProduct;  // Hinzugefügt
  String? selectedBarcode;
  BarcodeType selectedBarcodeType = BarcodeType.sales;



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
                        _buildInfoRow('Qualität', productData['quality_name']),
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
      setState(() {
        selectedAction = 'neu';
      });
      // // Für Web: Verwende verzögerte Navigation
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   Navigator.of(context).push(
      //     MaterialPageRoute(
      //       builder: (context) => Scaffold(
      //         body: AddProductScreen(
      //           editMode: false,
      //           isProduction: true,
      //         ),
      //       ),
      //     ),
      //   );
      // });
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
                      icon: Icons.precision_manufacturing,
                      iconName: 'precision_manufacturing',
                      title: 'Produktionseingang buchen',
                      subtitle: 'Neue Produktion dem Bestand hinzufügen',
                      onTap: () => setState(() => selectedAction = 'wareneingang'),
                      isSelected: selectedAction == 'wareneingang',
                    ),
                    _buildActionButton(
                      iconName: 'edit',
                      icon: Icons.edit,
                      title: 'Preis / Bestand bearbeiten',
                      subtitle: 'Produktdaten ändern',
                      onTap: () => setState(() => selectedAction = 'bearbeiten'),
                      isSelected: selectedAction == 'bearbeiten',
                    ),
                _buildActionButton(
                  iconName: 'add',
                  icon: Icons.add,
                  title: 'Neues Produkt',
                  subtitle: 'Produkt erstellen',
                  onTap: () => _navigateToNewProduct(context),
                  isSelected: selectedAction == 'neu',
                ),
                    _buildActionButton(
                      iconName: 'forest',
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
    String? iconName,  // Neuer Parameter für adaptive Icons
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
                iconName != null
                    ? getAdaptiveIcon(
                  iconName: iconName,
                  defaultIcon: icon,
                  size: 24,
                  color: isSelected ? primaryAppColor : Colors.grey.shade700,
                )
                    : Icon(
                    icon,
                    size: 24,
                    color: isSelected ? primaryAppColor : Colors.grey.shade700
                ),
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
        return AddProductScreen(
          isProduction: true,
          editMode: false,
          onSave: () {
            setState(() {
              selectedAction = '';
            });
          },
        );
      case 'wareneingang':
        return _buildWareneingangPanel();
      case 'bearbeiten':
        return _buildBearbeitenPanel();
      case 'rundholz':
        return RoundwoodEntryScreen();
      default:
        return const Center(
          child: Text('Bitte wähle eine Aktion aus'),
        );
    }
  }
  Widget _buildWareneingangPanel() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Produktion buchen',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F4A29),
                ),
              ),
              IconButton(
                icon: getAdaptiveIcon(
                  iconName: 'help',
                  defaultIcon: Icons.help,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  // Show help dialog or information
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Wie möchtest du die Produktion buchen?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wähle eine der folgenden Optionen',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWideScreen = constraints.maxWidth > 800;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildOptionButton(
                            icon: getAdaptiveIcon(
                              iconName: 'search',
                              defaultIcon: Icons.search,
                              color: Colors.white,
                            ),
                            label: 'Produktion suchen',
                            onPressed: _showProductionDialog,
                            isWideScreen: isWideScreen,
                            color: const Color(0xFF0F4A29),
                          ),
                          SizedBox(width: isWideScreen ? 48 : 24),
                          _buildOptionButton(
                            icon: getAdaptiveIcon(
                              iconName: 'keyboard',
                              defaultIcon: Icons.keyboard,
                              color: Colors.white,
                            ),
                            label: 'Barcode eingeben',
                            onPressed: _showBarcodeInputDialog,
                            isWideScreen: isWideScreen,
                            color: const Color(0xFF0F4A29).withOpacity(0.8),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4A29).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0F4A29).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'info',
                          defaultIcon: Icons.info,
                          color: const Color(0xFF0F4A29),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Hier kannst du neue Produktion in den Lagerbestand buchen. Wähle aus der Produktionsliste oder gib einen Produktions-Barcode ein.',
                            style: TextStyle(
                              color: const Color(0xFF0F4A29),
                            ),
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
    );
  }

// Verbesserte Methode für die Option-Buttons
  Widget _buildOptionButton({
    required Widget icon,
    required String label,
    required VoidCallback onPressed,
    required bool isWideScreen,
    Color color = const Color(0xFF0F4A29),
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isWideScreen ? 32 : 24,
          vertical: isWideScreen ? 20 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Container(
        width: isWideScreen ? 160 : 120,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: isWideScreen ? 16 : 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

// Helper method to create consistent option buttons

  void _showProductsSearchDialog() {
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
                          icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
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
    // Controller für die zwei Teile der Artikelnummer


    // Wenn ein bestehender Barcode vorhanden ist, aufteilen
    if (barcodeController.text.isNotEmpty) {
      final parts = barcodeController.text.split('.');
      if (parts.length >= 2) {
        partOneController.text = parts[0];
        partTwoController.text = parts[1];
      }
    }

    // Funktion zum Kombinieren der beiden Teile und Suchen
    void combineAndSearch() {
      if (partOneController.text.isNotEmpty && partTwoController.text.isNotEmpty) {
        final combinedBarcode = "${partOneController.text}.${partTwoController.text}";
        barcodeController.text = combinedBarcode; // Wichtig: Den kombinierten Wert speichern
        _searchProduct(combinedBarcode);
      } else {
        AppToast.show(message: "Bitte beide Teile der Artikelnummer eingeben", height: h);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preis / Bestand bearbeiten',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F4A29),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Artikelnummer eingeben',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gib die Artikelnummer im Format IIPP.HHQQ ein',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120, // Kleinere Breite für die Eingabefelder
                        child: TextFormField(
                          controller: partOneController,
                          decoration: InputDecoration(
                            labelText: 'IIPP',

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            fillColor: Colors.grey[50],
                            filled: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4), // Beschränkt auf 4 Zeichen
                          ],
                          onChanged: (value) {
                            // Automatisch zum nächsten Feld wechseln, wenn 4 Ziffern eingegeben wurden
                            if (value.length == 4) {
                              FocusScope.of(context).nextFocus();
                            }
                          },
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '.',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F4A29),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120, // Kleinere Breite für die Eingabefelder
                        child: TextFormField(
                          controller: partTwoController,
                          decoration: InputDecoration(
                            labelText: 'HHQQ',

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            fillColor: Colors.grey[50],
                            filled: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4), // Beschränkt auf 4 Zeichen
                          ],
                          onEditingComplete: combineAndSearch, // Bei Enter direkt suchen
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: combineAndSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4A29),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: getAdaptiveIcon(
                          iconName: 'search',
                          defaultIcon: Icons.search,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 300, // Begrenze die Breite auf einen vernünftigeren Wert
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showProductSearchDialog();
                          },
                          icon: getAdaptiveIcon(
                            iconName: 'inventory',
                            defaultIcon: Icons.inventory,
                            color: Colors.white,
                          ),
                          label: const Text('Produktliste durchsuchen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4A29),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4A29).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0F4A29).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'info',
                          defaultIcon: Icons.info,
                          color: const Color(0xFF0F4A29),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Hier kannst du vorhandene Produkte bearbeiten. Gib die Artikelnummer im Format IIPP.HHQQ ein oder verwende die Produktliste, um ein Produkt auszuwählen.',
                            style: TextStyle(
                              color: const Color(0xFF0F4A29),
                            ),
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
    );
  }







  void _showProductSearchDialog() {

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                // Drag Handle oben
                Container(
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Titel mit Schließen-Button
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      getAdaptiveIcon(iconName: 'warehouse', defaultIcon: Icons.warehouse,),

                      SizedBox(width: 12),
                      Text(
                        'Verkaufsliste',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryAppColor,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon:   getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),

                // Hauptinhalt
                Expanded(
                  child: WarehouseScreen(
                    mode: 'lookup',
                    isDialog: true,
                    onBarcodeSelected: (barcode) async {
                      print("trest");
                      Navigator.pop(context);
                      _searchProduct(barcode);
                      //await _fetchProductData(barcode);
                    },
                    key: UniqueKey(),
                  ),
                ),


              ],
            ),
          );
        },
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
              isProduction: false,
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
                    icon:  getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add,),
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
                                        icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete,),
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
                            child: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search,),

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
                            child: getAdaptiveIcon(iconName: 'keyboard', defaultIcon: Icons.keyboard,),

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