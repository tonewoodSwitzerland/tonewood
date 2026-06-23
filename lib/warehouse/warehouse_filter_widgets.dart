import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/icon_helper.dart';
import 'warehouse_filter.dart';

/// Markenfarbe der Filter-UI (war vorher inline im Screen verstreut).
const Color _kBrand = Color(0xFF0F4A29);

/// Anzeigenamen der vier Boolean-Merkmale (zentral, vorher mehrfach dupliziert).
const Map<String, String> kFeatureLabels = {
  'thermo': 'Thermo',
  'hasel': 'Haselfichte',
  'mondholz': 'Mondholz',
  'fsc': 'FSC',
};

/// Aufklappbare Filter-Kategorie (Karte mit Icon, Titel und Inhalt).
/// Vorher: WarehouseScreenState._buildFilterCategory.
class FilterCategoryCard extends StatelessWidget {
  const FilterCategoryCard({
    super.key,
    required this.iconName,
    required this.icon,
    required this.title,
    required this.child,
  });

  final String iconName;

  /// IconData oder Widget-Fallback für getAdaptiveIcon (daher dynamic, wie zuvor).
  final dynamic icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(
              red: 0,
              green: 0,
              blue: 0,
              alpha: 0.1,
            ),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: getAdaptiveIcon(
              iconName: iconName,
              defaultIcon: icon is IconData ? icon : Icons.category,
              color: _kBrand,
              size: 24,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          childrenPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [child],
        ),
      ),
    );
  }
}

/// Kompakter Chip für einen aktiven Filter mit Entfernen-Button.
/// Vorher: WarehouseScreenState._buildFilterChip.
class FilterRemoveChip extends StatelessWidget {
  const FilterRemoveChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: _kBrand.withOpacity(0.1),
      deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
      onDeleted: onRemove,
      deleteIconColor: _kBrand,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

/// Layout-Modus der aktiven-Filter-Liste.
enum ActiveFilterLayout {
  /// Horizontal scrollbare Reihe (mobile Leiste).
  horizontalScroll,

