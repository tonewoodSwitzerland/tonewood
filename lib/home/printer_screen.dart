import 'package:flutter/foundation.dart';
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
import 'package:another_brother/printer_info.dart' as brother;
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


  Map<String, bool> _productionFeatures = {
    'thermo': false,
    'hasel': false,
    'mondholz': false,
    'fsc': false,
    'year': false,
  };

// Methode zum Aktualisieren der Features
  void _updateProductionFeatures(String key, bool value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _productionFeatures[key] = value;
      });
    });
  }
  double _onlineShopPrice = 0.0;
  TextEditingController _priceController = TextEditingController();
  int lastShopItem=0;
  bool _onlineShopItem = false;
  bool _useShortCodes = false;
  bool _isExistingOnlineShopItem = false;
  TextEditingController maxLengthController = TextEditingController();
  String? _shortCodeDisplay;
  String _activeConnectionType = PrinterConnectionType.none;
  bool _includeBatchNumber = false;
  String? _printerDetails;
  PrinterModel selectedPrinterModel = PrinterModel.QL820NWB; ///TODO RÜCKGÄNGIG
//  PrinterModel selectedPrinterModel = PrinterModel.QL1110NWB;
  int printQuantity = 1;
  late List<LabelType> labelTypes;
  final TextEditingController barcodeController = TextEditingController();
  Printer? _selectedPrinter;
  BarcodeType selectedBarcodeType = BarcodeType.sales;
  bool _isPrinterOnline = false;
  bool _printerSearching = false;
  Color _indicatorColor = Colors.orange;
  String barcodeData = '';
  static const double DEFAULT_LABEL_WIDTH = 38;
  Map<String, dynamic>? productData;
  pw.Font? _customFont;
  @override
  void initState() {
    super.initState();

    // Label-Settings zuerst laden
    _loadLabelSettings().then((_) {
      // Dann erst den Rest
      _checkPrinterStatus();
      _loadLastSettings();
      _loadAbbreviations();
      _updateLabelTypes();
      _loadSwitchValue();
    });
  }


  Future<bool> _checkAndUpdateInventory(String productId) async {
    try {
      // Extrahiere den Verkaufscode wenn es ein Produktionscode ist
      String inventoryId = productId;
      if (selectedBarcodeType == BarcodeType.production) {
        final parts = productId.split('.');
        if (parts.length >= 2) {
          inventoryId = '${parts[0]}.${parts[1]}';  // Nur die ersten beiden Teile für Verkaufscode
        }
      }
      print('Checking inventory for: $inventoryId');

      // Lagerbestand prüfen
      final inventoryDoc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(inventoryId)  // Hier den extrahierten Code verwenden
          .get();

      if (!inventoryDoc.exists) {
        return false;
      }

      final currentQuantity = inventoryDoc.data()?['quantity'] ?? 0;
      final currentOnlineQuantity = inventoryDoc.data()?['quantity_online_shop'] ?? 0;

      // Prüfen ob mindestens 1 auf Lager
      if (currentQuantity < 1) {
        return false;
      }

      // Lagerbestand aktualisieren
      await FirebaseFirestore.instance
          .collection('inventory')
          .doc(inventoryId)  // Hier auch den extrahierten Code verwenden
          .update({
        'quantity': currentQuantity - 1,
        'quantity_online_shop': currentOnlineQuantity + 1,
      });

      return true;
    } catch (e) {
      print('Fehler bei Lagerprüfung: $e');
      return false;
    }
  }
  Future<void> _bookOnlineShopItem(int nextShopItem) async {  // nextShopItem statt lastShopItem
    if (_onlineShopPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bitte gib einen gültigen Preis ein'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      // Zuerst Lagerbestand prüfen und aktualisieren
      final inventoryUpdateSuccess = await _checkAndUpdateInventory(barcodeData);

      if (!inventoryUpdateSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nicht genügend Lagerbestand verfügbar'), backgroundColor: Colors.red),
        );
        return;
      }

      // nextShopItem ist bereits der richtige Wert
      String shopId = nextShopItem.toString().padLeft(4, '0');
      String fullBarcode = '$barcodeData.$shopId';

      // Shop-Eintrag erstellen
      await FirebaseFirestore.instance
          .collection('onlineshop')
          .doc(fullBarcode)
          .set({
        ...productData!,
        'sold': false,
        'created_at': FieldValue.serverTimestamp(),
        'barcode': fullBarcode,
        'shop_id': shopId,
        'price_CHF': _onlineShopPrice,
      });

      // Counter auf den VERWENDETEN Wert setzen
      await FirebaseFirestore.instance.collection('general_data').doc('counters').set(
          { 'lastShopifyItem': nextShopItem },  // Direkt den verwendeten Wert speichern
          SetOptions(merge: true)
      );

      _loadSwitchValue();  // Lädt dann den nächsten verfügbaren Wert

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produkt erfolgreich zum Shop hinzugefügt'), backgroundColor: Colors.green),
      );

    } catch (e) {
      print('Fehler beim Buchen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Buchen: $e'), backgroundColor: Colors.red),
      );
    }
  }




