import 'package:permission_handler/permission_handler.dart';
import 'package:tonewood/home/production_screen.dart';
import 'dart:math';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:another_brother/printer_info.dart';

import 'package:another_brother/label_info.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:tonewood/home/warehouse_screen.dart';
import '../components/product_cart.dart';
import '../constants.dart';
import '../services/print_status.dart';
import '../services/printer_service.dart';
enum BarcodeType {
  sales,
  production,
}
enum PrinterModel {
  QL1110NWB,
  QL820NWB,
}

class PrinterConnectionType {
  static const none = 'none';
  static const wifi = 'wifi';
  static const bluetooth = 'bluetooth';
}

// Label-Klasse zur besseren Strukturierung der Label-Daten
class LabelType {
  final String id;
  final String name;
  final String description;
  final double width;
  final double height;
  final String possible_size;

  LabelType({
    required this.id,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.possible_size,
  });
}
class PrinterScreen extends StatefulWidget {
  const PrinterScreen({Key? key}) : super(key: key);

  @override
  PrinterScreenState createState() => PrinterScreenState();
}

class PrinterScreenState extends State<PrinterScreen> {
  String _activeConnectionType = PrinterConnectionType.none;
  bool _includeBatchNumber = false;
  String? _printerDetails;
  PrinterModel selectedPrinterModel = PrinterModel.QL1110NWB;
  int printQuantity = 1;
  late List<LabelType> labelTypes;
  final TextEditingController barcodeController = TextEditingController();
  Printer? _selectedPrinter;
  BarcodeType selectedBarcodeType = BarcodeType.sales;
  bool _isPrinterOnline = false;
  bool _printerSearching = false;
  Color _indicatorColor = Colors.orange;
  String barcodeData = '';
  Map<String, dynamic>? productData;
  pw.Font? _customFont;
  @override
  void initState() {
    super.initState();
    _checkPrinterStatus();
    _loadLastSettings();
    labelTypes = _getBaseLabels();
    _loadLastSettings().then((_) {_updateLabelTypes();});

  }

  void showPrinterSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('general_data')
                  .doc('office')
                  .snapshots(),
              builder: (context, snapshot) {
                bool bluetoothFirst = snapshot.hasData
                    ? (snapshot.data?.data()?['bluetoothFirst'] ?? true)
                    : true;
                double defaultWidth = snapshot.hasData
                    ? (snapshot.data?.data()?['defaultLabelWidth']?.toDouble() ?? 62.0)
                    : 62.0;

                return AlertDialog(
                  backgroundColor: Colors.white,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4A29).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.print,
                          color: Color(0xFF0F4A29),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Drucker-Einstellungen'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verbindungsart
                      const Text(
                        'Bevorzugte Verbindung',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildConnectionOption(
                              icon: Icons.bluetooth,
                              label: 'Bluetooth',
                              isSelected: bluetoothFirst,
                              onTap: () {
                                FirebaseFirestore.instance
                                    .collection('general_data')
                                    .doc('office')
                                    .set({'bluetoothFirst': true}, SetOptions(merge: true));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildConnectionOption(
                              icon: Icons.wifi,
                              label: 'WLAN',
                              isSelected: !bluetoothFirst,
                              onTap: () {
                                FirebaseFirestore.instance
                                    .collection('general_data')
                                    .doc('office')
                                    .set({'bluetoothFirst': false}, SetOptions(merge: true));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Papierformat
                      const Text(
                        'Standard-Papierformat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildLabelOption(
                              width: 62,
                              isSelected: defaultWidth == 62,
                              onTap: () => _updateDefaultLabel(62),
                            ),
                            const SizedBox(width: 8),
                            _buildLabelOption(
                              width: 54,
                              isSelected: defaultWidth == 54,
                              onTap: () => _updateDefaultLabel(54),
                            ),
                            const SizedBox(width: 8),
                            _buildLabelOption(
                              width: 50,
                              isSelected: defaultWidth == 50,
                              onTap: () => _updateDefaultLabel(50),
                            ),
                            const SizedBox(width: 8),
                            _buildLabelOption(
                              width: 38,
                              isSelected: defaultWidth == 38,
                              onTap: () => _updateDefaultLabel(38),
                            ),
                            const SizedBox(width: 8),
                            _buildLabelOption(
                              width: 29,
                              isSelected: defaultWidth == 29,
                              onTap: () => _updateDefaultLabel(29),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Schließen'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLabelOption({
    required double width,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F4A29).withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '${width.toInt()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'mm',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateDefaultLabel(double width) {
    FirebaseFirestore.instance
        .collection('general_data')
        .doc('office')
        .set({
      'defaultLabelWidth': width,
    }, SetOptions(merge: true));
  }
  Widget _buildConnectionOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F4A29).withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  List<LabelType> _getBaseLabels() {
    return [
      LabelType(
        id: 'DK-22205',
        name: 'Endlospapier - DK-22205 - 62mm',
        description: '62mm x 30.48m',
        width: 62,
        height: 30480,
        possible_size: 'medium',
      ),
      LabelType(
        id: 'DK-N55224',
        name: 'Endlospapier - DK-N55224 - 54mm',
        description: '54mm x 30.48m',
        width: 54,
        height: 30480,
        possible_size: 'medium',
      ),
      LabelType(
        id: 'DK-22223',
        name: 'Endlospapier - DK-22223 - 50mm',
        description: '50mm x 30.48m',
        width: 50,
        height: 30480,
        possible_size: 'medium',
      ),
      LabelType(
        id: 'DK-22225',
        name: 'Endlospapier - DK-22225 - 38mm',
        description: '38mm x 30.48m',
        width: 38,
        height: 30480,
        possible_size: 'small',
      ),
      LabelType(
        id: 'DK-22210',
        name: 'Endlospapier - DK-22210 - 29mm',
        description: '29mm x 30.48m',
        width: 29,
        height: 30480,
        possible_size: 'small',
      ),
    ];
  }
  void _showProductSearchDialog() {
    if (selectedBarcodeType == BarcodeType.production) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductionScreen(
                  isDialog: true,
                  onProductSelected: (productId) async {
                    Navigator.pop(context);
                    await _handleProductionBarcode(productId);
                  },
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Verkaufsprodukte bleiben unverändert
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: WarehouseScreen(
                  isDialog: true,
                  onBarcodeSelected: (barcode) async {
                    Navigator.pop(context);
                    await _fetchProductData(barcode);
                  },
                  key: UniqueKey(),
                ),
              ),
            ),
          );
        },
      );
    }
  }
  Future<void> _savePrinterSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('printer')
          .set({
        'printerModel': selectedPrinterModel.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Fehler beim Speichern der Drucker-Einstellungen: $e');
    }
  }
  // Neue Methode zum Aktualisieren der verfügbaren Etiketten
  void _updateLabelTypes() {
    var updatedLabels = _getBaseLabels();

    // Füge das 103mm Label für QL-1110NWB hinzu
    if (selectedPrinterModel == PrinterModel.QL1110NWB) {
      updatedLabels.add(
        LabelType(
          id: 'DK-22246',
          name: 'Endlospapier - DK-22246 - 103mm',
          description: '103mm x 30.48m',
          width: 103,
          height: 30480,
          possible_size: 'big',
        ),
      );
    }

    setState(() {
      labelTypes = updatedLabels;
      // Wenn das aktuelle Label nicht mehr verfügbar ist, setze es zurück
      if (selectedLabel != null && !labelTypes.contains(selectedLabel)) {
        selectedLabel = null;
      }
    });
  }
