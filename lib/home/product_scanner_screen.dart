import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  ScannerScreenState createState() => ScannerScreenState();
}

class ScannerScreenState extends State<ScannerScreen> {
  Map<String, dynamic>? scannedProduct;
  String lastScannedBarcode = '';
  bool isLoading = false;

  Future<void> _startScanner() async {
    setState(() {
      isLoading = true;
      scannedProduct = null;
      lastScannedBarcode = '';
    });

    try {
      String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
        '#FF0000',
        'Abbrechen',
        true,
        ScanMode.BARCODE,
      );

      if (barcodeResult != '-1') {
        lastScannedBarcode = barcodeResult;
        await _fetchProductData(barcodeResult);
      }
    } on PlatformException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Scannen'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchProductData(String barcode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(barcode)
          .get();

      setState(() {
        if (doc.exists) {
          scannedProduct = doc.data();
        } else {
          scannedProduct = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden der Daten: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isLoading && scannedProduct == null && lastScannedBarcode.isEmpty)
            // Initial scan button
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _startScanner,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(24),
                          shape: const CircleBorder(),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tippe hier, um den Scanner zu starten.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else if (isLoading)
            // Loading indicator
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (scannedProduct != null)
              // Product info
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.qr_code),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Barcode: $lastScannedBarcode',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                _buildInfoRow('Produkt', scannedProduct!['product']),
                                _buildInfoRow('Instrument', scannedProduct!['instrument']),
                                _buildInfoRow('Bauteil', scannedProduct!['part']),
                                _buildInfoRow('Holzart', scannedProduct!['wood_type']),
                                _buildInfoRow('Größe', scannedProduct!['size']),
                                _buildInfoRow('Qualität', scannedProduct!['quality']),
                                _buildInfoRow('Bestand', scannedProduct!['quantity']?.toString() ?? '0'),
                                _buildInfoRow('Preis CHF', '${scannedProduct!['price_CHF']} CHF'),
                                const Divider(),
                                _buildBooleanRow('Thermobehandelt', scannedProduct!['thermally_treated'] ?? false),
                                _buildBooleanRow('Haselfichte', scannedProduct!['haselfichte'] ?? false),
                                _buildBooleanRow('Mondholz', scannedProduct!['moonwood'] ?? false),
                                _buildBooleanRow('FSC 100%', scannedProduct!['FSC_100'] ?? false),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _startScanner,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Neuen Scan starten'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (lastScannedBarcode.isNotEmpty)
                // Product not found
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Produkt mit Barcode\n$lastScannedBarcode\nnicht gefunden',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _startScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Neuen Scan starten'),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(value ? 'Ja' : 'Nein'),
        ],
      ),
    );
  }
}