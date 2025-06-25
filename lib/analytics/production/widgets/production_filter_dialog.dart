import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../components/filterCategory.dart';
import '../../../services/icon_helper.dart';
import '../models/production_filter.dart';
import '../constants/production_constants.dart';

class ProductionFilterDialog extends StatefulWidget {
  final ProductionFilter initialFilter;

  const ProductionFilterDialog({
    Key? key,
    required this.initialFilter,
  }) : super(key: key);

  @override
  ProductionFilterDialogState createState() => ProductionFilterDialogState();
}

class ProductionFilterDialogState extends State<ProductionFilterDialog> {
  late ProductionFilter tempFilter;

  @override
  void initState() {
    super.initState();
    tempFilter = widget.initialFilter;
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
                            buildFilterCategory(
                            icon:   Icons.forest,
                            iconName: 'forest',
                            title:   'Holzart',
                            child:   _buildWoodTypeFilter(),
                            hasActiveFilters:   tempFilter.woodTypes?.isNotEmpty ?? false,
                            ),
                            buildFilterCategory(
                              icon:   Icons.music_note,
                              iconName: 'music_note',
                              title:  'Instrument',
                              child:  _buildInstrumentsFilter(),
                              hasActiveFilters:  tempFilter.instruments?.isNotEmpty ?? false,
                            ),
                            buildFilterCategory(
                              icon:    Icons.category,
                              iconName: 'category',
                              title:    'Bauteil',
                              child:   _buildPartsFilter(),
                              hasActiveFilters: tempFilter.parts?.isNotEmpty ?? false,
                            ),

                            buildFilterCategory(
                              icon:    Icons.star,
                              iconName: 'star',
                              title:    'Qualität',
                              child:  _buildQualityFilter(),
                              hasActiveFilters:  tempFilter.qualities?.isNotEmpty ?? false,
                            ),


                            buildFilterCategory(
                              icon:   Icons.date_range,
                              iconName: 'date_range',
                              title:   'Jahrgang',
                              child:  _buildYearsFilter(),
                              hasActiveFilters:   tempFilter.years?.isNotEmpty ?? false,
                            ),

                            buildFilterCategory(
                              icon:Icons.calendar_today,
                              iconName: 'calendar_today',
                              title:    'Zeitraum',
                              child:   _buildDateFilter(),
                              hasActiveFilters:   tempFilter.timeRange != null || tempFilter.startDate != null,
                            ),
                            buildFilterCategory(
                              icon:    Icons.nightlight,
                              iconName: 'nightlight',
                              title:    'Spezielle Filter',
                              child:   _buildSpecialFilters(),
                              hasActiveFilters:   tempFilter.isMoonwood ?? false,
                            ),
                          ],
                        )
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
                child: getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list, color: Color(0xFF0F4A29)),
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
              icon: getAdaptiveIcon(iconName: 'clear_all', defaultIcon: Icons.clear_all,),
              label: const Text('Zurücksetzen'),
              onPressed: _resetFilters,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

// Active Filters Bar anpassen
  Widget _buildActiveFiltersBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (tempFilter.woodTypes?.isNotEmpty ?? false)
            ...tempFilter.woodTypes!.map(_buildWoodTypeChip),
          if (tempFilter.parts?.isNotEmpty ?? false)
            ...tempFilter.parts!.map(_buildPartChip),
          if (tempFilter.instruments?.isNotEmpty ?? false)
            ...tempFilter.instruments!.map(_buildInstrumentChip),
          if (tempFilter.qualities?.isNotEmpty ?? false)
            ...tempFilter.qualities!.map(_buildQualityChip),
          if (tempFilter.timeRange != null || tempFilter.startDate != null)
            _buildTimeRangeChip(),
          if (tempFilter.years?.isNotEmpty ?? false)
            ...tempFilter.years!.map(_buildYearChip),

          if (tempFilter.isMoonwood == true)
            _buildSpecialChip(
              'Mondholz',
              Colors.purple,
                  () => setState(() => tempFilter = tempFilter.copyWith(isMoonwood: false)),
            ),
          if (tempFilter.isHaselfichte == true)
            _buildSpecialChip(
              'Haselfichte',
              Colors.teal,
                  () => setState(() => tempFilter = tempFilter.copyWith(isHaselfichte: false)),
            ),
          if (tempFilter.isThermallyTreated == true)
            _buildSpecialChip(
              'Thermisch behandelt',
              Colors.orange,
                  () => setState(() => tempFilter = tempFilter.copyWith(isThermallyTreated: false)),
            ),
          if (tempFilter.isFSC == true)
            _buildSpecialChip(
              'FSC-100',
              Colors.green,
                  () => setState(() => tempFilter = tempFilter.copyWith(isFSC: false)),
            ),
        ],
      ),
    );
  }

