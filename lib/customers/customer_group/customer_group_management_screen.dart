import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/icon_helper.dart';
import '../customer.dart';

import 'customer_group.dart';
import 'customer_group_service.dart';


class CustomerGroupManagementScreen extends StatefulWidget {
  const CustomerGroupManagementScreen({Key? key}) : super(key: key);

  @override
  State<CustomerGroupManagementScreen> createState() => _CustomerGroupManagementScreenState();
}

class _CustomerGroupManagementScreenState extends State<CustomerGroupManagementScreen> {
  Map<String, int> _customerCounts = {};
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerCounts();
  }

  Future<void> _loadCustomerCounts() async {
    setState(() => _isLoadingCounts = true);
    try {
      final counts = await CustomerGroupService.getCustomerCountPerGroup();
      if (mounted) {
        setState(() {
          _customerCounts = counts;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kundengruppen'),
        actions: [
          IconButton(
            icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
            onPressed: () => _showGroupSheet(),
            tooltip: 'Neue Gruppe',
          ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'refresh', defaultIcon: Icons.refresh),
            onPressed: _loadCustomerCounts,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: StreamBuilder<List<CustomerGroup>>(
        stream: CustomerGroupService.getGroupsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getAdaptiveIcon(iconName: 'error', defaultIcon: Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Fehler: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            );
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadCustomerCounts,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final customerCount = _customerCounts[group.id] ?? 0;
                return _buildGroupCard(group, customerCount);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          getAdaptiveIcon(
            iconName: 'group_add',
            defaultIcon: Icons.group_add,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Keine Kundengruppen vorhanden',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Erstelle Gruppen um Kunden zu kategorisieren',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeDefaultGroups,
            icon: getAdaptiveIcon(iconName: 'auto_fix_high', defaultIcon: Icons.auto_fix_high),
            label: const Text('Standardgruppen erstellen'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(CustomerGroup group, int customerCount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showGroupCustomers(group),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: group.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    group.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (group.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'people',
                          defaultIcon: Icons.people,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isLoadingCounts
                              ? '...'
                              : '$customerCount ${customerCount == 1 ? 'Kunde' : 'Kunden'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showGroupSheet(group: group);
                      break;
                    case 'copy_emails':
                      _copyEmailsToClipboard(group);
                      break;
                    case 'view_customers':
                      _showGroupCustomers(group);
                      break;
                    case 'delete':
                      _confirmDeleteGroup(group);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view_customers',
                    child: Row(
                      children: [
                        getAdaptiveIcon(iconName: 'people', defaultIcon: Icons.people, size: 20),
                        const SizedBox(width: 12),
                        const Text('Kunden anzeigen'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy_emails',
                    child: Row(
                      children: [
                        getAdaptiveIcon(iconName: 'email', defaultIcon: Icons.email, size: 20),
                        const SizedBox(width: 12),
                        const Text('E-Mails kopieren'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit, size: 20),
                        const SizedBox(width: 12),
                        const Text('Bearbeiten'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        const Text('Löschen', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeDefaultGroups() async {
    try {
      await CustomerGroupService.initializeDefaultGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Standardgruppen wurden erstellt'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCustomerCounts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showGroupSheet({CustomerGroup? group}) async {
    final isEditing = group != null;
    final nameController = TextEditingController(text: group?.name ?? '');
    final descController = TextEditingController(text: group?.description ?? '');
    String selectedColor = group?.colorHex ?? CustomerGroup.availableColors.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${selectedColor.replaceAll('#', '')}', radix: 16)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: getAdaptiveIcon(
                            iconName: isEditing ? 'edit' : 'add',
                            defaultIcon: isEditing ? Icons.edit : Icons.add,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing ? 'Gruppe bearbeiten' : 'Neue Gruppe',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Name *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Color(int.parse('FF${selectedColor.replaceAll('#', '')}', radix: 16)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          autofocus: !isEditing,
                        ),

                        const SizedBox(height: 16),

                        // Beschreibung
                        TextField(
                          controller: descController,
                          decoration: InputDecoration(
                            labelText: 'Beschreibung (optional)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          maxLines: 2,
                        ),

                        const SizedBox(height: 24),

                        // Farbauswahl
                        Text(
                          'Farbe auswählen',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Farben als Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                          itemCount: CustomerGroup.availableColors.length,
                          itemBuilder: (context, index) {
                            final colorHex = CustomerGroup.availableColors[index];
                            final color = Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));
                            final isSelected = selectedColor == colorHex;

                            return GestureDetector(
                              onTap: () => setState(() => selectedColor = colorHex),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                                      : null,
                                  boxShadow: isSelected
                                      ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                                    : null,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Bitte Name eingeben')),
                                );
                                return;
                              }

                              try {
                                if (isEditing) {
                                  await CustomerGroupService.updateGroup(group!.copyWith(
                                    name: nameController.text.trim(),
                                    description: descController.text.trim(),
                                    colorHex: selectedColor,
                                  ));
                                } else {
                                  await CustomerGroupService.createGroup(CustomerGroup(
                                    id: '',
                                    name: nameController.text.trim(),
                                    description: descController.text.trim(),
                                    colorHex: selectedColor,
                                    sortOrder: DateTime.now().millisecondsSinceEpoch,
                                  ));
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEditing ? 'Gruppe aktualisiert' : 'Gruppe erstellt'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            icon: getAdaptiveIcon(
                              iconName: 'save',
                              defaultIcon: Icons.save,
                              color: Colors.white,
                            ),
                            label: Text(isEditing ? 'Speichern' : 'Erstellen'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _copyEmailsToClipboard(CustomerGroup group) async {
    try {
      final count = await CustomerGroupService.copyEmailsToClipboard(group.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count E-Mail-Adressen in Zwischenablage kopiert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showGroupCustomers(CustomerGroup group) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GroupCustomersSheet(group: group),
    );
  }

  Future<void> _confirmDeleteGroup(CustomerGroup group) async {
    final customerCount = _customerCounts[group.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppe löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie die Gruppe "${group.name}" wirklich löschen?'),
            if (customerCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$customerCount Kunden sind dieser Gruppe zugeordnet. Die Zuordnung wird entfernt.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CustomerGroupService.deleteGroup(group.id);
        _loadCustomerCounts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gruppe gelöscht'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// Bottom Sheet für Kunden einer Gruppe
class _GroupCustomersSheet extends StatelessWidget {
  final CustomerGroup group;

  const _GroupCustomersSheet({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: group.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      group.name.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (group.description?.isNotEmpty == true)
                        Text(
                          group.description!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final count = await CustomerGroupService.copyEmailsToClipboard(group.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$count E-Mails kopiert'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  icon: getAdaptiveIcon(iconName: 'email', defaultIcon: Icons.email),
                  tooltip: 'E-Mails kopieren',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: CustomerGroupService.getCustomersInGroupStream(group.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customers = snapshot.data ?? [];

                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        getAdaptiveIcon(
                          iconName: 'people_outline',
                          defaultIcon: Icons.people_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('Keine Kunden in dieser Gruppe'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: group.color.withOpacity(0.2),
                          child: Text(
                            customer.company.isNotEmpty
                                ? customer.company.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(color: group.color, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          customer.company.isNotEmpty ? customer.company : customer.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(customer.email),
                        trailing: IconButton(
                          icon: getAdaptiveIcon(
                            iconName: 'remove_circle_outline',
                            defaultIcon: Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            await CustomerGroupService.removeCustomersFromGroup(
                              [customer.id],
                              group.id,
                            );
                          },
                          tooltip: 'Aus Gruppe entfernen',
                        ),
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
}