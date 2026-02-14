
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/home/production_screen.dart';
import 'package:tonewood/analytics/roundwood/roundwood_entry_screen.dart';
import 'package:tonewood/warehouse/warehouse_screen.dart';
import 'package:tonewood/production/roundwood_selection_dialog.dart';
import 'package:tonewood/production/stamm_auswahl_sheet.dart';
import 'package:tonewood/production/stamm_buchung_sheet.dart';
import '../analytics/roundwood/models/roundwood_models.dart';
import '../analytics/roundwood/roundwood_list.dart';
import '../analytics/roundwood/services/roundwood_service.dart';
import '../constants.dart';
import '../services/icon_helper.dart';
import '../home/add_product_screen.dart';
import 'package:intl/intl.dart';

import '../home/barcode_scanner.dart';
import 'barcode_input_dialog.dart';
enum BarcodeType {
  sales,
  production,
}
class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  ProductManagementScreenState createState() => ProductManagementScreenState();
}

class ProductManagementScreenState extends State<ProductManagementScreen>
    with SingleTickerProviderStateMixin {  // ← Mixin hinzufügen
  late TabController _verwaltungTabController;

  @override
  void initState() {
    super.initState();
    _verwaltungTabController = TabController(length: 2, vsync: this);
  }

  final TextEditingController quantityController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();

  // Neue Controller für die Teile der Artikelnummer
  final TextEditingController partOneController = TextEditingController();
  final TextEditingController partTwoController = TextEditingController();
  Map<String, dynamic>? selectedProduct;  // Hinzugefügt
  String? selectedBarcode;
  BarcodeType selectedBarcodeType = BarcodeType.sales;


  void _showEditBarcodeInputDialog() async {
    final barcode = await showBarcodeInputDialog(
      context: context,
      type: BarcodeInputType.sales,  // Nur 8 Ziffern: IIPP.HHQQ
    );

    if (barcode != null && barcode.isNotEmpty) {
      _searchProductAndEdit(barcode);
    }
  }


  Future<void> _openLastStammBuchung() async {
    try {
      // Lade die letzten Stämme und filtere client-seitig
      final snapshot = await FirebaseFirestore.instance
          .collection('roundwood')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        AppToast.show(message: 'Keine Stämme vorhanden', height: h);
        return;
      }

      // Finde den ersten offenen Stamm (is_closed ist null, false oder fehlt)
      final offeneStaemme = snapshot.docs.where((doc) {
        final data = doc.data();
        final isClosed = data['is_closed'];
        return isClosed != true; // null, false oder fehlt = offen
      }).toList();

      if (offeneStaemme.isEmpty) {
        AppToast.show(message: 'Keine offenen Stämme vorhanden', height: h);
        return;
      }

      // Sortiere nach last_booking falls vorhanden, sonst nach timestamp
      offeneStaemme.sort((a, b) {
        final aBooking = a.data()['last_booking'] as Timestamp?;
        final bBooking = b.data()['last_booking'] as Timestamp?;

        if (aBooking != null && bBooking != null) {
          return bBooking.compareTo(aBooking);
        } else if (aBooking != null) {
          return -1;
        } else if (bBooking != null) {
          return 1;
        }
        return 0; // Behalte ursprüngliche Reihenfolge (nach timestamp)
      });

      final doc = offeneStaemme.first;
      if (!mounted) return;

      showStammBuchungSheet(
        context: context,
        stammId: doc.id,
        stammData: doc.data(),
      );
    } catch (e) {
      debugPrint('Fehler beim Laden des letzten Stamms: $e');
      AppToast.show(message: 'Fehler: $e', height: h);
    }
  }
  Future<void> _scanBarcodeForEdit() async {
    try {
      final String? barcodeResult = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleBarcodeScannerPage(),
        ),
      );
      print('Scanned barcode: $barcodeResult'); // Debug

      if (barcodeResult != '-1') {
        await _searchProductAndEdit(barcodeResult!);
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

  void _showBarcodeInputDialog() async {
    final barcode = await showBarcodeInputDialog(
      context: context,
      type: BarcodeInputType.production,
    );

    if (barcode != null && barcode.isNotEmpty) {
      _checkProductAndShowQuantity(barcode);
    }
  }
  Future<void> _scanBarcode() async {
    try {
      final String? barcodeResult = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleBarcodeScannerPage(),
        ),
      );

      if (barcodeResult != '-1') {
        print("bc:$barcodeResult");
        // Prüfe und validiere das Barcode-Format
        if (!_isValidProductionBarcode(barcodeResult!)) {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Ermöglicht volle Höhe
      backgroundColor: Colors.transparent, // Für abgerundete Ecken
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ProductionScreen
              Expanded(
                child: ProductionScreen(
                  isDialog: true,
                  onProductSelected: (productId) {
                    Navigator.pop(context);
                    _checkProductAndShowQuantity(productId);
                  },
                ),
              ),
            ],
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

  void _saveStockEntry(
      String productId,
      Map<String, dynamic> productData,
      int quantity, {
        String? roundwoodId,
        Map<String, dynamic>? roundwoodData,
      }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final parts = productId.split('.');
      final shortBarcode = '${parts[0]}.${parts[1]}';

      // 1. Update production collection (Hauptprodukt)
      final productionRef = firestore.collection('production').doc(productId);
      batch.update(productionRef, {
        'quantity': FieldValue.increment(quantity),
        'last_stock_entry': FieldValue.serverTimestamp(),
        'last_stock_change': quantity,
      });

      // 2. Update inventory collection
      final inventoryRef = firestore.collection('inventory').doc(shortBarcode);
      batch.set(inventoryRef, {
        'quantity': FieldValue.increment(quantity),
        'last_stock_entry': FieldValue.serverTimestamp(),
        'last_stock_change': quantity,
      }, SetOptions(merge: true));

      // 3. Get next batch number
      final batchesSnapshot = await productionRef
          .collection('batch')
          .orderBy('batch_number', descending: true)
          .limit(1)
          .get();

      int nextBatchNumber = 1;
      if (batchesSnapshot.docs.isNotEmpty) {
        nextBatchNumber = (batchesSnapshot.docs.first.data()['batch_number'] as int) + 1;
      }

      // 4. Create batch entry in subcollection (für Abwärtskompatibilität)
      final batchRef = productionRef
          .collection('batch')
          .doc(nextBatchNumber.toString().padLeft(4, '0'));

      final batchData = {
        'batch_number': nextBatchNumber,
        'quantity': quantity,
        'stock_entry_date': DateTime.now(),
        // NEU: Stamm-Referenz
        'roundwood_id': roundwoodId,
        'roundwood_internal_number': roundwoodData?['internal_number'],
        'roundwood_year': roundwoodData?['year'],
      };
      batch.set(batchRef, batchData);

      // 5. NEU: Create batch in flat collection (production_batches)
      final price = (productData['price_CHF'] as num?)?.toDouble() ?? 0.0;
      final value = quantity * price;

      final flatBatchRef = firestore.collection('production_batches').doc();
      final flatBatchData = {
        // Referenzen
        'product_id': productId,
        'batch_number': nextBatchNumber,
        'roundwood_id': roundwoodId,
        'roundwood_internal_number': roundwoodData?['internal_number'],
        'roundwood_year': roundwoodData?['year'],

        // Zeitdaten
        'stock_entry_date': FieldValue.serverTimestamp(),
        'year': productData['year'] ?? DateTime.now().year,

        // Mengen
        'quantity': quantity,
        'value': value,
        'unit': productData['unit'] ?? 'Stk',
        'price_CHF': price,

        // Produkt-Details (denormalisiert)
        'instrument_code': productData['instrument_code'],
        'instrument_name': productData['instrument_name'],
        'part_code': productData['part_code'],
        'part_name': productData['part_name'],
        'wood_code': productData['wood_code'],
        'wood_name': productData['wood_name'],
        'quality_code': productData['quality_code'],
        'quality_name': productData['quality_name'],

        // Spezial-Flags
        'moonwood': productData['moonwood'] ?? false,
        'haselfichte': productData['haselfichte'] ?? false,
        'thermally_treated': productData['thermally_treated'] ?? false,
        'FSC_100': productData['FSC_100'] ?? false,
      };
      batch.set(flatBatchRef, flatBatchData);

      // 6. Add stock entry for history
      final entryRef = firestore.collection('stock_entries').doc();
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
        // NEU: Stamm-Referenz auch hier
        'roundwood_id': roundwoodId,
        'roundwood_internal_number': roundwoodData?['internal_number'],
      });

      // Commit all changes
      await batch.commit();

      if (!mounted) return;

      // Erfolgsmeldung mit Stamm-Info
      String message = 'Wareneingang von $quantity ${productData['unit'] ?? 'Stück'} gebucht';
      if (roundwoodData != null) {
        message += ' (Stamm ${roundwoodData['internal_number']}/${roundwoodData['year']})';
      }

      AppToast.show(message: message, height: h);

    } catch (e) {
      print('Error saving stock entry: $e');
      if (!mounted) return;
      AppToast.show(message: 'Fehler beim Speichern: $e', height: h);
    }
  }
  void _showQuantityDialog(String productId, Map<String, dynamic> productData) {
    showRoundwoodSelection(
      context: context,
      productId: productId,
      productData: productData,
      onConfirm: (quantity, roundwoodId, roundwoodData) {
        _saveStockEntry(
          productId,
          productData,
          quantity,
          roundwoodId: roundwoodId,
          roundwoodData: roundwoodData,
        );
      },
    );
  }

