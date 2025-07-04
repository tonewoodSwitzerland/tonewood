// manual_product_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';
import '../constants.dart';

class ManualProductSheet {
  static Future<void> show(
      BuildContext context, {
        required Function(Map<String, dynamic>) onProductAdded,
      }) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualProductSheetContent(
        onProductAdded: onProductAdded,
      ),
    );
  }
}

class ManualProductSheetContent extends StatefulWidget {
  final Function(Map<String, dynamic>) onProductAdded;

  const ManualProductSheetContent({
    Key? key,
    required this.onProductAdded,
  }) : super(key: key);

  @override
  State<ManualProductSheetContent> createState() => _ManualProductSheetContentState();
}

class _ManualProductSheetContentState extends State<ManualProductSheetContent> {
  final _formKey = GlobalKey<FormState>();

  // Controller für manuelle Eingaben
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _thicknessController = TextEditingController();

  // Ausgewählte Werte
  Map<String, dynamic>? _selectedInstrument;
  Map<String, dynamic>? _selectedPart;
  Map<String, dynamic>? _selectedWood;
  Map<String, dynamic>? _selectedQuality;
  String _selectedUnit = 'Stück';
  String _selectedFscStatus = '100%';

  // Dropdown-Daten
  List<QueryDocumentSnapshot>? _instruments;
  List<QueryDocumentSnapshot>? _parts;
  List<QueryDocumentSnapshot>? _woodTypes;
  List<QueryDocumentSnapshot>? _qualities;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('instruments').orderBy('code').get(),
        FirebaseFirestore.instance.collection('parts').orderBy('code').get(),
        FirebaseFirestore.instance.collection('wood_types').orderBy('code').get(),
        FirebaseFirestore.instance.collection('qualities').orderBy('code').get(),
      ]);

      setState(() {
        _instruments = results[0].docs;
        _parts = results[1].docs;
        _woodTypes = results[2].docs;
        _qualities = results[3].docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Dropdown-Daten: $e');
      setState(() => _isLoading = false);
    }
  }

  String _generateManualProductId() {
    // Generiere eine eindeutige ID für manuelle Produkte
    return 'MANUAL_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _submitProduct() {
    if (_formKey.currentState!.validate()) {
      if (_selectedInstrument == null ||
          _selectedPart == null ||
          _selectedWood == null ||
          _selectedQuality == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte alle Dropdown-Felder auswählen'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0;

      // Erstelle das manuelle Produkt
      final manualProduct = {
        'product_id': _generateManualProductId(),
        'product_name': _productNameController.text.trim().isEmpty
            ? '${_selectedInstrument!['name']} - ${_selectedPart!['name']} - ${_selectedWood!['name']} - ${_selectedQuality!['name']}'
            : _productNameController.text.trim(),
        'quantity': quantity,
        'price_per_unit': price,
        'unit': _selectedUnit,
        'instrument_name': _selectedInstrument!['name'],
        'instrument_code': _selectedInstrument!['code'],
        'part_name': _selectedPart!['name'],
        'part_code': _selectedPart!['code'],
        'wood_name': _selectedWood!['name'],
        'wood_code': _selectedWood!['code'],
        'quality_name': _selectedQuality!['name'],
        'quality_code': _selectedQuality!['code'],
        'fsc_status': _selectedFscStatus,
        'is_manual_product': true, // Wichtige Markierung!
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Füge Maße hinzu, falls vorhanden
      if (_lengthController.text.isNotEmpty) {
        manualProduct['custom_length'] = double.tryParse(_lengthController.text.replaceAll(',', '.'));
      }
      if (_widthController.text.isNotEmpty) {
        manualProduct['custom_width'] = double.tryParse(_widthController.text.replaceAll(',', '.'));
      }
      if (_thicknessController.text.isNotEmpty) {
        manualProduct['custom_thickness'] = double.tryParse(_thicknessController.text.replaceAll(',', '.'));
      }

      widget.onProductAdded(manualProduct);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
          // Drag Handle
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'add_circle',
                  defaultIcon: Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Manuelles Produkt',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Scrollbarer Inhalt
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info-Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          getAdaptiveIcon(
                            iconName: 'info',
                            defaultIcon: Icons.info,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Manuelle Produkte werden nicht im Lager ausgebucht.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),



                    const SizedBox(height: 18),

                    // Dropdowns in 2er Grid
                    _buildSectionTitle('Produkteigenschaften', Icons.category),
                    const SizedBox(height: 12),

                    // Dropdowns einzeln untereinander für mobile
                    _buildDropdown(
                      label: 'Instrument *',
                      icon: Icons.music_note,
                      iconName: 'music_note',
                      items: _instruments,
                      value: _selectedInstrument,
                      onChanged: (value) => setState(() => _selectedInstrument = value),
                    ),

                    const SizedBox(height: 8),

                    _buildDropdown(
                      label: 'Bauteil *',
                      icon: Icons.category,
                      iconName: 'category',
                      items: _parts,
                      value: _selectedPart,
                      onChanged: (value) => setState(() => _selectedPart = value),
                    ),

                    const SizedBox(height: 8),

                    _buildDropdown(
                      label: 'Holzart *',
                      icon: Icons.forest,
                      iconName: 'forest',
                      items: _woodTypes,
                      value: _selectedWood,
                      onChanged: (value) => setState(() => _selectedWood = value),
                    ),

                    const SizedBox(height: 8),

                    _buildDropdown(
                      label: 'Qualität *',
                      icon: Icons.star,
                      iconName: 'star',
                      items: _qualities,
                      value: _selectedQuality,
                      onChanged: (value) => setState(() => _selectedQuality = value),
                    ),

                    const SizedBox(height: 24),

                    // Menge und Preis
                    _buildSectionTitle('Menge & Preis', Icons.shopping_cart),
                    const SizedBox(height: 12),

                    // Ersetzen Sie die Row mit Menge, Einheit und Preis durch folgende zwei Zeilen:

                    // Menge und Einheit in einer Zeile
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              labelStyle: TextStyle(fontSize: 14),
                              labelText: 'Menge *',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'numbers',
                                defaultIcon: Icons.numbers,
                              ),
                            ),
                            style: TextStyle(fontSize: 14),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Pflichtfeld';
                              }
                              if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                return 'Ungültig';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            decoration: InputDecoration(
                              labelText: 'Einheit',
                              labelStyle: TextStyle(fontSize: 14),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'straighten',
                                defaultIcon: Icons.straighten,
                                size: 20,
                              ),
                            ),
                            // style: TextStyle(fontSize: 14), // Diese Zeile entfernen
                            items: ['Stück', 'Kg', 'Palette', 'm³']
                                .map((unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit), // style hier auch entfernen
                            ))
                                .toList(),
                            onChanged: (value) => setState(() => _selectedUnit = value!),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Preis in eigener Zeile
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelStyle: TextStyle(fontSize: 14),
                        labelText: 'Preis (CHF) *',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: getAdaptiveIcon(
                          iconName: 'attach_money',
                          defaultIcon: Icons.attach_money,
                        ),
                      ),
                      style: TextStyle(fontSize: 14),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bitte Preis eingeben';
                        }
                        final price = double.tryParse(value.replaceAll(',', '.'));
                        if (price == null || price < 0) {
                          return 'Bitte gültigen Preis eingeben';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // FSC-Status
                    _buildSectionTitle('Zertifizierung', Icons.eco),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _selectedFscStatus,
                      decoration: InputDecoration(
                        labelText: 'FSC-Status',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: getAdaptiveIcon(
                          iconName: 'eco',
                          defaultIcon: Icons.eco,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: '100%', child: Text('100% FSC')),
                        DropdownMenuItem(value: 'Mix', child: Text('FSC Mix')),
                        DropdownMenuItem(value: 'Recycled', child: Text('FSC Recycled')),
                        DropdownMenuItem(value: 'Controlled', child: Text('FSC Controlled Wood')),
                        DropdownMenuItem(value: '-', child: Text('Kein FSC')),
                      ],
                      onChanged: (value) => setState(() => _selectedFscStatus = value!),
                    ),

                    const SizedBox(height: 24),

                    // Maße (optional)
                    _buildSectionTitle('Maße (optional)', Icons.straighten),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lengthController,
                            decoration: InputDecoration(
                              labelStyle: TextStyle(fontSize: 12),
                              labelText: 'L (mm)',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: Icon(Icons.straighten, size: 20),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _widthController,
                            decoration: InputDecoration(
                              labelStyle: TextStyle(fontSize: 12),
                              labelText: 'B (mm)',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: Icon(Icons.swap_horiz, size: 20),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _thicknessController,
                            decoration: InputDecoration(
                              labelStyle: TextStyle(fontSize: 12),
                              labelText: 'D (mm)',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: Icon(Icons.layers, size: 20),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer mit Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submitProduct,
                      icon: getAdaptiveIcon(
                        iconName: 'add_shopping_cart',
                        defaultIcon: Icons.add_shopping_cart,
                        color: Colors.white,
                      ),
                      label: const Text('Hinzufügen'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        getAdaptiveIcon(
          iconName: icon.toString().split('.').last,
          defaultIcon: icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String iconName,
    required List<QueryDocumentSnapshot>? items,
    required Map<String, dynamic>? value,
    required Function(Map<String, dynamic>?) onChanged,
  }) {
    return DropdownButtonFormField<String>(  // Ändern zu String
      value: value?['code'] as String?,      // Nur den Code als Value verwenden
      decoration: InputDecoration(
        labelStyle: TextStyle(fontSize: 14),
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: getAdaptiveIcon(
          iconName: iconName,
          defaultIcon: icon,
          size: 14,
        ),
      ),
      items: items?.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DropdownMenuItem<String>(     // Ändern zu String
          value: data['code'] as String,     // Nur den Code als Value
          child: Text('${data['name']} (${data['code']})'),
        );
      }).toList() ?? [],
      onChanged: (String? selectedCode) {    // String? statt Map
        if (selectedCode != null && items != null) {
          // Finde das vollständige Objekt basierend auf dem Code
          final selectedDoc = items.firstWhere(
                (doc) => (doc.data() as Map<String, dynamic>)['code'] == selectedCode,
          );
          onChanged(selectedDoc.data() as Map<String, dynamic>);
        } else {
          onChanged(null);
        }
      },
      validator: (value) {
        if (value == null) {
          return 'Bitte auswählen';
        }
        return null;
      },
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _thicknessController.dispose();
    super.dispose();
  }
}