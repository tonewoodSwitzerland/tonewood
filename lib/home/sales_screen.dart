import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  SalesScreenState createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen> {
  final List<Map<String, dynamic>> cartItems = [];
  bool isLoading = false;
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  Map<String, dynamic>? selectedProduct;

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
        // Linke Seite - Produkteingabe
        Container(
          width: 400,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produkt hinzufügen',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        border: OutlineInputBorder(),
                        helperText: 'Geben Sie den Barcode des Produkts ein',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onFieldSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _fetchProductAndShowQuantityDialog(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (barcodeController.text.isNotEmpty) {
                          _fetchProductAndShowQuantityDialog(barcodeController.text);
                        }
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Produkt suchen'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedProduct != null) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedProduct!['product'] ?? 'Unbekanntes Produkt',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Verfügbar: ${selectedProduct!['quantity'] ?? 0} Stück'),
                      Text('Preis: ${selectedProduct!['price_CHF']?.toStringAsFixed(2) ?? '0.00'} CHF'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Menge',
                          border: OutlineInputBorder(),
                          helperText: 'Anzahl eingeben',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (quantityController.text.isNotEmpty) {
                            final quantity = int.parse(quantityController.text);
                            if (quantity <= (selectedProduct!['quantity'] ?? 0)) {
                              setState(() {
                                cartItems.add({
                                  ...selectedProduct!,
                                  'barcode': barcodeController.text,
                                  'sale_quantity': quantity,
                                });
                                selectedProduct = null;
                                barcodeController.clear();
                                quantityController.clear();
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nicht genügend Bestand verfügbar'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Zum Warenkorb hinzufügen'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (cartItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: cartItems.isEmpty || isLoading ? null : _processTransaction,
                    icon: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.check),
                    label: const Text('Verkauf abschließen'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Rechte Seite - Warenkorb
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Warenkorb',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (cartItems.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Keine Produkte im Warenkorb'),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item['product'] ?? 'N/A'),
                          subtitle: Text('Barcode: ${item['barcode']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${item['sale_quantity']} Stück'),
                                  Text(
                                    '${(item['sale_quantity'] * (item['price_CHF'] ?? 0)).toStringAsFixed(2)} CHF',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    cartItems.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (cartItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total: ${cartItems.fold<double>(0.0, (sum, item) =>
                              sum + (item['sale_quantity'] as int) * (item['price_CHF'] ?? 0)
                              ).toStringAsFixed(2)} CHF',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${cartItems.fold<int>(0, (sum, item) => sum + (item['sale_quantity'] as int))} Artikel',
                              style: const TextStyle(
                                color: Colors.grey,
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
        ),
      ],
    );
  }
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Action Buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _scanProduct,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Produkt scannen'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
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
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Abbrechen'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (barcodeController.text.isNotEmpty) {
                                  Navigator.pop(context);
                                  _fetchProductAndShowQuantityDialog(barcodeController.text);
                                }
                              },
                              child: const Text('Suchen'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Manuell eingeben'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildCartList(),
        ),
        if (cartItems.isNotEmpty)
          _buildCheckoutBar(),
      ],
    );
  }

  // Hilfsmethoden für das Mobile-Layout
  Widget _buildCartList() {
    return cartItems.isEmpty
        ? const Center(child: Text('Keine Produkte im Warenkorb'))
        : ListView.builder(
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        final item = cartItems[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(item['product'] ?? 'N/A'),
            subtitle: Text('Barcode: ${item['barcode']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${item['sale_quantity']} Stück'),
                    Text(
                      '${(item['sale_quantity'] * (item['price_CHF'] ?? 0)).toStringAsFixed(2)} CHF',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => cartItems.removeAt(index)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total: ${cartItems.fold<double>(0.0, (sum, item) => sum + (item['sale_quantity'] as int) * (item['price_CHF'] ?? 0)).toStringAsFixed(2)} CHF',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${cartItems.fold<int>(0, (sum, item) => sum + (item['sale_quantity'] as int))} Artikel',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _processTransaction,
              icon: isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.check),
              label: const Text('Verkauf abschließen'),
            ),
          ],
        ),
      ),
    );
  }

  // Backend Methoden
  Future<void> _fetchProductAndShowQuantityDialog(String barcode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(barcode)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          selectedProduct = doc.data() as Map<String, dynamic>;
        });
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
          content: Text('Fehler beim Laden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanProduct() async {
    try {
      String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
        '#FF0000',
        'Abbrechen',
        true,
        ScanMode.BARCODE,
      );

      if (barcodeResult != '-1') {
        await _fetchProductAndShowQuantityDialog(barcodeResult);
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

  Future<void> _processTransaction() async {
    setState(() => isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var item in cartItems) {
        final docRef = FirebaseFirestore.instance
            .collection('products')
            .doc(item['barcode']);

        batch.update(docRef, {
          'quantity': FieldValue.increment(-item['sale_quantity']),
          'last_stock_change': -item['sale_quantity'],
          'last_stock_entry': FieldValue.serverTimestamp(),
        });

        final logRef = FirebaseFirestore.instance.collection('stock_entries').doc();
        batch.set(logRef, {
          'product_id': item['barcode'],
          'product_name': item['product'],
          'quantity_change': -item['sale_quantity'],
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'sale',
        });
      }

      await batch.commit();

      final receipt = await FirebaseFirestore.instance
          .collection('sales_receipts')
          .add({
        'items': cartItems.map((item) => {
          'product_id': item['barcode'],
          'product_name': item['product'],
          'quantity': item['sale_quantity'],
          'price_per_unit': item['price_CHF'],
          'total_price': item['sale_quantity'] * (item['price_CHF'] ?? 0),
        }).toList(),
        'total_amount': cartItems.fold(
          0.0,
              (sum, item) => sum + (item['sale_quantity'] * (item['price_CHF'] ?? 0)),
        ),
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        cartItems.clear();
        selectedProduct = null;
        isLoading = false;
        barcodeController.clear();
        quantityController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verkauf erfolgreich abgeschlossen'),
            action: SnackBarAction(
              label: 'Lieferschein',
              onPressed: () => _printReceipt(receipt.id),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Verarbeiten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _printReceipt(String receiptId) {
    // TODO: Implement receipt printing
    print('Printing receipt: $receiptId');
  }

  @override
  void dispose() {
    barcodeController.dispose();
    quantityController.dispose();
    super.dispose();
  }
}