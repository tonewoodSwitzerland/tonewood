// lib/screens/analytics/roundwood/widgets/roundwood_filter_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/roundwood_models.dart';
import '../constants/roundwood_constants.dart';

class RoundwoodFilterDialog extends StatefulWidget {
  final RoundwoodFilter initialFilter;

  const RoundwoodFilterDialog({
    Key? key,
    required this.initialFilter,
  }) : super(key: key);

  @override
  RoundwoodFilterDialogState createState() => RoundwoodFilterDialogState();
}

class RoundwoodFilterDialogState extends State<RoundwoodFilterDialog> {
  late RoundwoodFilter tempFilter;
  final TextEditingController additionalPurposeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    tempFilter = widget.initialFilter;
    additionalPurposeController.text = tempFilter.additionalPurpose ?? '';
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
            if (_hasActiveFilters())
              _buildActiveFiltersBar(),
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
                            _buildFilterCategory(
                              Icons.straighten,
                              'Volumen',
                              _buildVolumeFilter(),
                              tempFilter.volumeMin != null || tempFilter.volumeMax != null,
                            ),
                            _buildFilterCategory(
                              Icons.location_on,
                              'Herkunft',
                              _buildOriginFilter(),
                              tempFilter.origin != null,
                            ),
                            _buildFilterCategory(
                              Icons.calendar_today,
                              'Zeitraum',
                              _buildDateFilter(),
                              tempFilter.timeRange != null || tempFilter.startDate != null,
                            ),
                            _buildFilterCategory(
                              Icons.nightlight,
                              'Spezielle Filter',
                              _buildSpecialFilters(),
                              tempFilter.isMoonwood ?? false,
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
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => _removeWoodType(code),
          );
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
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => _removeQuality(code),
          );
        },
      ),
    );
  }

  Widget _buildOriginChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: Text('Herkunft: ${tempFilter.origin}'),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => setState(() {
          tempFilter = RoundwoodFilter(
            woodTypes: tempFilter.woodTypes,
            qualities: tempFilter.qualities,
            origin: null,
            volumeMin: tempFilter.volumeMin,
            volumeMax: tempFilter.volumeMax,
            isMoonwood: tempFilter.isMoonwood,
            timeRange: tempFilter.timeRange,
            startDate: tempFilter.startDate,
            endDate: tempFilter.endDate,
          );
        }),
      ),
    );
  }

  Widget _buildVolumeChip() {
    String volumeText = '';
    if (tempFilter.volumeMin != null && tempFilter.volumeMax != null) {
      volumeText = '${tempFilter.volumeMin}-${tempFilter.volumeMax} m³';
    } else if (tempFilter.volumeMin != null) {
      volumeText = '>${tempFilter.volumeMin} m³';
    } else if (tempFilter.volumeMax != null) {
      volumeText = '<${tempFilter.volumeMax} m³';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: Text('Volumen: $volumeText'),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => setState(() {
          tempFilter = RoundwoodFilter(
            woodTypes: tempFilter.woodTypes,
            qualities: tempFilter.qualities,
            origin: tempFilter.origin,
            volumeMin: null,
            volumeMax: null,
            isMoonwood: tempFilter.isMoonwood,
            timeRange: tempFilter.timeRange,
            startDate: tempFilter.startDate,
            endDate: tempFilter.endDate,
          );
        }),
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
      timeText = '${DateFormat('dd.MM.yy').format(tempFilter.startDate!)} - ${DateFormat('dd.MM.yy').format(tempFilter.endDate!)}';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: Text('Zeitraum: $timeText'),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => setState(() {
          tempFilter = RoundwoodFilter(
            woodTypes: tempFilter.woodTypes,
            qualities: tempFilter.qualities,
            origin: tempFilter.origin,
            volumeMin: tempFilter.volumeMin,
            volumeMax: tempFilter.volumeMax,
            isMoonwood: tempFilter.isMoonwood,
            timeRange: null,
            startDate: null,
            endDate: null,
          );
        }),
      ),
    );
  }

  Widget _buildMoonwoodChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: const Text('Nur Mondholz'),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => setState(() {
          tempFilter = RoundwoodFilter(
            woodTypes: tempFilter.woodTypes,
            qualities: tempFilter.qualities,
            origin: tempFilter.origin,
            volumeMin: tempFilter.volumeMin,
            volumeMax: tempFilter.volumeMax,
            isMoonwood: false,
            timeRange: tempFilter.timeRange,
            startDate: tempFilter.startDate,
            endDate: tempFilter.endDate,
          );
        }),
      ),
    );
  }

  void _removeWoodType(String code) {
    setState(() {
      tempFilter = RoundwoodFilter(
        woodTypes: tempFilter.woodTypes?.where((w) => w != code).toList(),
        qualities: tempFilter.qualities,
        origin: tempFilter.origin,
        volumeMin: tempFilter.volumeMin,
        volumeMax: tempFilter.volumeMax,
        isMoonwood: tempFilter.isMoonwood,
        timeRange: tempFilter.timeRange,
        startDate: tempFilter.startDate,
        endDate: tempFilter.endDate,
      );
    });
  }

  void _removeQuality(String code) {
    setState(() {
      tempFilter = RoundwoodFilter(
        woodTypes: tempFilter.woodTypes,
        qualities: tempFilter.qualities?.where((q) => q != code).toList(),
        origin: tempFilter.origin,
        volumeMin: tempFilter.volumeMin,
        volumeMax: tempFilter.volumeMax,
        isMoonwood: tempFilter.isMoonwood,
        timeRange: tempFilter.timeRange,
        startDate: tempFilter.startDate,
        endDate: tempFilter.endDate,
      );
    });
  }
  Widget _buildActiveFiltersBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (tempFilter.woodTypes?.isNotEmpty ?? false)
            ...tempFilter.woodTypes!.map(_buildWoodTypeChip),
          if (tempFilter.qualities?.isNotEmpty ?? false)
            ...tempFilter.qualities!.map(_buildQualityChip),
          if (tempFilter.origin != null)
            _buildOriginChip(),
          if (tempFilter.volumeMin != null || tempFilter.volumeMax != null)
            _buildVolumeChip(),
          if (tempFilter.timeRange != null)
            _buildTimeRangeChip(),
          if (tempFilter.isMoonwood ?? false)
            _buildMoonwoodChip(),
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

  // Helper methods
  void _resetFilters() {
    setState(() {
      tempFilter = RoundwoodFilter();
    });
  }

  bool _hasActiveFilters() {
    return (tempFilter.woodTypes?.isNotEmpty ?? false) ||
        (tempFilter.qualities?.isNotEmpty ?? false) ||
        tempFilter.origin != null ||
        tempFilter.volumeMin != null ||
        tempFilter.volumeMax != null ||
        (tempFilter.isMoonwood == true) ||  // statt ?? false
        tempFilter.timeRange != null ||
        tempFilter.startDate != null ||
        tempFilter.endDate != null;
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
              tempFilter = RoundwoodFilter(
                woodTypes: newSelection,
                qualities: tempFilter.qualities,
                purposeCodes: tempFilter.purposeCodes,
                additionalPurpose: tempFilter.additionalPurpose,
                origin: tempFilter.origin,
                volumeMin: tempFilter.volumeMin,
                volumeMax: tempFilter.volumeMax,
                isMoonwood: tempFilter.isMoonwood,
                startDate: tempFilter.startDate,
                endDate: tempFilter.endDate,
                timeRange: tempFilter.timeRange,
              );
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
              tempFilter = RoundwoodFilter(
                woodTypes: tempFilter.woodTypes,
                qualities: newSelection,
                purposeCodes: tempFilter.purposeCodes,
                additionalPurpose: tempFilter.additionalPurpose,
                origin: tempFilter.origin,
                volumeMin: tempFilter.volumeMin,
                volumeMax: tempFilter.volumeMax,
                isMoonwood: tempFilter.isMoonwood,
                startDate: tempFilter.startDate,
                endDate: tempFilter.endDate,
                timeRange: tempFilter.timeRange,
              );
            });
          },
        );
      },
    );
  }

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
      child: ExpansionTile(
        title: Text(
          selectedValues.isEmpty ? label : '${selectedValues.length} ausgewählt',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        children: [
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
        ],
      ),
    );
  }

  Widget _buildVolumeFilter() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: tempFilter.volumeMin?.toString(),
            decoration: InputDecoration(
              labelText: 'Minimum (m³)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                tempFilter = RoundwoodFilter(
                  woodTypes: tempFilter.woodTypes,
                  qualities: tempFilter.qualities,
                  purposeCodes: tempFilter.purposeCodes,
                  additionalPurpose: tempFilter.additionalPurpose,
                  origin: tempFilter.origin,
                  volumeMin: double.tryParse(value),
                  volumeMax: tempFilter.volumeMax,
                  isMoonwood: tempFilter.isMoonwood,
                  startDate: tempFilter.startDate,
                  endDate: tempFilter.endDate,
                  timeRange: tempFilter.timeRange,
                );
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            initialValue: tempFilter.volumeMax?.toString(),
            decoration: InputDecoration(
              labelText: 'Maximum (m³)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                tempFilter = RoundwoodFilter(
                  woodTypes: tempFilter.woodTypes,
                  qualities: tempFilter.qualities,
                  purposeCodes: tempFilter.purposeCodes,
                  additionalPurpose: tempFilter.additionalPurpose,
                  origin: tempFilter.origin,
                  volumeMin: tempFilter.volumeMin,
                  volumeMax: double.tryParse(value),
                  isMoonwood: tempFilter.isMoonwood,
                  startDate: tempFilter.startDate,
                  endDate: tempFilter.endDate,
                  timeRange: tempFilter.timeRange,
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOriginFilter() {
    return TextFormField(
      initialValue: tempFilter.origin,
      decoration: InputDecoration(
        hintText: 'z.B. Schweiz',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (value) {
        setState(() {
          tempFilter = RoundwoodFilter(
            woodTypes: tempFilter.woodTypes,
            qualities: tempFilter.qualities,
            purposeCodes: tempFilter.purposeCodes,
            additionalPurpose: tempFilter.additionalPurpose,
            origin: value.isEmpty ? null : value,
            volumeMin: tempFilter.volumeMin,
            volumeMax: tempFilter.volumeMax,
            isMoonwood: tempFilter.isMoonwood,
            startDate: tempFilter.startDate,
            endDate: tempFilter.endDate,
            timeRange: tempFilter.timeRange,
          );
        });
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
    tempFilter = RoundwoodFilter(
    woodTypes: tempFilter.woodTypes,
    qualities: tempFilter.qualities,
    purposeCodes: tempFilter.purposeCodes,
    additionalPurpose: tempFilter.additionalPurpose,
    origin: tempFilter.origin,
    volumeMin: tempFilter.volumeMin,
    volumeMax: tempFilter.volumeMax,
    isMoonwood: tempFilter.isMoonwood,
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
    tempFilter = RoundwoodFilter(
    woodTypes: tempFilter.woodTypes,
    qualities: tempFilter.qualities,
    purposeCodes: tempFilter.purposeCodes,
    additionalPurpose: tempFilter.additionalPurpose,
    origin: tempFilter.origin,
    volumeMin: tempFilter.volumeMin,
    volumeMax: tempFilter.volumeMax,
    isMoonwood: tempFilter.isMoonwood,
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
    tempFilter = RoundwoodFilter(
    woodTypes: tempFilter.woodTypes,
    qualities: tempFilter.qualities,
    purposeCodes: tempFilter.purposeCodes,
    additionalPurpose: tempFilter.additionalPurpose,
    origin: tempFilter.origin,
    volumeMin: tempFilter.volumeMin,
    volumeMax: tempFilter.volumeMax,
      isMoonwood: tempFilter.isMoonwood,
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
                tempFilter = RoundwoodFilter(
                  woodTypes: tempFilter.woodTypes,
                  qualities: tempFilter.qualities,
                  purposeCodes: tempFilter.purposeCodes,
                  additionalPurpose: tempFilter.additionalPurpose,
                  origin: tempFilter.origin,
                  volumeMin: tempFilter.volumeMin,
                  volumeMax: tempFilter.volumeMax,
                  isMoonwood: tempFilter.isMoonwood,
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
                    suffixIcon: const Icon(Icons.calendar_today),
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
                        tempFilter = RoundwoodFilter(
                          woodTypes: tempFilter.woodTypes,
                          qualities: tempFilter.qualities,
                          purposeCodes: tempFilter.purposeCodes,
                          additionalPurpose: tempFilter.additionalPurpose,
                          origin: tempFilter.origin,
                          volumeMin: tempFilter.volumeMin,
                          volumeMax: tempFilter.volumeMax,
                          isMoonwood: tempFilter.isMoonwood,
                          startDate: date,
                          endDate: tempFilter.endDate,
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
                    suffixIcon: const Icon(Icons.calendar_today),
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
                        tempFilter = RoundwoodFilter(
                          woodTypes: tempFilter.woodTypes,
                          qualities: tempFilter.qualities,
                          purposeCodes: tempFilter.purposeCodes,
                          additionalPurpose: tempFilter.additionalPurpose,
                          origin: tempFilter.origin,
                          volumeMin: tempFilter.volumeMin,
                          volumeMax: tempFilter.volumeMax,
                          isMoonwood: tempFilter.isMoonwood,
                          startDate: tempFilter.startDate,
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

  Widget _buildSpecialFilters() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        title: const Text('Nur Mondholz'),
        value: tempFilter.isMoonwood ?? false,
        onChanged: (value) {
          setState(() {
            tempFilter = RoundwoodFilter(
              woodTypes: tempFilter.woodTypes,
              qualities: tempFilter.qualities,
              purposeCodes: tempFilter.purposeCodes,
              additionalPurpose: tempFilter.additionalPurpose,
              origin: tempFilter.origin,
              volumeMin: tempFilter.volumeMin,
              volumeMax: tempFilter.volumeMax,
              isMoonwood: value,
              startDate: tempFilter.startDate,
              endDate: tempFilter.endDate,
              timeRange: tempFilter.timeRange,
            );
          });
        },
      ),
    );
  }


}