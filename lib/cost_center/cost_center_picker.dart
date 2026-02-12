import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/icon_helper.dart';
import 'cost_center.dart';
import 'cost_center_sheet.dart';


/// Picker-Dialog / Sheet zur Auswahl einer Kostenstelle im SalesScreen.
///
/// Ersetzt die alten Methoden `_showCostCenterSelection()` und
/// `_showNewCostCenterDialog()` aus dem SalesScreen.
///
/// Verwendung im SalesScreen:
/// ```dart
/// CostCenterPicker.show(
///   context,
///   selectedCostCenterId: selectedCostCenter?.id,
///   onSelected: (costCenter) async {
///     await _saveTemporaryCostCenter(costCenter);
///   },
/// );
/// ```
class CostCenterPicker {
  static void show(
      BuildContext context, {
        String? selectedCostCenterId,
        required Future<void> Function(CostCenter costCenter) onSelected,
      }) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    if (isWide) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            child: _CostCenterPickerContent(
              isDialog: true,
              selectedCostCenterId: selectedCostCenterId,
              onSelected: onSelected,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _CostCenterPickerContent(
          isDialog: false,
          selectedCostCenterId: selectedCostCenterId,
          onSelected: onSelected,
        ),
      );
    }
  }
}

// ─── Interner Content ────────────────────────────────────────

class _CostCenterPickerContent extends StatefulWidget {
  final bool isDialog;
  final String? selectedCostCenterId;
  final Future<void> Function(CostCenter costCenter) onSelected;

  const _CostCenterPickerContent({
    required this.isDialog,
    this.selectedCostCenterId,
    required this.onSelected,
  });

  @override
  State<_CostCenterPickerContent> createState() =>
      _CostCenterPickerContentState();
}

class _CostCenterPickerContentState extends State<_CostCenterPickerContent> {
  final TextEditingController searchController = TextEditingController();
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1),
              _buildSearchBar(context),
              Expanded(child: _buildList(context)),
              _buildFooter(context),
            ],
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(context),
          const Divider(height: 1),
          _buildSearchBar(context),
          Expanded(child: _buildList(context)),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: getAdaptiveIcon(
              iconName: 'account_balance_wallet',
              defaultIcon: Icons.account_balance_wallet,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kostenstelle auswählen',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          labelText: 'Suchen',
          hintText: 'Code, Name oder Beschreibung...',
          prefixIcon: getAdaptiveIcon(
            iconName: 'search',
            defaultIcon: Icons.search,
          ),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          isDense: true,
          suffixIcon: _searchTerm.isNotEmpty
              ? IconButton(
            icon: getAdaptiveIcon(
                iconName: 'clear', defaultIcon: Icons.clear),
            onPressed: () {
              searchController.clear();
              setState(() => _searchTerm = '');
            },
          )
              : null,
        ),
        onChanged: (value) => setState(() => _searchTerm = value.toLowerCase()),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cost_centers')
          .orderBy('code')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCostCenters = snapshot.data?.docs
            .map((doc) => CostCenter.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ))
            .where((cc) => cc.isActive)
            .toList() ??
            [];

        final filtered = _searchTerm.isEmpty
            ? allCostCenters
            : allCostCenters.where((cc) {
          return cc.code.toLowerCase().contains(_searchTerm) ||
              cc.name.toLowerCase().contains(_searchTerm) ||
              cc.description.toLowerCase().contains(_searchTerm);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(
                  iconName: 'account_balance',
                  defaultIcon: Icons.account_balance,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchTerm.isNotEmpty
                      ? 'Keine Kostenstellen für "$_searchTerm" gefunden'
                      : 'Keine Kostenstellen vorhanden',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final costCenter = filtered[index];
            final isSelected =
                widget.selectedCostCenterId == costCenter.id;

            return Card(
              elevation: isSelected ? 2 : 0,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: isSelected
                    ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                )
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      costCenter.code.length >= 2
                          ? costCenter.code.substring(0, 2)
                          : costCenter.code,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  '${costCenter.code} - ${costCenter.name}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: costCenter.description.isNotEmpty
                    ? Text(
                  costCenter.description,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
                    : null,
                trailing: isSelected
                    ? getAdaptiveIcon(
                  iconName: 'check_circle',
                  defaultIcon: Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                )
                    : null,
                onTap: () async {
                  await widget.onSelected(costCenter);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Kostenstelle "${costCenter.code}" ausgewählt'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
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
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Abbrechen'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showNewCostCenterForm(context);
                },
                icon: getAdaptiveIcon(
                  iconName: 'add',
                  defaultIcon: Icons.add,
                  color: Colors.white,
                ),
                label: const Text('Neue Kostenstelle'),
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
    );
  }

  void _showNewCostCenterForm(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    if (isWide) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 640, maxHeight: 720),
            child: const CostCenterFormContent(
              costCenter: null,
              isDialog: true,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const CostCenterFormContent(
          costCenter: null,
          isDialog: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}