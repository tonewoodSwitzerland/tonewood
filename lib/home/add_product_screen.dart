import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class AddProductScreen extends StatefulWidget {
  final bool editMode;
  final String? barcode;
  final Map<String, dynamic>? productData;
  final VoidCallback? onSave;
  const AddProductScreen({
    Key? key,
   required this.editMode,
    this.barcode,
    this.productData,
    this.onSave,
  }) : super(key: key);

  @override
  AddProductScreenState createState() => AddProductScreenState();
}

class AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dropdown options
  final List<String> instruments = [
    'Klassische Gitarre',
    'Western-Gitarre',
    'E-Gitarre',
    'Mandoline',
    'Geige',
    'Bratsche',
  ];

  final List<String> parts = [
    'Resonanzdecke',
    'Boden',
    'Zargen',
    'Hals',
    'Body',
    'Leistenholz',
    'Kopfplatte',
    'Set',
  ];

  final List<String> woodTypes = [
    'Fichte',
    'Ahorn',
    'Birne',
    'Palisander',
    'Mahagoni',
  ];

  final List<String> qualities = [
    'MA',
    'AAAA',
    'AAA',
    'AA',
    'I',
    'II',
  ];

  // Form fields
  String? selectedInstrument;
  String? selectedPart;
  String? selectedWoodType;
  String? selectedQuality;
  final TextEditingController sizeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  bool thermallyTreated = false;
  bool haselfichte = false;
  bool moonwood = false;
  bool fsc100 = false;

  @override
  void initState() {
    super.initState();

    if (widget.editMode && widget.productData != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    setState(() {
      // Load dropdown values
      selectedInstrument = widget.productData!['instrument'] as String?;
      selectedPart = widget.productData!['part'] as String?;
      selectedWoodType = widget.productData!['wood_type'] as String?;
      selectedQuality = widget.productData!['quality'] as String?;

      // Load text field values
      sizeController.text = widget.productData!['size']?.toString() ?? '';
      quantityController.text = widget.productData!['quantity']?.toString() ?? '0';
      priceController.text = widget.productData!['price_CHF']?.toString() ?? '0.0';

      // Load boolean values
      thermallyTreated = widget.productData!['thermally_treated'] ?? false;
      haselfichte = widget.productData!['haselfichte'] ?? false;
      moonwood = widget.productData!['moonwood'] ?? false;
      fsc100 = widget.productData!['FSC_100'] ?? false;
    });
  }
  Future<void> _loadProductData() async {
    if (widget.editMode && widget.barcode != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.barcode)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            // Load dropdown values
            selectedInstrument = data['instrument'] as String?;
            selectedPart = data['part'] as String?;
            selectedWoodType = data['wood_type'] as String?;
            selectedQuality = data['quality'] as String?;

            // Load text field values
            sizeController.text = data['size']?.toString() ?? '';
            quantityController.text = data['quantity']?.toString() ?? '0';
            priceController.text = data['price_CHF']?.toString() ?? '0.0';

            // Load boolean values
            thermallyTreated = data['thermally_treated'] ?? false;
            haselfichte = data['haselfichte'] ?? false;
            moonwood = data['moonwood'] ?? false;
            fsc100 = data['FSC_100'] ?? false;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Produktdaten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lade Daten wenn nötig neu
    if (widget.editMode && widget.barcode != null) {
      _loadProductData();
    }
  }
  Widget build(BuildContext context) {
    return Container(
     child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.editMode)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Barcode',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                widget.barcode ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Basic Information Card
                Card(
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
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Instrument',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedInstrument,
                          items: instruments.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedInstrument = value;
                            });
                          },
                          validator: (value) => value == null ? 'Pflichtfeld' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Bauteil',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedPart,
                          items: parts.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPart = value;
                            });
                          },
                          validator: (value) => value == null ? 'Pflichtfeld' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Holzart',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedWoodType,
                          items: woodTypes.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedWoodType = value;
                            });
                          },
                          validator: (value) => value == null ? 'Pflichtfeld' : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Qualität',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedQuality,
                          items: qualities.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedQuality = value;
                            });
                          },
                          validator: (value) => value == null ? 'Pflichtfeld' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: sizeController,
                          decoration: const InputDecoration(
                            labelText: 'Größe',
                            border: OutlineInputBorder(),
                            helperText: 'Format: 560 x 210 x 4.5 mm',
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'Pflichtfeld' : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Properties Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Eigenschaften',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('Thermobehandelt'),
                          value: thermallyTreated,
                          onChanged: (value) {
                            setState(() {
                              thermallyTreated = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Haselfichte'),
                          value: haselfichte,
                          onChanged: (value) {
                            setState(() {
                              haselfichte = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Mondholz'),
                          value: moonwood,
                          onChanged: (value) {
                            setState(() {
                              moonwood = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          title: const Text('FSC 100%'),
                          value: fsc100,
                          onChanged: (value) {
                            setState(() {
                              fsc100 = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Stock and Price Card
                Card(
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
                          decoration: const InputDecoration(
                            labelText: 'Bestand',
                            border: OutlineInputBorder(),
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
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          validator: (value) => value?.isEmpty ?? true ? 'Pflichtfeld' : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveProduct,
                    child: Text(widget.editMode ? 'Änderungen speichern' : 'Produkt anlegen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        final productData = {
          'instrument': selectedInstrument,
          'part': selectedPart,
          'wood_type': selectedWoodType,
          'size': sizeController.text,
          'quality': selectedQuality,
          'price_CHF': double.parse(priceController.text),
          'quantity': int.parse(quantityController.text),
          'thermally_treated': thermallyTreated,
          'haselfichte': haselfichte,
          'moonwood': moonwood,
          'FSC_100': fsc100,
          'last_modified': FieldValue.serverTimestamp(),
          'product': '$selectedInstrument $selectedPart $selectedWoodType', // Generierter Produktname
        };

        if (widget.editMode) {
          // Update existing product
          await FirebaseFirestore.instance
              .collection('products')
              .doc(widget.barcode)
              .update(productData);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkt erfolgreich aktualisiert'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Create new product with new barcode
          final statsDoc = await FirebaseFirestore.instance
              .collection('total')
              .doc('stats')
              .get();

          int lastBarcode = (statsDoc.data()?['lastBarcode'] ?? 10100000) as int;
          int newBarcode = lastBarcode + 1;

          // Update lastBarcode in stats
          await FirebaseFirestore.instance
              .collection('total')
              .doc('stats')
              .update({'lastBarcode': newBarcode});

          // Add new product with generated barcode
          await FirebaseFirestore.instance
              .collection('products')
              .doc(newBarcode.toString())
              .set({
            ...productData,
            'barcode': newBarcode.toString(),
            'created_at': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produkt erfolgreich angelegt mit Barcode: $newBarcode'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Navigate back
        if (mounted && !kIsWeb) {
         Navigator.pop(context);
        }

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    sizeController.dispose();
    quantityController.dispose();
    priceController.dispose();
    super.dispose();
  } }