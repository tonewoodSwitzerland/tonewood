import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({required Key key}) : super(key: key);

  @override
  WarehouseScreenState createState() => WarehouseScreenState();
}

class WarehouseScreenState extends State<WarehouseScreen> {
  // Filter states
  List<String> selectedInstruments = [];
  List<String> selectedWoodTypes = [];
  bool haselfichteFilter = false;  // Initialize with false instead of null
  bool moonwoodFilter = false;
  bool thermallyTreatedFilter = false;
  bool fscFilter = false;

  // Dropdown options based on your database
  final List<String> instruments = [
    'Klassische Gitarre',
    'Western-Gitarre',
    'E-Gitarre',
    'Mandoline',
    'Geige',
    'Bratsche'
  ];

  final List<String> woodTypes = [
    'Fichte',
    'Ahorn',
    'Birne'
  ];

  // Query builder based on filters
  Query<Map<String, dynamic>> buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('products');

    if (selectedInstruments.isNotEmpty) {
      query = query.where('instrument', whereIn: selectedInstruments);
    }
    if (selectedWoodTypes.isNotEmpty) {
      query = query.where('wood_type', whereIn: selectedWoodTypes);

    }
    if (haselfichteFilter) {  // Only apply if true
      query = query.where('haselfichte', isEqualTo: true);
    }
    if (moonwoodFilter) {
      query = query.where('moonwood', isEqualTo: true);
    }
    if (thermallyTreatedFilter) {
      query = query.where('thermally_treated', isEqualTo: true);
    }
    if (fscFilter) {
      query = query.where('FSC_100', isEqualTo: true);
    }