// Neue Methode nur für Label-Settings
  Future<void> _loadLabelSettings() async {
    try {
      final officeDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .get();

      labelTypes = _getBaseLabels();

      if (officeDoc.exists && officeDoc.data()?['defaultLabelWidth'] != null) {
        double labelWidth = officeDoc.data()!['defaultLabelWidth'].toDouble();
        setState(() {
          selectedLabel = labelTypes.firstWhere(
                (label) => label.width == labelWidth,
            orElse: () => labelTypes.first,
          );
        });
      } else {
        // Setze Default-Label wenn keine Einstellung gefunden
        setState(() {
          selectedLabel = labelTypes.firstWhere(
                (label) => label.width == DEFAULT_LABEL_WIDTH,
            orElse: () => labelTypes.first,
          );
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Label-Einstellungen: $e');
      // Setze Default im Fehlerfall
      setState(() {
        selectedLabel = labelTypes.firstWhere(
              (label) => label.width == DEFAULT_LABEL_WIDTH,
          orElse: () => labelTypes.first,
        );
      });
    }
  }
  Map<String, List<AbbreviationItem>> _abbreviations = {
    'instruments': [],
    'wood_types': [],
    'parts': [],
    'qualities': [],
  };

  Map<String, bool> _selectedAbbreviationTypes = {
    'instruments': true,
    'wood_types': true,
    'parts': true,
    'qualities': true,
  };

  // Neue Methode zum Umschalten der Abkürzungstypen
  void _toggleAbbreviationType(String type, bool value) {
    setState(() {
      _selectedAbbreviationTypes[type] = value;
    });
    _updateShortCodeDisplay(); // Aktualisiere die Anzeige
  }

// Modifizierte _updateShortCodeDisplay Methode
  Future<void> _updateShortCodeDisplay() async {
    // Erstmal den alten Display-Wert zurücksetzen
    setState(() {
      _shortCodeDisplay = null;
    });

    if (!_useShortCodes || barcodeData.isEmpty) {
      return;
    }

    try {
      String code = barcodeData.replaceAll('.', '');
      List<String> parts = [];
      for (int i = 0; i < code.length; i += 2) {
        if (i + 2 <= code.length) {
          parts.add(code.substring(i, i + 2));
        }
      }

      if (parts.length < 4) return;

      List<String> shorts = [];
      Map<String, String> collectionMap = {
        'instruments': parts[0],
        'parts': parts[1],
        'wood_types': parts[2],
        'qualities': parts[3],
      };

      for (var entry in collectionMap.entries) {
        if (_selectedAbbreviationTypes[entry.key] ?? false) {
          final items = _abbreviations[entry.key] ?? [];
          final item = items.firstWhere(
                (item) => item.code == entry.value,
            orElse: () => AbbreviationItem(code: '', name: '', short: ''),
          );
          if (item.short.isNotEmpty) {
            shorts.add(item.short);
          }
        }
      }

      // Wichtig: Hier setzen wir den Wert und erzwingen ein rebuild
      setState(() {
        _shortCodeDisplay = shorts.join('-');
      });

      print('Kürzel aktualisiert: $_shortCodeDisplay'); // Debug-Ausgabe
    } catch (e) {
      print('Fehler beim Aktualisieren der Abkürzungen: $e');
    }
  }
// Neue Methode zum Laden der Abkürzungen
  Future<void> _loadAbbreviations() async {
    final collections = ['instruments', 'wood_types', 'parts', 'qualities'];

    for (final collection in collections) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .orderBy('code')
            .get();

        setState(() {
          _abbreviations[collection] = snapshot.docs
              .map((doc) => AbbreviationItem.fromFirestore(doc.data()))
              .toList();
        });
      } catch (e) {
        print('Fehler beim Laden der Abkürzungen für $collection: $e');
      }
    }
  }
  void showPrinterSettingsDialog(BuildContext context) {
    // Controller für das Textfeld zur maximalen Länge

    // Debug-Ausgabe 1: Direkt beim Start
    FirebaseFirestore.instance
        .collection('general_data')
        .doc('office')
        .get()
        .then((doc) {
      print("====== DIRECT FIRESTORE CHECK ======");
      print("Document exists: ${doc.exists}");
      print("Document data: ${doc.data()}");
      if (doc.exists) {
        print("maxLabelLength in doc: ${doc.data()?['maxLabelLength']}");
        print("Type: ${doc.data()?['maxLabelLength']?.runtimeType}");
      }
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          // Volle Größe mit Margins
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8, // Max 80% der Bildschirmhöhe
            ),
            child: StatefulBuilder(
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
                    double maxLabelLength = snapshot.hasData
                        ? (snapshot.data?.data()?['maxLabelLength']?.toDouble() ?? 206.0)
                        : 206.0;

                    // Controller nur einmal setzen oder bei Änderungen in Firebase
                    if (maxLengthController.text.isEmpty ||
                        maxLengthController.text != maxLabelLength.toString()) {
                      maxLengthController.text = maxLabelLength.toString();
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dialog-Header
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
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
                              const Text(
                                'Drucker Einstellungen',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              )
                            ],
                          ),
                        ),

                        Divider(height: 1),

                        // Scrollbarer Inhalt
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(16),
                            child: Column(
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

                                const SizedBox(height: 24),

                                // Maximale Etikettenlänge
// Maximale Etikettenlänge
                                Text(
                                  'Maximale Etikettenlänge',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: maxLengthController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            border: InputBorder.none,
                                            hintText: 'Länge eingeben',
                                            suffixText: 'mm',
                                          ),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 48,
                                        width: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F4A29),
                                          borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            final double? value = double.tryParse(maxLengthController.text);
                                            if (value != null && value > 0) {
                                              // Mindestlänge von 80 Punkten (ca. 75mm) erzwingen
                                              final double finalValue = max(value, 80.0);

                                              if (finalValue != value) {
                                                // Wenn Wert angepasst wurde, Controller aktualisieren
                                                maxLengthController.text = finalValue.toString();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Wert auf Mindestlänge von 80 (ca. 75mm) angepasst'),
                                                      backgroundColor: Colors.orange,
                                                    )
                                                );
                                              }

                                              FirebaseFirestore.instance
                                                  .collection('general_data')
                                                  .doc('office')
                                                  .set({'maxLabelLength': finalValue}, SetOptions(merge: true));

                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: [
                                                        Icon(Icons.check_circle, color: Colors.white),
                                                        SizedBox(width: 8),
                                                        Text('Maximale Länge gespeichert'),
                                                      ],
                                                    ),
                                                    backgroundColor: const Color(0xFF0F4A29),
                                                  )
                                              );
                                            }
                                          },
                                          icon: Icon(Icons.save, color: Colors.white),
                                          tooltip: 'Speichern',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text(
                                    // Korrekter Umrechnungsfaktor: 0.937 (206 entspricht 193mm real)
                                    'Reale Länge ca. ${(maxLabelLength * 0.937).toStringAsFixed(1)}mm (Mindestens 75mm)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Hinweis: Die eingestellte Länge kann von der tatsächlichen Drucklänge abweichen. Bei Problemen die Länge anpassen.',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Footer mit Aktionsbuttons
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Schließen'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
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

    // Aktualisiere den lokalen State
    setState(() {
      selectedLabel = labelTypes.firstWhere(
            (label) => label.width == width,
        orElse: () => labelTypes.first,
      );
    });
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
                      Icon(Icons.inventory, color: primaryAppColor),
                      SizedBox(width: 12),
                      Text(
                        'Produktionsliste',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryAppColor,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),

                // Hauptinhalt
                Expanded(
                  child: ProductionScreen(
                    isDialog: true,
                    onProductSelected: (productId) async {
                      Navigator.pop(context);
                      await _handleProductionBarcode(productId);
                    },
                  ),
                ),


              ],
            ),
          );
        },
      );
    } else {

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
                      Icon(Icons.warehouse, color: primaryAppColor),
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
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),

                // Hauptinhalt
                Expanded(
                  child: WarehouseScreen(
                    mode: 'barcodePrinting',
                    isDialog: true,
                    onBarcodeSelected: (barcode) async {
                      print("trest");
                      Navigator.pop(context);
                      await _fetchProductData(barcode);
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
// Modifizierte Scan-Funktion mit Validierung
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
        print("bc:$barcodeResult");

        // Speichere den aktuellen Barcode-Typ
        BarcodeType currentType = selectedBarcodeType;

        // Prüfe, ob der Barcode für den aktuellen Typ gültig ist
        bool isValidForCurrentType = _validateBarcode(barcodeResult, currentType);

        // Prüfe, ob der Barcode für den anderen Typ gültig wäre
        BarcodeType otherType = currentType == BarcodeType.sales ? BarcodeType.production : BarcodeType.sales;
        bool isValidForOtherType = _validateBarcode(barcodeResult, otherType);

        if (isValidForCurrentType) {
          // Barcode ist für den aktuellen Typ gültig, verarbeite ihn
          if (currentType == BarcodeType.production) {
            await _handleProductionBarcode(barcodeResult);
          } else {
            await _fetchProductData(barcodeResult);
          }
        } else {
          // Zeige passende Fehlermeldung abhängig von der Situation
          String errorMessage;

          if (isValidForOtherType) {
            // Der Barcode ist für den anderen Typ gültig
            if (currentType == BarcodeType.production) {
              errorMessage = 'Du hast einen Verkaufscode gescannt. Ein Produktionsbarcode hat das Format IIPP.HHQQ.0000.JJ';
            } else {
              errorMessage = 'Du hast einen Produktionscode gescannt. Ein Verkaufsbarcode hat das Format IIPP.HHQQ';
            }
          } else {
            // Der Barcode ist für keinen Typ gültig
            if (currentType == BarcodeType.production) {
              errorMessage = 'Ungültiger Barcode. Ein Produktionsbarcode sollte das Format IIPP.HHQQ.0000.JJ haben.';
            } else {
              errorMessage = 'Ungültiger Barcode. Ein Verkaufsbarcode sollte das Format IIPP.HHQQ haben.';
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
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

// Aktualisierte Validierungsfunktion mit explizitem Typ-Parameter
  bool _validateBarcode(String barcode, BarcodeType type) {
    // Verkaufsbarcode-Format: xxxx.yyyy
    // Erweiterte Produktionsbarcode-Formate

    final RegExp salesPattern = RegExp(r'^\d{4}\.\d{4}$');

    // Erweiterte Muster für Produktionsbarcodes
    final RegExp productionPattern = RegExp(
        r'^\d{4}\.\d{4}\.\d{4}(\.\d{1,2})?(\.\d{4})?$'
    );

    if (type == BarcodeType.sales) {
      return salesPattern.hasMatch(barcode);
    } else {
      return productionPattern.hasMatch(barcode);
    }
  }


  Future<void> _loadSwitchValue() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('counters')
          .get();

      if (snapshot.exists) {
        setState(() {
          lastShopItem = snapshot['lastShopifyItem']+1;

        });
      }
    } catch (e) {
      print("Fehler beim Laden: $e");
    }
  }



  Future<void> _loadLastSettings() async {

    try {
      // Lade Drucker-Einstellungen
      final printerDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('printer')
          .get();

      // Lade Office-Einstellungen (inkl. Etikettenbreite)
      final officeDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .get();

      if (printerDoc.exists || officeDoc.exists) {

        setState(() {
          print("Lade Drucker Typ");
          // Lade den Drucker-Typ
          if (printerDoc.data()?['printerModel'] != null) {
            selectedPrinterModel = PrinterModel.values.firstWhere(
                  (model) => model.toString() == printerDoc.data()!['printerModel'],
             orElse: () => PrinterModel.QL820NWB,
             // orElse: () => PrinterModel.QL1110NWB,
              ///TODO RÜCKGÄNGIG

            );
            _updateLabelTypes();

            print("slP:$selectedPrinterModel");
         //   AppToast.show(height:h,message:"slP:$selectedPrinterModel");
          }

          // Setze das Label aus dem office Dokument
          if (officeDoc.data()?['defaultLabelWidth'] != null) {

            print("yoooo");

            double labelWidth = officeDoc.data()!['defaultLabelWidth'].toDouble();
            selectedLabel = labelTypes.firstWhere(
                  (label) => label.width == labelWidth,
              orElse: () => labelTypes.first,
            );
          }

          // Rest der Einstellungen...
          if (printerDoc.data()?['lastBarcodeType'] != null) {
            selectedBarcodeType = BarcodeType.values.firstWhere(
                  (type) => type.toString() == printerDoc.data()!['lastBarcodeType'],
              orElse: () => BarcodeType.sales,
            );
          }

          if (selectedBarcodeType == BarcodeType.sales &&
              printerDoc.data()?['lastSalesBarcode'] != null) {
            barcodeData = printerDoc.data()!['lastSalesBarcode'];
            _fetchProductData(barcodeData);
          } else if (selectedBarcodeType == BarcodeType.production &&
              printerDoc.data()?['lastProductionBarcode'] != null) {
            barcodeData = printerDoc.data()!['lastProductionBarcode'];
            _fetchProductData(barcodeData);
          }
        });

        print('Geladene Einstellungen:');
        print('Barcode-Typ: ${selectedBarcodeType}');
        print('Aktuelle Etikettenbreite: ${selectedLabel?.width}');
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
      // Reset existing shop item state
      setState(() {
        _isExistingOnlineShopItem = false;
      });

      // Check if this is an existing online shop item
      final onlineShopDoc = await FirebaseFirestore.instance
          .collection('onlineshop')
          .doc(barcode)
          .get();

      if (onlineShopDoc.exists) {
        setState(() {
          barcodeData = barcode;
          productData = onlineShopDoc.data();
          if (productData?['price_CHF'] != null) {
            _onlineShopPrice = productData!['price_CHF'].toDouble();
            _priceController.text = _onlineShopPrice.toString();
          }
          _isExistingOnlineShopItem = true;
          _onlineShopItem = true;
        });
        await _saveCurrentSettings();
        if (_useShortCodes) {
          await _updateShortCodeDisplay();
        }
        return;
      }


      if (selectedBarcodeType == BarcodeType.sales) {
        // Extrahiere den Verkaufscode (xxxx.yyyy)
        final searchBarcode = _extractSalesBarcode(barcode);

        final doc = await FirebaseFirestore.instance
            .collection('inventory')
            .doc(searchBarcode)
            .get();

        if (doc.exists) {
          setState(() {
            barcodeData = doc.id;
            productData = doc.data();
            if (productData?['price_CHF'] != null) {
              _onlineShopPrice = productData!['price_CHF'].toDouble();
              _priceController.text = _onlineShopPrice.toString();
            }
          });
          await _saveCurrentSettings();
          await _updateShortCodeDisplay();

          // Warte einen Frame, damit alles aktualisiert wird
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              // Hier nichts ändern, aber setState erzwingen
            });
          });
        } else {
          setState(() {
            barcodeData = 'Produkt nicht gefunden';
            productData = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produkt nicht gefunden: $searchBarcode'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
          // Setze die Features basierend auf dem Barcode
          if (parts.length >= 3) {
            final features = parts[2];
            _productionFeatures = {
              'thermo': features[0] == '1',
              'hasel': features[1] == '1',
              'mondholz': features[2] == '1',
              'fsc': features[3] == '1',
              'year': parts.length >= 4,
            };
          }
          if (productData?['price_CHF'] != null) {
            _onlineShopPrice = productData!['price_CHF'].toDouble();
            _priceController.text = _onlineShopPrice.toString();
          }
          _saveCurrentSettings();
        });
      }
      // Hier den neuen Code einfügen:
      await _updateShortCodeDisplay();

      // Zusätzliches setState für vollständiges UI-Update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          // Nichts ändern, nur UI aktualisieren
        });
      });


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

            Permission.bluetoothConnect,
            Permission.bluetoothScan,
            Permission.location,  // Location hinzufügen
          ].request();

          bool allGranted = statuses.values.every((status) => status.isGranted);
          if (!allGranted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bluetooth-Berechtigungen werden benötigt'),
                  backgroundColor: Colors.red,
                ),
              );
            }
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

