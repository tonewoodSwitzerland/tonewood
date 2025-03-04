// In lib/screens/production_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import 'add_product_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ProductionFilter {
  final List<String>? instruments;
  final List<String>? woodTypes;
  final List<String>? parts;
  final List<String>? qualities;

  ProductionFilter({
    this.instruments,
    this.woodTypes,
    this.parts,
    this.qualities,
  });

  ProductionFilter copyWith({
    List<String>? instruments,
    List<String>? woodTypes,
    List<String>? parts,
    List<String>? qualities,
  }) {
    return ProductionFilter(
      instruments: instruments ?? this.instruments,
      woodTypes: woodTypes ?? this.woodTypes,
      parts: parts ?? this.parts,
      qualities: qualities ?? this.qualities,
    );
  }

  bool hasActiveFilters() {
    return (instruments?.isNotEmpty ?? false) ||
        (woodTypes?.isNotEmpty ?? false) ||
        (parts?.isNotEmpty ?? false) ||
        (qualities?.isNotEmpty ?? false);
  }
}

class ProductionScreen extends StatefulWidget {
  final bool isDialog;
  final Function(String)? onProductSelected;

  const ProductionScreen({
    Key? key,
    this.isDialog = false,
    this.onProductSelected,
  }) : super(key: key);

  @override
  ProductionScreenState createState() => ProductionScreenState();
}

class ProductionScreenState extends State<ProductionScreen> {
  final TextEditingController searchController = TextEditingController();
  String searchTerm = '';
  String sortBy = 'last_modified'; // Neuer Sortier-State mit Standardwert