    return query;
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;

    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Lagerbestand'),
              centerTitle: true,
              // Nur für Mobile den Filter-Button zeigen
              actions: !isDesktopLayout ? [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterDialog(),
                ),
              ] : null,
            ),
            body: isDesktopLayout
                ? _buildDesktopLayout()
                : _buildMobileLayout(),
          );
        }
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Permanenter Filterbereich links
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
                child: const Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _buildFilterSection(),
              ),
            ],
          ),
        ),
        // Produktliste rechts
        Expanded(
          child: _buildProductList(),
        ),
      ],
    );
  }
  Widget _buildActiveFiltersChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          ...selectedInstruments.map((instrument) =>
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Chip(
                  label: Text(instrument),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      selectedInstruments.remove(instrument);
                    });
                  },
                ),
              ),
          ),
          ...selectedWoodTypes.map((woodType) =>
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Chip(
                  label: Text(woodType),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      selectedWoodTypes.remove(woodType);
                    });
                  },
                ),
              ),
          ),
          // ... rest der Chips ...
        ],
      ),
    );
  }
  Widget _buildMobileLayout() {
    return Column(
      children: [
        if (_hasActiveFilters())
          _buildActiveFiltersChips(),
        Expanded(
          child: _buildProductList(),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wichtig für korrektes Scrolling
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMultiSelectDropdown(
              label: 'Instrument',
              options: instruments,
              selectedValues: selectedInstruments,
              onChanged: (newSelection) {
                setState(() {
                  selectedInstruments = newSelection;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildMultiSelectDropdown(
              label: 'Holzart',
              options: woodTypes,
              selectedValues: selectedWoodTypes,
              onChanged: (newSelection) {
                setState(() {
                  selectedWoodTypes = newSelection;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Zusätzliche Filter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Haselfichte'),
              value: haselfichteFilter,
              onChanged: (bool? value) {
                setState(() {
                  haselfichteFilter = value ?? false;
                });
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('Mondholz'),
              value: moonwoodFilter,
              onChanged: (bool? value) {
                setState(() {
                  moonwoodFilter = value ?? false;
                });
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('Thermobehandelt'),
              value: thermallyTreatedFilter,
              onChanged: (bool? value) {
                setState(() {
                  thermallyTreatedFilter = value ?? false;
                });
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('FSC 100%'),
              value: fscFilter,
              onChanged: (bool? value) {
                setState(() {
                  fscFilter = value ?? false;
                });
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedInstruments.clear();
                    selectedWoodTypes.clear();
                    haselfichteFilter = false;
                    moonwoodFilter = false;
                    thermallyTreatedFilter = false;
                    fscFilter = false;
                  });
                },
                child: const Text('Filter zurücksetzen'),
              ),
            ),
            // Zusätzlicher Platz am Ende für besseres Scrolling
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCheckbox(String label, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Ein Fehler ist aufgetreten'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data?.docs.isEmpty ?? true) {
          return const Center(child: Text('Keine Produkte gefunden'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  data['product'] ?? 'Unbenanntes Produkt',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Instrument: ${data['instrument'] ?? 'N/A'}'),
                    Text('Holzart: ${data['wood_type'] ?? 'N/A'}'),
                    Text('Größe: ${data['size'] ?? 'N/A'}'),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bestand'),
                    Text(
                      '${data['quantity'] ?? 0}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                onTap: () => _showProductDetails(data),
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildMultiSelectDropdown({
    required String label,
    required List<String> options,
    required List<String> selectedValues,
    required Function(List<String>) onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                selectedValues.isEmpty ? 'Keine Auswahl' : selectedValues.join(', '),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: options.map((option) =>
                    CheckboxListTile(
                      title: Text(option),
                      value: selectedValues.contains(option),
                      onChanged: (bool? checked) {
                        List<String> newSelection = List.from(selectedValues);
                        if (checked ?? false) {
                          if (!newSelection.contains(option)) {
                            newSelection.add(option);
                          }
                        } else {
                          newSelection.remove(option);
                        }
                        onChanged(newSelection);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  bool _hasActiveFilters() {
    return selectedInstruments != null ||
        selectedWoodTypes != null ||
        haselfichteFilter ||
        moonwoodFilter ||
        thermallyTreatedFilter ||
        fscFilter;
  }
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8, // Größerer Dialog
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildMultiSelectDropdown(
                              label: 'Instrument',
                              options: instruments,
                              selectedValues: selectedInstruments,
                              onChanged: (newSelection) {
                                setState(() {
                                  selectedInstruments = newSelection;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildMultiSelectDropdown(
                              label: 'Holzart',
                              options: woodTypes,
                              selectedValues: selectedWoodTypes,
                              onChanged: (newSelection) {
                                setState(() {
                                  selectedWoodTypes = newSelection;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Card(
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    title: const Text('Haselfichte'),
                                    value: haselfichteFilter,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        haselfichteFilter = value ?? false;
                                      });
                                    },
                                  ),
                                  CheckboxListTile(
                                    title: const Text('Mondholz'),
                                    value: moonwoodFilter,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        moonwoodFilter = value ?? false;
                                      });
                                    },
                                  ),
                                  CheckboxListTile(
                                    title: const Text('Thermobehandelt'),
                                    value: thermallyTreatedFilter,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        thermallyTreatedFilter = value ?? false;
                                      });
                                    },
                                  ),
                                  CheckboxListTile(
                                    title: const Text('FSC 100%'),
                                    value: fscFilter,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        fscFilter = value ?? false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Buttons
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Zurücksetzen'),
                            onPressed: () {
                              setState(() {
                                selectedInstruments.clear();
                                selectedWoodTypes.clear();
                                haselfichteFilter = false;
                                moonwoodFilter = false;
                                thermallyTreatedFilter = false;
                                fscFilter = false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            child: const Text('Anwenden'),
                            onPressed: () {
                              this.setState(() {}); // Trigger rebuild with new filters
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProductDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['product'] ?? 'Produktdetails'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Instrument', data['instrument']),
                _detailRow('Bauteil', data['part']),
                _detailRow('Holzart', data['wood_type']),
                _detailRow('Größe', data['size']),
                _detailRow('Qualität', data['quality']),
                _detailRow('Bestand', data['quantity']?.toString()),
                _detailRow('Preis CHF', data['price_CHF']?.toString()),
                _booleanRow('Thermobehandelt', data['thermally_treated']),
                _booleanRow('Haselfichte', data['haselfichte']),
                _booleanRow('Mondholz', data['moonwood']),
                _booleanRow('FSC 100%', data['FSC_100']),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Schließen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  Widget _booleanRow(String label, bool? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value == true ? 'Ja' : 'Nein'),
          ),
        ],
      ),
    );
  }
}