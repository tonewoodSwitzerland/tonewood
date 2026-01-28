import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:tonewood/constants.dart';
import '../services/icon_helper.dart';

import '../services/standardized_product_export_service.dart';
import '../services/standardized_product_import_service.dart';
import '../services/standardized_products.dart';

class StandardizedProductManagementScreen extends StatefulWidget {
  const StandardizedProductManagementScreen({Key? key}) : super(key: key);

  @override
  StandardizedProductManagementScreenState createState() => StandardizedProductManagementScreenState();
}

class StandardizedProductManagementScreenState extends State<StandardizedProductManagementScreen> {
  final TextEditingController searchController = TextEditingController();
  List<DocumentSnapshot> _productDocs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 200;
  final ScrollController _scrollController = ScrollController();
  String _lastSearchTerm = '';
  List<StandardizedProduct> _allLoadedProducts = [];

  // Filter
  String? _selectedInstrument;
  List<String> _availableInstruments = [];

  @override
  void initState() {
    super.initState();
    _loadInstruments();
    _loadInitialProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadMoreProducts();
      }
    });

    searchController.addListener(_onSearchChanged);




  }

  Future<void> _loadInstruments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('standardized_products')
          .get();

      final instruments = <String>{};
      for (var doc in snapshot.docs) {
        final instrument = doc.data()['instrument'] as String?;
        if (instrument != null && instrument.isNotEmpty) {
          instruments.add(instrument);
        }
      }

      if (mounted) {
        setState(() {
          _availableInstruments = instruments.toList()..sort();
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Instrumente: $e');
    }
  }

  void _onSearchChanged() {
    if (searchController.text != _lastSearchTerm) {
      _lastSearchTerm = searchController.text;
      _resetAndReload();
    }
  }

  void _resetAndReload() {
    if (mounted) {
      setState(() {
        _productDocs = [];
        _hasMore = true;
        _allLoadedProducts = [];
      });
      _loadInitialProducts();
    }
  }

  Future<void> _loadInitialProducts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('standardized_products')
          .orderBy('articleNumber');

      if (_selectedInstrument != null) {
        query = query.where('instrument', isEqualTo: _selectedInstrument);
      }

      final querySnapshot = await query.limit(_limit).get();

      if (mounted) {
        setState(() {
          _productDocs = querySnapshot.docs;
          _allLoadedProducts = querySnapshot.docs.map((doc) =>
              StandardizedProduct.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
          _hasMore = querySnapshot.docs.length == _limit;
          _isLoading = false;
        });

        if (_lastSearchTerm.isNotEmpty) {
          _filterSearchResults();
        }
      }
    } catch (error) {
      print('Fehler beim Laden der Produkte: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading || !_hasMore || _productDocs.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final lastDoc = _productDocs.last;

      Query query = FirebaseFirestore.instance
          .collection('standardized_products')
          .orderBy('articleNumber')
          .startAfterDocument(lastDoc);

      if (_selectedInstrument != null) {
        query = query.where('instrument', isEqualTo: _selectedInstrument);
      }

      final querySnapshot = await query.limit(_limit).get();

      if (mounted) {
        setState(() {
          _productDocs.addAll(querySnapshot.docs);
          _allLoadedProducts.addAll(querySnapshot.docs.map((doc) =>
              StandardizedProduct.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
          _hasMore = querySnapshot.docs.length == _limit;
          _isLoading = false;
        });

        if (_lastSearchTerm.isNotEmpty) {
          _filterSearchResults();
        }
      }
    } catch (error) {
      print('Fehler beim Laden weiterer Produkte: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterSearchResults() {
    if (_lastSearchTerm.isEmpty) return;

    final searchTerm = _lastSearchTerm.toLowerCase();
    final filteredDocs = _productDocs.where((doc) {
      final product = StandardizedProduct.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      return product.articleNumber.toLowerCase().contains(searchTerm) ||
          product.productName.toLowerCase().contains(searchTerm) ||
          product.instrument.toLowerCase().contains(searchTerm);
    }).toList();

    if (mounted) {
      setState(() {
        _productDocs = filteredDocs;
      });
    }
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Standardprodukte'),
        actions: [
          // Debug-Button (nur für Entwicklung)

          IconButton(
            icon: getAdaptiveIcon(iconName: 'upload', defaultIcon: Icons.upload),
            onPressed: () => StandardizedProductImportService.showImportDialog(context, _resetAndReload),
            tooltip: 'Produkte importieren',
          ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download),
            onPressed: () => StandardizedProductExportService.exportProductsCsv(context),
            tooltip: 'Produkte exportieren',
          ),
        ],
      ),
      body: Column(
        children: [
          // Suchfeld und Filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Suchfeld
                TextFormField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Suchen (Artikelnr., Name, Instrument)',
                    prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                      icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear),
                      onPressed: () {
                        searchController.clear();
                      },
                    )
                        : null,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 12),
                // Instrumentenfilter
                if (_availableInstruments.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedInstrument,
                    decoration: InputDecoration(
                      labelText: 'Instrument filtern',
                      prefixIcon: getAdaptiveIcon(iconName: 'music_note', defaultIcon: Icons.music_note),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Alle Instrumente'),
                      ),
                      ..._availableInstruments.map((instrument) =>
                          DropdownMenuItem(
                            value: instrument,
                            child: Text(instrument),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedInstrument = value;
                      });
                      _resetAndReload();
                    },
                  ),
              ],
            ),
          ),

          // Ergebnisanzahl
          if (_lastSearchTerm.isNotEmpty || _selectedInstrument != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  if (_lastSearchTerm.isNotEmpty)
                    Text(
                      'Suche: "$_lastSearchTerm"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${_productDocs.length} Produkte',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Produktliste
          Expanded(
            child: _isLoading && _productDocs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _productDocs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getAdaptiveIcon(
                    iconName: 'inventory',
                    defaultIcon: Icons.inventory,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _lastSearchTerm.isEmpty
                        ? 'Keine Standardprodukte gefunden'
                        : 'Keine Ergebnisse für "${_lastSearchTerm}"',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _productDocs.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _productDocs.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final doc = _productDocs[index];
                final product = StandardizedProduct.fromMap(
                    doc.data() as Map<String, dynamic>, doc.id);

                return _buildProductCard(product);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(null),
        child: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
        tooltip: 'Neues Standardprodukt',
      ),
    );
  }

  Widget _buildProductCard(StandardizedProduct product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            product.articleNumber,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.productName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${product.parts} Teile',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.instrument),
            const SizedBox(height: 4),
            Text(
              'Standard: ${product.measurementText.standard}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              'Mit Zumaß: ${product.measurementText.withAddition}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
              onPressed: () => _showProductDialog(product),
            ),
            IconButton(
              icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
              onPressed: () => _showDeleteConfirmation(product),
            ),
          ],
        ),
        onTap: () => _showProductDetails(product),
      ),
    );
  }

  void _showProductDetails(StandardizedProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product.articleNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          product.instrument,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            // Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection(
                      'Grunddaten',
                      [
                        _buildDetailRow('Artikelnummer', product.articleNumber),

                        _buildDetailRow('Instrument', product.instrument),
                        _buildDetailRow('Teile', '${product.parts}'),
                        _buildDetailRow('Dickeklasse', '${product.thicknessClass}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Abmessungen',
                      [
                        _buildDetailRow('Länge (x)',
                            '${product.dimensions.length.standard} mm '
                                '(+${product.dimensions.length.addition}) = '
                                '${product.dimensions.length.withAddition} mm'),
                        _buildDetailRow('Breite (y)',
                            '${product.dimensions.width.standard} mm '
                                '(+${product.dimensions.width.addition}) = '
                                '${product.dimensions.width.withAddition} mm'),
                        _buildDetailRow('Dicke (z)',
                            product.dimensions.thickness.value2 != null
                                ? '${product.dimensions.thickness.value} / ${product.dimensions.thickness.value2} mm (Trapez)'
                                : '${product.dimensions.thickness.value} mm'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Maßtext',
                      [
                        _buildDetailRow('Standard', product.measurementText.standard),
                        _buildDetailRow('Mit Zumaß', product.measurementText.withAddition),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Volumen',
                      [
                        _buildDetailRow('Standard',
                            '${product.volume.mm3Standard.toStringAsFixed(0)} mm³ / '
                                '${product.volume.dm3Standard.toStringAsFixed(3)} dm³'),
                        _buildDetailRow('Mit Zumaß',
                            '${product.volume.mm3WithAddition.toStringAsFixed(0)} mm³ / '
                                '${product.volume.dm3WithAddition.toStringAsFixed(3)} dm³'),
                      ],
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(StandardizedProduct? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StandardizedProductDialog(
          product: product,
          onSave: (updatedProduct) async {
            try {
              if (product == null) {
                // Neues Produkt
                await FirebaseFirestore.instance
                    .collection('standardized_products')
                    .add(updatedProduct.toMap()..['createdAt'] = FieldValue.serverTimestamp());
              } else {
                // Bestehendes Produkt aktualisieren
                await FirebaseFirestore.instance
                    .collection('standardized_products')
                    .doc(product.id)
                    .update(updatedProduct.toMap()..['updatedAt'] = FieldValue.serverTimestamp());
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(product == null
                        ? 'Standardprodukt wurde angelegt'
                        : 'Standardprodukt wurde aktualisiert'),
                    backgroundColor: Colors.green,
                  ),
                );
                _resetAndReload();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fehler: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(StandardizedProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Standardprodukt löschen'),
        content: Text(
          'Möchtest du das Produkt "${product.articleNumber} - ${product.productName}" wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('standardized_products')
                    .doc(product.id)
                    .delete();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Standardprodukt wurde gelöscht'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _resetAndReload();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Löschen: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}

// Dialog zum Bearbeiten/Erstellen von Standardprodukten
class StandardizedProductDialog extends StatefulWidget {
  final StandardizedProduct? product;
  final Function(StandardizedProduct) onSave;

  const StandardizedProductDialog({
    Key? key,
    this.product,
    required this.onSave,
  }) : super(key: key);

  @override
  State<StandardizedProductDialog> createState() => _StandardizedProductDialogState();
}

class _StandardizedProductDialogState extends State<StandardizedProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _articleNumberController;
  late TextEditingController _productNameController;
  late TextEditingController _instrumentController;
  late TextEditingController _partsController;
  late TextEditingController _lengthStandardController;
  late TextEditingController _lengthAdditionController;
  late TextEditingController _widthStandardController;
  late TextEditingController _widthAdditionController;
  late TextEditingController _thicknessValueController;
  late TextEditingController _thicknessValue2Controller;
  late TextEditingController _thicknessClassController;

  bool _isCheckingArticleNumber = false;
  String? _articleNumberError;
  String? _selectedInstrumentCode;
  String? _selectedPartCode;


  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null && p.articleNumber.length == 4) {
      _selectedInstrumentCode = p.articleNumber.substring(0, 2);
      _selectedPartCode = p.articleNumber.substring(2, 4);

      // Prüfe sofort die Verfügbarkeit der Artikelnummer beim Bearbeiten
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkArticleNumber(p.articleNumber);
      });
    }
    _articleNumberController = TextEditingController(text: p?.articleNumber ?? '');
    _productNameController = TextEditingController(text: p?.productName ?? '');
    _instrumentController = TextEditingController(text: p?.instrument ?? '');
    _partsController = TextEditingController(text: p?.parts.toString() ?? '1');
    _lengthStandardController = TextEditingController(text: p?.dimensions.length.standard.toString() ?? '');
    _lengthAdditionController = TextEditingController(text: p?.dimensions.length.addition.toString() ?? '0');
    _widthStandardController = TextEditingController(text: p?.dimensions.width.standard.toString() ?? '');
    _widthAdditionController = TextEditingController(text: p?.dimensions.width.addition.toString() ?? '0');
    _thicknessValueController = TextEditingController(text: p?.dimensions.thickness.value.toString() ?? '');
    _thicknessValue2Controller = TextEditingController(text: p?.dimensions.thickness.value2?.toString() ?? '');
    _thicknessClassController = TextEditingController(text: p?.thicknessClass.toString() ?? '1');

    // Listener für Live-Volumenberechnung
    _lengthStandardController.addListener(() => setState(() {}));
    _lengthAdditionController.addListener(() => setState(() {}));
    _widthStandardController.addListener(() => setState(() {}));
    _widthAdditionController.addListener(() => setState(() {}));
    _thicknessValueController.addListener(() => setState(() {}));
    _thicknessValue2Controller.addListener(() => setState(() {}));
    _partsController.addListener(() => setState(() {}));

  }

  @override
  void dispose() {
    _articleNumberController.dispose();
    _productNameController.dispose();
    _instrumentController.dispose();
    _partsController.dispose();
    _lengthStandardController.dispose();
    _lengthAdditionController.dispose();
    _widthStandardController.dispose();
    _widthAdditionController.dispose();
    _thicknessValueController.dispose();
    _thicknessValue2Controller.dispose();
    _thicknessClassController.dispose();
    super.dispose();
  }


// Methode zur Generierung der Artikelnummer
  void _generateArticleNumber() {
    if (_selectedInstrumentCode != null && _selectedPartCode != null) {
      final newArticleNumber = _selectedInstrumentCode! + _selectedPartCode!;
      _articleNumberController.text = newArticleNumber;
      // Prüfe sofort die Verfügbarkeit
      _checkArticleNumber(newArticleNumber);
    }
  }





// Für Live-Validierung während der Eingabe:
  void _checkArticleNumber(String value) async {
    if (value.length != 4) {
      setState(() {
        _articleNumberError = null;
      });
      return;
    }

    setState(() {
      _isCheckingArticleNumber = true;
      _articleNumberError = null;
    });

    final isAvailable = await _isArticleNumberAvailable(value);

    if (mounted) {
      setState(() {
        _isCheckingArticleNumber = false;
        _articleNumberError = isAvailable ? null : 'Diese Nummer ist bereits vergeben';
      });
    }
  }

  Future<bool> _isArticleNumberAvailable(String articleNumber) async {
    // Bei Bearbeitung: Wenn die Nummer gleich bleibt, ist sie verfügbar
    if (widget.product != null && widget.product!.articleNumber == articleNumber) {
      return true;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('standardized_products')
          .where('articleNumber', isEqualTo: articleNumber)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('Fehler bei der Artikelnummer-Prüfung: $e');
      return false;
    }
  }
  @override
  @override

// Angepasste build Methode für StandardizedProductDialog:
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header mit Titel und Close-Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'inventory',
                defaultIcon: Icons.inventory,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                widget.product == null ? 'Neues Standardprodukt' : 'Standardprodukt bearbeiten',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: getAdaptiveIcon(
                  iconName: 'close',
                  defaultIcon: Icons.close,
                ),
              ),
            ],
          ),
        ),

        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

        // Form Content - Scrollbar
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grunddaten Section
                  _buildSectionHeader(
                    context,
                    'Grunddaten',
                    Icons.info,
                    'info'
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Instrument Dropdown
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('instruments')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }

                            final instruments = snapshot.data!.docs;

                            return DropdownButtonFormField<String>(
                              value: _selectedInstrumentCode,
                              decoration: InputDecoration(
                                labelText: 'Instrument *',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                prefixIcon: getAdaptiveIcon(
                                  iconName: 'music_note',
                                  defaultIcon: Icons.music_note,
                                ),
                              ),
                              hint: const Text('Instrument wählen'),
                              items: instruments.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: data['code'],
                                  child: Text('${data['name']} (${data['code']})'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedInstrumentCode = value;
                                  final selectedInstrument = instruments.firstWhere(
                                          (doc) => (doc.data() as Map<String, dynamic>)['code'] == value
                                  );
                                  final instrumentData = selectedInstrument.data() as Map<String, dynamic>;
                                  _instrumentController.text = instrumentData['name'] ?? '';
                                  _generateArticleNumber();
                                });
                              },
                              validator: (value) => value == null
                                  ? 'Bitte Instrument auswählen'
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Bauteil Dropdown
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('parts')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }

                            final parts = snapshot.data!.docs;

                            return DropdownButtonFormField<String>(
                              value: _selectedPartCode,
                              decoration: InputDecoration(
                                labelText: 'Bauteil *',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                prefixIcon: getAdaptiveIcon(
                                  iconName: 'build',
                                  defaultIcon: Icons.build,
                                ),
                              ),
                              hint: const Text('Bauteil wählen'),
                              items: parts.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: data['code'],
                                  child: Text('${data['name']} (${data['code']})'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPartCode = value;
                                  _generateArticleNumber();
                                });
                              },
                              validator: (value) => value == null
                                  ? 'Bitte Bauteil auswählen'
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Generierte Artikelnummer (nur Anzeige)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              getAdaptiveIcon(iconName: 'tag', defaultIcon:
                                Icons.tag,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Artikelnummer',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    _articleNumberController.text.isEmpty
                                        ? 'Wird automatisch generiert'
                                        : _articleNumberController.text,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _articleNumberController.text.isEmpty
                                          ? Colors.grey
                                          : Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  if (_articleNumberError != null)
                                    Text(
                                      _articleNumberError!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              if (_isCheckingArticleNumber)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else if (_articleNumberError == null && _articleNumberController.text.length == 4)
                                 getAdaptiveIcon(iconName: 'check_circle',defaultIcon:Icons.check_circle, color: Colors.green),
                            ],
                          ),
                        ),


                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Eigenschaften Section
                  _buildSectionHeader(
                    context,
                    'Eigenschaften',
                    Icons.category,
                    'category'
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _partsController,
                            decoration: InputDecoration(
                              labelText: 'Teile *',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'layers',
                                defaultIcon: Icons.layers,
                              ),
                            ),
                            validator: (value) => value?.isEmpty == true
                                ? 'Bitte Anzahl eingeben'
                                : null,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _thicknessClassController,
                            decoration: InputDecoration(
                              labelText: 'Dickeklasse',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'height',
                                defaultIcon: Icons.height,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Abmessungen Section
                  _buildSectionHeader(
                    context,
                    'Abmessungen (in mm)',
                    Icons.straighten,
                    'straighten'
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Länge
                        _buildDimensionRow(
                          context,
                          'Länge',
                          _lengthStandardController,
                          _lengthAdditionController,
                          Icons.arrow_right,
                          'arrow_right'
                        ),
                        const SizedBox(height: 16),

                        // Breite
                        _buildDimensionRow(
                          context,
                          'Breite',
                          _widthStandardController,
                          _widthAdditionController,
                          Icons.swap_horiz,
                          'swap_horiz'
                        ),
                        const SizedBox(height: 16),

                        // Dicke
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  getAdaptiveIcon(iconName: 'layers', defaultIcon:
                                    Icons.layers,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Dicke',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _thicknessValueController,
                                      decoration: InputDecoration(
                                        labelText: 'Dicke *',
                                        border: const OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Theme.of(context).colorScheme.surface,
                                        suffixText: 'mm',
                                      ),
                                      validator: (value) => value?.isEmpty == true
                                          ? 'Bitte Dicke eingeben'
                                          : null,
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _thicknessValue2Controller,
                                      decoration: InputDecoration(
                                        labelText: 'Dicke 2 (Trapez)',
                                        border: const OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Theme.of(context).colorScheme.surface,
                                        suffixText: 'mm',

                                      ),
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
// Volumen Section (nur Anzeige)
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                      context,
                      'Volumen (berechnet)',
                      Icons.view_in_ar,
                      'view_in_ar'
                  ),
                  const SizedBox(height: 16),

                  _buildVolumeDisplay(context),

                  const SizedBox(height: 24),

                ],
              ),
            ),
          ),
        ),

        // Action Buttons - Fixed at bottom
        Container(
          padding: const EdgeInsets.all(16.0),
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
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: getAdaptiveIcon(
                      iconName: 'cancel',
                      defaultIcon: Icons.cancel,
                    ),
                    label: const Text('Abbrechen'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: getAdaptiveIcon(
                      iconName: 'save',
                      defaultIcon: Icons.save,
                    ),
                    label: const Text('Speichern'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildVolumeDisplay(BuildContext context) {
    // Werte auslesen
    final lengthStandard = double.tryParse(_lengthStandardController.text) ?? 0;
    final lengthAddition = double.tryParse(_lengthAdditionController.text) ?? 0;
    final widthStandard = double.tryParse(_widthStandardController.text) ?? 0;
    final widthAddition = double.tryParse(_widthAdditionController.text) ?? 0;
    final thicknessValue = double.tryParse(_thicknessValueController.text) ?? 0;
    final thicknessValue2 = double.tryParse(_thicknessValue2Controller.text);
    final parts = int.tryParse(_partsController.text) ?? 1;

    // Mit Zumaß berechnen
    final lengthWithAddition = lengthStandard + lengthAddition;
    final widthWithAddition = widthStandard + widthAddition;

    // Effektive Dicke (bei Trapez: Durchschnitt)
    final effectiveThickness = thicknessValue2 != null
        ? (thicknessValue + thicknessValue2) / 2
        : thicknessValue;

    // Volumen berechnen (in mm³)
    final volumeMm3Standard = lengthStandard * widthStandard * effectiveThickness * parts;
    final volumeMm3WithAddition = lengthWithAddition * widthWithAddition * effectiveThickness * parts;

    // Umrechnungen
    final volumeDm3Standard = volumeMm3Standard / 1000000; // mm³ zu dm³
    final volumeDm3WithAddition = volumeMm3WithAddition / 1000000;
    final volumeM3Standard = volumeMm3Standard / 1000000000; // mm³ zu m³
    final volumeM3WithAddition = volumeMm3WithAddition / 1000000000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info-Hinweis
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'info',
                defaultIcon: Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Volumen wird automatisch aus den Abmessungen berechnet',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabellen-Header
          Row(
            children: [
              const SizedBox(width: 80),
              Expanded(
                child: Center(
                  child: Text(
                    'Standard',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Mit Zumaß',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // mm³
          _buildVolumeRow(
            context,
            'mm³',
            volumeMm3Standard,
            volumeMm3WithAddition,
            0, // Dezimalstellen
          ),
          const SizedBox(height: 8),

          // dm³
          _buildVolumeRow(
            context,
            'dm³',
            volumeDm3Standard,
            volumeDm3WithAddition,
            4,
          ),
          const SizedBox(height: 8),

          // m³
          _buildVolumeRow(
            context,
            'm³',
            volumeM3Standard,
            volumeM3WithAddition,
            6,
          ),

          // Formel-Anzeige
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formel:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Länge × Breite × Dicke${thicknessValue2 != null ? ' (Ø)' : ''} × Teile',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (lengthStandard > 0 && widthStandard > 0 && effectiveThickness > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Standard: ${lengthStandard.toStringAsFixed(0)} × ${widthStandard.toStringAsFixed(0)} × ${effectiveThickness.toStringAsFixed(1)} × $parts = ${volumeMm3Standard.toStringAsFixed(0)} mm³',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeRow(
      BuildContext context,
      String unit,
      double valueStandard,
      double valueWithAddition,
      int decimals,
      ) {
    String formatValue(double value, int dec) {
      if (value == 0) return '-';
      if (dec == 0) {
        return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]}.',
        );
      }
      return value.toStringAsFixed(dec);
    }

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            unit,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                formatValue(valueStandard, decimals),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                formatValue(valueWithAddition, decimals),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
// Hilfsmethoden für das Layout:

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, String iconName) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child:
          getAdaptiveIcon(iconName: iconName, defaultIcon:
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionRow(
      BuildContext context,
      String label,
      TextEditingController standardController,
      TextEditingController additionController,
      IconData icon,
      String iconName
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: iconName, defaultIcon:
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: standardController,
                  decoration: InputDecoration(
                    labelText: '$label Standard *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    suffixText: 'mm',
                  ),
                  validator: (value) => value?.isEmpty == true
                      ? 'Bitte $label eingeben'
                      : null,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child:  getAdaptiveIcon(iconName: 'add', defaultIcon:
                    Icons.add,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: additionController,
                  decoration: InputDecoration(
                    labelText: 'Zumaß',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    suffixText: 'mm',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() async {
    if (_formKey.currentState?.validate() == true) {
      // Zeige Ladeindikator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Prüfe Artikelnummer-Verfügbarkeit
      final articleNumber = _articleNumberController.text;
      final isAvailable = await _isArticleNumberAvailable(articleNumber);

      // Entferne Ladeindikator
      if (mounted) Navigator.pop(context);

      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Die Artikelnummer $articleNumber ist bereits vergeben'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final lengthStandard = double.tryParse(_lengthStandardController.text) ?? 0;
      final lengthAddition = double.tryParse(_lengthAdditionController.text) ?? 0;
      final widthStandard = double.tryParse(_widthStandardController.text) ?? 0;
      final widthAddition = double.tryParse(_widthAdditionController.text) ?? 0;
      final thicknessValue = double.tryParse(_thicknessValueController.text) ?? 0;
      final thicknessValue2 = _thicknessValue2Controller.text.isNotEmpty
          ? double.tryParse(_thicknessValue2Controller.text)
          : null;

      final parts = int.tryParse(_partsController.text) ?? 1;

      // Berechnungen
      final lengthWithAddition = lengthStandard + lengthAddition;
      final widthWithAddition = widthStandard + widthAddition;

      // Volumenberechnung (vereinfacht)
      final volumeStandard = lengthStandard * widthStandard * thicknessValue * parts;
      final volumeWithAddition = lengthWithAddition * widthWithAddition * thicknessValue * parts;

      // Maßtext generieren
      final measurementStandard = '$parts# ${lengthStandard.toStringAsFixed(0)}×${widthStandard.toStringAsFixed(0)}×${thicknessValue}';
      final measurementWithAddition = '$parts# ${lengthWithAddition.toStringAsFixed(0)}×${widthWithAddition.toStringAsFixed(0)}×${thicknessValue}';
      // Hole den Bauteil-Namen für productName
      String bauteilName = _productNameController.text; // Fallback
      if (_selectedPartCode != null) {
        final partSnapshot = await FirebaseFirestore.instance
            .collection('parts')
            .where('code', isEqualTo: _selectedPartCode)
            .limit(1)
            .get();

        if (partSnapshot.docs.isNotEmpty) {
          bauteilName = partSnapshot.docs.first.data()['name'] ?? _productNameController.text;
        }
      }
      final product = StandardizedProduct(
        id: widget.product?.id ?? '',
        articleNumber: articleNumber,
        productName:  bauteilName,
        instrument: _instrumentController.text,
        parts: parts,
        dimensions: ProductDimensions(
          length: DimensionData(
            standard: lengthStandard,
            addition: lengthAddition,
            withAddition: lengthWithAddition,
          ),
          width: DimensionData(
            standard: widthStandard,
            addition: widthAddition,
            withAddition: widthWithAddition,
          ),
          thickness: ThicknessData(
            value: thicknessValue,
            value2: thicknessValue2,
          ),
        ),
        thicknessClass: int.tryParse(_thicknessClassController.text) ?? 1,
        measurementText: MeasurementText(
          standard: measurementStandard,
          withAddition: measurementWithAddition,
        ),
        volume: VolumeData(
          mm3Standard: volumeStandard,
          mm3WithAddition: volumeWithAddition,
          dm3Standard: volumeStandard / 1000000,
          dm3WithAddition: volumeWithAddition / 1000000,
        ),
      );

      widget.onSave(product);
    }
  } }