// Neue Hilfsmethode für editierbare Properties
  Widget _buildEditablePropertyRow(String label, ValueNotifier<bool> controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller,
            builder: (context, value, child) {
              return Switch(
                value: value,
                onChanged: (newValue) {
                  controller.value = newValue;
                },
                activeColor: Colors.green[700],
              );
            },
          ),
        ],
      ),
    );
  }

// Neue Methode für die Bestätigungsdialog
  void _showProductChangeConfirmation(
      String oldProductId,
      Map<String, dynamic> productData,
      bool thermallyTreated,
      bool haselfichte,
      bool moonwood,
      bool fsc100,
      String year,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              getAdaptiveIcon(iconName: 'warning', defaultIcon:
                Icons.warning,
                color: Colors.orange[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Wichtiger Hinweis'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diese Änderung hat folgende Auswirkungen:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChangeItem('Die alte Produktions-ID wird gelöscht', oldProductId),
                    const SizedBox(height: 8),
                    _buildChangeItem('Eine neue Produktions-ID wird generiert', _generateNewProductId(productData, thermallyTreated, haselfichte, moonwood, fsc100, year)),
                    const SizedBox(height: 8),
                    const Text(
                      '• Alle Chargen werden übertragen',
                      style: TextStyle(fontSize: 13),
                    ),
                    const Text(
                      '• Die Lagerbestände werden aktualisiert',
                      style: TextStyle(fontSize: 13),
                    ),
                    const Text(
                      '• Diese Aktion kann nicht rückgängig gemacht werden',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Möchtest du wirklich fortfahren?',
                style: TextStyle(fontWeight: FontWeight.w500),
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
                Navigator.pop(context);
                _performProductChange(
                  oldProductId,
                  productData,
                  thermallyTreated,
                  haselfichte,
                  moonwood,
                  fsc100,
                  year,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ja, Änderungen durchführen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChangeItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 13)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(text: label),
                const TextSpan(text: ': '),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// Methode zur Generierung der neuen Produkt-ID
  String _generateNewProductId(
      Map<String, dynamic> productData,
      bool thermallyTreated,
      bool haselfichte,
      bool moonwood,
      bool fsc100,
      String year,
      ) {
    // Eigenschaften-Code generieren nach dem korrekten Format
    String propertiesCode = '';
    propertiesCode += thermallyTreated ? '1' : '0';  // Position 1: Thermo
    propertiesCode += haselfichte ? '1' : '0';       // Position 2: Hasel
    propertiesCode += moonwood ? '1' : '0';          // Position 3: Mondholz
    propertiesCode += fsc100 ? '1' : '0';            // Position 4: FSC

    // Neue ID zusammensetzen im Format: IIPP.HHQQ.EEEE.JJ
    return '${productData['instrument_code']}${productData['part_code']}.${productData['wood_code']}${productData['quality_code']}.${propertiesCode}.${year.substring(2)}'; }

// Methode zur Durchführung der Produktänderung
  Future<void> _performProductChange(
      String oldProductId,
      Map<String, dynamic> productData,
      bool thermallyTreated,
      bool haselfichte,
      bool moonwood,
      bool fsc100,
      String year,
      ) async {
    try {
      // Zeige Ladeindikator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final batch = FirebaseFirestore.instance.batch();

      // Generiere neue Produkt-ID
      final newProductId = _generateNewProductId(
        productData,
        thermallyTreated,
        haselfichte,
        moonwood,
        fsc100,
        year,
      );

      // WICHTIG: Prüfe ob das neue Produkt bereits existiert
      final newProductRef = FirebaseFirestore.instance.collection('production').doc(newProductId);
      final newProductDoc = await newProductRef.get();

      if (newProductDoc.exists) {
        // Produkt existiert bereits - Abbruch!
        Navigator.pop(context); // Schließe Ladeindikator

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  getAdaptiveIcon(iconName: 'error',defaultIcon:Icons.error, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  const Text('Fehler: Produkt existiert bereits'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ein Produkt mit der ID $newProductId existiert bereits in der Datenbank.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Diese Kombination von Eigenschaften ist bereits vorhanden:',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Thermobehandelt: ${thermallyTreated ? "Ja" : "Nein"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Haselfichte: ${haselfichte ? "Ja" : "Nein"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Mondholz: ${moonwood ? "Ja" : "Nein"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• FSC 100%: ${fsc100 ? "Ja" : "Nein"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Jahrgang: $year',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bitte wähle andere Eigenschaften oder breche den Vorgang ab.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Verstanden'),
                ),
              ],
            );
          },
        );
        return; // Beende die Funktion hier
      }

      // 1. Hole alle Daten des alten Produkts inklusive Chargen
      final oldProductRef = FirebaseFirestore.instance.collection('production').doc(oldProductId);
      final oldProductDoc = await oldProductRef.get();

      if (!oldProductDoc.exists) {
        Navigator.pop(context);
        AppToast.show(message: 'Altes Produkt nicht gefunden', height: h);
        return;
      }

      final oldProductData = oldProductDoc.data()!;

      // Hole alle Chargen
      final batchesSnapshot = await oldProductRef.collection('batch').get();

      // 2. Erstelle neues Produkt mit aktualisierten Eigenschaften
      final updatedProductData = {
        ...oldProductData,
        'thermally_treated': thermallyTreated,
        'haselfichte': haselfichte,
        'moonwood': moonwood,
        'FSC_100': fsc100,
        'year': int.parse(year),
        'product_id': newProductId,
        'barcode': newProductId,
        'last_modified': FieldValue.serverTimestamp(),
        'modified_from': oldProductId,
      };

      batch.set(newProductRef, updatedProductData);

      // 3. Kopiere alle Chargen zum neuen Produkt
      for (var batchDoc in batchesSnapshot.docs) {
        final batchData = batchDoc.data();
        final newBatchRef = newProductRef.collection('batch').doc(batchDoc.id);
        batch.set(newBatchRef, {
          ...batchData,
          'migrated_from': oldProductId,
          'migration_date': FieldValue.serverTimestamp(),
        });
      }

      // 4. Update inventory collection wenn nötig
      final parts = oldProductId.split('.');
      final oldShortBarcode = '${parts[0]}.${parts[1]}';
      final newParts = newProductId.split('.');
      final newShortBarcode = '${newParts[0]}.${newParts[1]}';

      if (oldShortBarcode != newShortBarcode) {
        // Hole alte inventory Daten
        final oldInventoryRef = FirebaseFirestore.instance.collection('inventory').doc(oldShortBarcode);
        final oldInventoryDoc = await oldInventoryRef.get();

        if (oldInventoryDoc.exists) {
          final inventoryData = oldInventoryDoc.data()!;

          // Prüfe ob neues inventory bereits existiert
          final newInventoryRef = FirebaseFirestore.instance.collection('inventory').doc(newShortBarcode);
          final newInventoryDoc = await newInventoryRef.get();

          if (newInventoryDoc.exists) {
            // Addiere die Menge zum bestehenden inventory
            batch.update(newInventoryRef, {
              'quantity': FieldValue.increment(inventoryData['quantity'] ?? 0),
              'last_modified': FieldValue.serverTimestamp(),
            });
          } else {
            // Erstelle neuen inventory Eintrag
            batch.set(newInventoryRef, {
              ...inventoryData,
              'last_modified': FieldValue.serverTimestamp(),
              'modified_from': oldShortBarcode,
            });
          }

          // Lösche alten inventory Eintrag nur wenn er nicht mehr gebraucht wird
          // (Prüfe ob noch andere production docs diesen inventory nutzen)
          final otherProductsQuery = await FirebaseFirestore.instance
              .collection('production')
              .where('product_id', isGreaterThanOrEqualTo: oldShortBarcode)
              .where('product_id', isLessThan: oldShortBarcode + '\uf8ff')
              .get();

          if (otherProductsQuery.docs.length <= 1) { // Nur das aktuelle Produkt
            batch.delete(oldInventoryRef);
          }
        }
      }

      // 5. Erstelle Verlaufseintrag
      final historyRef = FirebaseFirestore.instance.collection('product_changes').doc();
      batch.set(historyRef, {
        'old_product_id': oldProductId,
        'new_product_id': newProductId,
        'change_type': 'property_modification',
        'changed_properties': {
          'thermally_treated': thermallyTreated,
          'haselfichte': haselfichte,
          'moonwood': moonwood,
          'FSC_100': fsc100,
          'year': year,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'batches_migrated': batchesSnapshot.docs.length,
      });

      // 6. Lösche altes Produkt und alle Chargen
      for (var batchDoc in batchesSnapshot.docs) {
        batch.delete(batchDoc.reference);
      }
      batch.delete(oldProductRef);

      // Commit aller Änderungen
      await batch.commit();

      // Schließe Ladeindikator
      if (!mounted) return;
      Navigator.pop(context); // Loading dialog
      Navigator.pop(context); // Bottom sheet

      // Zeige Erfolgsmeldung
      AppToast.show(
        message: 'Produkt erfolgreich geändert. Neue ID: $newProductId',
        height: h,
      );

    } catch (e) {
      print('Error changing product: $e');
      if (!mounted) return;
      Navigator.pop(context); // Loading dialog

      AppToast.show(
        message: 'Fehler beim Ändern des Produkts: $e',
        height: h,
      );
    }
  }

// Hilfsmethoden für das Design
  Widget _buildDetailRow({
    required Widget icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionSection({
    required String title,
    required Widget icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
        ),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: icon,
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: value ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: value ? Colors.green[200]! : Colors.red[200]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                getAdaptiveIcon(iconName:value ?  'check_circle':'cancel', defaultIcon:
                  value ? Icons.check_circle : Icons.cancel,
                  color: value ? Colors.green[700] : Colors.red[700],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  value ? 'Ja' : 'Nein',
                  style: TextStyle(
                    color: value ? Colors.green[700] : Colors.red[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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
  void _showStammAuswahlDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StammAuswahlSheet(
          onStammSelected: (stammId, stammData) {
            Navigator.pop(context); // Auswahl-Dialog schließen
            // Buchungs-Sheet öffnen
            showStammBuchungSheet(
              context: context,
              stammId: stammId,
              stammData: stammData,
            );
          },
        );
      },
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
                child:
                ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  children: [
                    // === PRODUKTION BUCHEN ===
                    _buildMenuSection('Produktion buchen'),
                    _buildActionButton(
                      icon: Icons.qr_code,
                      iconName: 'qr_code',
                      title: 'Direkt buchen',
                      subtitle: 'Produkt über Barcode finden',
                      onTap: () => setState(() => selectedAction = 'direkt_buchen'),
                      isSelected: selectedAction == 'direkt_buchen',
                    ),
                    _buildActionButton(
                      icon: Icons.account_tree,
                      iconName: 'account_tree',
                      title: 'Über Stamm buchen',
                      subtitle: 'Erst Stamm wählen, dann Produkte',
                      onTap: () => setState(() => selectedAction = 'ueber_stamm'),
                      isSelected: selectedAction == 'ueber_stamm',
                    ),
                    const Divider(height: 32, indent: 16, endIndent: 16),
                    // === VERWALTUNG ===
                    _buildMenuSection('Verwaltung'),
                    _buildActionButton(
                      icon: Icons.inventory_2,
                      iconName: 'inventory_2',
                      title: 'Produkte',
                      subtitle: 'Bearbeiten & Neu anlegen',
                      onTap: () => setState(() => selectedAction = 'produkte'),
                      isSelected: selectedAction == 'produkte',
                    ),
                    _buildActionButton(
                      icon: Icons.forest,
                      iconName: 'forest',
                      title: 'Rundholz',
                      subtitle: 'Stämme verwalten',
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
  Widget _buildMenuSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isSelected,
    required String iconName,  // Neuer Parameter für adaptive Icons
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
               getAdaptiveIcon(
                  iconName: iconName,
                  defaultIcon: icon,
                  size: 24,
                  color: isSelected ? primaryAppColor : Colors.grey.shade700,
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
  Widget _buildUeberStammPanel() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Über Stamm buchen', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0F4A29))),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  getAdaptiveIcon(iconName: 'account_tree', defaultIcon: Icons.account_tree, size: 64, color: const Color(0xFF0F4A29)),
                  const SizedBox(height: 24),
                  Text('Stamm-basierte Buchung', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Wähle zuerst einen Stamm aus.\nDie Attribute (Holzart, Mondholz, FSC, Jahr) werden automatisch übernommen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showStammAuswahlDialog,  // ← Hier

                    icon: getAdaptiveIcon(iconName: 'forest', defaultIcon: Icons.forest, color: Colors.white),
                    label: const Text('Stamm auswählen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4A29),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildProduktePanel() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Produkte verwalten', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0F4A29))),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return Row(
                children: [
                  Expanded(
                    child: _buildOptionButton(
                      icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit, color: Colors.white),
                      label: 'Bearbeiten',
                      onPressed: () => setState(() => selectedAction = 'bearbeiten'),
                      isWideScreen: isWide,
                      color: const Color(0xFF0F4A29),
                    ),
                  ),
                  SizedBox(width: isWide ? 24 : 12),
                  // NEU: Scannen Button
                  Expanded(
                    child: _buildOptionButton(
                      icon: getAdaptiveIcon(iconName: 'qr_code_scanner', defaultIcon: Icons.qr_code_scanner, color: Colors.white),
                      label: 'Scannen',
                      onPressed: _scanBarcodeForEdit,
                      isWideScreen: isWide,
                      color: const Color(0xFF0F4A29).withOpacity(0.85),
                    ),
                  ),
                  SizedBox(width: isWide ? 24 : 12),
                  Expanded(
                    child: _buildOptionButton(
                      icon: getAdaptiveIcon(iconName: 'add_circle', defaultIcon: Icons.add_circle, color: Colors.white),
                      label: 'Neu anlegen',
                      onPressed: () => setState(() => selectedAction = 'neu'),
                      isWideScreen: isWide,
                      color: const Color(0xFF0F4A29).withOpacity(0.7),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildRightPanel() {
    switch (selectedAction) {
      case 'neu':
        return AddProductScreen(isProduction: true, editMode: false, onSave: () => setState(() => selectedAction = ''));
      case 'direkt_buchen':
      case 'wareneingang':  // Fallback für alte Auswahl
        return _buildWareneingangPanel();
      case 'ueber_stamm':
        return _buildUeberStammPanel();  // NEU
      case 'bearbeiten':
        return _buildBearbeitenPanel();
      case 'produkte':
        return _buildProduktePanel();  // NEU
      case 'rundholz':
        return _buildRundholzManagementPanel();
      default:
        return const Center(child: Text('Bitte wähle eine Aktion aus'));
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
                'Produktion',
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
                              iconName: 'dialpad',  // Passendes Icon für Numpad
                              defaultIcon: Icons.dialpad,
                              color: Colors.white,
                            ),
                            label: 'Barcode eingeben',
                            onPressed: _showBarcodeInputDialog,  // Nutzt jetzt den neuen Dialog
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


  Widget _buildRundholzManagementPanel() {
    return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rundholz',
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
                    // Show help dialog
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
                      'Was möchtest du tun?',
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
                                iconName: 'add_circle',
                                defaultIcon: Icons.add_circle,
                                color: Colors.white,
                              ),
                              label: 'Neues Rundholz',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RoundwoodEntryScreen(),
                                  ),
                                );
                              },
                              isWideScreen: isWideScreen,
                              color: const Color(0xFF0F4A29),
                            ),
                            SizedBox(width: isWideScreen ? 48 : 24),
                            _buildOptionButton(
                              icon: getAdaptiveIcon(
                                iconName: 'edit',
                                defaultIcon: Icons.edit,
                                color: Colors.white,
                              ),
                              label: 'Rundholz bearbeiten',
                              onPressed: _showRoundwoodListDialog,
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
                              'Hier kannst du Rundholz erfassen und bearbeiten. Wähle "Neues Rundholz" für einen neuen Eintrag oder "Rundholz bearbeiten" um bestehende Einträge zu verwalten.',
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
        ));
    }

  void _showRoundwoodListDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'forest',
                      defaultIcon: Icons.forest,
                      color: const Color(0xFF0F4A29),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Rundholz bearbeiten',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F4A29),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: getAdaptiveIcon(
                        iconName: 'close',
                        defaultIcon: Icons.close,
                      ),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
              // RoundwoodList
              Expanded(
                child: RoundwoodList(
                  showHeaderActions: true,
                  filter: RoundwoodFilter(),
                  onFilterChanged: (filter) {
                    // Handle filter changes if needed
                  },
                  service: RoundwoodService(),
                  isDesktopLayout: false,
                ),
              ),
            ],
          ),
        );
      },
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
            'Produkt',
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
                                        icon: getAdaptiveIcon(iconName: 'edit',defaultIcon:Icons.edit),
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
  Widget _buildMobileActionCard({
    required Gradient gradient,
    required Widget icon,
    required String title,
    required String subtitle,
    List<Widget>? actions,
    VoidCallback? onTap,
    Color? borderColor,
    Color contentColor = Colors.white,
    Widget? customContent,  // ← NEU
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: contentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: icon,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: contentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // ═══ Custom Content ODER Actions ═══
                if (customContent != null) ...[
                  const SizedBox(height: 16),
                  customContent,
                ] else if (actions != null && actions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(height: 1, color: contentColor.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerwaltungTabCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0F4A29).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab Header
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: TabBar(
              controller: _verwaltungTabController,
              labelColor: const Color(0xFF0F4A29),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF0F4A29),
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getAdaptiveIcon(iconName: 'inventory_2', defaultIcon: Icons.inventory_2, size: 18),
                      const SizedBox(width: 8),
                      const Text('Produkte'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getAdaptiveIcon(iconName: 'forest', defaultIcon: Icons.forest, size: 18),
                      const SizedBox(width: 8),
                      const Text('Rundholz'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          AnimatedBuilder(
            animation: _verwaltungTabController,
            builder: (context, _) {
              return IndexedStack(
                index: _verwaltungTabController.index,
                children: [
                  // === TAB 1: Produkte ===
                  // === TAB 1: Produkte ===
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionChip(
                                icon: Icons.edit,
                                iconName: 'edit',
                                label: 'Bearbeiten',
                                onTap: _showEditBarcodeInputDialog,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // NEU: Scannen Chip
                            Expanded(
                              child: _buildActionChip(
                                icon: Icons.qr_code_scanner,
                                iconName: 'qr_code_scanner',
                                label: 'Scannen',
                                onTap: _scanBarcodeForEdit,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionChip(
                                icon: Icons.add_circle,
                                iconName: 'add_circle',
                                label: 'Neu anlegen',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AddProductScreen(editMode: false, isProduction: true)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Platzhalter für symmetrisches Layout
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // === TAB 2: Rundholz ===
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionChip(
                                icon: Icons.add_circle,
                                iconName: 'add_circle',
                                label: 'Neuer Stamm',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RoundwoodEntryScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildActionChip(
                                icon: Icons.edit,
                                iconName: 'edit',
                                label: 'Bearbeiten',
                                onTap: _showRoundwoodListDialog,
                              ),
                            ),

                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [

                            Expanded(
                              child: _buildActionChip(
                                icon: Icons.lock,
                                iconName: 'lock',
                                label: 'Abschließen',
                                onTap: _showStammAbschliessenDialog,
                              ),

                            ),
                            const SizedBox(width: 8),

                            Expanded(child: SizedBox(width: 8,)),
                            ],
                        ),
                      ],
                    ),
                  ),   ],
              );
            },
          ),
        ],
      ),
    );
  }
  void _showStammAbschliessenDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'lock',
                      defaultIcon: Icons.lock,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Stamm abschließen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F4A29),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
              // Info
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'info',
                      defaultIcon: Icons.info,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Wähle einen Stamm zum Abschließen. Abgeschlossene Stämme werden bei der Buchung ausgeblendet.',
                        style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
              // RoundwoodList - nur offene Stämme
              Expanded(
                child: RoundwoodList(
                  showHeaderActions: false,
                  filter: RoundwoodFilter(showClosed: false),
                  onFilterChanged: (filter) {},
                  service: RoundwoodService(),
                  isDesktopLayout: false,
                  onItemSelected: (stammId, stammData) {
                    Navigator.pop(context);
                    _confirmCloseStamm(stammId, stammData);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmCloseStamm(String stammId, Map<String, dynamic> stammData) {
    final stammNr = stammData['internal_number'] ?? '?';
    final stammJahr = stammData['year'] ?? '?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'lock',
              defaultIcon: Icons.lock,
              color: Colors.orange[700],
            ),
            const SizedBox(width: 8),
            const Text('Stamm abschließen?'),
          ],
        ),
        content: Text(
          'Möchtest du den Stamm $stammNr/$stammJahr wirklich abschließen?\n\nDer Stamm wird bei der Buchung ausgeblendet, kann aber weiterhin eingesehen werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _closeStamm(stammId, stammData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            child: const Text('Abschließen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _closeStamm(String stammId, Map<String, dynamic> stammData) async {
    try {
      await FirebaseFirestore.instance
          .collection('roundwood')
          .doc(stammId)
          .update({
        'is_closed': true,
        'closed_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      AppToast.show(
        message: 'Stamm ${stammData['internal_number']}/${stammData['year']} abgeschlossen',
        height: h,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: 'Fehler: $e', height: h);
    }
  }
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ═══════════════════════════════════════════════════════════
              // PRODUKTION BUCHEN - 2x2 Grid
              // ═══════════════════════════════════════════════════════════
              _buildMobileActionCard(
                gradient: LinearGradient(
                  colors: [Colors.grey[100]!, Colors.grey[200]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderColor: const Color(0xFF0F4A29).withOpacity(0.3),
                contentColor: const Color(0xFF0F4A29),
                icon: getAdaptiveIcon(
                  iconName: 'precision_manufacturing',
                  defaultIcon: Icons.precision_manufacturing,
                  color: const Color(0xFF0F4A29),
                  size: 36,
                ),
                title: 'Produktion buchen',
                subtitle: 'Direkt oder über Stamm',
                actions: [], // Keine Actions hier, wir bauen custom content
                customContent: Column(
                  children: [
                    // Erste Zeile
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionChip(
                            icon: Icons.search,
                            iconName: 'search',
                            label: 'Suchen',
                            onTap: _showProductionDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionChip(
                            icon: Icons.qr_code_scanner,
                            iconName: 'qr_code_scanner',
                            label: 'Scannen',
                            onTap: _scanBarcode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Zweite Zeile
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionChip(
                            icon: Icons.dialpad,
                            iconName: 'dialpad',
                            label: 'Eingabe',
                            onTap: _showBarcodeInputDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionChip(
                            icon: Icons.account_tree,
                            iconName: 'account_tree',
                            label: 'Über Stamm',
                            onTap: _showStammAuswahlDialog,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ═══════════════════════════════════════════════════════════════
                    // NEU: Dritte Zeile - Letzter Stamm
                    // ═══════════════════════════════════════════════════════════════
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionChip(
                            icon: Icons.history,
                            iconName: 'history',
                            label: 'Letzter Stamm',
                            onTap: _openLastStammBuchung,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox()), // Platzhalter für symmetrie
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ═══════════════════════════════════════════════════════════
              // VERWALTUNG - TabView
              // ═══════════════════════════════════════════════════════════
              _buildVerwaltungTabCard(),
            ],
          ),
        ),
      ),
    );
  }

// Hilfsmethode für Action Chips innerhalb der Cards
  Widget _buildActionChip({
    required IconData icon,
    required String iconName,
    required String label,
    required VoidCallback onTap,
    double? width,
    Color? chipColor,
  }) {
    final color = chipColor ?? const Color(0xFF0F4A29);

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              getAdaptiveIcon(iconName: iconName, defaultIcon:
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Hilfsmethode für kompakte Cards
  Widget _buildMobileCompactCard({
    required Color color,
    required Widget icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: icon,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  @override
  void dispose() {
    quantityController.dispose();
    barcodeController.dispose();
    _verwaltungTabController.dispose();
    super.dispose();
  }
}