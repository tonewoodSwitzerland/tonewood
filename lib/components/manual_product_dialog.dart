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

  // NEU: Zusätzliche Controller für Gewichtslogik
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _densityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customTariffController = TextEditingController();
  // NEU: Gratisartikel-Variablen
  bool _isGratisartikel = false;
  final TextEditingController _proformaController = TextEditingController();


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

// Erweitere die _submitProduct Methode:
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
        'price_per_unit': _isGratisartikel ? 0.0 : price, // NEU: 0 bei Gratisartikel
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
        'is_manual_product': true,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Nach den anderen Feldern hinzufügen:
      if (_customTariffController.text.trim().isNotEmpty) {
        manualProduct['custom_tariff_number'] = _customTariffController.text.trim();
      }
      // NEU: Englische Bezeichnungen hinzufügen falls vorhanden
      if (_selectedInstrument!['name_english'] != null) {
        manualProduct['instrument_name_en'] = _selectedInstrument!['name_english'];
      }
      if (_selectedPart!['name_english'] != null) {
        manualProduct['part_name_en'] = _selectedPart!['name_english'];
      }
      if (_selectedWood!['name_english'] != null) {
        manualProduct['wood_name_en'] = _selectedWood!['name_english'];
      }

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

      // NEU: Volumen hinzufügen
      if (_volumeController.text.isNotEmpty) {
        manualProduct['volume_per_unit'] = double.tryParse(_volumeController.text.replaceAll(',', '.')) ?? 0.0;
      }

      // NEU: Dichte hinzufügen
      if (_densityController.text.isNotEmpty) {
        manualProduct['density'] = double.tryParse(_densityController.text.replaceAll(',', '.')) ?? 0.0;
      }

      // NEU: Notizen hinzufügen
      if (_notesController.text.trim().isNotEmpty) {
        manualProduct['notes'] = _notesController.text.trim();
      }

      // NEU: Gratisartikel-Logik
      if (_isGratisartikel) {
        manualProduct['is_gratisartikel'] = true;
        final proformaValue = double.tryParse(_proformaController.text.replaceAll(',', '.')) ?? price;
        manualProduct['proforma_value'] = proformaValue;
      }

      widget.onProductAdded(manualProduct);
      Navigator.pop(context);
    }
  }
  Future<String> _getAutomaticTariffNumber() async {
    try {
      if (_selectedWood == null) return 'Bitte Holzart wählen';

      final woodCode = _selectedWood!['code'] as String;
      final woodTypeDoc = await FirebaseFirestore.instance
          .collection('wood_types')
          .doc(woodCode)
          .get();

      if (!woodTypeDoc.exists) return 'Keine Zolltarifnummer';

      final woodInfo = woodTypeDoc.data()!;

      // Bestimme Zolltarifnummer basierend auf Dicke
      final thicknessText = _thicknessController.text.replaceAll(',', '.');
      final thickness = double.tryParse(thicknessText) ?? 0.0;

      if (thickness <= 6.0) {
        return woodInfo['z_tares_1'] ?? '4408.1000';
      } else {
        return woodInfo['z_tares_2'] ?? '4407.1200';
      }
    } catch (e) {
      print('Fehler beim Laden der Zolltarifnummer: $e');
      return 'Fehler beim Laden';
    }
  }
  void _calculateVolumeFromDimensions() {
    // Parse die Maße
    final lengthText = _lengthController.text.replaceAll(',', '.');
    final widthText = _widthController.text.replaceAll(',', '.');
    final thicknessText = _thicknessController.text.replaceAll(',', '.');

    final length = double.tryParse(lengthText);
    final width = double.tryParse(widthText);
    final thickness = double.tryParse(thicknessText);

    // Nur berechnen wenn alle drei Werte vorhanden sind
    if (length != null && length > 0 &&
        width != null && width > 0 &&
        thickness != null && thickness > 0) {

      // Berechne Volumen in m³ (Maße sind in mm)
      final volumeInM3 = (length * width * thickness) / 1000000000.0;

      // Setze das berechnete Volumen
      setState(() {
        _volumeController.text = volumeInM3.toStringAsFixed(5);
      });
    }
  }


  // NEU: Hilfsmethode für Dichte aus Holzart
  Future<void> _updateDensityFromWood(Map<String, dynamic>? wood) async {
    if (wood != null && wood['density'] != null) {
      setState(() {
        _densityController.text = wood['density'].toString();
      });
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
                onChanged: (value) {
          setState(() => _selectedWood = value);
          // NEU: Setze Dichte automatisch wenn Holzart gewählt wird
          if (value != null && value['density'] != null) {
          _densityController.text = value['density'].toString();
          }
          },
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
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(
                                  iconName: 'numbers',
                                  defaultIcon: Icons.numbers,
                                ),
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
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(
                                  iconName: 'straighten',
                                  defaultIcon: Icons.straighten,
                                  size: 20,
                                ),
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
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                            iconName: 'money_bag',
                            defaultIcon: Icons.savings,
                          ),
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
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                            iconName: 'eco',
                            defaultIcon: Icons.eco,
                          ),
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

