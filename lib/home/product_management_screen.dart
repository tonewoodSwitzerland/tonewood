import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';
import 'stock_entry_screen.dart';
import 'add_product_screen.dart';

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
  Future<void> _scanAndUpdateStock() async {
    try {
      String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Abbrechen',
        true,
        ScanMode.BARCODE,
      );

      if (barcodeResult != '-1') {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(barcodeResult)
            .get();

        if (!mounted) return;

        if (doc.exists) {
          _showQuantityDialog(barcodeResult, doc.data() as Map<String, dynamic>);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkt nicht gefunden'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Scannen'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanAndEditProduct() async {
    try {
      String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Abbrechen',
        true,
        ScanMode.BARCODE,
      );

      if (barcodeResult != '-1') {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(barcodeResult)
            .get();

        if (!mounted) return;

        if (doc.exists) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddProductScreen(
                editMode: true,
                barcode: barcodeResult,


              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkt nicht gefunden'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Scannen'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  void _showEditBarcodeInputDialog() {
    barcodeController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Produkt bearbeiten'),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                        _checkProductAndEdit(barcodeController.text);
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

      if (barcodeResult != '-1') {
        _checkProductAndEdit(barcodeResult);
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Scannen'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkProductAndEdit(String barcode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(barcode)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProductScreen(
              editMode: true,
              barcode: barcode,

              key: UniqueKey(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produkt nicht gefunden'),
            backgroundColor: Colors.orange,
          ),
        );
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

  void _showBarcodeInputDialog() {
    barcodeController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Barcode eingeben'),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
        _checkProductAndShowQuantity(barcodeResult);
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Scannen'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkProductAndShowQuantity(String barcode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(barcode)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        _showQuantityDialog(barcode, doc.data() as Map<String, dynamic>);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produkt nicht gefunden'),
            backgroundColor: Colors.orange,
          ),
        );
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




  void _showQuantityDialog(String barcode, Map<String, dynamic> productData) {
    quantityController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Wareneingang buchen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Produkt: ${productData['product'] ?? 'N/A'}'),
              Text('Aktueller Bestand: ${productData['quantity'] ?? 0}'),
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
                  final increment = int.parse(quantityController.text);
                  final currentQuantity = productData['quantity'] ?? 0;

                  await FirebaseFirestore.instance
                      .collection('products')
                      .doc(barcode)
                      .update({
                    'quantity': currentQuantity + increment,
                    'last_stock_entry': FieldValue.serverTimestamp(),
                    'last_stock_change': increment,
                  });

                  await FirebaseFirestore.instance
                      .collection('stock_entries')
                      .add({
                    'product_id': barcode,
                    'product_name': productData['product'],
                    'quantity_change': increment,
                    'timestamp': FieldValue.serverTimestamp(),
                    'type': 'entry',
                  });

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bestand aktualisiert auf ${currentQuantity + increment}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  String selectedAction = ''; // Speichert die aktuelle Aktion (Wareneingang, Bearbeiten, etc.)

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;

    return Scaffold(
      body: isDesktopLayout ? _buildDesktopLayout() : _buildMobileLayout(),
    );
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
                      title: 'Wareneingang buchen',
                      subtitle: 'Neue Ware dem Bestand hinzufügen',
                      onTap: () => setState(() => selectedAction = 'wareneingang'),
                      isSelected: selectedAction == 'wareneingang',
                    ),
                    _buildActionButton(
                      icon: Icons.edit,
                      title: 'Produkt bearbeiten',
                      subtitle: 'Produktdaten ändern',
                      onTap: () => setState(() => selectedAction = 'bearbeiten'),
                      isSelected: selectedAction == 'bearbeiten',
                    ),
                    _buildActionButton(
                      icon: Icons.add_circle_outline,
                      title: 'Neues Produkt',
                      subtitle: 'Produkt erstellen',
                      onTap: () => setState(() => selectedAction = 'neu'),  // Geändert
                      isSelected: selectedAction == 'neu',
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
      default:
        return const Center(
          child: Text('Bitte wählen Sie eine Aktion aus'),
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
            'Wareneingang buchen',
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
                      helperText: 'Geben Sie den Barcode des Produkts ein',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

  Widget _buildBearbeitenPanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(  // Kein Container oder SingleChildScrollView mehr auf dieser Ebene
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produkt bearbeiten',
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
                      helperText: 'Geben Sie den Barcode des zu bearbeitenden Produkts ein',
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
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(barcode)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          selectedProduct = doc.data() as Map<String, dynamic>;
          selectedBarcode = barcode;
        });
      } else {
        setState(() {
          selectedProduct = null;
          selectedBarcode = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produkt nicht gefunden'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        selectedProduct = null;
        selectedBarcode = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Suche: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Optional: Eine spezifische Methode für die Bearbeitung
  Future<void> _searchProductForEdit(String barcode) async {
    await _searchProduct(barcode);
    if (selectedProduct != null) {
      // Hier könnten noch spezifische Vorbereitungen für die Bearbeitung stattfinden
    }
  }
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stock Entry Card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.add_shopping_cart, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Wareneingang buchen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Wähle eine Eingabemethode',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _scanBarcode(),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scanner'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showBarcodeInputDialog,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.keyboard),
                          label: const Text('Manuell'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Edit Product Card
            Card(
              margin: const EdgeInsets.all(16),
              child: InkWell(
                onTap: _showEditBarcodeInputDialog,
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.edit, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Produkt bearbeiten',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Geben einen Barcode ein oder nutze den Scanner',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // New Product Card
            Card(
              margin: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddProductScreen(editMode: false),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.add_circle_outline, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Neues Produkt anlegen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Erfasse ein neues Produkt',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Behalten Sie alle existierenden Dialog- und Scanner-Methoden bei
  // (_showQuantityDialog, _scanBarcode, etc.)

  @override
  void dispose() {
    quantityController.dispose();
    barcodeController.dispose();
    super.dispose();
  }
}