import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../components/filterCategory.dart';
import '../../../services/icon_helper.dart';
import '../models/roundwood_models.dart';
import '../services/roundwood_service.dart';

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
  final RoundwoodService _service = RoundwoodService();
  List<int> _availableYears = [];
// NEU: Oben in RoundwoodFilterDialogState hinzufügen:
  Map<String, String> _woodTypeNames = {};
  Map<String, String> _qualityNames = {};
  // Hardcoded Verwendungszwecke (wie im Entry Screen)
  final List<String> _availablePurposes = ['Gitarre', 'Violine', 'Viola', 'Cello', 'Bass'];

  @override
  @override
  void initState() {
    super.initState();
    tempFilter = widget.initialFilter;
    _loadAvailableYears();
    _loadNames(); // NEU
  }

// NEU: Methode hinzufügen
  Future<void> _loadNames() async {
    final woodSnap = await FirebaseFirestore.instance.collection('wood_types').get();
    final qualSnap = await FirebaseFirestore.instance.collection('qualities').get();

    if (mounted) {
      setState(() {
        for (final doc in woodSnap.docs) {
          final data = doc.data();
          final code = data['code'] as String? ?? doc.id;
          final name = data['name'] as String? ?? code;
          _woodTypeNames[code] = name;
        }
        for (final doc in qualSnap.docs) {
          final data = doc.data();
          final code = data['code'] as String? ?? doc.id;
          final name = data['name'] as String? ?? code;
          _qualityNames[code] = name;
        }
      });
    }
  }

  Future<void> _loadAvailableYears() async {
    final years = await _service.getAvailableYears();
    if (mounted) {
      setState(() => _availableYears = years);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3)],
                      ),
                      child: Theme(
                        data: ThemeData(dividerColor: Colors.transparent),
                        child: Column(
                          children: [
                            // NEU: Jahr Filter
                            buildFilterCategory(
                              icon: Icons.calendar_today,
                              iconName: 'calendar_today',
                              title: 'Jahrgang',
                              child: _buildYearFilter(),
                              hasActiveFilters: tempFilter.year != null,
                            ),
                            buildFilterCategory(
                              icon: Icons.forest,
                              iconName: 'forest',
                              title: 'Holzart',
                              child: _buildWoodTypeFilter(),
                              hasActiveFilters: tempFilter.woodTypes?.isNotEmpty ?? false,
                            ),
                            buildFilterCategory(
                              icon: Icons.star,
                              iconName: 'star',
                              title: 'Qualität',
                              child: _buildQualityFilter(),
                              hasActiveFilters: tempFilter.qualities?.isNotEmpty ?? false,
                            ),
                            // NEU: Verwendungszweck Filter
                            buildFilterCategory(
                              icon: Icons.assignment,
                              iconName: 'assignment',
                              title: 'Verwendungszweck',
                              child: _buildPurposeFilter(),
                              hasActiveFilters: tempFilter.purposes?.isNotEmpty ?? false,
                            ),
                            buildFilterCategory(
                              icon: Icons.straighten,
                              iconName: 'straighten',
                              title: 'Volumen',
                              child: _buildVolumeFilter(),
                              hasActiveFilters: tempFilter.volumeMin != null || tempFilter.volumeMax != null,
                            ),
                            buildFilterCategory(
                              icon: Icons.location_on,
                              iconName: 'location',
                              title: 'Herkunft',
                              child: _buildOriginFilter(),
                              hasActiveFilters: tempFilter.origin != null,
                            ),
                            buildFilterCategory(
                              icon: Icons.date_range,
                              iconName: 'date_range',
                              title: 'Zeitraum',
                              child: _buildDateFilter(),
                              hasActiveFilters: tempFilter.timeRange != null || tempFilter.startDate != null,
                            ),
                            buildFilterCategory(
                              icon: Icons.eco,
                              iconName: 'eco',
                              title: 'Spezielle Filter',
                              child: _buildSpecialFilters(),
                              hasActiveFilters: (tempFilter.isMoonwood ?? false) || (tempFilter.isFSC ?? false),
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
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))],
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
                child: getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list, color: const Color(0xFF0F4A29)),
              ),
              const SizedBox(width: 12),
              const Text('Filter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F4A29))),
            ],
          ),
          const Spacer(),
          if (_hasActiveFilters())
            TextButton.icon(
              icon: getAdaptiveIcon(iconName: 'clear_all', defaultIcon: Icons.clear_all),
              label: const Text('Zurücksetzen'),
              onPressed: _resetFilters,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }
  Widget _buildSpecialFilters() {
    return Column(
      children: [
        // Mondholz Filter (existiert bereits)
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SwitchListTile(
            title: const Text('Nur Mondholz'),
            secondary: getAdaptiveIcon(iconName: 'nightlight', defaultIcon: Icons.nightlight, color: const Color(0xFF0F4A29)),
            value: tempFilter.isMoonwood ?? false,
            onChanged: (value) {
              setState(() {
                tempFilter = tempFilter.copyWith(isMoonwood: value ? true : null, clearMoonwood: !value);
              });
            },
            activeColor: const Color(0xFF0F4A29),
          ),
        ),
        const SizedBox(height: 8),
        // FSC Filter (existiert bereits)
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SwitchListTile(
            title: const Text('Nur FSC-zertifiziert'),
            secondary: getAdaptiveIcon(iconName: 'eco', defaultIcon: Icons.eco, color: Colors.green),
            value: tempFilter.isFSC ?? false,
            onChanged: (value) {
              setState(() {
                tempFilter = tempFilter.copyWith(isFSC: value ? true : null, clearFSC: !value);
              });
            },
            activeColor: const Color(0xFF0F4A29),
          ),
        ),
        const SizedBox(height: 8),
        // ═══════════════════════════════════════════════════════════════════
        // NEU: Abgeschlossene Stämme ausblenden
        // ═══════════════════════════════════════════════════════════════════
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange[300]!),
            borderRadius: BorderRadius.circular(8),
            color: (tempFilter.showClosed == false) ? Colors.orange[50] : null,
          ),
          child: SwitchListTile(
            title: const Text('Abgeschlossene ausblenden'),
            subtitle: Text(
              'Nur offene Stämme anzeigen',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            secondary: getAdaptiveIcon(
              iconName: (tempFilter.showClosed == false) ? 'visibility_off' : 'visibility',
              defaultIcon: (tempFilter.showClosed == false) ? Icons.visibility_off : Icons.visibility,
              color: Colors.orange[700],
            ),
            value: tempFilter.showClosed == false,
            onChanged: (value) {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  showClosed: value ? false : null,
                  clearShowClosed: !value,
                );
              });
            },
            activeColor: Colors.orange[700],
          ),
        ),
      ],
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// ERGÄNZUNG 2: In _buildActiveFiltersBar() den Chip hinzufügen
// ═══════════════════════════════════════════════════════════════════════════

  Widget _buildActiveFiltersBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (tempFilter.year != null)
            _buildFilterChip('Jahr: ${tempFilter.year}', () => _updateFilter(clearYear: true)),


          if (tempFilter.woodTypes?.isNotEmpty ?? false)
            ...tempFilter.woodTypes!.map((w) => _buildFilterChip(
              'Holz: ${_woodTypeNames[w] ?? w}',
                  () => _removeWoodType(w),
            )),
          if (tempFilter.qualities?.isNotEmpty ?? false)
            ...tempFilter.qualities!.map((q) => _buildFilterChip(
              'Qualität: ${_qualityNames[q] ?? q}',
                  () => _removeQuality(q),
            )),

          if (tempFilter.purposes?.isNotEmpty ?? false)
            ...tempFilter.purposes!.map((p) => _buildFilterChip('Zweck: $p', () => _removePurpose(p))),
          if (tempFilter.origin != null)
            _buildFilterChip('Herkunft: ${tempFilter.origin}', () => _updateFilter(clearOrigin: true)),
          if (tempFilter.volumeMin != null || tempFilter.volumeMax != null)
            _buildVolumeChip(),
          if (tempFilter.timeRange != null || tempFilter.startDate != null)
            _buildTimeRangeChip(),
          if (tempFilter.isMoonwood ?? false)
            _buildFilterChip('Nur Mondholz', () => _updateFilter(clearMoonwood: true)),
          if (tempFilter.isFSC ?? false)
            _buildFilterChip('Nur FSC', () => _updateFilter(clearFSC: true)),
          // ═══════════════════════════════════════════════════════════════════
          // NEU: Chip für "Abgeschlossene ausblenden"
          // ═══════════════════════════════════════════════════════════════════
          if (tempFilter.showClosed == false)
            _buildFilterChip(
              'Abgeschlossene ausgeblendet',
                  () => _updateFilter(clearShowClosed: true),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: Text(label),
        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close, size: 18),
        onDeleted: onDelete,
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
    return _buildFilterChip('Volumen: $volumeText', () => _updateFilter(clearVolume: true));
  }

  Widget _buildTimeRangeChip() {
    String timeText = '';
    if (tempFilter.timeRange != null) {
      switch (tempFilter.timeRange) {
        case 'week': timeText = 'Woche'; break;
        case 'month': timeText = 'Monat'; break;
        case 'quarter': timeText = 'Quartal'; break;
        case 'year': timeText = 'Jahr'; break;
      }
    } else if (tempFilter.startDate != null && tempFilter.endDate != null) {
      timeText = '${DateFormat('dd.MM.yy').format(tempFilter.startDate!)} - ${DateFormat('dd.MM.yy').format(tempFilter.endDate!)}';
    }
    return _buildFilterChip('Zeitraum: $timeText', () => _updateFilter(clearDates: true));
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, -1))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!)),
            child: const Text('Abbrechen'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(tempFilter),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F4A29)),
            child: const Text('Anwenden'),
          ),
        ],
      ),
    );
  }

  // NEU: Jahr Filter
  Widget _buildYearFilter() {
    if (_availableYears.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableYears.map((year) {
        final isSelected = tempFilter.year == year;
        return FilterChip(
          label: Text('$year'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              tempFilter = tempFilter.copyWith(year: selected ? year : null, clearYear: !selected);
            });
          },
          selectedColor: const Color(0xFF0F4A29).withOpacity(0.2),
          checkmarkColor: const Color(0xFF0F4A29),
        );
      }).toList(),
    );
  }

  Widget _buildWoodTypeFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('wood_types').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return _buildMultiSelectList(
          options: snapshot.data!.docs,
          selectedValues: tempFilter.woodTypes ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(woodTypes: newSelection.isEmpty ? null : newSelection, clearWoodTypes: newSelection.isEmpty);
            });
          },
        );
      },
    );
  }

  Widget _buildQualityFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('qualities').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return _buildMultiSelectList(
          options: snapshot.data!.docs,
          selectedValues: tempFilter.qualities ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(qualities: newSelection.isEmpty ? null : newSelection, clearQualities: newSelection.isEmpty);
            });
          },
        );
      },
    );
  }

  // NEU: Verwendungszweck Filter
  Widget _buildPurposeFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availablePurposes.map((purpose) {
        final isSelected = tempFilter.purposes?.contains(purpose) ?? false;
        return FilterChip(
          label: Text(purpose),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              final currentPurposes = List<String>.from(tempFilter.purposes ?? []);
              if (selected) {
                currentPurposes.add(purpose);
              } else {
                currentPurposes.remove(purpose);
              }
              tempFilter = tempFilter.copyWith(
                purposes: currentPurposes.isEmpty ? null : currentPurposes,
                clearPurposes: currentPurposes.isEmpty,
              );
            });
          },
          selectedColor: const Color(0xFF0F4A29).withOpacity(0.2),
          checkmarkColor: const Color(0xFF0F4A29),
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelectList({
    required List<DocumentSnapshot> options,
    required List<String> selectedValues,
    required Function(List<String>) onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final data = option.data() as Map<String, dynamic>;
        final code = data['code'] as String? ?? option.id;
        final name = data['name'] as String? ?? code;
        final isSelected = selectedValues.contains(code);

        return FilterChip(
          label: Text(name),
          selected: isSelected,
          onSelected: (selected) {
            final newSelection = List<String>.from(selectedValues);
            if (selected) {
              newSelection.add(code);
            } else {
              newSelection.remove(code);
            }
            onChanged(newSelection);
          },
          selectedColor: const Color(0xFF0F4A29).withOpacity(0.2),
          checkmarkColor: const Color(0xFF0F4A29),
        );
      }).toList(),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                tempFilter = tempFilter.copyWith(volumeMin: double.tryParse(value));
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                tempFilter = tempFilter.copyWith(volumeMax: double.tryParse(value));
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) {
        setState(() {
          tempFilter = tempFilter.copyWith(origin: value.isEmpty ? null : value, clearOrigin: value.isEmpty);
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
            _buildTimeRangeFilterChip('Woche', 'week'),
            _buildTimeRangeFilterChip('Monat', 'month'),
            _buildTimeRangeFilterChip('Quartal', 'quarter'),
            _buildTimeRangeFilterChip('Jahr', 'year'),
          ],
        ),
        const SizedBox(height: 16),
        Text('Oder Zeitraum wählen:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDatePickerField('Von', tempFilter.startDate, (date) {
              setState(() {
                tempFilter = tempFilter.copyWith(startDate: date, timeRange: null);
              });
            })),
            const SizedBox(width: 16),
            Expanded(child: _buildDatePickerField('Bis', tempFilter.endDate, (date) {
              setState(() {
                tempFilter = tempFilter.copyWith(endDate: date, timeRange: null);
              });
            })),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeRangeFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: tempFilter.timeRange == value,
      onSelected: (selected) {
        setState(() {
          tempFilter = tempFilter.copyWith(
            timeRange: selected ? value : null,
            clearDates: true,
          );
        });
      },
      selectedColor: const Color(0xFF0F4A29).withOpacity(0.2),
      checkmarkColor: const Color(0xFF0F4A29),
    );
  }

  Widget _buildDatePickerField(String label, DateTime? value, Function(DateTime) onSelected) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
      ),
      readOnly: true,
      controller: TextEditingController(text: value != null ? DateFormat('dd.MM.yyyy').format(value) : ''),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) onSelected(date);
      },
    );
  }



  void _resetFilters() {
    setState(() {
      tempFilter = RoundwoodFilter();
    });
  }

  bool _hasActiveFilters() {
    return tempFilter.toMap().isNotEmpty;
  }

  void _updateFilter({
    bool clearYear = false,
    bool clearWoodTypes = false,
    bool clearQualities = false,
    bool clearPurposes = false,
    bool clearOrigin = false,
    bool clearVolume = false,
    bool clearMoonwood = false,
    bool clearFSC = false,
    bool clearDates = false,
    bool clearShowClosed = false,  // ← NEU
  }) {
    setState(() {
      tempFilter = tempFilter.copyWith(
        clearYear: clearYear,
        clearWoodTypes: clearWoodTypes,
        clearQualities: clearQualities,
        clearPurposes: clearPurposes,
        clearOrigin: clearOrigin,
        clearVolume: clearVolume,
        clearMoonwood: clearMoonwood,
        clearFSC: clearFSC,
        clearDates: clearDates,
        clearShowClosed: clearShowClosed,  // ← NEU
      );
    });
  }

  void _removeWoodType(String code) {
    final newList = tempFilter.woodTypes?.where((w) => w != code).toList();
    setState(() {
      tempFilter = tempFilter.copyWith(woodTypes: newList?.isEmpty == true ? null : newList, clearWoodTypes: newList?.isEmpty == true);
    });
  }

  void _removeQuality(String code) {
    final newList = tempFilter.qualities?.where((q) => q != code).toList();
    setState(() {
      tempFilter = tempFilter.copyWith(qualities: newList?.isEmpty == true ? null : newList, clearQualities: newList?.isEmpty == true);
    });
  }

  void _removePurpose(String purpose) {
    final newList = tempFilter.purposes?.where((p) => p != purpose).toList();
    setState(() {
      tempFilter = tempFilter.copyWith(purposes: newList?.isEmpty == true ? null : newList, clearPurposes: newList?.isEmpty == true);
    });
  }
}