// Zolltarifnummer
                    _buildSectionTitle('Zolltarifnummer', Icons.local_shipping),
                    const SizedBox(height: 12),

// Info-Box
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
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Die Zolltarifnummer wird automatisch basierend auf Holzart und Dicke ermittelt. Sie können diese überschreiben.',
                              style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

// Automatische Zolltarifnummer anzeigen
                    FutureBuilder<String>(
                      future: _getAutomaticTariffNumber(),
                      builder: (context, snapshot) {
                        final automaticTariff = snapshot.data ?? 'Wird berechnet...';

                        return Column(
                          children: [
                            // Anzeige der automatischen Zolltarifnummer
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  getAdaptiveIcon(
                                    iconName: 'auto_awesome',
                                    defaultIcon: Icons.auto_awesome,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Automatische Zolltarifnummer',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          automaticTariff,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Freitextfeld für individuelle Zolltarifnummer
                            TextFormField(
                              controller: _customTariffController,
                              decoration: InputDecoration(
                                labelText: 'Individuelle Zolltarifnummer (optional)',
                                hintText: 'z.B. 4407.1200',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: getAdaptiveIcon(
                                    iconName: 'edit',
                                    defaultIcon: Icons.edit,
                                  ),
                                ),
                                helperText: 'Überschreibt die automatische Zolltarifnummer',
                                suffixIcon: _customTariffController.text.isNotEmpty
                                    ? IconButton(
                                  icon: getAdaptiveIcon(
                                    iconName: 'clear',
                                    defaultIcon: Icons.clear,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _customTariffController.clear();
                                    });
                                  },
                                )
                                    : null,
                              ),
                              onChanged: (value) => setState(() {}),
                            ),
                          ],
                        );
                      },
                    ),



// Füge diese UI-Abschnitte nach dem FSC-Status Dropdown ein:

// Nach FSC-Status Dropdown:
                    const SizedBox(height: 24),

// NEU: Notizen-Bereich
                    _buildSectionTitle('Hinweise', Icons.note_alt),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Spezielle Hinweise (optional)',
                        hintText: 'z.B. besondere Qualitätsmerkmale, Lagerort, etc.',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                            iconName: 'note',
                            defaultIcon: Icons.note_alt,
                          ),
                        ),
                      ),
                      maxLines: 3,
                      minLines: 2,
                    ),

                    const SizedBox(height: 24),

// Ersetze den bestehenden Maße-Bereich mit diesem erweiterten Bereich:
                    _buildSectionTitle('Maße & Gewicht (optional)', Icons.straighten),
                    const SizedBox(height: 12),

// Maße in einer Reihe
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
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(iconName: 'straighten', defaultIcon: Icons.straighten, size: 20),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                            onChanged: (value) => setState(() {  _calculateVolumeFromDimensions();}), // Für Gewichtsberechnung
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _widthController,
                            decoration: InputDecoration(
                              labelStyle: TextStyle(fontSize: 12),
                              labelText: 'B (mm)',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(iconName: 'swap_horiz', defaultIcon: Icons.swap_horiz, size: 20),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                            onChanged: (value) => setState(() {_calculateVolumeFromDimensions(); }), // Für Gewichtsberechnung
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _thicknessController,
                            decoration: InputDecoration(
                              labelStyle: TextStyle(fontSize: 12),
                              labelText: 'D (mm)',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(iconName: 'layers', defaultIcon: Icons.layers, size: 20),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                            onChanged: (value) => setState(() {_calculateVolumeFromDimensions(); }), // Für Gewichtsberechnung
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

// NEU: Volumen-Eingabe
                    TextFormField(
                      controller: _volumeController,
                      decoration: InputDecoration(
                        labelText: 'Volumen (m³)',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                              iconName: 'view_in_ar',
                              defaultIcon: Icons.view_in_ar,
                              size: 20
                          ),
                        ),
                        helperText: 'Optional: Volumen manuell eingeben oder aus Maßen berechnen lassen',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,5}')),
                      ],
                      onChanged: (value) => setState(() {}), // Für Gewichtsberechnung
                    ),

                    const SizedBox(height: 12),

