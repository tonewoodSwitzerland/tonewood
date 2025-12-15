import 'package:flutter/material.dart';
import '../../services/icon_helper.dart';

import 'customer_group.dart';
import 'customer_group_service.dart';

/// Wiederverwendbares Widget zur Auswahl von Kundengruppen
class CustomerGroupSelectionWidget extends StatefulWidget {
  final List<String> selectedGroupIds;
  final ValueChanged<List<String>> onChanged;
  final bool showLabel;
  final bool compact;

  const CustomerGroupSelectionWidget({
    Key? key,
    required this.selectedGroupIds,
    required this.onChanged,
    this.showLabel = true,
    this.compact = false,
  }) : super(key: key);

  @override
  State<CustomerGroupSelectionWidget> createState() => _CustomerGroupSelectionWidgetState();
}

class _CustomerGroupSelectionWidgetState extends State<CustomerGroupSelectionWidget> {
  List<CustomerGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await CustomerGroupService.getAllGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleGroup(String groupId) {
    final newSelection = List<String>.from(widget.selectedGroupIds);
    if (newSelection.contains(groupId)) {
      newSelection.remove(groupId);
    } else {
      newSelection.add(groupId);
    }
    widget.onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'info',
              defaultIcon: Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Keine Kundengruppen vorhanden. Erstelle zuerst Gruppen in der Kundenverwaltung.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'group',
                defaultIcon: Icons.group,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Kundengruppen',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.selectedGroupIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.selectedGroupIds.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _groups.map((group) {
            final isSelected = widget.selectedGroupIds.contains(group.id);
            return FilterChip(
              label: Text(
                group.name,
                style: TextStyle(
                  fontSize: widget.compact ? 12 : 14,
                  color: isSelected ? Colors.white : group.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _toggleGroup(group.id),
              backgroundColor: group.color.withOpacity(0.1),
              selectedColor: group.color,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected ? group.color : group.color.withOpacity(0.5),
                width: isSelected ? 2 : 1,
              ),
              padding: widget.compact
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Kompakte Version für Listen-Anzeige (nur Chips, keine Auswahl)
class CustomerGroupChips extends StatelessWidget {
  final List<String> groupIds;
  final bool wrap;
  final double? maxWidth;

  const CustomerGroupChips({
    Key? key,
    required this.groupIds,
    this.wrap = true,
    this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (groupIds.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<CustomerGroup>>(
      future: CustomerGroupService.getAllGroups(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final allGroups = snapshot.data!;
        final matchingGroups = allGroups
            .where((g) => groupIds.contains(g.id))
            .toList();

        if (matchingGroups.isEmpty) return const SizedBox.shrink();

        final chips = matchingGroups.map((group) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: group.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: group.color.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Text(
            group.name,
            style: TextStyle(
              fontSize: 11,
              color: group.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        )).toList();

        if (wrap) {
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: chips,
          );
        }

        return SizedBox(
          width: maxWidth,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips
                  .map((chip) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: chip,
              ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Dialog zur Gruppenauswahl (für Bulk-Aktionen)
class CustomerGroupSelectionDialog extends StatefulWidget {
  final List<String> initialSelection;
  final String title;
  final String? subtitle;

  const CustomerGroupSelectionDialog({
    Key? key,
    this.initialSelection = const [],
    this.title = 'Kundengruppen auswählen',
    this.subtitle,
  }) : super(key: key);

  static Future<List<String>?> show(
      BuildContext context, {
        List<String> initialSelection = const [],
        String title = 'Kundengruppen auswählen',
        String? subtitle,
      }) {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => CustomerGroupSelectionDialog(
        initialSelection: initialSelection,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<CustomerGroupSelectionDialog> createState() => _CustomerGroupSelectionDialogState();
}

class _CustomerGroupSelectionDialogState extends State<CustomerGroupSelectionDialog> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.subtitle != null) ...[
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            CustomerGroupSelectionWidget(
              selectedGroupIds: _selectedIds,
              onChanged: (ids) => setState(() => _selectedIds = ids),
              showLabel: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedIds),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}