import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/icon_helper.dart';
import 'cost_center.dart';
import 'cost_center_sheet.dart';


/// Hauptscreen für die Kostenstellenverwaltung
class CostCenterManagementScreen extends StatefulWidget {
  const CostCenterManagementScreen({Key? key}) : super(key: key);

  @override
  CostCenterManagementScreenState createState() =>
      CostCenterManagementScreenState();
}

class CostCenterManagementScreenState
    extends State<CostCenterManagementScreen> {
  final TextEditingController searchController = TextEditingController();
  String _filterStatus = 'all'; // 'all', 'active', 'inactive'

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 700;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kostenstellen'),
        actions: [
          PopupMenuButton<String>(
            icon: getAdaptiveIcon(
              iconName: 'filter_list',
              defaultIcon: Icons.filter_list,
            ),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _filterStatus = value),
            itemBuilder: (context) => [
              _buildFilterMenuItem('all', 'Alle anzeigen'),
              _buildFilterMenuItem('active', 'Nur aktive'),
              _buildFilterMenuItem('inactive', 'Nur inaktive'),
            ],
          ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
            tooltip: 'Neue Kostenstelle',
            onPressed: () => _showCostCenterForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Suchleiste
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Kostenstelle suchen',
                hintText: 'Nach Code, Name oder Beschreibung suchen...',
                prefixIcon: getAdaptiveIcon(
                  iconName: 'search',
                  defaultIcon: Icons.search,
                ),
                border: const OutlineInputBorder(),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'clear',
                    defaultIcon: Icons.clear,
                  ),
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          // Filter-Info Chip
          if (_filterStatus != 'all')
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      _filterStatus == 'active'
                          ? 'Nur aktive'
                          : 'Nur inaktive',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: getAdaptiveIcon(
                      iconName: 'close',
                      defaultIcon: Icons.close,
                      size: 16,
                    ),
                    onDeleted: () => setState(() => _filterStatus = 'all'),
                    backgroundColor: _filterStatus == 'active'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                  ),
                ],
              ),
            ),

          // Liste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cost_centers')
                  .orderBy('code')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Fehler: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final searchTerm = searchController.text.toLowerCase();

                final filtered = docs.where((doc) {
                  final cc = CostCenter.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                  if (_filterStatus == 'active' && !cc.isActive) return false;
                  if (_filterStatus == 'inactive' && cc.isActive) return false;
                  if (searchTerm.isEmpty) return true;
                  return cc.code.toLowerCase().contains(searchTerm) ||
                      cc.name.toLowerCase().contains(searchTerm) ||
                      cc.description.toLowerCase().contains(searchTerm);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        getAdaptiveIcon(
                          iconName: 'account_balance_wallet',
                          defaultIcon: Icons.account_balance_wallet,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchTerm.isNotEmpty
                              ? 'Keine Kostenstellen für "$searchTerm" gefunden'
                              : 'Keine Kostenstellen vorhanden',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                        if (searchTerm.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showCostCenterForm(context),
                            icon: getAdaptiveIcon(
                              iconName: 'add',
                              defaultIcon: Icons.add,
                              color: Colors.white,
                            ),
                            label: const Text('Erste Kostenstelle anlegen'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final activeCount = filtered.where((doc) {
                  final cc = CostCenter.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                  return cc.isActive;
                }).length;
                final inactiveCount = filtered.length - activeCount;

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _buildStatChip(context, '${filtered.length}',
                              'Gesamt', Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 16),
                          _buildStatChip(
                              context, '$activeCount', 'Aktiv', Colors.green),
                          const SizedBox(width: 16),
                          _buildStatChip(context, '$inactiveCount', 'Inaktiv',
                              Colors.orange),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final cc = CostCenter.fromMap(
                            doc.data() as Map<String, dynamic>,
                            doc.id,
                          );
                          return _buildCostCenterCard(context, cc);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      BuildContext context, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCostCenterCard(BuildContext context, CostCenter cc) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cc.isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              cc.code.length > 3 ? cc.code.substring(0, 3) : cc.code,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: cc.isActive
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Colors.grey,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(cc.name, overflow: TextOverflow.ellipsis)),
            if (!cc.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'INAKTIV',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Code: ${cc.code}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (cc.description.isNotEmpty)
              Text(
                cc.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        isThreeLine: cc.description.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () => _showCostCenterForm(context, costCenter: cc),
            ),
            IconButton(
              icon: getAdaptiveIcon(
                  iconName: 'delete', defaultIcon: Icons.delete),
              tooltip: 'Löschen',
              onPressed: () => _showDeleteDialog(cc),
            ),
          ],
        ),
        onTap: () => _showCostCenterDetails(context, cc),
      ),
    );
  }

  // ─── Navigation ───────────────────────────────────────────

  void _showCostCenterForm(BuildContext context, {CostCenter? costCenter}) {
    if (_isWideScreen(context)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 640, maxHeight: 720),
            child: CostCenterFormContent(
                costCenter: costCenter, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            CostCenterFormContent(costCenter: costCenter, isDialog: false),
      );
    }
  }

  void _showCostCenterDetails(BuildContext context, CostCenter cc) {
    if (_isWideScreen(context)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 560, maxHeight: 600),
            child: CostCenterDetailsContent(
              costCenter: cc,
              isDialog: true,
              onEdit: () {
                Navigator.pop(context);
                _showCostCenterForm(context, costCenter: cc);
              },
              onDelete: () {
                Navigator.pop(context);
                _showDeleteDialog(cc);
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CostCenterDetailsContent(
          costCenter: cc,
          isDialog: false,
          onEdit: () {
            Navigator.pop(context);
            _showCostCenterForm(context, costCenter: cc);
          },
          onDelete: () {
            Navigator.pop(context);
            _showDeleteDialog(cc);
          },
        ),
      );
    }
  }

  void _showDeleteDialog(CostCenter cc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kostenstelle löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Möchtest du die folgende Kostenstelle wirklich löschen?',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            _buildDeleteDetailRow('Code', cc.code),
            _buildDeleteDetailRow('Name', cc.name),
            if (cc.description.isNotEmpty)
              _buildDeleteDetailRow('Beschreibung', cc.description),
            _buildDeleteDetailRow(
                'Erstellt am', DateFormat('dd.MM.yyyy').format(cc.createdAt)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'warning',
                    defaultIcon: Icons.warning_amber_rounded,
                    size: 20,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alternativ kannst du die Kostenstelle als inaktiv markieren, um sie zu behalten.',
                      style:
                      TextStyle(fontSize: 12, color: Colors.orange[700]),
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
          if (cc.isActive)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('cost_centers')
                      .doc(cc.id)
                      .update({'isActive': false});
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kostenstelle als inaktiv markiert'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Fehler: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: getAdaptiveIcon(
                  iconName: 'visibility_off',
                  defaultIcon: Icons.visibility_off),
              label: const Text('Deaktivieren'),
            ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('cost_centers')
                    .doc(cc.id)
                    .delete();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kostenstelle erfolgreich gelöscht'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Fehler beim Löschen: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: getAdaptiveIcon(
                iconName: 'delete', defaultIcon: Icons.delete),
            label: const Text('Endgültig löschen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_filterStatus == value)
            getAdaptiveIcon(
              iconName: 'check',
              defaultIcon: Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            )
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}