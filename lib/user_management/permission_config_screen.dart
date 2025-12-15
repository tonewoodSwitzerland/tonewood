// lib/user_management/permission_config_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';
import 'permission_service.dart';
import 'role_editor_dialog.dart';

class PermissionConfigScreen extends StatefulWidget {
  const PermissionConfigScreen({super.key});

  @override
  State<PermissionConfigScreen> createState() => _PermissionConfigScreenState();
}

class _PermissionConfigScreenState extends State<PermissionConfigScreen>
    with SingleTickerProviderStateMixin {
  final _permissions = PermissionService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _permissions.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: getAdaptiveIcon(
            iconName: 'arrow_back',
            defaultIcon: Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'security',
              defaultIcon: Icons.security,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            const Text('Administration'),
          ],
        ),
        backgroundColor: const Color(0xFF0F4A29),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Berechtigungen'),
            Tab(text: 'Rollen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PermissionsTab(),
          _RolesTab(),
        ],
      ),
    );
  }
}

// ===== BERECHTIGUNGEN TAB =====
class _PermissionsTab extends StatefulWidget {
  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  final _permissions = PermissionService();
  Map<String, int> _currentPermissions = {};
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    await _permissions.loadPermissions(forceReload: true);
    final perms = <String, int>{};
    for (final f in PermissionService.allFeatures) {
      perms[f.id] = _permissions.getMinRoleForFeature(f.id);
    }
    setState(() => _currentPermissions = perms);
  }

  Future<void> _saveAll() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('permissions')
          .set(_currentPermissions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                getAdaptiveIcon(iconName: 'check_circle', defaultIcon: Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Text('Berechtigungen gespeichert'),
              ],
            ),
            backgroundColor: const Color(0xFF0F4A29),
          ),
        );
        setState(() => _hasChanges = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<FeatureDefinition>>{};
    for (final f in PermissionService.allFeatures) {
      categories.putIfAbsent(f.category, () => []).add(f);
    }

    return StreamBuilder<List<UserRole>>(
      stream: _permissions.rolesStream,
      builder: (context, snapshot) {
        final roles = snapshot.data ?? _permissions.roles;

        return Column(
          children: [
            if (_hasChanges)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'warning', defaultIcon: Icons.warning, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Ungespeicherte Änderungen')),
                    ElevatedButton(
                      onPressed: _saveAll,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4A29)),
                      child: const Text('Speichern', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCategorySection('Bottom Navigation', categories['bottomNav'] ?? [], roles),
                  _buildCategorySection('Aufträge & Angebote', categories['drawer_orders'] ?? [], roles),
                  _buildCategorySection('Stammdaten', categories['drawer_masterdata'] ?? [], roles),
                  _buildCategorySection('Einstellungen', categories['drawer_settings'] ?? [], roles),
                  _buildCategorySection('AppBar Buttons', categories['appBar'] ?? [], roles),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySection(String title, List<FeatureDefinition> features, List<UserRole> roles) {
    if (features.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5),
          ),
        ),
        ...features.map((f) => _buildFeatureCard(f, roles)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFeatureCard(FeatureDefinition feature, List<UserRole> roles) {
    final currentMin = _currentPermissions[feature.id] ?? feature.defaultMinRole;
    final currentRole = _permissions.getRole(currentMin);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Center(child: getAdaptiveIcon(iconName: feature.iconName, defaultIcon: Icons.extension, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feature.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(feature.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: currentRole.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: currentRole.color.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: currentMin,
                  isDense: true,
                  items: roles.map((role) => DropdownMenuItem<int>(
                    value: role.groupId,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(color: role.color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: Center(child: Text('${role.groupId}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: role.color))),
                        ),
                        const SizedBox(width: 8),
                        Text(role.name, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() { _currentPermissions[feature.id] = v; _hasChanges = true; });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== ROLLEN TAB =====
class _RolesTab extends StatelessWidget {
  final _permissions = PermissionService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserRole>>(
      stream: _permissions.rolesStream,
      builder: (context, snapshot) {
        final roles = snapshot.data ?? _permissions.roles;
        final canAddRole = _permissions.getNextAvailableGroupId() > 0;

        return Column(
          children: [
            // Info-Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'System-Rollen (Mitarbeiter, Admin, SuperAdmin) können nicht gelöscht werden.',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: roles.length,
                itemBuilder: (context, index) => _buildRoleCard(context, roles[index]),
              ),
            ),
            // Add Button
            if (canAddRole)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRoleEditor(context, null),
                    icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add, color: Colors.white, size: 20),
                    label: const Text('Neue Rolle erstellen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4A29),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRoleCard(BuildContext context, UserRole role) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon mit Farbe
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: role.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Center(child: getAdaptiveIcon(iconName: role.iconName, defaultIcon: Icons.person, color: role.color, size: 24)),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(role.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                        child: Text('ID: ${role.groupId}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ),
                      if (role.isSystemRole) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text('System', style: TextStyle(fontSize: 10, color: Colors.orange.shade800)),
                        ),
                      ],
                    ],
                  ),
                  if (role.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(role.description, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ),
                ],
              ),
            ),
            // Actions
            IconButton(
              icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit, color: const Color(0xFF0F4A29), size: 20),
              onPressed: () => _showRoleEditor(context, role),
            ),
            if (!role.isSystemRole)
              IconButton(
                icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _confirmDeleteRole(context, role),
              ),
          ],
        ),
      ),
    );
  }

  void _showRoleEditor(BuildContext context, UserRole? role) {
    RoleEditorDialog.show(context, role: role);
  }

  Future<void> _confirmDeleteRole(BuildContext context, UserRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rolle löschen?'),
        content: Text('Möchtest du die Rolle "${role.name}" wirklich löschen?\n\nDies ist nur möglich, wenn keine Benutzer diese Rolle haben.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _permissions.deleteRole(role.groupId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Rolle gelöscht' : 'Löschen nicht möglich - Benutzer mit dieser Rolle vorhanden'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}