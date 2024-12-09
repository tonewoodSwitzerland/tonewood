import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class AddProductScreen extends StatefulWidget {
  final bool editMode;
  final bool isProduction; // Neuer required Parameter
  final String? barcode;
  final Map<String, dynamic>? productData;
  final VoidCallback? onSave;

  const AddProductScreen({
    Key? key,
    required this.editMode,
    required this.isProduction,
    this.barcode,
    this.productData,
    this.onSave,
  }) : super(key: key);

  @override
  AddProductScreenState createState() => AddProductScreenState();
}

class AddProductScreenState extends State<AddProductScreen> {

  final _formKey = GlobalKey<FormState>();

  bool hasGeneratedBarcodeError = false;
  String? existingUnit;
  bool isUnitMismatch = false;
  String? unitMismatchMessage;

  String? selectedInstrument;
  String? selectedPart;
  String? selectedWoodType;
  String? selectedQuality;
  int? selectedYear;
  String? selectedUnit;
  String generatedBarcode = '';
  String shortBarcode = '';
  bool? isProduction;
  // Controllers
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  final TextEditingController customProductController = TextEditingController();

  // Properties
  bool thermallyTreated = false;
  bool haselfichte = false;
  bool moonwood = false;
  bool fsc100 = false;
  bool isSpecialProduct = false;

  // Constants
  final List<String> units = ['Stück', 'Kg', 'Palette', 'm³'];

  // Dropdown data
  List<QueryDocumentSnapshot>? instruments;
  List<QueryDocumentSnapshot>? parts;
  List<QueryDocumentSnapshot>? woodTypes;
  List<QueryDocumentSnapshot>? qualities;

  @override
  void initState() {
    super.initState();
    print('AddProductScreen initState'); // Debug
    print('editMode: ${widget.editMode}'); // Debug
    print('barcode: ${widget.barcode}'); // Debug
    print('productData: ${widget.productData}'); // Debug

    if (widget.editMode && widget.productData != null) {
      // Zuerst die Dropdown-Daten laden
      _loadDropdownData().then((_) {
        print('Dropdown data loaded, now loading existing data'); // Debug
        _loadExistingData();
      });
    } else {
      _loadDropdownData();
      _checkExistingProduct();
    }
  }
  // Neue Methode zur Prüfung existierender Produkte
  Future<void> _checkExistingProduct() async {
    if (!mounted) return;

    void _showExistingProductError(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Verstanden',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }

    if (shortBarcode.isNotEmpty) {
      try {
        // Prüfe Inventory
        final inventoryDoc = await FirebaseFirestore.instance
            .collection('inventory')
            .doc(shortBarcode)
            .get();

        if (inventoryDoc.exists) {
          final data = inventoryDoc.data() as Map<String, dynamic>;
          setState(() {
            existingUnit = data['unit'] as String?;

            // Prüfe Einheit
            if (existingUnit != null && selectedUnit != null && existingUnit != selectedUnit) {
              isUnitMismatch = true;
              unitMismatchMessage = 'Produkt existiert mit der Einheit "$existingUnit"!';
              _showExistingProductError(unitMismatchMessage!);
            } else {
              isUnitMismatch = false;
              unitMismatchMessage = null;
            }
          });
        }

        // Prüfe Production bei neuem Produktionseintrag
        if (widget.isProduction && generatedBarcode.isNotEmpty) {
          final productionDoc = await FirebaseFirestore.instance
              .collection('production')
              .doc(generatedBarcode)
              .get();

          if (productionDoc.exists) {
            _showExistingProductError(
                'Diese Produktions-Artikelnummer existiert bereits: $generatedBarcode'
            );
            setState(() {
              generatedBarcode = 'FEHLER: Bereits vorhanden';
              hasGeneratedBarcodeError = true; // Wichtig für die Speichervalidierung
            });
          }
        }
      } catch (e) {
        print('Fehler bei der Produktprüfung: $e');
      }
    }
  }

  Future<void> _updateBarcode() async {
    _updateShortBarcode();

    if (!widget.isProduction) {
      setState(() {
        generatedBarcode = shortBarcode;
        hasGeneratedBarcodeError = false;
      });
      return;
    }

    if (selectedInstrument != null &&
        selectedPart != null &&
        selectedWoodType != null &&
        selectedQuality != null &&
        selectedYear != null) {

      final thermo = thermallyTreated ? "1" : "0";
      final hasel = haselfichte ? "1" : "0";
      final mond = moonwood ? "1" : "0";
      final fichte = fsc100 ? "1" : "0";
      final variablenTeil = "$thermo$hasel$mond$fichte";

      final potentialBarcode = '$shortBarcode.$variablenTeil.${selectedYear.toString().substring(2)}';

      try {
        final productionDoc = await FirebaseFirestore.instance
            .collection('production')
            .doc(potentialBarcode)
            .get();

        if (productionDoc.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Diese Produktions-Artikelnummer existiert bereits: $potentialBarcode'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          setState(() {
            generatedBarcode = 'FEHLER: Diese Kombination existiert bereits';
            hasGeneratedBarcodeError = true;
          });
        } else {
          setState(() {
            generatedBarcode = potentialBarcode;
            hasGeneratedBarcodeError = false;
          });
        }
      } catch (e) {
        print('Fehler bei der Barcode-Prüfung: $e');
        setState(() {
          generatedBarcode = 'FEHLER: Prüfung fehlgeschlagen';
          hasGeneratedBarcodeError = true;
        });
      }
    }
  }
  // Neue Methode zur Generierung der verkürzten Artikelnummer
  void _updateShortBarcode() {
    if (selectedInstrument != null &&
        selectedPart != null &&
        selectedWoodType != null &&
        selectedQuality != null) {
      setState(() {
        shortBarcode = '$selectedInstrument$selectedPart.$selectedWoodType$selectedQuality';
      });
      _checkInventoryUnit();
    }
  }