print("printers:ssss:$printers");

        if (printers.isNotEmpty && mounted) {
          setState(() {
            _isPrinterOnline = true;
            _indicatorColor = primaryAppColor;
            _activeConnectionType = PrinterConnectionType.bluetooth;
           // _printerDetails = '${printers.first.modelName} (${printers.first.macAddress})';
            _printerDetails = '${printers.first.modelName}';
          });
          return true;
        }
      } else {
        List<NetPrinter> printers =
        await printer.getNetPrinters([printInfo.printerModel.getName()]);

        print("printers:$printers");


        if (printers.isNotEmpty && mounted) {

          print("yuup");
          setState(() {
            _isPrinterOnline = true;
            _indicatorColor = primaryAppColor;
            _activeConnectionType = PrinterConnectionType.wifi;
           // _printerDetails = '${printers.first.modelName} (${printers.first.nodeName})';
            _printerDetails = '${printers.first.modelName}';
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
      print(printInfo.printerModel);
     printInfo.printerModel = Model.QL_820NWB;
    // printInfo.printerModel = Model.QL_1110NWB;
      ///TODO RÜCKGÄNGIG

      // printInfo.printerModel = selectedPrinterModel == PrinterModel.QL1110NWB
      //     ? Model.QL_1110NWB
      //     : Model.QL_820NWB;

      print("sPM:$selectedPrinterModel");
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

  Future<bool> printLabel(BuildContext context) async {
    print("Starte Druckvorgang...");
    if (!_isPrinterOnline || barcodeData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Drucker nicht bereit oder kein Barcode ausgewählt'),
        backgroundColor: Colors.red,
      ));
      return false;
    }

    bool druckErfolgreich = false;


    await PrintStatus.show(context, () async {
      try {
        PrintStatus.updateStatus("Initialisiere Drucker...");
        print("Aktiver Verbindungstyp: $_activeConnectionType");

        // Benutzereinstellung für bevorzugte Verbindung laden
        bool useBluetoothFirst = await FirebaseFirestore.instance
            .collection('general_data')
            .doc('office')
            .get()
            .then((doc) => doc.get('bluetoothFirst') ?? true);

        print("Bluetooth First: $useBluetoothFirst");

        var printer = Printer();
        var printInfo = PrinterInfo();

        print("Ausgewähltes Druckermodell: $selectedPrinterModel");
        // printInfo.printerModel = selectedPrinterModel == PrinterModel.QL1110NWB
        //     ? Model.QL_1110NWB
        //     : Model.QL_820NWB;

      printInfo.printerModel = Model.QL_820NWB;
      //  printInfo.printerModel = Model.QL_1110NWB;
        ///TODO RÜCKGÄNGIG


        print("Konfiguriertes Druckermodell: ${printInfo.printerModel}");

        print("uBL:$useBluetoothFirst");

        // Erst die bevorzugte Verbindungsart versuchen
        if (useBluetoothFirst) {
          printInfo.port = Port.BLUETOOTH;
          // Versuche Bluetooth
          print("Versuche Bluetooth-Verbindung...");
         // List<BluetoothPrinter> bluetoothPrinters = await printer.getBluetoothPrinters([printInfo.printerModel.getName()]);
          List<BluetoothPrinter> bluetoothPrinters = await printer.getBluetoothPrinters([Model.QL_820NWB.getName()]);
         //List<BluetoothPrinter> bluetoothPrinters = await printer.getBluetoothPrinters([Model.QL_1110NWB.getName()]);
          ///TODO RÜCKGÄNGIG


          print("Gefundene Bluetooth-Drucker: ${bluetoothPrinters.length}");
          for (var p in bluetoothPrinters) {
            print("- ${p.modelName} (${p.macAddress})");
          }

          if (bluetoothPrinters.isNotEmpty) {
            _activeConnectionType = PrinterConnectionType.bluetooth;
            // Bluetooth-spezifische Konfiguration
          } else {
            // Wenn Bluetooth fehlschlägt, versuche WLAN
            print("Bluetooth fehlgeschlagen, versuche WLAN");
            printInfo.port = Port.NET;
           // List<NetPrinter> netPrinters = await printer.getNetPrinters([printInfo.printerModel.getName()]);
            List<NetPrinter> netPrinters = await printer.getNetPrinters([Model.QL_820NWB.getName()]);
          // List<NetPrinter> netPrinters = await printer.getNetPrinters([Model.QL_1110NWB.getName()]);

            ///TODO RÜCKGÄNGIG

            print("Gefundene Netzwerk-Drucker: ${netPrinters.length}");
            for (var p in netPrinters) {
              print("- ${p.modelName} (${p.ipAddress})");
            }

            if (netPrinters.isNotEmpty) {
              _activeConnectionType = PrinterConnectionType.wifi;
              // WLAN-spezifische Konfiguration
            }
          }
        } else {
          print("WLAN wird zuerst versucht");
          // WLAN zuerst versuchen
          printInfo.port = Port.NET;
          //List<NetPrinter> netPrinters = await printer.getNetPrinters([printInfo.printerModel.getName()]);
         List<NetPrinter> netPrinters = await printer.getNetPrinters([Model.QL_820NWB.getName()]);
         ///TODO Rückgängi
        // List<NetPrinter> netPrinters = await printer.getNetPrinters([Model.QL_1110NWB.getName()]);


          print("Gefundene Netzwerk-Drucker: ${netPrinters.length}");
          for (var p in netPrinters) {
            print("- ${p.modelName} (${p.ipAddress})");
          }

          if (netPrinters.isNotEmpty) {
            _activeConnectionType = PrinterConnectionType.wifi;
            // WLAN-spezifische Konfiguration
          } else {
            // Wenn WLAN fehlschlägt, versuche Bluetooth
            print("WLAN fehlgeschlagen, versuche Bluetooth");
            printInfo.port = Port.BLUETOOTH;
          //  List<BluetoothPrinter> bluetoothPrinters = await printer.getBluetoothPrinters([printInfo.printerModel.getName()]);
            List<BluetoothPrinter> bluetoothPrinters = await printer.getBluetoothPrinters([Model.QL_820NWB.getName()]);

            print("Gefundene Bluetooth-Drucker: ${bluetoothPrinters.length}");
            for (var p in bluetoothPrinters) {
              print("- ${p.modelName} (${p.macAddress})");
            }

            if (bluetoothPrinters.isNotEmpty) {
              _activeConnectionType = PrinterConnectionType.bluetooth;
              // Bluetooth-spezifische Konfiguration
            }
          }
        }

        printInfo.isAutoCut = true;
        printInfo.isCutAtEnd = true;
        printInfo.numberOfCopies = printQuantity;
        printInfo.printMode = PrintMode.FIT_TO_PAGE;
        printInfo.orientation = brother.Orientation.LANDSCAPE;

        if (selectedLabel != null) {
          var labelId = QL700.W62.getId();  // Zum Debuggen
          var labelIndex = QL700.ordinalFromID(labelId);  // Zum Debuggen
          print('Selected Label Width: ${selectedLabel!.width}');
          print('Label ID: $labelId');
          print('Label Index: $labelIndex');

          switch(selectedLabel!.width.toInt()) {
            case 62:
              printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W62.getId());
              print('Setting label 62mm: ${printInfo.labelNameIndex}');
              break;
            case 54:
              printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W54.getId());
              print('Setting label 54mm: ${printInfo.labelNameIndex}');
              break;
            case 50:
              printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W50.getId());
              print('Setting label 50mm: ${printInfo.labelNameIndex}');
              break;
            case 38:
              printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W38.getId());
              print('Setting label 38mm: ${printInfo.labelNameIndex}');
              break;
            case 29:
              printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W29.getId());
              print('Setting label 29mm: ${printInfo.labelNameIndex}');
              break;
            default:
              throw Exception('Ungültige Etikettengröße: ${selectedLabel!.width}mm');
          }
        }

        PrintStatus.updateStatus("Suche Drucker...");
        if (_activeConnectionType == PrinterConnectionType.bluetooth) {
          PrintStatus.updateStatus("Prüfe Bluetooth-Verbindung...");
          // Kurze Verzögerung einfügen
          await Future.delayed(const Duration(milliseconds: 1000));

          List<BluetoothPrinter> bluetoothPrinters = await printer.getBluetoothPrinters([printInfo.printerModel.getName()]);
          print("Finale Bluetooth-Drucker Suche: ${bluetoothPrinters.length} Drucker gefunden");

          if (bluetoothPrinters.isEmpty) {
            throw Exception('Bluetooth-Drucker nicht gefunden');
          }

          PrintStatus.updateStatus("Verbinde mit Bluetooth-Drucker...");
          // Sicherstellen dass der Drucker erreichbar ist
          printInfo.macAddress = bluetoothPrinters[0].macAddress;
          print("Versuche Verbindung mit MAC: ${printInfo.macAddress}");
          bool isConnected = await printer.setPrinterInfo(printInfo);
          if (!isConnected) {
            throw Exception('Bluetooth-Verbindung fehlgeschlagen');
          }
        } else {
          print("Suche nach Netzwerk-Druckern...");
          List<NetPrinter> netPrinters = await printer.getNetPrinters([printInfo.printerModel.getName()]);
          print("Finale Netzwerk-Drucker Suche: ${netPrinters.length} Drucker gefunden");

          if (netPrinters.isEmpty) {
            throw Exception('Netzwerk-Drucker nicht gefunden');
          }
          PrintStatus.updateStatus("Konfiguriere Drucker...");
          printInfo.ipAddress = netPrinters[0].ipAddress;
          print("Versuche Verbindung mit IP: ${printInfo.ipAddress}");
          await printer.setPrinterInfo(printInfo);
        }

        PrintStatus.updateStatus("Generiere PDF...");
        final pdfFile = await _generatePdfForPrinter2();

        PrintStatus.updateStatus("Sende Daten an Drucker...");
        var status = await printer.printPdfFile(pdfFile.path, 1);

        // Prüfe ob es ein echter Fehler ist oder ERROR_NONE
        // Prüfe ob es ein echter Fehler ist oder ERROR_NONE
        if (status.errorCode.getName() != 'ERROR_NONE') {
          print("Druckerstatus: ${status.errorCode.getName()}");

          // Spezifischen Fehler für falsches Label abfangen
          if (status.errorCode.getName() == 'ERROR_WRONG_LABEL') {
            throw Exception('WRONG_LABEL'); // Spezieller Fehler für Labelgröße
          }

          throw status;
        }


        druckErfolgreich = true;
        PrintStatus.updateStatus("Druckvorgang erfolgreich abgeschlossen");
        await Future.delayed(const Duration(milliseconds: 500));

        await FirebaseFirestore.instance.collection('print_logs').add({
          'timestamp': FieldValue.serverTimestamp(),
          'barcode': barcodeData,
          'quantity': printQuantity,
          'labelWidth': selectedLabel?.width,
          'labelType': selectedLabel?.id,
          'barcodeType': selectedBarcodeType.toString(),
        });

      } catch (e) {
        print("Druckfehler aufgetreten: $e");

        // Speziellen Fehler für Labelgröße abfangen
        if (e.toString().contains('WRONG_LABEL')) {
          PrintStatus.updateStatus("Fehler: Falsche Etikettengröße im Drucker");
          await Future.delayed(const Duration(seconds: 2));
        } else {
          PrintStatus.updateStatus("Fehler: ${PrinterErrorHelper.getErrorMessage(e)}");
          await Future.delayed(const Duration(seconds: 1));
        }

        throw e;
      }
    }).catchError((error) async {
      // Abfangen des Fehlers nach dem Dialog
      if (error.toString().contains('WRONG_LABEL')) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Falsche Etikettengröße'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Die eingestellte Etikettengröße stimmt nicht mit der im Drucker eingelegten überein.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Schließen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showPrinterSettingsDialog(context); // Öffne direkt die Druckereinstellungen
                  },
                  child: Text('Einstellungen öffnen',style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(

                    backgroundColor: primaryAppColor,
                  ),
                ),
              ],
            );
          },
        );
      }
      return false;
    });

    return druckErfolgreich;
  }
  Future<File> _generatePdfForPrinter3() async {
    final pdf = pw.Document();

    // Feste Dimensionen
    final labelWidth = 38.0;     // Breite des Labels
    final boxWidth = 35.0;       // Breite des Kästchens
    final boxLength = 40.0;      // Länge des Kästchens
    final spacing = 5.0;         // Abstand zwischen Box und Text

    // Text für das Label (nur Short Code wenn aktiviert)
    String displayText = _useShortCodes && _shortCodeDisplay != null ? _shortCodeDisplay! : '';

    // Schätzung der Textlänge (ca. 2mm pro Zeichen bei Schriftgröße 14)
    final double estimatedTextLength = _useShortCodes && _shortCodeDisplay != null ?displayText.length * 6.5:0;

    // Gesamtlänge des Labels berechnen
    final labelLength = boxLength + spacing + estimatedTextLength;

    final pageFormat = PdfPageFormat(
      labelLength,  // Breite ist die längere Seite
      labelWidth,   // Höhe ist die kürzere Seite
      marginAll: 0,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              // Box mit Barcode und Text darunter
              pw.Container(
                width: boxLength,
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: boxLength,
                      height: boxWidth - 10, // Etwas kleiner für den Text unten
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: barcodeData,
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      barcodeData,
                      style: pw.TextStyle(
                        fontSize: 8, // Kleinere Schrift für den Code
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Abstand
              pw.SizedBox(width: spacing),
              // Short Code wenn aktiviert
              if (displayText.isNotEmpty)
                pw.Container(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    displayText,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/label.pdf");
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Error creating PDF: $e');
      rethrow;
    }
  }

  // Verbesserte Funktion für die Textbreite
  double calculateTextWidth(String text, double fontSize) {
    double width = 0;

    // Zeichengewichtung (relative Breite)
    Map<String, double> charWidths = {
      'i': 0.3,
      'l': 0.3,
      'I': 0.3,
      'j': 0.4,
      'f': 0.4,
      't': 0.4,
      'r': 0.5,
      // Standard für nicht definierte Zeichen
      'default': 0.7,
      // Breite Zeichen
      'w': 0.9,
      'W': 0.9,
      'm': 0.9,
      'M': 0.9,
      'O': 0.8,
      'G': 0.8,
      // Sonderzeichen
      '-': 0.4,
      '.': 0.3,
      ' ': 0.3,
    };

    // Jedes Zeichen einzeln bewerten
    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      double factor = charWidths[char] ?? charWidths['default']!;
      width += fontSize * factor;
    }

    return width;
  }


  Future<File> _generatePdfForPrinter2() async {
    final pdf = pw.Document();

    // Barcode mit Shop-ID generieren wenn Online Shop aktiv ist
    String displayBarcode = barcodeData;
    if (!_isExistingOnlineShopItem && _onlineShopItem && selectedBarcodeType == BarcodeType.production) {
      String formattedShopId = lastShopItem.toString().padLeft(4, '0');
      displayBarcode = '$barcodeData.$formattedShopId';
    }

    final double labelWidth = selectedLabel?.width.toDouble() ?? 38;
    final double scaleFactor = labelWidth / 38;

    // Initiale Größen
    double mainCodeSize = 17.0 * scaleFactor;
    double featureSize = 11.0 * scaleFactor;

    // Basisgrößen
    final double barcodeHeight = 20.0 * scaleFactor;
    final double barcodeWidth = 80.0 * scaleFactor;
    final double spacing = 2 * scaleFactor;
    final double textSize = 7 * scaleFactor;

    // Firebase-Einstellungen abrufen
    final officeSettings = await FirebaseFirestore.instance
        .collection('general_data')
        .doc('office')
        .get();

    // Maximale Etikettenlänge aus Firebase laden (Default: 206)
    // Mit Mindestlänge von 80 (ca. 75mm)
    final double MAX_LABEL_LENGTH = max(
        officeSettings.data()?['maxLabelLength']?.toDouble() ?? 206.0,
        80.0
    );

    // Hauptabkürzungen für erste Zeile
    List<String> mainElements = [];
    // Features für zweite Zeile
    List<String> featureElements = [];

    if (_useShortCodes) {
      if (_shortCodeDisplay != null) {
        mainElements.add(_shortCodeDisplay!);
      }

      if (selectedBarcodeType == BarcodeType.production) {
        final parts = barcodeData.split('.');
        if (parts.length >= 3) {
          final features = parts[2];
          if (features[0] == '1' && _productionFeatures['thermo']!) featureElements.add('Th');
          if (features[1] == '1' && _productionFeatures['hasel']!) featureElements.add('Ha');
          if (features[2] == '1' && _productionFeatures['mondholz']!) featureElements.add('Mo');
          if (features[3] == '1' && _productionFeatures['fsc']!) featureElements.add('FSC');
          if (parts.length >= 4 && _productionFeatures['year']!) featureElements.add('${parts[3]}');
        }
      }
    }

    // Funktion für die Textbreitenberechnung
    double calculateTextWidth(String text, double fontSize) {
      double width = 0;
      Map<String, double> charWidths = {
        'i': 0.3, 'l': 0.3, 'I': 0.3, 'j': 0.4, 'f': 0.4, 't': 0.4, 'r': 0.5,
        'default': 0.7,
        'w': 0.9, 'W': 0.9, 'm': 0.9, 'M': 0.9, 'O': 0.8, 'G': 0.8,
        '-': 0.4, '.': 0.3, ' ': 0.3,
      };

      for (int i = 0; i < text.length; i++) {
        String char = text[i];
        double factor = charWidths[char] ?? charWidths['default']!;
        width += fontSize * factor;
      }
      return width;
    }

    // Funktion zur Berechnung der Gesamtlänge
    double calculateTotalLength() {
      double totalLength = barcodeWidth + spacing;

      // Text-Elemente
      if (mainElements.isNotEmpty) {
        double textWidth = 0;
        for (var element in mainElements) {
          textWidth += calculateTextWidth(element, mainCodeSize) + spacing;
        }
        totalLength += textWidth;
      }

      // Feature-Elemente
      if (featureElements.isNotEmpty) {
        double featureWidth = 0;
        for (var element in featureElements) {
          featureWidth += calculateTextWidth(element, featureSize) + (spacing * 3);
        }
        totalLength = max(totalLength, barcodeWidth + spacing + featureWidth);
      }

      // Puffer hinzufügen
      totalLength += 10 * scaleFactor;

      return totalLength;
    }

    // Iteratives Verkleinern der Schriftgröße, wenn nötig
    double totalLength = calculateTotalLength();
    int iterations = 0;
    final int MAX_ITERATIONS = 200; // Begrenzen um Endlosschleifen zu vermeiden

    while (totalLength > MAX_LABEL_LENGTH && iterations < MAX_ITERATIONS) {
      // Schriftgrößen um 5% verkleinern
      mainCodeSize *= 0.95;
      featureSize *= 0.95;

      // Neu berechnen
      totalLength = calculateTotalLength();
      iterations++;

      print("Iteration $iterations: Länge=$totalLength, Haupttextgröße=$mainCodeSize, Feature-Größe=$featureSize");
    }

    // Absolute Grenze durchsetzen
    if (totalLength > MAX_LABEL_LENGTH) {
      totalLength = MAX_LABEL_LENGTH;
      print("Warnung: Maximale Etikettenlänge erreicht. Einige Inhalte könnten abgeschnitten werden.");
    }

    final pageFormat = PdfPageFormat(totalLength, labelWidth, marginAll: 0);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              if (mainElements.isNotEmpty || featureElements.isNotEmpty) pw.SizedBox(width: 5*spacing),
              // Barcode-Bereich
              pw.Container(
                width: barcodeWidth,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: displayBarcode,
                      height: barcodeHeight,
                      drawText: false,
                    ),
                    pw.SizedBox(height: spacing / 2),
                    pw.Text(
                      displayBarcode,
                      style: pw.TextStyle(
                        fontSize: _onlineShopItem ? textSize*0.8 : textSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              if (mainElements.isNotEmpty || featureElements.isNotEmpty)
                pw.SizedBox(width: 5*spacing),

              // Zwei Spalten mit Elementen
              if (mainElements.isNotEmpty || featureElements.isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    // Erste Zeile: Hauptabkürzungen
                    if (mainElements.isNotEmpty)
                      pw.Row(
                        children: mainElements.map((element) => pw.Container(
                          padding: pw.EdgeInsets.symmetric(horizontal: spacing/2),
                          child: pw.Text(
                            element,
                            style: pw.TextStyle(
                              fontSize: mainCodeSize,  // Angepasste Größe
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        )).toList(),
                      ),

                    pw.SizedBox(height: spacing /2),

                    // Zweite Zeile: Features in Kästchen
                    if (featureElements.isNotEmpty)
                      pw.Row(
                        children: featureElements.map((element) => pw.Container(
                          margin: pw.EdgeInsets.only(right: spacing),
                          padding: pw.EdgeInsets.symmetric(
                              horizontal: spacing,
                              vertical: spacing/5
                          ),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(width: 0.5),
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                          child: pw.Text(
                            element,
                            style: pw.TextStyle(
                              fontSize: featureSize,  // Angepasste Größe
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        )).toList(),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/label.pdf");
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Error creating PDF: $e');
      rethrow;
    }
  }

  Future<File> _generatePdfForPrinter() async {
    final pdf = pw.Document();

    double pageWidth = selectedLabel?.width.toDouble() ?? 62.0;
    double barcodeArea = pageWidth * 0.9;  // 90% der Label-Breite
    double textHeight = pageWidth * 0.15;
    double effectiveHeight = pageWidth;
    double effectiveWidth = barcodeArea;

    // Hier ist der Trick:
    // - effectiveWidth wird zur Länge des Labels nach der Drehung
    // - effectiveHeight wird zur Breite des Labels nach der Drehung

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          effectiveWidth,
          effectiveHeight,
          marginAll: 0,
        ),
        build: (pw.Context context) {
          return pw.Row(
            children: [
              pw.Transform.rotate(
                angle: pi/2,
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: barcodeArea,
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.BarcodeWidget(
                            data: barcodeData,
                            barcode: pw.Barcode.code128(),
                            width: barcodeArea,
                            height: effectiveHeight * 0.3,
                            drawText: false,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            barcodeData,
                            style: pw.TextStyle(
                              fontSize: textHeight,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_useShortCodes && _shortCodeDisplay != null)
                      pw.Container(

                        width: 10.0,
                        child: pw.Text(
                          _shortCodeDisplay!,
                          style: pw.TextStyle(
                            fontSize: textHeight,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/label.pdf");
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Error creating PDF: $e');
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

          Padding(
            padding: const EdgeInsets.fromLTRB(8,8,8,0),
            child: Row(
              children: [
                Expanded(
                  child:ElevatedButton(
                    onPressed: _showProductSearchDialog,
                    child: kIsWeb
                        ? const Text('Suchen',style: smallHeadline,)
                        : const Icon(Icons.search),
                  )
                ),
              if(!kIsWeb)  const SizedBox(width: 8),
                if(!kIsWeb)   Expanded(
                  child: ElevatedButton(
                    onPressed: _startScanner,
                    child:



                    const Icon(Icons.qr_code_scanner),

                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                  ElevatedButton(
                    onPressed: () => _showManualInputDialog(),

                    child: kIsWeb
                        ? const Text('Manuelle Eingabe',style: smallHeadline,)
                        : const Icon(Icons.keyboard),

                  ),
                ),
              ],
            ),
          ),

          AbbreviationSelector(
            selectedTypes: _selectedAbbreviationTypes,
            onTypeToggled: _toggleAbbreviationType,
            abbreviations: _abbreviations,
            useShortCodes: _useShortCodes,
            onUseShortCodesChanged: (value) async {
              setState(() {
                _useShortCodes = value;
              });
              if (barcodeData.isNotEmpty) {
                await _updateShortCodeDisplay();
              }
            },
            barcodeData: barcodeData,
            barcodeType: selectedBarcodeType,
            productionFeatures: _productionFeatures,  // Neu
            onFeatureToggled: _updateProductionFeatures,  // Neu
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

    // Barcode mit Shop-ID generieren wenn Online Shop aktiv ist
    String displayBarcode = barcodeData;
    if (!_isExistingOnlineShopItem && _onlineShopItem && selectedBarcodeType == BarcodeType.production) {
      String formattedShopId = lastShopItem.toString().padLeft(4, '0');
      displayBarcode = '$barcodeData.$formattedShopId';
    }



    // Hauptabkürzungen für erste Zeile
    List<String> mainElements = [];
    // Features für zweite Zeile
    List<String> featureElements = [];

    if (_useShortCodes) {
      if (_shortCodeDisplay != null) {
        mainElements.add(_shortCodeDisplay!);
      }

      if (selectedBarcodeType == BarcodeType.production) {
        final parts = barcodeData.split('.');
        if (parts.length >= 3) {
          final features = parts[2];
          if (features[0] == '1' && _productionFeatures['thermo']!) featureElements.add('Th');
          if (features[1] == '1' && _productionFeatures['hasel']!) featureElements.add('Ha');
          if (features[2] == '1' && _productionFeatures['mondholz']!) featureElements.add('Mo');
          if (features[3] == '1' && _productionFeatures['fsc']!) featureElements.add('FSC');
          if (parts.length >= 4 && _productionFeatures['year']!) featureElements.add('${parts[3]}');
        }
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        height: 180,
        padding: EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BarcodeWidget(
                  data: displayBarcode,  // Hier wird der möglicherweise modifizierte Barcode verwendet
                  barcode: Barcode.code128(),
                  height: 60,
                  width: 200,
                  drawText: false,
                ),
                SizedBox(height: 4),
                Text(
                  displayBarcode,  // Und hier auch
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(width: 16),
            if (_useShortCodes)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Erste Zeile: Hauptabkürzung
                  if (mainElements.isNotEmpty)
                    Text(
                      mainElements.first,
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(height: 8),
                  // Zweite Zeile: Features in Boxen
                  if (featureElements.isNotEmpty)
                    Row(
                      children: featureElements.map((feature) => Container(
                        margin: EdgeInsets.only(right: 8),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: primaryAppColor),
                        ),
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            color: primaryAppColor,
                          ),
                        ),
                      )).toList(),
                    ),
                ],
              ),
          ],
        ),
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


  //
  //
  // Future<void> _updateShortCodeDisplay() async {
  //   if (!_useShortCodes || barcodeData.isEmpty) {
  //     setState(() {
  //       _shortCodeDisplay = null;
  //     });
  //     return;
  //   }
  //
  //   try {
  //     // Barcode in 2-Ziffern-Gruppen aufteilen
  //     String code = barcodeData.replaceAll('.', ''); // Punkte entfernen
  //     List<String> parts = [];
  //     for (int i = 0; i < code.length; i += 2) {
  //       if (i + 2 <= code.length) {
  //         parts.add(code.substring(i, i + 2));
  //       }
  //     }
  //
  //     if (parts.length < 4) return;
  //
  //     List<String> shorts = [];
  //
  //     // Instrument (erste 2 Ziffern)
  //     var instrumentDoc = await FirebaseFirestore.instance
  //         .collection('instruments')
  //         .doc(parts[0])
  //         .get();
  //     if (instrumentDoc.exists) {
  //       shorts.add(instrumentDoc.data()?['short'] ?? '');
  //     }
  //
  //     // Part Type (zweite 2 Ziffern)
  //     var partDoc = await FirebaseFirestore.instance
  //         .collection('parts')
  //         .doc(parts[1])
  //         .get();
  //     if (partDoc.exists) {
  //       shorts.add(partDoc.data()?['short'] ?? '');
  //     }
  //
  //     // Origin (dritte 2 Ziffern)
  //     var originDoc = await FirebaseFirestore.instance
  //         .collection('wood_types')
  //         .doc(parts[2])
  //         .get();
  //     if (originDoc.exists) {
  //       shorts.add(originDoc.data()?['short'] ?? '');
  //     }
  //
  //     // Material (vierte 2 Ziffern)
  //     var materialDoc = await FirebaseFirestore.instance
  //         .collection('qualities')
  //         .doc(parts[3])
  //         .get();
  //     if (materialDoc.exists) {
  //       shorts.add(materialDoc.data()?['short'] ?? '');
  //     }
  //
  //     setState(() {
  //       _shortCodeDisplay = shorts.join('-');
  //     });
  //     print('Abkürzungen gefunden: $shorts');
  //   } catch (e) {
  //     print('Fehler beim Laden der Abkürzungen: $e');
  //   }
  // }

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
                child: Column(
                  children: [
                    if (selectedBarcodeType == BarcodeType.production)
                      Card(
                      color: Colors.white,
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
                                    Icons.shopping_cart_checkout,
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
                                      Row(
                                        children: [
                                          Text(
                                            'Shop',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (_onlineShopItem)
                                            Expanded(
                                              child: Container(
                                                height: 40,
                                                child: TextField(
                                                  controller: _priceController,
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  decoration: InputDecoration(
                                                   //prefixIcon: Icon(Icons.currency_bitcoin, color: primaryAppColor),
                                                    prefixText: 'CHF ',
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                                    ),
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                                  ),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _onlineShopPrice = double.tryParse(value) ?? 0.0;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.9,
                                  child: Switch(
                                    value: _onlineShopItem,
                                    onChanged: (bool value) {
                                      setState(() {
                                        _onlineShopItem = value;
                                        if (!value) {
                                          _priceController.clear();
                                          _onlineShopPrice = 0.0;
                                        } else if (productData != null && productData!['price_CHF'] != null) {
                                          // Restore price from productData when toggling back on
                                          _onlineShopPrice = productData!['price_CHF'].toDouble();
                                          _priceController.text = _onlineShopPrice.toString();
                                        }
                                      });
                                    },
                                    activeColor: primaryAppColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  'Shop-ID',
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

                                        Text(
                                          '$lastShopItem',
                                          style: TextStyle(
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

                          ],
                        ),
                      ),
                    ),
                    Card(
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
                                        'Drucken',
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
                                      // Neue Zeile für die Etikettenbreite
                                      Text(
                                        'Etikett: ${selectedLabel?.width ?? "-"} mm',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _isPrinterOnline ? Colors.black54 : Colors.grey,
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
                                  'Etiketten:',
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
                            const SizedBox(height: 16),
                            if (_onlineShopItem && selectedBarcodeType == BarcodeType.production)
                              _isExistingOnlineShopItem
                                  ? // Nur ein Button zum erneuten Drucken für existierende Shop-Artikel
                              Container(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: barcodeData.isEmpty || !_isPrinterOnline
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
                                    'Barcode erneut drucken',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: barcodeData.isEmpty || !_isPrinterOnline
                                          ? Colors.grey.shade600
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ):
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: barcodeData.isEmpty
                                            ? null
                                            : () => _bookOnlineShopItem(lastShopItem),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[200],
                                          disabledBackgroundColor: Colors.grey.shade300,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Nur buchen',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: barcodeData.isEmpty
                                                ? Colors.grey.shade600
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: barcodeData.isEmpty || !_isPrinterOnline
                                        ? null
                                        : () async {
                                      // 1. Zuerst Lagerbestand prüfen, ohne ihn zu aktualisieren
                                      try {
                                        // Extrahiere den Verkaufscode
                                        String inventoryId = barcodeData;
                                        if (selectedBarcodeType == BarcodeType.production) {
                                          final parts = barcodeData.split('.');
                                          if (parts.length >= 2) {
                                            inventoryId = '${parts[0]}.${parts[1]}';
                                          }
                                        }

                                        // Lagerbestand prüfen (ohne zu aktualisieren)
                                        final inventoryDoc = await FirebaseFirestore.instance
                                            .collection('inventory')
                                            .doc(inventoryId)
                                            .get();

                                        if (!inventoryDoc.exists) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Produkt nicht im Lager gefunden'), backgroundColor: Colors.red),
                                          );
                                          return;
                                        }

                                        final currentQuantity = inventoryDoc.data()?['quantity'] ?? 0;

                                        // 2. Prüfen ob mindestens 1 auf Lager
                                        if (currentQuantity < 1) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Nicht genügend Lagerbestand verfügbar'), backgroundColor: Colors.red),
                                          );
                                          return;
                                        }

                                        // 3. Lagerbestand ist ok - jetzt drucken
                                        bool druckErfolgreich = await printLabel(context);

                                        // 4. Wenn Druck erfolgreich, dann buchen
                                        if (druckErfolgreich) {
                                          await _bookOnlineShopItem(lastShopItem);
                                        } else {
                                          // Druckfehler
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Buchung wurde nicht durchgeführt, da der Druck fehlgeschlagen ist'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Fehler bei der Lagerprüfung: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryAppColor,
                                      disabledBackgroundColor: Colors.grey.shade300,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Drucken & buchen',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: barcodeData.isEmpty || !_isPrinterOnline
                                            ? Colors.grey.shade600
                                            : Colors.white,
                                      ),
                                    ),
                                  )
                                ],
                              )
                            else
                            // Ursprünglicher einzelner Button wenn Online-Shop deaktiviert
                              Container(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: barcodeData.isEmpty || !_isPrinterOnline
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
                                    !_isPrinterOnline
                                        ? 'Drucker nicht verfügbar'
                                        : 'Drucken',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: barcodeData.isEmpty || !_isPrinterOnline
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
                  ],
                ),
              )



            ],
          ),
        ),
      );
        }
    )


    );
  }
}

// Neue Klasse für die Abkürzungsauswahl
// In der AbbreviationSelector Klasse:
class AbbreviationSelector extends StatefulWidget {
  final Map<String, bool> selectedTypes;
  final Function(String, bool) onTypeToggled;
  final Map<String, List<AbbreviationItem>> abbreviations;
  final bool useShortCodes;
  final Function(bool) onUseShortCodesChanged;
  final String barcodeData;
  final BarcodeType barcodeType;
  final Map<String, bool> productionFeatures;  // Neu
  final Function(String, bool) onFeatureToggled;  // Neu

  const AbbreviationSelector({
    Key? key,
    required this.selectedTypes,
    required this.onTypeToggled,
    required this.abbreviations,
    required this.useShortCodes,
    required this.onUseShortCodesChanged,
    required this.barcodeData,
    required this.barcodeType,
    required this.productionFeatures,
    required this.onFeatureToggled,
  }) : super(key: key);

  @override
  State<AbbreviationSelector> createState() => _AbbreviationSelectorState();
}

class _AbbreviationSelectorState extends State<AbbreviationSelector> {
  bool _isExpanded = true; // Neuer State für den Expanded-Zustand
  Map<String, bool> _productionFeatures = {
    'thermo': false,
    'hasel':false,
    'mondholz': false,
    'fsc': false,
    'year': false,
  };
  String? _year;

  @override
  void initState() {
    super.initState();
    // Statt direkt setState aufzurufen, verzögern wir die Initialisierung
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _parseProductionCode();
    });
  }

  @override
  void didUpdateWidget(AbbreviationSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.barcodeData != oldWidget.barcodeData) {
      _parseProductionCode();
    }
  }

  void _parseProductionCode() {
    if (widget.barcodeType == BarcodeType.production && widget.barcodeData.isNotEmpty) {
      final parts = widget.barcodeData.split('.');
      if (parts.length >= 3) {
        final features = parts[2];

        setState(() {
          _productionFeatures = {
            'thermo': features[0] == '1',
            'hasel': features[1] == '1',
            'mondholz': features[2] == '1',
            'fsc': features[3] == '1',
            'year': parts.length >= 4
          };
        });
      }
    }
  }

  void _showFeatureNotAvailable(String feature) {
    Fluttertoast.showToast(
      msg: "Dieser Barcode enthält kein $feature",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  Widget _buildProductionFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text(
          'Zusätzliche Merkmale',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureChip(
              'Th',
              _productionFeatures['thermo'] ?? false,
                  (value) {
                // Wenn Feature im Barcode als '1' markiert ist
                if (widget.barcodeData.isNotEmpty) {
                  final parts = widget.barcodeData.split('.');
                  if (parts.length >= 3 && parts[2][0] == '1') {
                    setState(() {
                      _productionFeatures['thermo'] = !_productionFeatures['thermo']!;
                      widget.onFeatureToggled('thermo', !(widget.productionFeatures['thermo'] ?? false));

                    });
                  } else {
                    _showFeatureNotAvailable('Thermo-Behandlung');
                  }
                }
              },
            ),
            _buildFeatureChip(
              'Ha',
              _productionFeatures['hasel'] ?? false,
                  (value) {
                if (widget.barcodeData.isNotEmpty) {
                  final parts = widget.barcodeData.split('.');
                  if (parts.length >= 3 && parts[2][1] == '1') {
                    setState(() {
                      _productionFeatures['hasel'] = !_productionFeatures['hasel']!;
                      widget.onFeatureToggled('hasel', !(widget.productionFeatures['hasel'] ?? false));
    });

                  } else {
                    _showFeatureNotAvailable('Hasel-Behandlung');
                  }
                }
              },
            ),
            _buildFeatureChip(
              'Mo',
              _productionFeatures['mondholz'] ?? false,
                  (value) {
                if (widget.barcodeData.isNotEmpty) {
                  final parts = widget.barcodeData.split('.');
                  if (parts.length >= 3 && parts[2][2] == '1') {
    setState(() {
      _productionFeatures['mondholz'] = !_productionFeatures['mondholz']!;

      widget.onFeatureToggled('mondholz', !(widget.productionFeatures['mondholz'] ?? false));

    });
                  } else {
                    _showFeatureNotAvailable('Mondholz');
                  }
                }
              },
            ),
            _buildFeatureChip(
              'FSC',
              _productionFeatures['fsc'] ?? false,
                  (value) {
                if (widget.barcodeData.isNotEmpty) {
                  final parts = widget.barcodeData.split('.');
                  if (parts.length >= 3 && parts[2][3] == '1') {
    setState(() {
    _productionFeatures['fsc'] = !_productionFeatures['fsc']!;

                      widget.onFeatureToggled('fsc', !(widget.productionFeatures['fsc'] ?? false));
    });

                  } else {
                    _showFeatureNotAvailable('FSC-Zertifizierung');
                  }
                }
              },
            ),

              _buildFeatureChip(
                'YY',
                _productionFeatures['year'] ?? false,
                    (value) {
    setState(() {
    _productionFeatures['year'] = !_productionFeatures['year']!;
                    widget.onFeatureToggled('year', !(widget.productionFeatures['year'] ?? false));
    });


                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureChip(
      String short,
      bool isActive,
      Function(bool?) onChanged,
      ) {
    bool isAvailable = false;
    if (widget.barcodeData.isNotEmpty && widget.barcodeType == BarcodeType.production) {
      final parts = widget.barcodeData.split('.');
      if (parts.length >= 3) {
        final features = parts[2];
        isAvailable = switch (short) {
          'Th' => features[0] == '1',
          'Ha' => features[1] == '1',
          'Mo' => features[2] == '1',
          'FSC' => features[3] == '1',
          'YY' => parts.length >= 4,
          _ => false
        };
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.grey[100] : Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAvailable ? Colors.grey[300]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            short,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isAvailable ? primaryAppColor : Colors.grey,
            ),
          ),
          Checkbox(
            value: isActive,  // Hier nur isActive statt isActive && isAvailable
            onChanged: isAvailable ? onChanged : null,
            activeColor: primaryAppColor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: EdgeInsets.all(12.0),
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
              Icon(
                Icons.short_text,
                color: primaryAppColor.withOpacity(0.6),
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Abkürzungen',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: widget.useShortCodes,
                          onChanged: widget.onUseShortCodesChanged,
                          activeColor: primaryAppColor,
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: widget.useShortCodes ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 24),
                ...widget.abbreviations.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getGroupTitle(entry.key),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          Checkbox(
                            value: widget.selectedTypes[entry.key] ?? false,
                            onChanged: (bool? value) {
                              if (value != null) {
                                widget.onTypeToggled(entry.key, value);
                              }
                            },
                            activeColor: primaryAppColor,
                          ),
                        ],
                      ),
                    ],
                  );
                }).toList(),
                if (widget.barcodeType == BarcodeType.production &&
                    widget.barcodeData.isNotEmpty)
                  _buildProductionFeatures(),
              ],
            ) : Container(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}


  String _getGroupTitle(String key) {
    switch (key) {
      case 'instruments':
        return 'Instrumente';
      case 'wood_types':
        return 'Holzarten';
      case 'parts':
        return 'Bauteile';
      case 'qualities':
        return 'Qualitäten';
      default:
        return key;
    }
  }

  Widget _buildAbbreviationChip(AbbreviationItem item) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        '${item.short} - ${item.name}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[800],
        ),
      ),
    );
  }


// Hilfsklasse für Abkürzungselemente
class AbbreviationItem {
  final String code;
  final String name;
  final String short;

  AbbreviationItem({
    required this.code,
    required this.name,
    required this.short,
  });

  factory AbbreviationItem.fromFirestore(Map<String, dynamic> data) {
    return AbbreviationItem(
      code: data['code'] ?? '',
      name: data['name'] ?? '',
      short: data['short'] ?? '',
    );
  }
}