// MultiSelect Dropdown hinzufügen
  Widget _buildMultiSelectDropdown({
    required String label,
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
      child:
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView(
              shrinkWrap: true,
              children: options.map((option) {
                final data = option.data() as Map<String, dynamic>;
                final isSelected = selectedValues.contains(option.id);

                return CheckboxListTile(
                  title: Text(data['name'] as String),
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

  Widget _buildWoodTypeChip(String code) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('wood_types')
            .doc(code)
            .snapshots(),
        builder: (context, snapshot) {
          final name = snapshot.hasData
              ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
              : code;
          return Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text('$name ($code)'),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  woodTypes: tempFilter.woodTypes?.where((t) => t != code).toList(),
                );
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildPartChip(String code) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parts')
            .doc(code)
            .snapshots(),
        builder: (context, snapshot) {
          final name = snapshot.hasData
              ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
              : code;
          return Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text('$name ($code)'),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  parts: tempFilter.parts?.where((t) => t != code).toList(),
                );
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildInstrumentChip(String code) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('instruments')
            .doc(code)
            .snapshots(),
        builder: (context, snapshot) {
          final name = snapshot.hasData
              ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
              : code;
          return Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text('$name ($code)'),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  instruments: tempFilter.instruments?.where((t) => t != code).toList(),
                );
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildYearChip(String year) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: Text('$year'),
        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
        onDeleted: () {
          setState(() {
            tempFilter = tempFilter.copyWith(
              years: tempFilter.years?.where((y) => y != year).toList(),
            );
          });
        },
      ),
    );
  }

  Widget _buildQualityChip(String code) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('qualities')
            .doc(code)
            .snapshots(),
        builder: (context, snapshot) {
          final name = snapshot.hasData
              ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
              : code;
          return Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text('$name ($code)'),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  qualities: tempFilter.qualities?.where((q) => q != code).toList(),
                );
              });
            },
          );
        },
      ),
    );
  }


  Widget _buildTimeRangeChip() {
    String timeText = '';
    if (tempFilter.timeRange != null) {
      switch (tempFilter.timeRange) {
        case 'week':
          timeText = 'Woche';
          break;
        case 'month':
          timeText = 'Monat';
          break;
        case 'quarter':
          timeText = 'Quartal';
          break;
        case 'year':
          timeText = 'Jahr';
          break;
      }
    } else if (tempFilter.startDate != null && tempFilter.endDate != null) {
      timeText =
      '${DateFormat('dd.MM.yy').format(tempFilter.startDate!)} - ${DateFormat('dd.MM.yy').format(tempFilter.endDate!)}';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: Text('Zeitraum: $timeText'),
        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
        onDeleted: () => _resetTimeFilter(),
      ),
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
          label: 'Holzart auswählen',
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

  Widget _buildYearsFilter() {
    // Jahre von 2001 bis zum aktuellen Jahr + 1 generieren
    final int currentYear = DateTime.now().year;
    final List<String> years = [];

    // Jahre in umgekehrter Reihenfolge erstellen (neueste zuerst)
    for (int year = currentYear + 1; year >= 2001; year--) {
      years.add(year.toString());
    }

    // Widget für die Jahre-Auswahl erstellen
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: years.map((year) {
            final bool isSelected = (tempFilter.years ?? []).contains(year);
            return FilterChip(
              label: Text(year),
              selected: isSelected,
              onSelected: (selected) {
                final List<String> updatedYears = List.from(tempFilter.years ?? []);
                if (selected) {
                  updatedYears.add(year);
                } else {
                  updatedYears.remove(year);
                }
                setState(() {
                  tempFilter = tempFilter.copyWith(years: updatedYears);
                });
              },
              selectedColor: const Color(0xFF0F4A29).withOpacity(0.2),
              checkmarkColor: const Color(0xFF0F4A29),
            );
          }).toList(),
        ),
      ],
    );
  }
  Widget _buildInstrumentsFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('instruments')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Instrument auswählen',
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
  Widget _buildPartsFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parts')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Bauteil auswählen',
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
          label: 'Qualität auswählen',
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


  Widget _buildDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Woche'),
              selected: tempFilter.timeRange == 'week',
              onSelected: (selected) {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    timeRange: selected ? 'week' : null,
                    startDate: null,
                    endDate: null,
                  );
                });
              },
            ),
            FilterChip(
              label: const Text('Monat'),
              selected: tempFilter.timeRange == 'month',
              onSelected: (selected) {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    timeRange: selected ? 'month' : null,
                    startDate: null,
                    endDate: null,
                  );
                });
              },
            ),
            FilterChip(
              label: const Text('Quartal'),
              selected: tempFilter.timeRange == 'quarter',
              onSelected: (selected) {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    timeRange: selected ? 'quarter' : null,
                    startDate: null,
                    endDate: null,
                  );
                });
              },
            ),
            FilterChip(
              label: const Text('Jahr'),
              selected: tempFilter.timeRange == 'year',
              onSelected: (selected) {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    timeRange: selected ? 'year' : null,
                    startDate: null,
                    endDate: null,
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Oder Zeitraum wählen:',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Von',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: tempFilter.startDate != null
                      ? DateFormat('dd.MM.yyyy').format(tempFilter.startDate!)
                      : '',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: tempFilter.startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      tempFilter = tempFilter.copyWith(
                        startDate: date,
                        timeRange: null,
                      );
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Bis',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: tempFilter.endDate != null
                      ? DateFormat('dd.MM.yyyy').format(tempFilter.endDate!)
                      : '',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: tempFilter.endDate ?? DateTime.now(),
                    firstDate: tempFilter.startDate ?? DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      tempFilter = tempFilter.copyWith(
                        endDate: date,
                        timeRange: null,
                      );
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
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
    onPressed: () => Navigator.of(context).pop(tempFilter),
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

  Widget _buildSpecialFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Special Wood Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 1,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 5,
          children: [
            _buildSpecialFilterCard(
              title: 'Mondholz',
              icon: Icons.nightlight,
              color: Colors.purple,
              isSelected: tempFilter.isMoonwood ?? false,
              onTap: () {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    isMoonwood: !(tempFilter.isMoonwood ?? false),
                  );
                });
              },
            ),
            _buildSpecialFilterCard(
              title: 'Haselfichte',
              icon: Icons.nature,
              color: Colors.teal,
              isSelected: tempFilter.isHaselfichte ?? false,
              onTap: () {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    isHaselfichte: !(tempFilter.isHaselfichte ?? false),
                  );
                });
              },
            ),
            _buildSpecialFilterCard(
              title: 'Thermisch behandelt',
              icon: Icons.whatshot,
              color: Colors.orange,
              isSelected: tempFilter.isThermallyTreated ?? false,
              onTap: () {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    isThermallyTreated: !(tempFilter.isThermallyTreated ?? false),
                  );
                });
              },
            ),
            _buildSpecialFilterCard(
              title: 'FSC-100',
              icon: Icons.eco,
              color: Colors.green,
              isSelected: tempFilter.isFSC ?? false,
              onTap: () {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    isFSC: !(tempFilter.isFSC ?? false),
                  );
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecialFilterCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey.withOpacity(0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? color : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

// Und im ActiveFiltersBar die Chips für Spezialholz anpassen:
  Widget _buildSpecialChip(String label, Color color, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: CircleAvatar(
          backgroundColor: Colors.transparent,
          child: Icon(
            _getSpecialIcon(label),
            color: color,
            size: 16,
          ),
        ),
        backgroundColor: color.withOpacity(0.1),
        label: Text(
          label,
          style: TextStyle(color: color),
        ),
        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
        onDeleted: onRemove,
      ),
    );
  }

  IconData _getSpecialIcon(String label) {
    switch (label) {
      case 'Mondholz':
        return Icons.nightlight;
      case 'Haselfichte':
        return Icons.nature;
      case 'Thermisch behandelt':
        return Icons.whatshot;
      case 'FSC-100':
        return Icons.eco;
      default:
        return Icons.star;
    }
  }

  void _resetTimeFilter() {
    setState(() {
      tempFilter = tempFilter.copyWith(
        timeRange: null,
        startDate: null,
        endDate: null,
      );
    });
  }

  void _resetFilters() {
    setState(() {
      tempFilter = ProductionFilter();
    });
  }

  // _hasActiveFilters anpassen
  bool _hasActiveFilters() {
    return (tempFilter.woodTypes?.isNotEmpty ?? false) ||
        (tempFilter.instruments?.isNotEmpty ?? false) ||
        (tempFilter.parts?.isNotEmpty ?? false) ||
        (tempFilter.qualities?.isNotEmpty ?? false) ||
        (tempFilter.years?.isNotEmpty ?? false) ||
        tempFilter.timeRange != null ||
        tempFilter.startDate != null ||
        tempFilter.endDate != null ||
        tempFilter.isMoonwood == true;
  }

// Mondholz Chip hinzufügen
  Widget _buildMoonwoodChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: const Text('Mondholz'),
        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
        onDeleted: () => setState(() {
          tempFilter = tempFilter.copyWith(isMoonwood: false);
        }),
      ),
    );
}}