// Methode zur Prüfung der Einheit im Inventory
  Future<void> _checkInventoryUnit() async {
    if (shortBarcode.isEmpty) return;

    try {
      final inventoryDoc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(shortBarcode)
          .get();

      if (inventoryDoc.exists) {
        final data = inventoryDoc.data() as Map<String, dynamic>;
        final inventoryUnit = data['unit'] as String?;

        setState(() {
          existingUnit = inventoryUnit;

          // Prüfe ob die aktuelle Einheit von der existierenden abweicht
          if (selectedUnit != null && inventoryUnit != null && selectedUnit != inventoryUnit) {
            isUnitMismatch = true;
            unitMismatchMessage = 'Produkt existiert bereits mit der Einheit "$inventoryUnit"!';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(unitMismatchMessage!),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          } else {
            isUnitMismatch = false;
            unitMismatchMessage = null;
          }
        });
      } else {
        setState(() {
          existingUnit = null;
          isUnitMismatch = false;
          unitMismatchMessage = null;
        });
      }
    } catch (e) {
      print('Fehler bei der Einheitenprüfung: $e');
    }
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

      if (!mounted) return;

      setState(() {
        instruments = instrumentsSnapshot.docs;
        parts = partsSnapshot.docs;
        woodTypes = woodTypesSnapshot.docs;
        qualities = qualitiesSnapshot.docs;
      });
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
    }
  }
  void _loadExistingData() {
    if (widget.productData == null) {
      print('No product data to load'); // Debug
      return;
    }

    print('Loading existing data: ${widget.productData}'); // Debug

    try {
      setState(() {
        // Grundinformationen laden
        selectedInstrument = widget.productData!['instrument_code'];
        selectedPart = widget.productData!['part_code'];
        selectedWoodType = widget.productData!['wood_code'];
        selectedQuality = widget.productData!['quality_code'];
        selectedUnit = widget.productData!['unit'];

        // Menge und Preis laden
        quantityController.text = widget.productData!['quantity']?.toString() ?? '0';
        priceController.text = widget.productData!['price_CHF']?.toString() ?? '0.0';

        // Short Barcode generieren oder laden
        if (widget.productData!['short_barcode'] != null) {
          shortBarcode = widget.productData!['short_barcode'];
        } else {
          // Wenn kein short_barcode vorhanden, generieren wir ihn
          shortBarcode = '$selectedInstrument$selectedPart.$selectedWoodType$selectedQuality';
        }

        // Wenn im Produktionsmodus, lade auch die Produktionsdetails
        if (widget.isProduction) {
          selectedYear = widget.productData!['year_full'] ??
              int.parse('20${widget.productData!['year']}');
          thermallyTreated = widget.productData!['thermally_treated'] ?? false;
          haselfichte = widget.productData!['haselfichte'] ?? false;
          moonwood = widget.productData!['moonwood'] ?? false;
          fsc100 = widget.productData!['FSC_100'] ?? false;
        }
      });

      // Barcode aktualisieren
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateBarcode();
      });
    } catch (e) {
      print('Error loading existing data: $e'); // Debug
    }
  }
  // Modifizierte _updateBarcode Methode




  Future<String> _getNextSequence() async {
    try {
      final prefix = '$selectedInstrument$selectedPart.$selectedWoodType$selectedQuality.${selectedYear.toString().substring(2)}';

      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('barcode', isGreaterThanOrEqualTo: prefix)
          .where('barcode', isLessThan: prefix + '\uf8ff')
          .orderBy('barcode', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return '0001';
      }

      String lastBarcode = snapshot.docs.first.id;
      String lastSequence = lastBarcode.split('.').last;
      int nextSequence = int.parse(lastSequence) + 1;

      return nextSequence.toString().padLeft(4, '0');
    } catch (e) {
      print('Fehler bei Sequenzgenerierung: $e');
      return '0001';
    }
  }
  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(
      currentYear - 1999,
          (index) => 2000 + index,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isProduction
              ? (widget.editMode ? 'Produktion bearbeiten' : 'Neues Produkt')
              : (widget.editMode ? 'Bestand bearbeiten' : 'Neuer Verkauf'),
          style: headline4_0,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barcode Anzeige
              if (!widget.editMode)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          widget.isProduction
                              ? 'Generierte Produktions-Artikelnummer:'
                              : 'Verkaufs-Artikelnummer:',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isProduction ? generatedBarcode : shortBarcode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(

                             'Verkaufs-Artikelnummer:',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                         shortBarcode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Grundinformationen Card (immer sichtbar)
            IgnorePointer(
                  ignoring:    widget.editMode,
                  child: _buildBasicInformationCard()),

              const SizedBox(height: 16),

              // Produktionsdetails nur im Produktionsmodus anzeigen
              if (widget.isProduction) ...[
                _buildProductionDetailsCard(),
                const SizedBox(height: 16),
              ],

              // Bestand und Preis Card
              _buildInventoryAndPriceCard(),

              const SizedBox(height: 24),

              // Speichern Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  child: Text(widget.editMode ? 'Änderungen speichern' : 'Speichern'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }

  Widget _buildBasicInformationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grundinformationen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (instruments != null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Instrument',
                  border: OutlineInputBorder(),
                ),
                value: selectedInstrument,
                items: instruments!.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: data['code'] as String,
                    child: Text('${data['name']} (${data['code']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedInstrument = value;
                    _updateBarcode();
                  });
                },
                validator: (value) => value == null ? 'Pflichtfeld' : null,
              ),
            const SizedBox(height: 16),
            if (parts != null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Bauteil',
                  border: OutlineInputBorder(),
                ),
                value: selectedPart,
                items: parts!.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: data['code'] as String,
                    child: Text('${data['name']} (${data['code']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPart = value;
                    _updateBarcode();
                  });
                },
                validator: (value) => value == null ? 'Pflichtfeld' : null,
              ),
            const SizedBox(height: 16),
            if (woodTypes != null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Holzart',
                  border: OutlineInputBorder(),
                ),
                value: selectedWoodType,
                items: woodTypes!.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: data['code'] as String,
                    child: Text('${data['name']} (${data['code']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedWoodType = value;
                    _updateBarcode();
                  });
                },
                validator: (value) => value == null ? 'Pflichtfeld' : null,
              ),
            const SizedBox(height: 16),
            if (qualities != null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Qualität',
                  border: OutlineInputBorder(),
                ),
                value: selectedQuality,
                items: qualities!.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: data['code'] as String,
                    child: Text('${data['name']} (${data['code']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedQuality = value;
                    _updateBarcode();
                  });
                },
                validator: (value) => value == null ? 'Pflichtfeld' : null,
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Einheit',
                border: OutlineInputBorder(),
                errorText: isUnitMismatch ? unitMismatchMessage : null,
                errorStyle: TextStyle(color: Colors.red),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isUnitMismatch ? Colors.red : Colors.grey,
                    width: isUnitMismatch ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isUnitMismatch ? Colors.red : primaryAppColor,
                    width: 2,
                  ),
                ),
              ),
              value: selectedUnit,
              items: units.map((unit) => DropdownMenuItem<String>(
                value: unit,
                child: Text(unit),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedUnit = value;
                  if (existingUnit != null && value != existingUnit) {
                    isUnitMismatch = true;
                    unitMismatchMessage = 'Produkt existiert bereits mit der Einheit "$existingUnit"!';
                  } else {
                    isUnitMismatch = false;
                    unitMismatchMessage = null;
                  }
                });
              },
              validator: (value) => value == null ? 'Pflichtfeld' : null,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryAndPriceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bestand und Preis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Bestand (${selectedUnit ?? ""})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) => value?.isEmpty ?? true ? 'Pflichtfeld' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Preis (CHF)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) => value?.isEmpty ?? true ? 'Pflichtfeld' : null,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildProductionDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produktionsdetails',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Jahrgang Dropdown
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Jahrgang',
                border: OutlineInputBorder(),
              ),
              value: selectedYear,
              items: List<int>.generate(
                DateTime.now().year - 1999,
                    (index) => 2000 + index,
              ).map((year) => DropdownMenuItem<int>(
                value: year,
                child: Text(year.toString()),
              )).toList(),
              onChanged: (value) {
                if (value != selectedYear) {  // Nur updaten wenn sich der Wert wirklich ändert
                  setState(() {
                    selectedYear = value;
                  });
                  _updateBarcode();  // Direkte Prüfung bei Änderung
                }
              },
              validator: (value) => value == null ? 'Pflichtfeld' : null,
            ),

            const SizedBox(height: 24),
            const Text(
              'Eigenschaften',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Thermobehandelt Switch
            SwitchListTile(
              title: const Text('Thermobehandelt'),
              value: thermallyTreated,
              onChanged: (value) {
                setState(() {
                  thermallyTreated = value;
                  _updateBarcode();
                });
              },
            ),

            // Haselfichte Switch
            SwitchListTile(
              title: const Text('Haselfichte'),
              value: haselfichte,
              onChanged: (value) {
                setState(() {
                  haselfichte = value;
                  _updateBarcode();
                });
              },
            ),

            // Mondholz Switch
            SwitchListTile(
              title: const Text('Mondholz'),
              value: moonwood,
              onChanged: (value) {
                setState(() {
                  moonwood = value;
                  _updateBarcode();
                });
              },
            ),

            // FSC 100% Switch
            SwitchListTile(
              title: const Text('FSC 100%'),
              value: fsc100,
              onChanged: (value) {
                setState(() {
                  fsc100 = value;
                  _updateBarcode();
                });
              },
            ),
          ],
        ),
      ),
    );
  }


  String getNameFromDocs(List<QueryDocumentSnapshot> docs, String code) {
    try {
      final doc = docs.firstWhere(
            (doc) => (doc.data() as Map<String, dynamic>)['code'] == code,
      );
      return (doc.data() as Map<String, dynamic>)['name'] as String;
    } catch (e) {
      print('Fehler beim Abrufen des Namens für Code $code: $e');
      return '';
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    // Verhindere das Speichern bei Barcode-Fehlern
    if (widget.isProduction && hasGeneratedBarcodeError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speichern nicht möglich: Ungültige Produktions-Artikelnummer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Einheitenprüfung
    if (isUnitMismatch) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Falsche Einheit'),
          content: Text('Das Produkt existiert bereits mit der Einheit "$existingUnit". '
              'Bitte verwende die gleiche Einheit für dieses Produkt.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Verstanden'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final baseData = {
        'instrument_code': selectedInstrument,
        'instrument_name': getNameFromDocs(instruments!, selectedInstrument!),
        'part_code': selectedPart,
        'part_name': getNameFromDocs(parts!, selectedPart!),
        'wood_code': selectedWoodType,
        'wood_name': getNameFromDocs(woodTypes!, selectedWoodType!),
        'quality_code': selectedQuality,
        'quality_name': getNameFromDocs(qualities!, selectedQuality!),
        'unit': selectedUnit,
        'price_CHF': double.parse(priceController.text),
        'last_modified': FieldValue.serverTimestamp(),
        'short_barcode': shortBarcode,
      };

      final productName = '${baseData['instrument_name']} - ${baseData['part_name']} - ${baseData['wood_name']}';
      baseData['product_name'] = productName;

      if (widget.editMode) {
        // Bearbeitungsmodus
        await FirebaseFirestore.instance
            .collection(widget.isProduction ? 'production' : 'inventory')
            .doc(widget.isProduction ? widget.barcode : shortBarcode)
            .update(baseData);
      } else {
        // Neuer Eintrag
        final batch = FirebaseFirestore.instance.batch();

        // Produktionseintrag
        if (widget.isProduction) {
          final productionData = {
            ...baseData,
            'year': selectedYear,
            'thermally_treated': thermallyTreated,
            'haselfichte': haselfichte,
            'moonwood': moonwood,
            'FSC_100': fsc100,
            'barcode': generatedBarcode,
            'created_at': FieldValue.serverTimestamp(),
          };

          final batchData = {
            'batch_number': 1,
            'quantity': int.parse(quantityController.text),
            'stock_entry_date': FieldValue.serverTimestamp(),
          };

          final productionRef = FirebaseFirestore.instance
              .collection('production')
              .doc(generatedBarcode);

          final firstBatch = productionRef
              .collection('batch')
              .doc('0001');

          batch.set(productionRef, productionData);
          batch.set(firstBatch, batchData);
        }

        // Inventory Update mit Quantity-Aggregation
        final inventoryRef = FirebaseFirestore.instance
            .collection('inventory')
            .doc(shortBarcode);

        // Hole aktuellen Inventory-Stand
        final inventoryDoc = await inventoryRef.get();
        final currentQuantity = inventoryDoc.exists
            ? (inventoryDoc.data()?['quantity'] as num?)?.toInt() ?? 0
            : 0;

        // Addiere neue Quantity
        final newQuantity = currentQuantity + int.parse(quantityController.text);

        // Inventory Update mit Quantity-Aggregation
        if (inventoryDoc.exists) {
          // Wenn das Produkt bereits existiert, nur die Menge aktualisieren
          batch.update(inventoryRef, {
            'quantity': newQuantity,
            'last_modified': FieldValue.serverTimestamp(),
          });
        } else {
          // Wenn es ein neues Produkt ist, alle Daten setzen
          batch.set(inventoryRef, {
            ...baseData,
            'quantity': int.parse(quantityController.text),
            'created_at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erfolgreich gespeichert'),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.onSave != null) {
        widget.onSave!();
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

  }





  @override
  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    customProductController.dispose();
    super.dispose();
  }
}