// NEU: Dichte-Eingabe
                    TextFormField(
                      controller: _densityController,
                      decoration: InputDecoration(
                        labelText: 'Spezifisches Gewicht (kg/m³)',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                              iconName: 'grain',
                              defaultIcon: Icons.grain,
                              size: 20
                          ),
                        ),
                        helperText: _selectedWood != null && _selectedWood!['density'] != null
                            ? 'Dichte aus Holzart: ${_selectedWood!['density']} kg/m³'
                            : 'Manuell eingeben falls nicht automatisch geladen',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,0}')),
                      ],
                      onChanged: (value) => setState(() {}), // Für Gewichtsberechnung
                    ),

// NEU: Gewichtsberechnung anzeigen
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        // Parse Werte
                        final quantityText = _quantityController.text.replaceAll(',', '.');
                        final volumeText = _volumeController.text.replaceAll(',', '.');
                        final densityText = _densityController.text.replaceAll(',', '.');

                        final quantity = double.tryParse(quantityText) ?? 0.0;
                        final volumePerUnit = double.tryParse(volumeText) ?? 0.0;
                        final density = double.tryParse(densityText) ?? 0.0;

                        // Berechne Gewicht
                        final weightPerUnit = volumePerUnit * density; // kg pro Einheit
                        final totalWeight = weightPerUnit * quantity; // Gesamtgewicht

                        if (volumePerUnit > 0 && density > 0) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    getAdaptiveIcon(
                                      iconName: 'scale',
                                      defaultIcon: Icons.scale,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Gewichtsberechnung',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Volumen: ${volumePerUnit.toStringAsFixed(5)} m³ × Dichte: ${density.toStringAsFixed(0)} kg/m³',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Gewicht pro ${_selectedUnit}:'),
                                    Text(
                                      '${weightPerUnit.toStringAsFixed(2)} kg',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (quantity > 0) ...[
                                  const SizedBox(height: 4),
                                  Divider(),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Gesamtgewicht:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${totalWeight.toStringAsFixed(2)} kg',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        } else {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                getAdaptiveIcon(
                                  iconName: 'info',
                                  defaultIcon: Icons.info,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Gewichtsberechnung erfordert Volumen und Dichte',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 24),

// NEU: Gratisartikel-Bereich
                    _buildSectionTitle('Gratisartikel', Icons.card_giftcard),
                    const SizedBox(height: 12),

                    StatefulBuilder(
                      builder: (context, setCheckboxState) {
                        return Column(
                          children: [
                            CheckboxListTile(
                              title: const Text('Als Gratisartikel markieren'),
                              subtitle: const Text(
                                'Artikel wird mit 0.00 berechnet, Pro-forma-Wert nur für Handelsrechnung',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: _isGratisartikel,
                              onChanged: (value) {
                                setCheckboxState(() {
                                  _isGratisartikel = value ?? false;
                                  if (_isGratisartikel && _proformaController.text.isEmpty) {
                                    _proformaController.text = _priceController.text;
                                  }
                                });
                              },
                            ),

                            // Pro-forma-Wert Eingabe (nur sichtbar wenn Checkbox aktiv)
                            if (_isGratisartikel) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _proformaController,
                                decoration: InputDecoration(
                                  labelText: 'Pro-forma-Wert für Handelsrechnung',
                                  suffixText: 'CHF',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surface,
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: getAdaptiveIcon(
                                        iconName: 'receipt_long',
                                        defaultIcon: Icons.receipt_long
                                    ),
                                  ),
                                  helperText: 'Dieser Wert erscheint nur auf der Handelsrechnung',
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
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
                        iconName: 'shopping_cart',
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
        prefixIcon: Padding(
          padding: const EdgeInsets.all(8.0),
          child: getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            size: 14,
          ),
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
    _volumeController.dispose();
    _densityController.dispose();
    _notesController.dispose();
    _proformaController.dispose();
    _customTariffController.dispose();
    super.dispose();
  }
}