// ═══════════════════════════════════════════════════════════════════════════
// lib/production/stamm_buchung_sheet.dart
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../home/add_product_screen.dart';
import '../home/barcode_scanner.dart';
import '../services/icon_helper.dart';

/// Sheet/Dialog für die Produktionsbuchung über einen ausgewählten Stamm
///
/// Verwendung:
/// ```dart
/// showStammBuchungSheet(
///   context: context,
///   stammId: 'abc123',
///   stammData: {...},
/// );
/// ```
Future<void> showStammBuchungSheet({
  required BuildContext context,
  required String stammId,
  required Map<String, dynamic> stammData,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isDesktop = screenWidth > 800;

  if (isDesktop) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 900,
          height: MediaQuery.of(context).size.height * 0.85,
          child: _StammBuchungContent(
            stammId: stammId,
            stammData: stammData,
            isDesktop: true,
          ),
        ),
      ),
    );
  } else {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _StammBuchungContent(
          stammId: stammId,
          stammData: stammData,
          isDesktop: false,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _StammBuchungContent extends StatefulWidget {
  final String stammId;
  final Map<String, dynamic> stammData;
  final bool isDesktop;
  final ScrollController? scrollController;

  const _StammBuchungContent({
    required this.stammId,
    required this.stammData,
    required this.isDesktop,
    this.scrollController,
  });

  @override
  State<_StammBuchungContent> createState() => _StammBuchungContentState();
}

class _StammBuchungContentState extends State<_StammBuchungContent> {
  // Dropdown Data
  List<QueryDocumentSnapshot>? instruments;
  List<QueryDocumentSnapshot>? parts;
  List<QueryDocumentSnapshot>? qualities;

  // Auswahl
  String? selectedInstrument;
  String? selectedPart;
  String? selectedQuality;
  bool thermallyTreated = false;
  bool haselfichte = false;

  // Menge
  final TextEditingController _mengeController = TextEditingController(text: '1');
  final TextEditingController _preisController = TextEditingController();
  String _selectedUnit = 'Stk';
  bool _isNewProduct = false;  // True wenn Produkt noch nicht in inventory existiert

  final List<String> _availableUnits = ['Stk', 'Kg', 'Palette', 'm³', 'm²'];

  // Behalten-Checkboxen (werden in Firebase gespeichert)
  bool _keepInstrument = false;
  bool _keepPart = false;
  bool _keepQuality = false;
  bool _keepThermo = false;
  bool _keepHasel = false;
  bool _keepMenge = false;

  // Gebuchte Produkte für diesen Stamm
  List<Map<String, dynamic>> _gebuchteProdukte = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Vom Stamm übernommene Werte (readonly)
  late String woodType;
  late String woodName;
  late bool moonwood;
  late bool fsc100;
  late int year;

  @override
  void initState() {
    super.initState();
    _initStammData();
    _loadDropdownData();
    _loadGebuchteProdukte();
    _loadKeepSettings();
  }

  void _initStammData() {
    woodType = widget.stammData['wood_type'] ?? '';
    woodName = widget.stammData['wood_name'] ?? widget.stammData['wood_type'] ?? '';
    moonwood = widget.stammData['is_moonwood'] ?? false;
    fsc100 = widget.stammData['is_fsc'] ?? false;
    year = widget.stammData['year'] ?? DateTime.now().year;
  }
  Future<void> _scanAndFillProduct() async {
    try {
      final String? barcodeResult = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleBarcodeScannerPage(),
        ),
      );

      if (barcodeResult == null || barcodeResult == '-1') return;

      // Parse den Barcode (Format: IIPP.HHQQ)
      final barcodeParts = barcodeResult.split('.');
      if (barcodeParts.length < 2 || barcodeParts[0].length != 4 || barcodeParts[1].length != 4) {
        AppToast.show(
          message: 'Ungültiges Format. Erwartet: IIPP.HHQQ',
          height: h,
        );
        return;
      }

      final instrumentCode = barcodeParts[0].substring(0, 2);
      final partCode = barcodeParts[0].substring(2, 4);
      final scannedWoodCode = barcodeParts[1].substring(0, 2);
      final qualityCode = barcodeParts[1].substring(2, 4);

      // Prüfe ob der Holztyp zum Stamm passt
      if (scannedWoodCode != woodType) {
        // Hole den Namen der gescannten Holzart
        String scannedWoodName = scannedWoodCode;
        try {
          final woodDoc = await FirebaseFirestore.instance
              .collection('wood_types')
              .doc(scannedWoodCode)
              .get();
          if (woodDoc.exists) {
            scannedWoodName = woodDoc.data()?['name'] ?? scannedWoodCode;
          }
        } catch (_) {}

        AppToast.show(
          message: 'Holzart $scannedWoodCode ($scannedWoodName) passt nicht zum Stamm $woodType ($woodName)',
          height: h,
        );
        return;
      }

      // Prüfe ob die Codes in den Dropdowns existieren
      final instrumentExists = instruments?.any(
            (doc) => (doc.data() as Map<String, dynamic>)['code'] == instrumentCode,
      ) ?? false;
      final partExists = parts?.any(
            (doc) => (doc.data() as Map<String, dynamic>)['code'] == partCode,
      ) ?? false;
      final qualityExists = qualities?.any(
            (doc) => (doc.data() as Map<String, dynamic>)['code'] == qualityCode,
      ) ?? false;

      if (!instrumentExists || !partExists || !qualityExists) {
        AppToast.show(
          message: 'Ein oder mehrere Codes wurden nicht gefunden',
          height: h,
        );
        return;
      }

      // Setze die Werte
      setState(() {
        selectedInstrument = instrumentCode;
        selectedPart = partCode;
        selectedQuality = qualityCode;

        // Auto-Thermo für bestimmte Qualitäten
        if (['20', '21', '22', '23'].contains(qualityCode)) {
          thermallyTreated = true;
        }
      });

      // Prüfe ob Produkt existiert
      _checkProductExists();

      AppToast.show(
        message: 'Produkt übernommen ✓',
        height: h,
      );

    } catch (e) {
      debugPrint('Fehler beim Scannen: $e');
      AppToast.show(message: 'Fehler beim Scannen', height: h);
    }
  }
  Future<void> _loadKeepSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_settings')
          .doc('stamm_buchung')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _keepInstrument = data['keep_instrument'] ?? false;
          _keepPart = data['keep_part'] ?? false;
          _keepQuality = data['keep_quality'] ?? false;
          _keepThermo = data['keep_thermo'] ?? false;
          _keepHasel = data['keep_hasel'] ?? false;
          _keepMenge = data['keep_menge'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Keep-Settings: $e');
    }
  }


  Future<void> _checkProductExists() async {
    final shortBarcode = _generateShortBarcode();
    if (shortBarcode.isEmpty || shortBarcode.contains('─')) return;

    try {
      final inventoryDoc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(shortBarcode)
          .get();

      if (mounted) {
        setState(() {
          if (inventoryDoc.exists) {
            _isNewProduct = false;
            final data = inventoryDoc.data()!;
            _selectedUnit = data['unit'] ?? 'Stk';
            _preisController.text = (data['price_CHF'] ?? 0.0).toString();
          } else {
            _isNewProduct = true;
            _preisController.text = '';
          }
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Prüfen des Produkts: $e');
    }
  }


  Future<void> _saveKeepSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('user_settings')
          .doc('stamm_buchung')
          .set({
        'keep_instrument': _keepInstrument,
        'keep_part': _keepPart,
        'keep_quality': _keepQuality,
        'keep_thermo': _keepThermo,
        'keep_hasel': _keepHasel,
        'keep_menge': _keepMenge,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Fehler beim Speichern der Keep-Settings: $e');
    }
  }

  void _toggleKeep(String field, bool value) {
    setState(() {
      switch (field) {
        case 'instrument': _keepInstrument = value; break;
        case 'part': _keepPart = value; break;
        case 'quality': _keepQuality = value; break;
        case 'thermo': _keepThermo = value; break;
        case 'hasel': _keepHasel = value; break;
        case 'menge': _keepMenge = value; break;
      }
    });
    _saveKeepSettings();
  }

  Future<void> _loadDropdownData() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('instruments').orderBy('code').get(),
        FirebaseFirestore.instance.collection('parts').orderBy('code').get(),
        FirebaseFirestore.instance.collection('qualities').orderBy('code').get(),
      ]);

      if (!mounted) return;
      setState(() {
        instruments = results[0].docs;
        parts = results[1].docs;
        qualities = results[2].docs;
      });
    } catch (e) {
      debugPrint('Fehler beim Laden der Dropdown-Daten: $e');
    }
  }

  Future<void> _loadGebuchteProdukte() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('production_batches')
          .where('roundwood_id', isEqualTo: widget.stammId)
          .orderBy('stock_entry_date', descending: true)
          .get();

      if (!mounted) return;
      setState(() {
        _gebuchteProdukte = snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fehler beim Laden der gebuchten Produkte: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getNameFromDocs(List<QueryDocumentSnapshot>? docs, String? code) {
    if (docs == null || code == null) return '';
    try {
      final doc = docs.firstWhere(
            (doc) => (doc.data() as Map<String, dynamic>)['code'] == code,
      );
      return (doc.data() as Map<String, dynamic>)['name'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  String _generateBarcode() {
    if (selectedInstrument == null || selectedPart == null || selectedQuality == null) {
      return '';
    }

    final thermo = thermallyTreated ? "1" : "0";
    final hasel = haselfichte ? "1" : "0";
    final mond = moonwood ? "1" : "0";
    final fsc = fsc100 ? "1" : "0";

    return '$selectedInstrument$selectedPart.$woodType$selectedQuality.$thermo$hasel$mond$fsc.${year.toString().substring(2)}';
  }

  String _generateShortBarcode() {
    if (selectedInstrument == null || selectedPart == null || selectedQuality == null) {
      return '';
    }
    return '$selectedInstrument$selectedPart.$woodType$selectedQuality';
  }

  Future<void> _buchen() async {
    if (selectedInstrument == null || selectedPart == null || selectedQuality == null) {
      AppToast.show(message: 'Bitte alle Felder ausfüllen', height: h);
      return;
    }

    final menge = int.tryParse(_mengeController.text) ?? 0;
    if (menge <= 0) {
      AppToast.show(message: 'Bitte gültige Menge eingeben', height: h);
      return;
    }

    // NEU: Bei neuem Produkt Preis prüfen
    if (_isNewProduct) {
      final preis = double.tryParse(_preisController.text) ?? 0.0;
      if (preis <= 0) {
        AppToast.show(message: 'Bitte gültigen Preis eingeben', height: h);
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final productId = _generateBarcode();
      final shortBarcode = _generateShortBarcode();

      // Namen holen
      final instrumentName = _getNameFromDocs(instruments, selectedInstrument);
      final partName = _getNameFromDocs(parts, selectedPart);
      final qualityName = _getNameFromDocs(qualities, selectedQuality);

      // NEU: Preis und Unit bestimmen
      double price;
      String unit;

      if (_isNewProduct) {
        price = double.tryParse(_preisController.text) ?? 0.0;
        unit = _selectedUnit;
      } else {
        // Hole aus inventory
        final inventoryDoc = await firestore.collection('inventory').doc(shortBarcode).get();
        if (inventoryDoc.exists) {
          price = (inventoryDoc.data()?['price_CHF'] as num?)?.toDouble() ?? 0.0;
          unit = inventoryDoc.data()?['unit'] ?? 'Stk';
        } else {
          price = 0.0;
          unit = 'Stk';
        }
      }

      final value = menge * price;

      // Produktname generieren
      final productName = '$instrumentName $partName';

      // 1. Production Collection Update/Create
      final productionRef = firestore.collection('production').doc(productId);
      final productionDoc = await productionRef.get();

      if (productionDoc.exists) {
        batch.update(productionRef, {
          'quantity': FieldValue.increment(menge),
          'last_stock_entry': FieldValue.serverTimestamp(),
          'last_stock_change': menge,
        });
      } else {
        batch.set(productionRef, {
          'product_id': productId,
          'barcode': productId,
          'short_barcode': shortBarcode,
          'instrument_code': selectedInstrument,
          'instrument_name': instrumentName,
          'part_code': selectedPart,
          'part_name': partName,
          'wood_code': woodType,
          'wood_name': woodName,
          'quality_code': selectedQuality,
          'quality_name': qualityName,
          'product_name': productName,  // ← NEU: product_name setzen
          'year': year,
          'thermally_treated': thermallyTreated,
          'haselfichte': haselfichte,
          'moonwood': moonwood,
          'FSC_100': fsc100,
          'quantity': menge,
          'unit': unit,  // ← NEU: unit setzen
          'price_CHF': price,  // ← NEU: price setzen
          'created_at': FieldValue.serverTimestamp(),
          'last_stock_entry': FieldValue.serverTimestamp(),
        });
      }

      // 2. Batch Nummer ermitteln
      final batchesSnapshot = await productionRef
          .collection('batch')
          .orderBy('batch_number', descending: true)
          .limit(1)
          .get();

      int nextBatchNumber = 1;
      if (batchesSnapshot.docs.isNotEmpty) {
        nextBatchNumber = (batchesSnapshot.docs.first.data()['batch_number'] as int) + 1;
      }

      // 3. Batch in Subcollection
      final batchRef = productionRef.collection('batch').doc(nextBatchNumber.toString().padLeft(4, '0'));
      batch.set(batchRef, {
        'batch_number': nextBatchNumber,
        'quantity': menge,
        'stock_entry_date': FieldValue.serverTimestamp(),
        'roundwood_id': widget.stammId,
        'roundwood_internal_number': widget.stammData['internal_number'],
        'roundwood_year': widget.stammData['year'],
      });

      // 4. Flat Batch Collection
      final flatBatchRef = firestore.collection('production_batches').doc();
      batch.set(flatBatchRef, {
        'product_id': productId,
        'batch_number': nextBatchNumber,
        'roundwood_id': widget.stammId,
        'roundwood_internal_number': widget.stammData['internal_number'],
        'roundwood_year': widget.stammData['year'],
        'stock_entry_date': FieldValue.serverTimestamp(),
        'year': year,
        'quantity': menge,
        'value': value,
        'unit': unit,
        'price_CHF': price,
        'instrument_code': selectedInstrument,
        'instrument_name': instrumentName,
        'part_code': selectedPart,
        'part_name': partName,
        'wood_code': woodType,
        'wood_name': woodName,
        'quality_code': selectedQuality,
        'quality_name': qualityName,
        'moonwood': moonwood,
        'haselfichte': haselfichte,
        'thermally_treated': thermallyTreated,
        'FSC_100': fsc100,
      });

      // 5. Inventory Update
      final inventoryRef = firestore.collection('inventory').doc(shortBarcode);
      final existingInventory = await inventoryRef.get();

      if (existingInventory.exists) {
        batch.update(inventoryRef, {
          'quantity': FieldValue.increment(menge),
          'last_stock_entry': FieldValue.serverTimestamp(),
          'last_stock_change': menge,
        });
      } else {
        // NEU: Komplettes Inventory-Dokument erstellen
        batch.set(inventoryRef, {
          'instrument_code': selectedInstrument,
          'instrument_name': instrumentName,
          'part_code': selectedPart,
          'part_name': partName,
          'wood_code': woodType,
          'wood_name': woodName,
          'quality_code': selectedQuality,
          'quality_name': qualityName,
          'product_name': productName,
          'short_barcode': shortBarcode,
          'unit': unit,
          'price_CHF': price,
          'quantity': menge,
          'created_at': FieldValue.serverTimestamp(),
          'last_stock_entry': FieldValue.serverTimestamp(),
          'last_modified': FieldValue.serverTimestamp(),
        });
      }

      // 6. Stock Entry für History
      final entryRef = firestore.collection('stock_entries').doc();
      batch.set(entryRef, {
        'product_id': productId,
        'batch_number': nextBatchNumber,
        'product_name': productName,
        'quantity_change': menge,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'entry',
        'entry_type': 'stamm_buchung',
        'instrument_name': instrumentName,
        'part_name': partName,
        'wood_name': woodName,
        'quality_name': qualityName,
        'roundwood_id': widget.stammId,
        'roundwood_internal_number': widget.stammData['internal_number'],
      });



      await batch.commit();

      await FirebaseFirestore.instance
          .collection('roundwood')
          .doc(widget.stammId)
          .update({
        'last_booking': FieldValue.serverTimestamp(),
      });


      if (!mounted) return;

      AppToast.show(
        message: '$menge x $instrumentName $partName $qualityName gebucht',
        height: h,
      );

      // Reset Formular
      setState(() {
        if (!_keepInstrument) selectedInstrument = null;
        if (!_keepPart) selectedPart = null;
        if (!_keepQuality) selectedQuality = null;
        if (!_keepThermo) thermallyTreated = false;
        if (!_keepHasel) haselfichte = false;
        if (!_keepMenge) _mengeController.text = '1';
        _isNewProduct = false;
        _preisController.text = '';
        _isSaving = false;
      });

      _loadGebuchteProdukte();

    } catch (e) {
      debugPrint('Fehler beim Buchen: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.show(message: 'Fehler beim Buchen: $e', height: h);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: widget.isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final stammNr = widget.stammData['internal_number'] ?? '?';
    final stammJahr = widget.stammData['year'] ?? '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F4A29),
        borderRadius: widget.isDesktop
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          if (!widget.isDesktop)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: getAdaptiveIcon(
                  iconName: 'forest',
                  defaultIcon: Icons.forest,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stamm $stammNr / $stammJahr',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          woodName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        if (moonwood) ...[
                          const SizedBox(width: 8),
                          _buildHeaderTag('Mondholz', Icons.nightlight),
                        ],
                        if (fsc100) ...[
                          const SizedBox(width: 8),
                          _buildHeaderTag('FSC', Icons.eco),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),  // ← Direkt schließen, keine Bestätigung

                icon: getAdaptiveIcon(
                  iconName: 'close',
                  defaultIcon: Icons.close,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Linke Seite: Gebuchte Produkte
        Expanded(
          flex: 1,
          child: _buildGebuchteProdukteListe(),
        ),
        Container(width: 1, color: Colors.grey[300]),
        // Rechte Seite: Buchungsformular
        Expanded(
          flex: 1,
          child: _buildBuchungsFormular(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        children: [
          _buildBuchungsFormular(),
          const Divider(height: 1),
          _buildGebuchteProdukteListe(),
        ],
      ),
    );
  }

  Widget _buildGebuchteProdukteListe() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'history',
                  defaultIcon: Icons.history,
                  color: const Color(0xFF0F4A29),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bereits gebucht',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4A29),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4A29).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_gebuchteProdukte.length} Einträge',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F4A29),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else if (_gebuchteProdukte.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'inbox',
                      defaultIcon: Icons.inbox,
                      color: Colors.grey[400],
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Noch keine Buchungen\nfür diesen Stamm',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            widget.isDesktop
                ? Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _gebuchteProdukte.length,
                itemBuilder: (context, index) => _buildProduktItem(_gebuchteProdukte[index]),
              ),
            )
                : Column(
              children: _gebuchteProdukte
                  .map((p) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildProduktItem(p),
              ))
                  .toList(),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  Widget _buildProduktItem(Map<String, dynamic> produkt) {
    final productId = produkt['product_id'] as String? ?? '';
    // Short Barcode aus product_id extrahieren (erste 2 Teile: IIPP.HHQQ)
    final parts = productId.split('.');
    final shortBarcode = parts.length >= 2 ? '${parts[0]}.${parts[1]}' : productId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _openProductEdit(shortBarcode),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Menge Badge
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4A29).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${produkt['quantity'] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4A29),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Produkt-Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zeile 1: Produkt Name
                    Text(
                      '${produkt['instrument_name']} ${produkt['part_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    // Zeile 2: Qualität & Holzart
                    Text(
                      '${produkt['quality_name']} • ${produkt['wood_name']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    // Zeile 3: Artikelnummer (NEU)
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'tag',
                          defaultIcon: Icons.tag,
                          color: Colors.grey[500],
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          productId,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontFamily: 'monospace',
                          ),
                        ),
                        const Spacer(),
                        // Edit-Hinweis
                        getAdaptiveIcon(
                          iconName: 'edit',
                          defaultIcon: Icons.edit,
                          color: Colors.grey[400],
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Eigenschaften Icons
              Column(
                children: [
                  if (produkt['thermally_treated'] == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: getAdaptiveIcon(
                        iconName: 'whatshot',
                        defaultIcon: Icons.whatshot,
                        color: Colors.orange,
                        size: 16,
                      ),
                    ),
                  if (produkt['haselfichte'] == true)
                    getAdaptiveIcon(
                      iconName: 'grain',
                      defaultIcon: Icons.grain,
                      color: Colors.brown,
                      size: 16,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// Neue Methode: _openProductEdit() hinzufügen
// ═══════════════════════════════════════════════════════════════════════════

  Future<void> _openProductEdit(String shortBarcode) async {
    try {
      // Hole Produkt-Daten aus inventory
      final inventoryDoc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(shortBarcode)
          .get();

      if (!mounted) return;

      if (inventoryDoc.exists) {
        // Navigiere zum AddProductScreen im Edit-Modus
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProductScreen(
              isProduction: false,
              editMode: true,
              barcode: shortBarcode,
              productData: inventoryDoc.data(),
              onSave: () {
                // Optional: Liste neu laden nach Speichern
                _loadGebuchteProdukte();
              },
            ),
          ),
        );
      } else {
        AppToast.show(
          message: 'Produkt $shortBarcode nicht im Verkaufslager gefunden',
          height: h,
        );
      }
    } catch (e) {
      debugPrint('Fehler beim Öffnen des Produkts: $e');
      AppToast.show(message: 'Fehler: $e', height: h);
    }
  }
  Widget _buildBuchungsFormular() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card: Vom Stamm übernommen
          _buildStammInfoCard(),
          const SizedBox(height: 16),

          // Produkt-Auswahl
          _buildProduktAuswahlCard(),
          const SizedBox(height: 16),

          // Eigenschaften
          _buildEigenschaftenCard(),
          const SizedBox(height: 16),

          // Menge
          _buildMengeCard(),
          const SizedBox(height: 24),

          // Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }
  Widget _buildStammInfoCard() {
    final previewBarcode = _generatePreviewBarcode();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F4A29).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F4A29).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Stamm-Info Zeile
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'info',
                defaultIcon: Icons.info_outline,
                color: const Color(0xFF0F4A29),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Vom Stamm: $woodName, Jahr $year${moonwood ? ', Mondholz' : ''}${fsc100 ? ', FSC' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF0F4A29).withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barcode Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4A29).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF0F4A29).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                getAdaptiveIcon(
                  iconName: 'qr_code',
                  defaultIcon: Icons.qr_code,
                  color: const Color(0xFF0F4A29),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  previewBarcode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                    color: Color(0xFF0F4A29),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generatePreviewBarcode() {
    // Teil 1: Instrument (II) + Part (PP)
    final instrument = selectedInstrument ?? '──';
    final part = selectedPart ?? '──';

    // Teil 2: Wood (HH) + Quality (QQ)
    final wood = woodType.isNotEmpty ? woodType : '──';
    final quality = selectedQuality ?? '──';

    // Teil 3: Eigenschaften (EEEE)
    final thermo = thermallyTreated ? '1' : '0';
    final hasel = haselfichte ? '1' : '0';
    final mond = moonwood ? '1' : '0';
    final fsc = fsc100 ? '1' : '0';
    final eigenschaften = '$thermo$hasel$mond$fsc';

    // Teil 4: Jahr (JJ)
    final jahr = year.toString().substring(2);

    return '$instrument$part.$wood$quality.$eigenschaften.$jahr';
  }
  Widget _buildProduktAuswahlCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'category',
                  defaultIcon: Icons.category,
                  color: const Color(0xFF0F4A29),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Produkt wählen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4A29),
                  ),
                ),
                const Spacer(),
                // ═══════════════════════════════════════════════════
                // NEU: Scan-Button
                // ═══════════════════════════════════════════════════
                IconButton(
                  onPressed: _scanAndFillProduct,
                  icon: getAdaptiveIcon(
                    iconName: 'qr_code_scanner',
                    defaultIcon: Icons.qr_code_scanner,
                    color: const Color(0xFF0F4A29),
                    size: 22,
                  ),
                  tooltip: 'Verkaufscode scannen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // ═══════════════════════════════════════════════════
                _buildKeepInfoButton(),
              ],
            ),
            const SizedBox(height: 16),
            // Instrument mit Behalten-Checkbox
            _buildDropdownWithKeep(
              label: 'Instrument',
              value: selectedInstrument,
              items: instruments,
              onChanged: (v) {
                setState(() => selectedInstrument = v);
                _checkProductExists();  // ← NEU
              },
              keepValue: _keepInstrument,
              onKeepChanged: (v) => _toggleKeep('instrument', v),
            ),
            const SizedBox(height: 12),

            // Bauteil mit Behalten-Checkbox
            _buildDropdownWithKeep(
              label: 'Bauteil',
              value: selectedPart,
              items: parts,
              onChanged: (v) {
                setState(() => selectedPart = v);
                _checkProductExists();  // ← NEU
              },
              keepValue: _keepPart,
              onKeepChanged: (v) => _toggleKeep('part', v),
            ),
            const SizedBox(height: 12),

            // Qualität mit Behalten-Checkbox + Auto-Thermo
            _buildDropdownWithKeep(
              label: 'Qualität',
              value: selectedQuality,
              items: qualities,
              onChanged: (v) {
                setState(() {
                  selectedQuality = v;
                  if (v != null && ['20', '21', '22', '23'].contains(v)) {
                    thermallyTreated = true;
                  }
                });
                _checkProductExists();  // ← NEU
              },
              keepValue: _keepQuality,
              onKeepChanged: (v) => _toggleKeep('quality', v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeepInfoButton() {
    return IconButton(
      onPressed: () => _showKeepInfoDialog(),
      icon: getAdaptiveIcon(
        iconName: 'help_outline',
        defaultIcon: Icons.help_outline,
        color: Colors.grey[500],
        size: 20,
      ),
      tooltip: 'Info zu Behalten-Funktion',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  void _showKeepInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'push_pin',
              defaultIcon: Icons.push_pin,
              color: const Color(0xFF0F4A29),
            ),
            const SizedBox(width: 8),
            const Text('Werte behalten'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mit dem Pin-Symbol kannst du Werte für die nächste Buchung behalten.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4A29).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'lightbulb',
                    defaultIcon: Icons.lightbulb_outline,
                    color: const Color(0xFF0F4A29),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Praktisch wenn du z.B. viele Gitarren-Decken in verschiedenen Qualitäten buchst.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Deine Einstellungen werden gespeichert.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownWithKeep({
    required String label,
    required String? value,
    required List<QueryDocumentSnapshot>? items,
    required Function(String?) onChanged,
    required bool keepValue,
    required Function(bool) onKeepChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: items != null
              ? DropdownButtonFormField<String>(
            decoration: _inputDecoration(label),
            value: value,
            items: items.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DropdownMenuItem<String>(
                value: data['code'] as String,
                child: Text('${data['name']} (${data['code']})'),
              );
            }).toList(),
            onChanged: onChanged,
          )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        _buildKeepCheckbox(keepValue, onKeepChanged),
      ],
    );
  }

  Widget _buildKeepCheckbox(bool value, Function(bool) onChanged) {
    return Tooltip(
      message: value ? 'Wert wird behalten' : 'Wert nach Buchung löschen',
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 48,
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFF0F4A29).withOpacity(0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value
                  ? const Color(0xFF0F4A29)
                  : Colors.grey[300]!,
            ),
          ),
          child: Icon(
            value ? Icons.push_pin : Icons.push_pin_outlined,
            color: value ? const Color(0xFF0F4A29) : Colors.grey[400],
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildEigenschaftenCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'tune',
                  defaultIcon: Icons.tune,
                  color: const Color(0xFF0F4A29),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Eigenschaften',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4A29),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSwitchWithKeep(
              title: 'Thermobehandelt',
              icon: Icons.whatshot,
              iconName: 'whatshot',
              value: thermallyTreated,
              onChanged: (v) => setState(() => thermallyTreated = v),
              keepValue: _keepThermo,
              onKeepChanged: (v) => _toggleKeep('thermo', v),
            ),
            _buildSwitchWithKeep(
              title: 'Haselfichte',
              icon: Icons.grain,
              iconName: 'grain',
              value: haselfichte,
              onChanged: (v) => setState(() => haselfichte = v),
              keepValue: _keepHasel,
              onKeepChanged: (v) => _toggleKeep('hasel', v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchWithKeep({
    required String title,
    required IconData icon,
    required String iconName,
    required bool value,
    required Function(bool) onChanged,
    required bool keepValue,
    required Function(bool) onKeepChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: SwitchListTile(
            title: Row(
              children: [
                getAdaptiveIcon(
                  iconName: iconName,
                  defaultIcon: icon,
                  color: value ? const Color(0xFF0F4A29) : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF0F4A29),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        _buildKeepCheckbox(keepValue, onKeepChanged),
      ],
    );
  }

  Widget _buildMengeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════════════════════════
            // NEU: Hinweis wenn neues Produkt
            // ═══════════════════════════════════════════════════════════════
            if (_isNewProduct) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'info',
                      defaultIcon: Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Neues Produkt - bitte Einheit und Preis angeben',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Einheit Dropdown
              Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'straighten',
                    defaultIcon: Icons.straighten,
                    color: const Color(0xFF0F4A29),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Einheit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: _availableUnits.map((unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(unit),
                )).toList(),
                onChanged: (v) => setState(() => _selectedUnit = v ?? 'Stk'),
              ),
              const SizedBox(height: 16),
              // Preis Eingabe
              Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'payments',
                    defaultIcon: Icons.payments,
                    color: const Color(0xFF0F4A29),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Preis (CHF)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _preisController,
                decoration: InputDecoration(
                  hintText: '0.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixText: 'CHF ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // ═══════════════════════════════════════════════════════════════
            // Bestehende Menge-Eingabe
            // ═══════════════════════════════════════════════════════════════
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'numbers',
                  defaultIcon: Icons.numbers,
                  color: const Color(0xFF0F4A29),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Menge',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Zeige Einheit wenn bekannt
                if (!_isNewProduct)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedUnit,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    final current = int.tryParse(_mengeController.text) ?? 1;
                    if (current > 1) {
                      _mengeController.text = (current - 1).toString();
                    }
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'remove_circle',
                    defaultIcon: Icons.remove_circle,
                    color: const Color(0xFF0F4A29),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 8),
                // ═══════════════════════════════════════════════════════════════
                // TextField OHNE suffix
                // ═══════════════════════════════════════════════════════════════
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _mengeController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                // ═══════════════════════════════════════════════════════════════
                // NEU: Einheit als separates Element
                // ═══════════════════════════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4A29).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0F4A29).withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    _selectedUnit,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F4A29),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final current = int.tryParse(_mengeController.text) ?? 0;
                    _mengeController.text = (current + 1).toString();
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'add_circle',
                    defaultIcon: Icons.add_circle,
                    color: const Color(0xFF0F4A29),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 8),
                _buildKeepCheckbox(_keepMenge, (v) => _toggleKeep('menge', v)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildActionButtons() {
    final canBook = selectedInstrument != null &&
        selectedPart != null &&
        selectedQuality != null &&
        (_mengeController.text.isNotEmpty && int.tryParse(_mengeController.text) != 0);

    final isClosed = widget.stammData['is_closed'] ?? false;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: canBook && !_isSaving ? _buchen : null,
            icon: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : getAdaptiveIcon(
              iconName: 'add',
              defaultIcon: Icons.add,
              color: Colors.white,
            ),
            label: Text(_isSaving ? 'Wird gebucht...' : 'Buchen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4A29),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Fertig Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: getAdaptiveIcon(
                  iconName: 'check',
                  defaultIcon: Icons.check,
                  color: const Color(0xFF0F4A29),
                ),
                label: const Text('Fertig'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F4A29),
                  side: const BorderSide(color: Color(0xFF0F4A29)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Stamm abschließen Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isClosed ? null : () => _showCloseStammConfirmation(),
                icon: getAdaptiveIcon(
                  iconName: isClosed ? 'lock' : 'lock_open',
                  defaultIcon: isClosed ? Icons.lock : Icons.lock_open,
                  color: Colors.white,
                ),
                label: Text(isClosed ? 'Abgeschlossen' : 'Abschließen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClosed ? Colors.grey : Colors.orange[700],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[400],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCloseStammConfirmation() {
    final stammNr = widget.stammData['internal_number'] ?? '?';
    final stammJahr = widget.stammData['year'] ?? '?';

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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchtest du den Stamm $stammNr/$stammJahr wirklich abschließen?'),
            const SizedBox(height: 12),
            Container(
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
                    defaultIcon: Icons.info_outline,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Abgeschlossene Stämme werden standardmäßig ausgeblendet, können aber weiterhin geöffnet werden.',
                      style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
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
              Navigator.pop(context);
              await _closeStamm();
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

  Future<void> _closeStamm() async {
    try {
      await FirebaseFirestore.instance
          .collection('roundwood')
          .doc(widget.stammId)
          .update({
        'is_closed': true,
        'closed_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      AppToast.show(
        message: 'Stamm ${widget.stammData['internal_number']}/${widget.stammData['year']} abgeschlossen',
        height: h,
      );

      // Sheet schließen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: 'Fehler: $e', height: h);
    }
  }
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  void _showCloseConfirmation() {
    if (_gebuchteProdukte.isEmpty) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stamm abschließen?'),
        content: Text(
          'Du hast ${_gebuchteProdukte.length} Produkte für diesen Stamm gebucht. Möchtest du die Buchung beenden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Weiter buchen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dialog schließen
              Navigator.pop(context); // Sheet schließen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4A29),
            ),
            child: const Text('Abschließen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mengeController.dispose();
    _preisController.dispose();  // ← NEU
    super.dispose();
  }
}