  /// Umbrechendes Wrap (Panel + Dialog).
  wrap,
}

/// Vereinheitlichte Anzeige der aktiven Filter als entfernbare Chips.
/// Ersetzt die drei vorher fast identischen Implementierungen
/// (_buildActiveFiltersChips, _buildActiveFiltersSummary, Dialog-Wrap).
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.layout,
    required this.filter,
    required this.instruments,
    required this.parts,
    required this.woodTypes,
    required this.qualities,
    required this.onRemoveInstrument,
    required this.onRemovePart,
    required this.onRemoveWood,
    required this.onRemoveQuality,
    required this.onRemoveUnit,
    required this.onRemoveFeature,
    required this.onRemoveActs,
    required this.onRemoveYear,
    required this.onRemoveDate,
    this.showCodeInLabel = false,
    this.showUnit = true,
  });

  final ActiveFilterLayout layout;
  final WarehouseFilter filter;

  final List<QueryDocumentSnapshot>? instruments;
  final List<QueryDocumentSnapshot>? parts;
  final List<QueryDocumentSnapshot>? woodTypes;
  final List<QueryDocumentSnapshot>? qualities;

  final void Function(String code) onRemoveInstrument;
  final void Function(String code) onRemovePart;
  final void Function(String code) onRemoveWood;
  final void Function(String code) onRemoveQuality;
  final VoidCallback onRemoveUnit;
  final void Function(String key) onRemoveFeature;
  final VoidCallback onRemoveActs;
  final void Function(String year) onRemoveYear;
  final VoidCallback onRemoveDate;

  /// true: Chip-Label zeigt "Name (CODE)" (mobile Variante), sonst nur "Name".
  final bool showCodeInLabel;

  /// true: Einheit-Chip wird angezeigt (war nur in der mobilen Leiste der Fall).
  final bool showUnit;

  String _nameForCode(List<QueryDocumentSnapshot>? docs, String code) {
    if (docs == null || docs.isEmpty) return code;
    try {
      final doc = docs.firstWhere(
            (d) => (d.data() as Map<String, dynamic>)['code'] == code,
      );
      final data = doc.data() as Map<String, dynamic>?;
      return (data?['name'] as String?) ?? code;
    } catch (_) {
      return code;
    }
  }

  String _codeLabel(List<QueryDocumentSnapshot>? docs, String code) {
    final name = _nameForCode(docs, code);
    return showCodeInLabel ? '$name ($code)' : name;
  }

  String _dateLabel() {
    final fmt = DateFormat('dd.MM.yyyy');
    final from = filter.createdFrom;
    final to = filter.createdTo;
    if (from != null && to != null) {
      return '${fmt.format(from)} – ${fmt.format(to)}';
    }
    if (from != null) return 'ab ${fmt.format(from)}';
    if (to != null) return 'bis ${fmt.format(to)}';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      ...filter.instrumentCodes.map((c) => FilterRemoveChip(
        label: _codeLabel(instruments, c),
        onRemove: () => onRemoveInstrument(c),
      )),
      ...filter.partCodes.map((c) => FilterRemoveChip(
        label: _codeLabel(parts, c),
        onRemove: () => onRemovePart(c),
      )),
      ...filter.woodCodes.map((c) => FilterRemoveChip(
        label: _codeLabel(woodTypes, c),
        onRemove: () => onRemoveWood(c),
      )),
      ...filter.qualityCodes.map((c) => FilterRemoveChip(
        label: _codeLabel(qualities, c),
        onRemove: () => onRemoveQuality(c),
      )),
      if (showUnit && filter.unit != null)
        FilterRemoveChip(
          label: 'Einheit: ${filter.unit}',
          onRemove: onRemoveUnit,
        ),
      ...filter.features.map((k) => FilterRemoveChip(
        label: kFeatureLabels[k] ?? k,
        onRemove: () => onRemoveFeature(k),
      )),
      if (filter.isActs == true)
        FilterRemoveChip(label: 'ACTS', onRemove: onRemoveActs),
      ...filter.years.map((y) => FilterRemoveChip(
        label: 'Jg. $y',
        onRemove: () => onRemoveYear(y),
      )),
      if (filter.hasDateFilter)
        FilterRemoveChip(
          label: 'Datum: ${_dateLabel()}',
          onRemove: onRemoveDate,
        ),
    ];

    if (layout == ActiveFilterLayout.horizontalScroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            for (final chip in chips)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: chip,
              ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

/// Von-Bis-Datumsfilter auf `created_at` (responsiv).
/// Vorher: WarehouseScreenState._buildDateRangeFilter.
/// Meldet jede Änderung über [onChanged] – die Seiteneffekte (Speichern,
/// Suche leeren, Stream neu laden) liegen bewusst beim Aufrufer.
class DateRangeFilterCard extends StatelessWidget {
  const DateRangeFilterCard({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    Future<void> pickDate({required bool isFrom}) async {
      final initial = isFrom
          ? (from ?? to ?? DateTime.now())
          : (to ?? from ?? DateTime.now());
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
        helpText: isFrom ? 'Von-Datum wählen' : 'Bis-Datum wählen',
      );
      if (picked == null) return;
      if (isFrom) {
        var newTo = to;
        if (newTo != null && picked.isAfter(newTo)) newTo = picked;
        onChanged(picked, newTo);
      } else {
        var newFrom = from;
        if (newFrom != null && picked.isBefore(newFrom)) newFrom = picked;
        onChanged(newFrom, picked);
      }
    }

    Widget buildField({
      required String label,
      required DateTime? value,
      required bool isFrom,
    }) {
      return InkWell(
        onTap: () => pickDate(isFrom: isFrom),
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: value == null
                ? getAdaptiveIcon(
              iconName: 'calendar_today',
              defaultIcon: Icons.calendar_today,
              size: 18,
            )
                : IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 18,
              constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: getAdaptiveIcon(
                iconName: 'close',
                defaultIcon: Icons.close,
                size: 18,
              ),
              onPressed: () =>
              isFrom ? onChanged(null, to) : onChanged(from, null),
            ),
            suffixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          child: Text(
            value == null ? '–' : dateFormat.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value == null ? Colors.grey[500] : Colors.black87,
            ),
          ),
        ),
      );
    }

    return FilterCategoryCard(
      iconName: 'date_range',
      icon: Icons.date_range,
      title: 'Erstellungsdatum',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 340;
          final fromField = buildField(label: 'Von', value: from, isFrom: true);
          final toField = buildField(label: 'Bis', value: to, isFrom: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stack) ...[
                fromField,
                const SizedBox(height: 12),
                toField,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fromField),
                    const SizedBox(width: 12),
                    Expanded(child: toField),
                  ],
                ),
              if (from != null || to != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: getAdaptiveIcon(
                      iconName: 'clear',
                      defaultIcon: Icons.clear,
                      size: 16,
                    ),
                    label: const Text('Datum zurücksetzen'),
                    onPressed: () => onChanged(null, null),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Shop-Eigenschaften: vier Boolean-Merkmale, ACTS und Jahrgang.
/// Vorher: WarehouseScreenState._buildShopPropertyFilters.
class ShopPropertyFilterCard extends StatelessWidget {
  const ShopPropertyFilterCard({
    super.key,
    required this.selectedFeatures,
    required this.isActs,
    required this.selectedYears,
    required this.availableYears,
    required this.onToggleFeature,
    required this.onToggleActs,
    required this.onToggleYear,
  });

  final Set<String> selectedFeatures;
  final bool? isActs;
  final List<String> selectedYears;
  final List<String> availableYears;
  final void Function(String key, bool selected) onToggleFeature;
  final void Function(bool selected) onToggleActs;
  final void Function(String year, bool selected) onToggleYear;

  @override
  Widget build(BuildContext context) {
    return FilterCategoryCard(
      iconName: 'tune',
      icon: Icons.tune,
      title: 'Eigenschaften',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...WarehouseFilter.featureKeys.map((key) {
                return FilterChip(
                  label: Text(kFeatureLabels[key] ?? key),
                  selected: selectedFeatures.contains(key),
                  onSelected: (sel) => onToggleFeature(key, sel),
                );
              }),
              FilterChip(
                label: const Text('ACTS'),
                selected: isActs == true,
                onSelected: (sel) => onToggleActs(sel),
              ),
            ],
          ),
          if (availableYears.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Jahrgang',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableYears.map((year) {
                return FilterChip(
                  label: Text(year),
                  selected: selectedYears.contains(year),
                  onSelected: (sel) => onToggleYear(year, sel),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mehrfachauswahl per Checkbox-Liste (Instrument/Bauteil/Holzart/Qualität).
/// Vorher: WarehouseScreenState._buildMultiSelectDropdown.
class MultiSelectDropdown extends StatelessWidget {
  const MultiSelectDropdown({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
  });

  final List<QueryDocumentSnapshot> options;
  final List<String> selectedValues;
  final void Function(List<String>) onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: options.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final code = data['code'] as String;
              final name = data['name'] as String;
              return CheckboxListTile(
                title: Text('$name ($code)'),
                value: selectedValues.contains(code),
                onChanged: (checked) {
                  final newSelection = List<String>.from(selectedValues);
                  if (checked ?? false) {
                    if (!newSelection.contains(code)) newSelection.add(code);
                  } else {
                    newSelection.remove(code);
                  }
                  onChanged(newSelection);
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}