// Modifiziere die Scan-Funktion
  Future<void> _startScanner() async {
    setState(() {
      _printerSearching = true;
      barcodeData = '';
    });

    try {
      String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
        '#FF0000',
        'Abbrechen',
        true,
        ScanMode.BARCODE,
      );

      if (barcodeResult != '-1') {
        if (selectedBarcodeType == BarcodeType.production) {
          await _handleProductionBarcode(barcodeResult);
        } else {
          await _fetchProductData(barcodeResult);
        }
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
        _printerSearching = false;
      });
    }
  }
  // Neue Funktion zum Laden der letzten Einstellungen
  Future<void> _loadLastSettings() async {
    try {
      // Lade Drucker-Einstellungen
      final printerDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('printer')
          .get();

      // Lade Office-Einstellungen (inkl. Standard-Format)
      final officeDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .get();

      if (printerDoc.exists || officeDoc.exists) {
        setState(() {
          // Lade den Drucker-Typ
          if (printerDoc.data()?['printerModel'] != null) {
            selectedPrinterModel = PrinterModel.values.firstWhere(
                  (model) => model.toString() == printerDoc.data()!['printerModel'],
              orElse: () => PrinterModel.QL1110NWB,
            );
            _updateLabelTypes();
          }

          // Lade das Standard-Papierformat aus office
          if (officeDoc.data()?['defaultLabelWidth'] != null) {
            double defaultWidth = officeDoc.data()!['defaultLabelWidth'].toDouble();
            selectedLabel = labelTypes.firstWhere(
                  (label) => label.width == defaultWidth,
              orElse: () => labelTypes.first,
            );
          }

          // Rest der Einstellungen wie bisher...
          if (printerDoc.data()?['lastBarcodeType'] != null) {
            selectedBarcodeType = BarcodeType.values.firstWhere(
                  (type) => type.toString() == printerDoc.data()!['lastBarcodeType'],
              orElse: () => BarcodeType.sales,
            );
          }

          if (selectedBarcodeType == BarcodeType.sales && printerDoc.data()?['lastSalesBarcode'] != null) {
            barcodeData = printerDoc.data()!['lastSalesBarcode'];
            _fetchProductData(barcodeData);
          } else if (selectedBarcodeType == BarcodeType.production && printerDoc.data()?['lastProductionBarcode'] != null) {
            barcodeData = printerDoc.data()!['lastProductionBarcode'];
            _fetchProductData(barcodeData);
          }
        });

        print('Geladene Einstellungen:');
        print('Barcode-Typ: ${selectedBarcodeType}');
        print('Standard Label-Breite: ${selectedLabel?.width}');
        print('Verkaufs-Barcode: ${printerDoc.data()?['lastSalesBarcode']}');
        print('Produktions-Barcode: ${printerDoc.data()?['lastProductionBarcode']}');
      }
    } catch (e) {
      print('Fehler beim Laden der Einstellungen: $e');
    }
  }

  // Neue Funktion zum Speichern der aktuellen Einstellungen
  Future<void> _saveCurrentSettings() async {
    print("Speichere Einstellungen...");
    try {
      // Bestimme welcher Barcode aktualisiert werden soll
      Map<String, dynamic> updateData = {
        'lastBarcodeType': selectedBarcodeType.toString(),
        'lastLabelWidth': selectedLabel?.width,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Füge den entsprechenden Barcode hinzu
      if (barcodeData.isNotEmpty && barcodeData != 'Produkt nicht gefunden') {
        if (selectedBarcodeType == BarcodeType.sales) {
          updateData['lastSalesBarcode'] = barcodeData;
        } else {
          updateData['lastProductionBarcode'] = barcodeData;
        }
      }

      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('printer')
          .set(updateData, SetOptions(merge: true));

      print('Gespeicherte Daten: $updateData');
    } catch (e) {
      print('Fehler beim Speichern der Einstellungen: $e');
    }
  }
  // Modifiziere die bestehenden Funktionen, um die Einstellungen zu speichern

  // Beim Ändern des Barcode-Typs
  void _onBarcodeTypeChanged(BarcodeType? value) {
    if (value != null) {
      setState(() {
        selectedBarcodeType = value;
        barcodeData = '';
        productData = null;
      });
      _saveCurrentSettings();
    }
  }

  // Beim Ändern des Labels
  void _onLabelSelected(LabelType? newValue) {
    setState(() {
      selectedLabel = newValue;
    });
    _saveCurrentSettings();
  }

  // Hilfsfunktion zum Extrahieren des Verkaufscodes
  String _extractSalesBarcode(String fullBarcode) {
    final parts = fullBarcode.split('.');
    if (parts.length >= 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return fullBarcode;
  }

  Future<void> _fetchProductData(String barcode) async {
    try {
      if (selectedBarcodeType == BarcodeType.sales) {
        // Extrahiere den Verkaufscode (xxxx.yyyy)
        final searchBarcode = _extractSalesBarcode(barcode);

        final doc = await FirebaseFirestore.instance
            .collection('inventory')
            .doc(searchBarcode)
            .get();

        setState(() {
          if (doc.exists) {
            barcodeData = doc.id;
            productData = doc.data();
            _saveCurrentSettings();
          } else {
            barcodeData = 'Produkt nicht gefunden';
            productData = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Produkt nicht gefunden: $searchBarcode'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      } else {
        await _handleProductionBarcode(barcode);
      }
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _handleProductionBarcode(String barcode) async {
    try {
      // Prüfe ob es ein Verkaufscode ist (nur zwei Teile)
      final parts = barcode.split('.');

      // Suche nach Produktionscodes basierend auf dem gescannten Code
      final QuerySnapshot productionDocs;
      if (parts.length == 2) {
        // Es wurde ein Verkaufscode gescannt
        productionDocs = await FirebaseFirestore.instance
            .collection('production')
            .where('barcode', isGreaterThanOrEqualTo: barcode)
            .where('barcode', isLessThan: barcode + '\uf8ff')
            .get();
      } else {
        // Es wurde ein Produktionscode gescannt
        final baseBarcode = parts.length >= 4 ? parts.sublist(0, 4).join('.') : barcode;
        productionDocs = await FirebaseFirestore.instance
            .collection('production')
            .where(FieldPath.documentId, isEqualTo: baseBarcode)
            .get();
      }

      if (productionDocs.docs.isEmpty) {
        setState(() {
          barcodeData = 'Produkt nicht gefunden';
          productData = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produkt nicht gefunden'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Wenn mehrere Produktionscodes gefunden wurden oder Chargen gewünscht sind
      if ((productionDocs.docs.length > 1 || _includeBatchNumber) && parts.length < 5) {
        // Zeige Dialog zur Auswahl des Produktionscodes und der Charge
        final result = await showDialog<Map<String, String>>(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2, color: primaryAppColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Produktion auswählen',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (parts.length == 2)
                                  Text(
                                    'Verkaufscode: $barcode',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: productionDocs.docs.length,
                        itemBuilder: (context, index) {
                          final productionDoc = productionDocs.docs[index];
                          final productionData = productionDoc.data() as Map<String, dynamic>;

                          return FutureBuilder<QuerySnapshot>(
                            future: _includeBatchNumber
                                ? FirebaseFirestore.instance
                                .collection('production')
                                .doc(productionDoc.id)
                                .collection('batch')
                                .orderBy('batch_number', descending: true)
                                .get()
                                : null,
                            builder: (context, AsyncSnapshot<QuerySnapshot?> snapshot) {
                              if (_includeBatchNumber && snapshot.connectionState == ConnectionState.waiting) {
                                return Card(
                                  child: ListTile(
                                    title: Text('Lade Chargen...'),
                                    leading: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              return Card(
                                child: _includeBatchNumber
                                    ? ExpansionTile(
                                  title: Text(productionDoc.id),
                                  subtitle: Text(productionData['product_name']?.toString() ?? ''),
                                  leading: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryAppColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.inventory,
                                      color: primaryAppColor,
                                    ),
                                  ),
                                  children: [
                                    if (snapshot.hasData)
                                      ...snapshot.data!.docs.map((batchDoc) {
                                        final batchData = batchDoc.data() as Map<String, dynamic>;
                                        final batchNumber = batchData['batch_number'];
                                        final formattedBatchNumber = batchNumber.toString().padLeft(4, '0');
                                        final quantity = batchData['quantity']?.toString() ?? '';
                                        final createdAt = batchData['created_at'] as Timestamp?;

                                        return ListTile(
                                          leading: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: primaryAppColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              formattedBatchNumber,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: primaryAppColor,
                                              ),
                                            ),
                                          ),
                                          title: Text('Charge $formattedBatchNumber'),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Menge: $quantity'),
                                              if (createdAt != null)
                                                Text('Datum: ${createdAt.toDate().toString().split(' ')[0]}'),
                                            ],
                                          ),
                                          onTap: () => Navigator.pop(context, {
                                            'productionCode': productionDoc.id,
                                            'batchNumber': formattedBatchNumber,
                                          }),
                                        );
                                      })
                                    else
                                      ListTile(
                                        title: Text('Keine Chargen verfügbar'),
                                      ),
                                  ],
                                )
                                    : ListTile(
                                  leading: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryAppColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.inventory,
                                      color: primaryAppColor,
                                    ),
                                  ),
                                  title: Text(productionDoc.id),
                                  subtitle: Text(productionData['product_name']?.toString() ?? ''),
                                  onTap: () => Navigator.pop(context, {
                                    'productionCode': productionDoc.id,
                                    'batchNumber': null,
                                  }),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Abbrechen'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        if (result != null) {
          final fullBarcode = _includeBatchNumber && result['batchNumber'] != null
              ? '${result['productionCode']}.${result['batchNumber']}'
              : result['productionCode']!;

          final doc = await FirebaseFirestore.instance
              .collection('production')
              .doc(result['productionCode'])
              .get();

          setState(() {
            barcodeData = fullBarcode;
            productData = doc.data() as Map<String, dynamic>?;
            _saveCurrentSettings();
          });
        }
      } else {
        // Direkter Code wurde gescannt
        final doc = productionDocs.docs.first;
        setState(() {
          barcodeData = doc.id;
          productData = doc.data() as Map<String, dynamic>?;
          _saveCurrentSettings();
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Produktionsdaten: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<bool> _tryConnection(Printer printer, PrinterInfo printInfo, Port port) async {
    if (!mounted) return false;

    try {
      // Für Bluetooth die Berechtigungen prüfen
      if (port == Port.BLUETOOTH) {
        if (Platform.isAndroid) {
          Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetooth,
            Permission.bluetoothConnect,
            Permission.bluetoothScan,
          ].request();

          // Prüfe ob alle Berechtigungen erteilt wurden
          bool allGranted = statuses.values.every((status) => status.isGranted);
          if (!allGranted) {
            print('Bluetooth-Berechtigungen nicht erteilt');
            return false;
          }
        }
      }

      printInfo.port = port;
      await printer.setPrinterInfo(printInfo);

      if (port == Port.BLUETOOTH) {
        List<BluetoothPrinter> printers =
        await printer.getBluetoothPrinters([printInfo.printerModel.getName()]);

        if (printers.isNotEmpty && mounted) {
          setState(() {
            _isPrinterOnline = true;
            _indicatorColor = primaryAppColor;
            _activeConnectionType = PrinterConnectionType.bluetooth;
            _printerDetails = '${printers.first.modelName} (${printers.first.macAddress})';
          });
          return true;
        }
      } else {
        List<NetPrinter> printers =
        await printer.getNetPrinters([printInfo.printerModel.getName()]);

        if (printers.isNotEmpty && mounted) {
          setState(() {
            _isPrinterOnline = true;
            _indicatorColor = primaryAppColor;
            _activeConnectionType = PrinterConnectionType.wifi;
            _printerDetails = '${printers.first.modelName} (${printers.first.nodeName})';
          });
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Verbindungsfehler für ${port.toString()}: $e');
      return false;
    }
  }
  Future<void> _checkPrinterStatus() async {
    if (!mounted) return;

    setState(() {
      _printerSearching = true;
      _activeConnectionType = PrinterConnectionType.none;
    });

    try {
      bool useBluetoothFirst = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .get()
          .then((doc) => doc.get('bluetoothFirst') ?? true);

      var printer = Printer();
      var printInfo = PrinterInfo();
      printInfo.printerModel = Model.QL_820NWB;

      // Erste Verbindungsmethode versuchen
      bool connected = await _tryConnection(
          printer,
          printInfo,
          useBluetoothFirst ? Port.BLUETOOTH : Port.NET
      );

      // Wenn erste Methode fehlschlägt, zweite versuchen
      if (!connected) {
        connected = await _tryConnection(
            printer,
            printInfo,
            useBluetoothFirst ? Port.NET : Port.BLUETOOTH
        );
      }

      if (!mounted) return;

      // Finaler Status-Update
      setState(() {
        _printerSearching = false;
        // Wenn keine Verbindung hergestellt wurde, setze Status auf "nicht verbunden"
        if (!connected) {
          _isPrinterOnline = false;
          _indicatorColor = Colors.red;
          _printerDetails = null;
          _activeConnectionType = PrinterConnectionType.none;
        }
      });

    } catch (e) {
      print('Fehler bei Druckersuche: $e');
      if (!mounted) return;
      setState(() {
        _isPrinterOnline = false;
        _indicatorColor = Colors.red;
        _printerDetails = null;
        _activeConnectionType = PrinterConnectionType.none;
        _printerSearching = false;
      });
    }
  }

  void _updatePrinterStatus(bool isOnline, String modelName, String identifier, String connectionType) {
    if (!mounted) return;
    setState(() {
      _isPrinterOnline = isOnline;
      _indicatorColor = isOnline ? primaryAppColor : Colors.red;
      _printerSearching = false;
      _printerDetails = isOnline ? '$modelName ($identifier)' : null;
      _activeConnectionType = connectionType;
      if (isOnline) {
        _savePrinterName(identifier);
      }
    });
  }

  Widget _buildConnectionIndicator() {
    if (_printerSearching) {
      return Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.all(8.0),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      );
    }

    IconData iconData;
    switch (_activeConnectionType) {
      case PrinterConnectionType.wifi:
        iconData = Icons.wifi;
        break;
      case PrinterConnectionType.bluetooth:
        iconData = Icons.bluetooth;
        break;
      default:
        iconData = Icons.print;
    }

    return Container(
      margin: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          Icon(
            iconData,
            color: _indicatorColor,
            size: 24,
          ),
          if (!_isPrinterOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Future<void> _savePrinterName(String nodeName) async {
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('printer')
          .set({
        'printerNodeName': nodeName,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Fehler beim Speichern des Druckernamens: $e');
    }
  }
  Future<void> printLabel(BuildContext context) async {
    if (!_isPrinterOnline || barcodeData.isEmpty || selectedLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drucker nicht bereit oder kein Barcode ausgewählt'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await PrintStatus.show(context, () async {
      try {
        PrinterService.onStatusUpdate = (status) {
          print(status);
        };

        var printer = Printer();
        var printInfo = PrinterInfo();
        printInfo.printerModel = Model.QL_820NWB;
        printInfo.printMode = PrintMode.FIT_TO_PAGE;
        printInfo.isAutoCut = true;
        printInfo.port = Port.NET;
        printInfo.printQuality = PrintQuality.HIGH_RESOLUTION;
        printInfo.numberOfCopies = printQuantity;

        print("sl:$selectedLabel");
        if (selectedLabel != null) {
          final labelMap = {
            62: QL1100.W62,
            54: QL1100.W54,
            50: QL1100.W50,
            38: QL1100.W38,
            29: QL1100.W29,
          };

          var labelType = labelMap[selectedLabel!.width.toInt()];
          if (labelType != null) {
            printInfo.labelNameIndex = QL1100.ordinalFromID(labelType.getId());
          }
        }

        await printer.setPrinterInfo(printInfo);

        PrinterService.updateStatus("Suche Drucker...");
        List<NetPrinter> printers = await printer.getNetPrinters([Model.QL_820NWB.getName()]);
        if (printers.isEmpty) {
          throw Exception('Drucker nicht gefunden');
        }

        PrinterService.updateStatus("Konfiguriere Drucker...");
        printInfo.ipAddress = printers[0].ipAddress;
        await printer.setPrinterInfo(printInfo);

        PrinterService.updateStatus("Generiere PDF...");
        final pdfFile = await _generatePdfForPrinter();

        PrinterService.updateStatus("Sende Daten an Drucker...");
        await printer.printPdfFile(pdfFile.path, 1);

        PrinterService.updateStatus("Druckvorgang abgeschlossen");

        await FirebaseFirestore.instance.collection('print_logs').add({
          'timestamp': FieldValue.serverTimestamp(),
          'barcode': barcodeData,
          'quantity': printQuantity,
          'labelWidth': selectedLabel?.width,
          'labelType': selectedLabel?.id,
          'barcodeType': selectedBarcodeType.toString(),
        });

      } catch (e) {
        print('Druckfehler: $e');
        throw e;
      }
    });
  }

  // Future<void> printLabel(BuildContext context) async {
  //   try {
  //     if (!_isPrinterOnline) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Drucker ist nicht verbunden'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     final pdfFile = await _generatePdfForPrinter();
  //
  //     var printer = Printer();
  //     var printInfo = PrinterInfo();
  //     printInfo.printerModel = selectedPrinterModel == PrinterModel.QL1110NWB
  //         ? Model.QL_1110NWB
  //         : Model.QL_820NWB;
  //     printInfo.printMode = PrintMode.FIT_TO_PAGE;
  //     printInfo.isAutoCut = true;
  //     printInfo.port = Port.NET;
  //     printInfo.printQuality = PrintQuality.HIGH_RESOLUTION;
  //     printInfo.numberOfCopies = printQuantity; // Setze die Anzahl hier
  //
  //     if (selectedLabel != null) {
  //       final labelMap = {
  //         62: QL1100.W62,
  //         54: QL1100.W54,
  //         50: QL1100.W50,
  //         38: QL1100.W38,
  //         29: QL1100.W29,
  //       };
  //
  //       var labelType = labelMap[selectedLabel!.width.toInt()];
  //       if (labelType != null) {
  //         printInfo.labelNameIndex = QL1100.ordinalFromID(labelType.getId());
  //       }
  //     }
  //
  //     await printer.setPrinterInfo(printInfo);
  //     List<NetPrinter> printers = await printer.getNetPrinters([printInfo.printerModel.getName()]);
  //
  //     if (printers.isEmpty) {
  //       throw Exception('Keine Drucker gefunden');
  //     }
  //
  //     printInfo.ipAddress = printers.first.ipAddress;
  //     await printer.setPrinterInfo(printInfo);
  //
  //     try {
  //       // Ändere den Druckaufruf - drucke nur einmal, aber mit der eingestellten Kopienanzahl
  //       await printer.printPdfFile(pdfFile.path, 1);
  //
  //       // Logging nach erfolgreichem Druck
  //       await FirebaseFirestore.instance.collection('print_logs').add({
  //         'timestamp': FieldValue.serverTimestamp(),
  //         'barcode': barcodeData,
  //         'quantity': printQuantity,
  //         'printerModel': selectedPrinterModel.toString(),
  //         'labelWidth': selectedLabel?.width,
  //         'labelType': selectedLabel?.id,
  //         'barcodeType': selectedBarcodeType.toString(),
  //       });
  //
  //       await FirebaseFirestore.instance
  //           .collection('general_data')
  //           .doc('printer')
  //           .set({
  //         'totalLabelsPrinted': FieldValue.increment(printQuantity),
  //         'lastPrintTimestamp': FieldValue.serverTimestamp(),
  //       }, SetOptions(merge: true));
  //
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('$printQuantity Etikett(en) wurden gedruckt'),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     } finally {
  //       await pdfFile.delete().catchError((e) => print('Fehler beim Löschen der temporären PDF: $e'));
  //     }
  //   } catch (e) {
  //     print('Druckfehler: $e');
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Druckfehler: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  Future<File> _generatePdfForPrinter() async {
    final pdf = pw.Document();

    double pageWidth = selectedLabel?.width.toDouble() ?? PdfPageFormat.a4.width;
    double pageHeight = 21; // Feste Höhe für Endlos-Etiketten

    // Berechne optimale Barcode-Größe basierend auf der Papierbreite
    double barcodeWidth = pageWidth * 1;
    double barcodeHeight = pageHeight * 0.5;
    double fontSize = pageWidth * 0.05; // Dynamische Schriftgröße

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          pageWidth,
          pageHeight,
          marginAll: 0,
        ),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  data: barcodeData,
                  barcode: pw.Barcode.code128(),
                  width: barcodeWidth,
                  height: barcodeHeight,
                  drawText: false, // Kein automatischer Text unter dem Barcode
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  barcodeData,
                  style: pw.TextStyle(
                    font: _customFont, // Verwende die geladene Schriftart
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/label.pdf");
      await file.writeAsBytes(await pdf.save());

      // Debug-Ausgabe der PDF-Größe
      print('PDF created: ${await file.length()} bytes');
      print('PDF path: ${file.path}');

      return file;
    } catch (e) {
      print('Fehler bei der PDF-Erstellung: $e');
      rethrow;
    }
  }


  Widget _buildBarcodeTypeSelector() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Expanded(
                child: RadioListTile<BarcodeType>(
                  title: Text('Verkauf',style: smallestHeadline,),
                  value: BarcodeType.sales,
                  groupValue: selectedBarcodeType,
                  onChanged: (BarcodeType? value) async {
                    if (value != null) {
                      setState(() {
                        selectedBarcodeType = value;
                        _includeBatchNumber = false; // Reset beim Wechsel
                        barcodeData = '';
                        productData = null;
                      });

                      // Lade den letzten Verkaufscode
                      try {
                        final doc = await FirebaseFirestore.instance
                            .collection('general_data')
                            .doc('printer')
                            .get();

                        if (doc.exists && doc.data()?['lastSalesBarcode'] != null) {
                          String lastCode = doc.data()!['lastSalesBarcode'];
                          if (lastCode.isNotEmpty) {
                            await _fetchProductData(lastCode);
                          }
                        }
                      } catch (e) {
                        print('Fehler beim Laden des letzten Verkaufscodes: $e');
                      }

                      _saveCurrentSettings();
                    }
                  },
                  activeColor: primaryAppColor,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    RadioListTile<BarcodeType>(
                      title: Text('Produktion',style: smallestHeadline,),
                      value: BarcodeType.production,
                      groupValue: selectedBarcodeType,
                      onChanged: (BarcodeType? value) async {
                        if (value != null) {
                          setState(() {
                            selectedBarcodeType = value;
                            barcodeData = '';
                            productData = null;
                          });

                          try {
                            final doc = await FirebaseFirestore.instance
                                .collection('general_data')
                                .doc('printer')
                                .get();

                            if (doc.exists && doc.data()?['lastProductionBarcode'] != null) {
                              String lastCode = doc.data()!['lastProductionBarcode'];
                              if (lastCode.isNotEmpty) {
                                await _fetchProductData(lastCode);
                              }
                            }
                          } catch (e) {
                            print('Fehler beim Laden des letzten Produktionscodes: $e');
                          }

                          _saveCurrentSettings();
                        }
                      },
                      activeColor: primaryAppColor,
                    ),

                  ],
                ),
              ),
            ],
          ),
          if (selectedBarcodeType == BarcodeType.production)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                children: [
                  Checkbox(
                    value: _includeBatchNumber,
                    onChanged: (bool? value) {
                      setState(() {
                        _includeBatchNumber = value ?? false;
                        barcodeData = '';
                        productData = null;
                      });
                    },
                    activeColor: primaryAppColor,
                  ),
                  Text('Barcode inkl. Chargen-Nummer',style: smallestHeadline,),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8,8,8,0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:_showProductSearchDialog,
                    child:const Icon(Icons.search),


                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startScanner,
                    child: const Icon(Icons.qr_code_scanner),

                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showManualInputDialog(),
                    // onPressed: () {
                    //   barcodeController.clear();
                    //   showDialog(
                    //     context: context,
                    //     builder: (BuildContext context) {
                    //       return AlertDialog(
                    //         title: const Text('Barcode eingeben'),
                    //         content: Column(
                    //           mainAxisSize: MainAxisSize.min,
                    //           children: [
                    //             TextFormField(
                    //               controller: barcodeController,
                    //               decoration: const InputDecoration(
                    //                 labelText: 'Barcode',
                    //                 border: OutlineInputBorder(),
                    //               ),
                    //               keyboardType: TextInputType.number,
                    //             //  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    //               autofocus: true,
                    //             ),
                    //           ],
                    //         ),
                    //         actions: [
                    //           TextButton(
                    //             onPressed: () => Navigator.pop(context),
                    //             child: const Text('Abbrechen'),
                    //           ),
                    //           ElevatedButton(
                    //             onPressed: () async {
                    //               if (barcodeController.text.isNotEmpty) {
                    //                 barcodeData = barcodeController.text;
                    //                 await _fetchProductData(barcodeData);
                    //                 Navigator.pop(context);
                    //               }
                    //             },
                    //             child: const Text('Suchen'),
                    //           ),
                    //         ],
                    //       );
                    //     },
                    //   );
                    // },
                    child: const Icon(Icons.keyboard),

                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPreview() {
    if (productData == null || barcodeData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Text(
            'Keine Produktdaten verfügbar',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Berechne die Breite basierend auf dem ausgewählten Papierformat
    double containerWidth = selectedLabel?.width ?? 62.0;

    // Skalierungsfaktor für die Anzeige
    double scaleFactor = 4.0;

    return Container(
      width: containerWidth * scaleFactor,
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BarcodeWidget(
            data: barcodeData,
            barcode: Barcode.code128(),
            width: containerWidth * scaleFactor * 0.9,
            height: 80,
          ),
          SizedBox(height: 8),
          Text(
            barcodeData,
            style: TextStyle(
              fontSize: min(containerWidth * 0.15, 14.0),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  void _showPrinterStatusToast() {
    if (!_printerSearching) {
      setState(() {
        _indicatorColor = Colors.orange; // Setze die Leuchte auf Orange, wenn die Suche beginnt
      });
      Fluttertoast.showToast(
        msg: "Drucker wird gesucht...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );

      // Beginne die Druckersuche nach dem Klick
      _checkPrinterStatus();
    }
  }

  LabelType? selectedLabel;

// Modifiziere den manuellen Eingabe-Dialog
  void _showManualInputDialog() {
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
                keyboardType: TextInputType.text,
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
              onPressed: () async {
                if (barcodeController.text.isNotEmpty) {
                  Navigator.pop(context);
                  if (selectedBarcodeType == BarcodeType.production) {
                    await _handleProductionBarcode(barcodeController.text);
                  } else {
                    await _fetchProductData(barcodeController.text);
                  }
                }
              },
              child: const Text('Suchen'),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Barcode drucken', style: headline4_0)),
        actions: [
          // GestureDetector(
          //   onTap: _showPrinterStatusToast,
          //   child: Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: Container(
          //       width: 20,
          //       height: 20,
          //       decoration: BoxDecoration(
          //         shape: BoxShape.circle,
          //         color: _indicatorColor,
          //         boxShadow: [
          //           BoxShadow(
          //             color: Colors.grey.withOpacity(0.6),
          //             spreadRadius: 2,
          //             blurRadius: 2,
          //             offset: Offset(0, 0),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showPrinterSettingsDialog(context);
            },
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body:
        LayoutBuilder(
        builder: (context, constraints) {
      return
        SingleChildScrollView(

        child: Container(
        constraints: BoxConstraints(
      minHeight: constraints.maxHeight,),
      child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: <Widget>[

              _buildBarcodeTypeSelector(),
              //
              // SizedBox(height: 0.02 * MediaQuery.of(context).size.height),
              // BarcodeWidget(
              //   data: barcodeData,
              //   barcode: pw.Barcode.code128(),
              //   width: 200,
              //   height: 80,
              // ),

              // Padding(
              //   padding: const EdgeInsets.fromLTRB(8,8,8,0),
              //   child: Row(
              //     children: [
              //       Expanded(
              //         child: ElevatedButton(
              //           onPressed:_showProductSearchDialog,
              //          child:const Icon(Icons.search),
              //
              //
              //         ),
              //       ),
              //       const SizedBox(width: 8),
              //       Expanded(
              //         child: ElevatedButton(
              //           onPressed: _startScanner,
              //          child: const Icon(Icons.qr_code_scanner),
              //
              //         ),
              //       ),
              //       const SizedBox(width: 8),
              //       Expanded(
              //         child: ElevatedButton(
              //           onPressed: () => _showManualInputDialog(),
              //           // onPressed: () {
              //           //   barcodeController.clear();
              //           //   showDialog(
              //           //     context: context,
              //           //     builder: (BuildContext context) {
              //           //       return AlertDialog(
              //           //         title: const Text('Barcode eingeben'),
              //           //         content: Column(
              //           //           mainAxisSize: MainAxisSize.min,
              //           //           children: [
              //           //             TextFormField(
              //           //               controller: barcodeController,
              //           //               decoration: const InputDecoration(
              //           //                 labelText: 'Barcode',
              //           //                 border: OutlineInputBorder(),
              //           //               ),
              //           //               keyboardType: TextInputType.number,
              //           //             //  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              //           //               autofocus: true,
              //           //             ),
              //           //           ],
              //           //         ),
              //           //         actions: [
              //           //           TextButton(
              //           //             onPressed: () => Navigator.pop(context),
              //           //             child: const Text('Abbrechen'),
              //           //           ),
              //           //           ElevatedButton(
              //           //             onPressed: () async {
              //           //               if (barcodeController.text.isNotEmpty) {
              //           //                 barcodeData = barcodeController.text;
              //           //                 await _fetchProductData(barcodeData);
              //           //                 Navigator.pop(context);
              //           //               }
              //           //             },
              //           //             child: const Text('Suchen'),
              //           //           ),
              //           //         ],
              //           //       );
              //           //     },
              //           //   );
              //           // },
              //           child: const Icon(Icons.keyboard),
              //
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

              // Padding(
              //   padding: const EdgeInsets.all(0.0),
              //   child: Container(
              //     margin: const EdgeInsets.all(8.0),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       mainAxisSize: MainAxisSize.min,
              //       children: [
              //         // Text(
              //         //   'Papierformat auswählen:',
              //         //   style: TextStyle(
              //         //     fontSize: 16,
              //         //     fontWeight: FontWeight.bold,
              //         //     color: Colors.black87,
              //         //   ),
              //         // ),
              //         const SizedBox(height: 8),
              //         Container(
              //           decoration: BoxDecoration(
              //             color: Colors.white,
              //             borderRadius: BorderRadius.circular(8),
              //             border: Border.all(color: Colors.grey.shade300),
              //             boxShadow: [
              //               BoxShadow(
              //                 color: Colors.grey.withOpacity(0.1),
              //                 spreadRadius: 1,
              //                 blurRadius: 2,
              //                 offset: Offset(0, 1),
              //               ),
              //             ],
              //           ),
              //           child: DropdownButtonHideUnderline(
              //             child: ButtonTheme(
              //               alignedDropdown: true,
              //               child: DropdownButton<LabelType>(
              //                 value: selectedLabel,
              //                 isExpanded: true,
              //                 icon: Container(
              //                   padding: EdgeInsets.only(right: 12),
              //                   child: Icon(
              //                     Icons.arrow_drop_down,
              //                     color: Colors.black54,
              //                     size: 30,
              //                   ),
              //                 ),
              //                 dropdownColor: Colors.white,
              //                 borderRadius: BorderRadius.circular(8),
              //                 items: labelTypes.map((LabelType label) {
              //                   return DropdownMenuItem<LabelType>(
              //                     value: label,
              //                     child: Row(
              //                       children: [
              //                         Container(
              //                           width: 50,
              //                           height: 40,
              //                           decoration: BoxDecoration(
              //                             color: const Color(0xFF0F4A29).withOpacity(0.1),
              //                             borderRadius: BorderRadius.circular(8),
              //                           ),
              //                           child: Center(
              //                             child: Text(
              //                               '${label.width}',
              //                               style: TextStyle(
              //                                 fontWeight: FontWeight.bold,
              //                                 color: const Color(0xFF3E9C37),
              //                               ),
              //                             ),
              //                           ),
              //                         ),
              //                         SizedBox(width: 12),
              //                         Expanded(
              //                           child: Column(
              //                             crossAxisAlignment: CrossAxisAlignment.start,
              //                             mainAxisSize: MainAxisSize.min,
              //                             children: [
              //                               Text(
              //                                 'Endlospapier ${label.width}mm',
              //                                 style: TextStyle(
              //                                   fontWeight: FontWeight.w500,
              //                                   fontSize: 15,
              //                                 ),
              //                               ),
              //                               Text(
              //                                 label.description,
              //                                 style: TextStyle(
              //                                   color: Colors.grey[600],
              //                                   fontSize: 13,
              //                                 ),
              //                               ),
              //                             ],
              //                           ),
              //                         ),
              //                       ],
              //                     ),
              //                   );
              //                 }).toList(),
              //                 onChanged: (LabelType? newValue) {
              //                   setState(() {
              //
              //                     selectedLabel = newValue;
              //                   });
              //                   _saveCurrentSettings();
              //                 },
              //                 hint: Text(
              //                   'Bitte Papierformat wählen',
              //                   style: TextStyle(color: Colors.grey[600]),
              //                 ),
              //               ),
              //             ),
              //           ),
              //         ),
              //       ],
              //     ),
              //   )
              // ),
              //
              //
              //  Padding(
              //               //     padding: const EdgeInsets.all(8.0),
              //               //     child: Container(
              //               //       decoration: BoxDecoration(
              //               //         border: Border.all(color: Colors.grey),
              //               //         borderRadius: BorderRadius.circular(8.0),
              //               //       ),
              //               //       child: selectedLabel == null
              //               //           ? Center(child: Padding(
              //               //             padding: const EdgeInsets.all(30.0),
              //               //             child: Text('Bitte wähle ein Papierformat aus'),
              //               //           ))
              //               //           : ClipRRect(
              //               //         borderRadius: BorderRadius.circular(8.0),
              //               //         child: Container(
              //               //           color: Colors.white,
              //               //           child: _buildPreview(),
              //               //         ),
              //               //       ),
              //               //     ),
              //               //   ),
              //               //
               Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child:  ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        color: Colors.white,
                        child: _buildPreview(),
                      ),
                    ),
                  ),
                ),

              Container(
                margin: const EdgeInsets.all(8.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _isPrinterOnline
                                    ? const Color(0xFF0F4A29).withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.print,
                                size: 24,
                                color: _isPrinterOnline
                                    ? primaryAppColor
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Etikett drucken',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _isPrinterOnline
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isPrinterOnline
                                        ? (barcodeData.isEmpty
                                        ? 'Bitte zuerst Produkt auswählen'
                                        : _printerDetails ?? 'Drucker bereit')
                                        : 'Drucker nicht verfügbar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _isPrinterOnline
                                          ? Colors.black54
                                          : Colors.grey,
                                    ),
                                  ),

                                ],
                              ),
                            ),
                            IconButton(
                              icon: _printerSearching
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : Icon(Icons.refresh),
                              onPressed: _printerSearching
                                  ? null
                                  : () {
                                setState(() {
                                  _printerSearching = true;
                                  _indicatorColor = Colors.orange;
                                });
                                _checkPrinterStatus();
                              },
                            ),
                            _buildConnectionIndicator(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Anzahl Etiketten:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),

                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove),
                                      onPressed: printQuantity > 1
                                          ? () => setState(() => printQuantity--)
                                          : null,
                                      color: const Color(0xFF3E9C37),
                                    ),
                                    Text(
                                      '$printQuantity',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add),
                                      onPressed: () => setState(() => printQuantity++),
                                      color: const Color(0xFF3E9C37),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: barcodeData.isEmpty || !_isPrinterOnline|| selectedLabel==null
                                ? null
                                : () => printLabel(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryAppColor,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              selectedLabel==null
                                  ? 'Barcode nicht definiert'
                                  : !_isPrinterOnline
                                  ? 'Drucker nicht verfügbar'
                                  : 'Drucken',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: barcodeData.isEmpty || !_isPrinterOnline || selectedLabel==null
                                    ? Colors.grey.shade600
                                    : Colors.white,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              )

              // if (barcodeData.isNotEmpty)  // Produktkarte nur anzeigen wenn Barcode gescannt
              //   Padding(
              //     padding: const EdgeInsets.all(16.0),
              //     child: ProductCard(
              //       barcode: barcodeData,
              //       productData: productData,
              //     ),
              //   ),

            ],
          ),
        ),
      );
        }
    )


    );
  }
}