  bool sortByCreatedAt = false; // false bedeutet Sortierung nach last_modified
  final DateFormat dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  // Filter-Zustand
  ProductionFilter filter = ProductionFilter();
  bool showFilters = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.isDialog
            ? TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Suchen...',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => searchTerm = value.toLowerCase()),
        )
            : const Text('Produktion'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
          if (widget.isDialog)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Aktive Filter anzeigen, wenn vorhanden
          if (filter.hasActiveFilters())
            _buildActiveFiltersBar(),

          // Sortier-Toggle
          // Sortier-Toggle mit drei Optionen
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSortButton(
                    icon: Icons.update,
                    label: 'Änderung',
                    isSelected: sortBy == 'last_modified',
                    onTap: () => setState(() => sortBy = 'last_modified'),
                  ),
                  _buildSortButton(
                    icon: Icons.event_note,
                    label: 'Erstellt',
                    isSelected: sortBy == 'created_at',
                    onTap: () => setState(() => sortBy = 'created_at'),
                  ),
                  _buildSortButton(
                    icon: Icons.sort,
                    label: 'A-Z',
                    isSelected: sortBy == 'product_name',
                    onTap: () => setState(() => sortBy = 'product_name'),
                  ),
                ],
              ),
            ),
          ),

          // Liste der Produkte
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Neue Logik:
              stream: FirebaseFirestore.instance
                  .collection('production')
                  .orderBy(sortBy, descending: sortBy != 'product_name') // Für Namen aufsteigend, sonst absteigend
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!.docs.where((doc) {
                  // Textsuche
                  if (searchTerm.isNotEmpty) {
                    final data = doc.data() as Map<String, dynamic>;
                    final searchText = '${data['product_name']} ${doc.id}'.toLowerCase();
                    if (!searchText.contains(searchTerm)) {
                      return false;
                    }
                  }

                  // Filter anwenden
                  return _matchesFilters(doc.id);
                }).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Keine Produkte gefunden'),
                        const SizedBox(height: 24),
                        if (!widget.isDialog)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AddProductScreen(
                                    editMode: false,
                                    isProduction: true,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Neues Produkt anlegen'),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(
                          data['product_name']+' - '+ data['quality_name'] ?? 'Unbekanntes Produkt',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Artikelnummer: ${doc.id}', style: TextStyle(fontSize: 12)),
                            if (data['created_at'] != null)
                              Text('Erstellt: ${dateTimeFormat.format((data['created_at'] as Timestamp).toDate())}', style: TextStyle(fontSize: 12)),
                            if (data['last_modified'] != null)
                              Text('Letzte Änderung: ${dateTimeFormat.format((data['last_modified'] as Timestamp).toDate())}', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: widget.onProductSelected != null
                            ? () => widget.onProductSelected!(doc.id)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Prüfen, ob ein Barcode zu den ausgewählten Filtern passt
  bool _matchesFilters(String barcode) {
    // Wenn keine Filter aktiv sind, alle Produkte anzeigen
    if (!filter.hasActiveFilters()) {
      return true;
    }

    // Barcode in Teile zerlegen (z.B. "0102.0304.0000.0000")
    final parts = barcode.split('.');
    if (parts.length < 2) return false;

    // Extrahiere die ersten beiden Teile und teile sie in 2-Zeichen-Codes
    String relevantPart = parts[0] + parts[1];
    List<String> codes = [];
    for (int i = 0; i < relevantPart.length; i += 2) {
      if (i + 2 <= relevantPart.length) {
        codes.add(relevantPart.substring(i, i + 2));
      }
    }

    // Prüfe Filter für jede Kategorie
    if (filter.instruments != null && filter.instruments!.isNotEmpty && codes.length > 0) {
      if (!filter.instruments!.contains(codes[0])) {
        return false;
      }
    }

    if (filter.parts != null && filter.parts!.isNotEmpty && codes.length > 1) {
      if (!filter.parts!.contains(codes[1])) {
        return false;
      }
    }

    if (filter.woodTypes != null && filter.woodTypes!.isNotEmpty && codes.length > 2) {
      if (!filter.woodTypes!.contains(codes[2])) {
        return false;
      }
    }

    if (filter.qualities != null && filter.qualities!.isNotEmpty && codes.length > 3) {
      if (!filter.qualities!.contains(codes[3])) {
        return false;
      }
    }

    return true;
  }

  // Filter-Dialog anzeigen
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductionFilterDialog(
          initialFilter: filter,
          onFilterChanged: (newFilter) {
            setState(() {
              filter = newFilter;
            });
          },
        );
      },
    );
  }

  // Aktive Filter-Anzeige
  Widget _buildActiveFiltersBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: Color(0xFF0F4A29), size: 16),
              SizedBox(width: 8),
              Text(
                'Aktive Filter',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F4A29),
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    filter = ProductionFilter();
                  });
                },
                child: Text('Zurücksetzen'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Instrument-Chips
                if (filter.instruments != null)
                  ...filter.instruments!.map((code) => _buildFilterChip(
                      'instruments', code, 'Instrument'
                  )).toList(),

                // Holzarten-Chips
                if (filter.woodTypes != null)
                  ...filter.woodTypes!.map((code) => _buildFilterChip(
                      'wood_types', code, 'Holzart'
                  )).toList(),

                // Bauteile-Chips
                if (filter.parts != null)
                  ...filter.parts!.map((code) => _buildFilterChip(
                      'parts', code, 'Bauteil'
                  )).toList(),

                // Qualitäten-Chips
                if (filter.qualities != null)
                  ...filter.qualities!.map((code) => _buildFilterChip(
                      'qualities', code, 'Qualität'
                  )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
// Hilfsmethode für die Sortierbuttons
  Widget _buildSortButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Color(0xFF0F4A29).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Color(0xFF0F4A29)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Color(0xFF0F4A29) : Colors.grey[600],
                size: 18,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Color(0xFF0F4A29) : Colors.grey[800],
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Filter-Chip für eine Kategorie
  Widget _buildFilterChip(String collection, String code, String label) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection(collection).doc(code).get(),
      builder: (context, snapshot) {
        String name = code;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            name = data['name'] ?? code;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text('$label: $name'),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                if (collection == 'instruments') {
                  filter = filter.copyWith(
                      instruments: filter.instruments!.where((c) => c != code).toList()
                  );
                } else if (collection == 'wood_types') {
                  filter = filter.copyWith(
                      woodTypes: filter.woodTypes!.where((c) => c != code).toList()
                  );
                } else if (collection == 'parts') {
                  filter = filter.copyWith(
                      parts: filter.parts!.where((c) => c != code).toList()
                  );
                } else if (collection == 'qualities') {
                  filter = filter.copyWith(
                      qualities: filter.qualities!.where((c) => c != code).toList()
                  );
                }
              });
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// Filter-Dialog für Produktionsfilter
class ProductionFilterDialog extends StatefulWidget {
  final ProductionFilter initialFilter;
  final Function(ProductionFilter) onFilterChanged;

  const ProductionFilterDialog({
    Key? key,
    required this.initialFilter,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  ProductionFilterDialogState createState() => ProductionFilterDialogState();
}

class ProductionFilterDialogState extends State<ProductionFilterDialog> {
  late ProductionFilter tempFilter;

  @override
  void initState() {
    super.initState();
    tempFilter = ProductionFilter(
      instruments: widget.initialFilter.instruments != null
          ? List.from(widget.initialFilter.instruments!)
          : null,
      woodTypes: widget.initialFilter.woodTypes != null
          ? List.from(widget.initialFilter.woodTypes!)
          : null,
      parts: widget.initialFilter.parts != null
          ? List.from(widget.initialFilter.parts!)
          : null,
      qualities: widget.initialFilter.qualities != null
          ? List.from(widget.initialFilter.qualities!)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            _buildHeader(),
            if (_hasActiveFilters()) _buildActiveFiltersBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Theme(
                        data: ThemeData(dividerColor: Colors.transparent),
                        child: Column(
                          children: [
                            _buildFilterCategory(
                              Icons.piano,
                              'Instrument',
                              _buildInstrumentFilter(),
                              tempFilter.instruments?.isNotEmpty ?? false,
                            ),
                            _buildFilterCategory(
                              Icons.construction,
                              'Bauteil',
                              _buildPartsFilter(),
                              tempFilter.parts?.isNotEmpty ?? false,
                            ),
                            _buildFilterCategory(
                              Icons.forest,
                              'Holzart',
                              _buildWoodTypeFilter(),
                              tempFilter.woodTypes?.isNotEmpty ?? false,
                            ),
                            _buildFilterCategory(
                              Icons.grade,
                              'Qualität',
                              _buildQualityFilter(),
                              tempFilter.qualities?.isNotEmpty ?? false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4A29).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.filter_list, color: Color(0xFF0F4A29)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F4A29),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_hasActiveFilters())
            TextButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Zurücksetzen'),
              onPressed: _resetFilters,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (tempFilter.instruments?.isNotEmpty ?? false)
            ...tempFilter.instruments!.map(_buildInstrumentChip),
          if (tempFilter.woodTypes?.isNotEmpty ?? false)
            ...tempFilter.woodTypes!.map(_buildWoodTypeChip),
          if (tempFilter.parts?.isNotEmpty ?? false)
            ...tempFilter.parts!.map(_buildPartChip),
          if (tempFilter.qualities?.isNotEmpty ?? false)
            ...tempFilter.qualities!.map(_buildQualityChip),
        ],
      ),
    );
  }

  Widget _buildFilterCategory(
      IconData icon,
      String title,
      Widget child,
      bool hasActiveFilters,
      ) {
    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasActiveFilters
              ? const Color(0xFF0F4A29).withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: hasActiveFilters ? const Color(0xFF0F4A29) : Colors.grey,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: hasActiveFilters ? FontWeight.bold : FontWeight.normal,
          color: hasActiveFilters ? const Color(0xFF0F4A29) : Colors.black,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: child,
        ),
      ],
    );
  }

  Widget _buildInstrumentFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('instruments')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          options: snapshot.data!.docs,
          selectedValues: tempFilter.instruments ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(instruments: newSelection);
            });
          },
        );
      },
    );
  }

  Widget _buildWoodTypeFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wood_types')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          options: snapshot.data!.docs,
          selectedValues: tempFilter.woodTypes ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(woodTypes: newSelection);
            });
          },
        );
      },
    );
  }

  Widget _buildPartsFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parts')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          options: snapshot.data!.docs,
          selectedValues: tempFilter.parts ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(parts: newSelection);
            });
          },
        );
      },
    );
  }

  Widget _buildQualityFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('qualities')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          options: snapshot.data!.docs,
          selectedValues: tempFilter.qualities ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(qualities: newSelection);
            });
          },
        );
      },
    );
  }

  Widget _buildMultiSelectDropdown({
    required List<DocumentSnapshot> options,
    required List<String> selectedValues,
    required Function(List<String>) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(maxHeight: 250),
        child: ListView(
          shrinkWrap: true,
          children: options.map((option) {
            final data = option.data() as Map<String, dynamic>;
            final isSelected = selectedValues.contains(option.id);

            final displayName = data['name'] ?? 'Unbekannt';

            return CheckboxListTile(
              title: Text(displayName),
              value: isSelected,
              onChanged: (bool? checked) {
                if (checked == true) {
                  onChanged([...selectedValues, option.id]);
                } else {
                  onChanged(
                    selectedValues.where((id) => id != option.id).toList(),
                  );
                }
              },
              activeColor: const Color(0xFF0F4A29),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInstrumentChip(String code) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('instruments')
          .doc(code)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
            : code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  instruments: tempFilter.instruments?.where((t) => t != code).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildWoodTypeChip(String code) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wood_types')
          .doc(code)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
            : code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  woodTypes: tempFilter.woodTypes?.where((t) => t != code).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildPartChip(String code) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parts')
          .doc(code)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
            : code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  parts: tempFilter.parts?.where((t) => t != code).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildQualityChip(String code) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('qualities')
          .doc(code)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
            : code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  qualities: tempFilter.qualities?.where((t) => t != code).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Abbrechen'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {
              widget.onFilterChanged(tempFilter);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F4A29),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Anwenden'),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return (tempFilter.instruments?.isNotEmpty ?? false) ||
        (tempFilter.woodTypes?.isNotEmpty ?? false) ||
        (tempFilter.parts?.isNotEmpty ?? false) ||
        (tempFilter.qualities?.isNotEmpty ?? false);
  }

  void _resetFilters() {
    setState(() {
      tempFilter = ProductionFilter();
    });
  }
}