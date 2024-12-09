// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
//
// class StockEntryScreen extends StatefulWidget {
//   const StockEntryScreen({Key? key}) : super(key: key);
//
//   @override
//   StockEntryScreenState createState() => StockEntryScreenState();
// }
//
// class StockEntryScreenState extends State<StockEntryScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _barcodeController = TextEditingController();
//   final _quantityController = TextEditingController();
//   Map<String, dynamic>? _scannedProduct;
//
//   @override
//   void dispose() {
//     _barcodeController.dispose();
//     _quantityController.dispose();
//     super.dispose();
//   }
//
//   Future<void> scanBarcode() async {
//     try {
//       String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
//         '#ff6666', // Scan line color
//         'Abbrechen', // Cancel button text
//         true, // Show flash icon
//         ScanMode.BARCODE,
//       );
//
//       // FlutterBarcodeScanner returns "-1" when scanning is cancelled
//       if (barcodeResult != '-1') {
//         setState(() {
//           _barcodeController.text = barcodeResult;
//         });
//         await _searchProduct();
//       }
//     } on PlatformException {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Fehler beim Scannen'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<void> _searchProduct() async {
//     if (_barcodeController.text.isEmpty) return;
//
//     try {
//       final doc = await FirebaseFirestore.instance
//           .collection('products')
//           .doc(_barcodeController.text)
//           .get();
//
//       setState(() {
//         if (doc.exists) {
//           _scannedProduct = doc.data();
//         } else {
//           _scannedProduct = null;
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Produkt nicht gefunden'),
//               backgroundColor: Colors.orange,
//             ),
//           );
//         }
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Fehler beim Suchen: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<void> _updateStock() async {
//     if (_formKey.currentState?.validate() != true || _scannedProduct == null) return;
//
//     try {
//       final increment = int.parse(_quantityController.text);
//       final currentQuantity = _scannedProduct?['quantity'] ?? 0;
//
//       await FirebaseFirestore.instance
//           .collection('products')
//           .doc(_barcodeController.text)
//           .update({
//         'quantity': currentQuantity + increment,
//         'last_stock_entry': FieldValue.serverTimestamp(),
//         'last_stock_change': increment,
//       });
//
//       // Log the stock entry
//       await FirebaseFirestore.instance
//           .collection('stock_entries')
//           .add({
//         'product_id': _barcodeController.text,
//         'product_name': _scannedProduct?['product'],
//         'quantity_change': increment,
//         'timestamp': FieldValue.serverTimestamp(),
//         'type': 'entry',
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Bestand erfolgreich aktualisiert'),
//           backgroundColor: Colors.green,
//         ),
//       );
//
//       // Reset form
//       setState(() {
//         _scannedProduct = null;
//         _barcodeController.clear();
//         _quantityController.clear();
//       });
//
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Fehler beim Aktualisieren: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Bestandszugang buchen'),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Barcode Scanner Card
//               Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Produkt Scanner',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: TextFormField(
//                               controller: _barcodeController,
//                               decoration: const InputDecoration(
//                                 labelText: 'Barcode',
//                                 border: OutlineInputBorder(),
//                               ),
//                               validator: (value) {
//                                 if (value == null || value.isEmpty) {
//                                   return 'Bitte Barcode eingeben oder scannen';
//                                 }
//                                 return null;
//                               },
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           ElevatedButton.icon(
//                             onPressed: scanBarcode,
//                             icon: const Icon(Icons.qr_code_scanner),
//                             label: const Text('Scannen'),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       if (_barcodeController.text.isNotEmpty)
//                         ElevatedButton(
//                           onPressed: _searchProduct,
//                           child: const Text('Produkt suchen'),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//
//               // Product Info
//               if (_scannedProduct != null) ...[
//                 Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Produktinformationen',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         Text('Produkt: ${_scannedProduct?['product'] ?? 'N/A'}'),
//                         Text('Instrument: ${_scannedProduct?['instrument'] ?? 'N/A'}'),
//                         Text('Holzart: ${_scannedProduct?['wood_type'] ?? 'N/A'}'),
//                         Text('Qualität: ${_scannedProduct?['quality'] ?? 'N/A'}'),
//                         Text('Aktueller Bestand: ${_scannedProduct?['quantity'] ?? 0}'),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//
//                 // Quantity Input
//                 Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Zugangsmenge',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         TextFormField(
//                           controller: _quantityController,
//                           decoration: const InputDecoration(
//                             labelText: 'Menge',
//                             border: OutlineInputBorder(),
//                             helperText: 'Positive Zahl für Zugang eingeben',
//                           ),
//                           keyboardType: TextInputType.number,
//                           inputFormatters: [
//                             FilteringTextInputFormatter.digitsOnly
//                           ],
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return 'Bitte Menge eingeben';
//                             }
//                             if (int.tryParse(value) == null || int.parse(value) <= 0) {
//                               return 'Bitte gültige positive Zahl eingeben';
//                             }
//                             return null;
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//
//                 // Submit Button
//                 SizedBox(
//                   width: double.infinity,
//                   height: 50,
//                   child: ElevatedButton(
//                     onPressed: _updateStock,
//                     child: const Text('Bestand aktualisieren'),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StockEntryScreen extends StatefulWidget {
  const StockEntryScreen({Key? key}) : super(key: key);

  @override
  StockEntryScreenState createState() => StockEntryScreenState();
}

class StockEntryScreenState extends State<StockEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _quantityController = TextEditingController();
  Map<String, dynamic>? _scannedProduct;
  List<FlSpot> _stockTrendPoints = [];
  double _maxY = 0;

  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadStockTrend() async {
    if (_scannedProduct == null) return;

    try {
      final entries = await FirebaseFirestore.instance
          .collection('stock_entries')
          .where('product_id', isEqualTo: _barcodeController.text)
          .orderBy('timestamp', descending: false)
          .limit(30)
          .get();

      double runningTotal = 0;
      List<FlSpot> points = [];

      for (int i = 0; i < entries.docs.length; i++) {
        final entry = entries.docs[i].data();
        runningTotal += (entry['quantity_change'] as num).toDouble();
        points.add(FlSpot(i.toDouble(), runningTotal));
        if (runningTotal > _maxY) _maxY = runningTotal;
      }

      setState(() {
        _stockTrendPoints = points;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden der Bestandshistorie: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> scanBarcode() async {
    try {
      String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Abbrechen',
        true,
        ScanMode.BARCODE,
      );

      if (barcodeResult != '-1') {
        setState(() {
          _barcodeController.text = barcodeResult;
        });
        await _searchProduct();
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

  Future<void> _searchProduct() async {
    if (_barcodeController.text.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(_barcodeController.text)
          .get();

      setState(() {
        if (doc.exists) {
          _scannedProduct = doc.data();
          _loadStockTrend(); // Load stock trend when product is found
        } else {
          _scannedProduct = null;
          _stockTrendPoints = [];
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkt nicht gefunden'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Suchen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateStock() async {
    if (_formKey.currentState?.validate() != true || _scannedProduct == null) return;

    try {
      final increment = int.parse(_quantityController.text);
      final currentQuantity = _scannedProduct?['quantity'] ?? 0;

      await FirebaseFirestore.instance
          .collection('products')
          .doc(_barcodeController.text)
          .update({
        'quantity': currentQuantity + increment,
        'last_stock_entry': FieldValue.serverTimestamp(),
        'last_stock_change': increment,
      });

      await FirebaseFirestore.instance
          .collection('stock_entries')
          .add({
        'product_id': _barcodeController.text,
        'product_name': _scannedProduct?['product'],
        'quantity_change': increment,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'entry',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bestand erfolgreich aktualisiert'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload product and trend data
      await _searchProduct();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Aktualisieren: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStockTrendChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: (_stockTrendPoints.length - 1).toDouble(),
          minY: 0,
          maxY: _maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: _stockTrendPoints,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bestandszugang buchen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Produkt Scanner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Barcode',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Bitte Barcode eingeben oder scannen';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: scanBarcode,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scannen'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_barcodeController.text.isNotEmpty)
                        ElevatedButton(
                          onPressed: _searchProduct,
                          child: const Text('Produkt suchen'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_scannedProduct != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Produktinformationen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Produkt: ${_scannedProduct?['product'] ?? 'N/A'}'),
                        Text('Instrument: ${_scannedProduct?['instrument'] ?? 'N/A'}'),
                        Text('Holzart: ${_scannedProduct?['wood_type'] ?? 'N/A'}'),
                        Text('Qualität: ${_scannedProduct?['quality'] ?? 'N/A'}'),
                        Text('Aktueller Bestand: ${_scannedProduct?['quantity'] ?? 0}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stock Trend Chart
                if (_stockTrendPoints.isNotEmpty)
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Bestandsverlauf',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStockTrendChart(),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zugangsmenge',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Menge',
                            border: OutlineInputBorder(),
                            helperText: 'Positive Zahl für Zugang eingeben',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Bitte Menge eingeben';
                            }
                            if (int.tryParse(value) == null || int.parse(value) <= 0) {
                              return 'Bitte gültige positive Zahl eingeben';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _updateStock,
                    child: const Text('Bestand aktualisieren'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}