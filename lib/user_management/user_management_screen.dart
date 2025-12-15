// lib/user_management/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';
import 'permission_service.dart';

class UserManagementScreen extends StatefulWidget {
  final int currentUserGroup;

  const UserManagementScreen({
    super.key,
    required this.currentUserGroup,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _permissions = PermissionService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _permissions.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

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
              iconName: 'manage_accounts',
              defaultIcon: Icons.manage_accounts,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            const Text('Benutzerverwaltung'),
          ],
        ),
        backgroundColor: const Color(0xFF0F4A29),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<UserRole>>(
        stream: _permissions.rolesStream,
        builder: (context, rolesSnapshot) {
          final roles = rolesSnapshot.data ?? _permissions.roles;

          return isWideScreen
              ? _buildDesktopLayout(roles)
              : _buildMobileLayout(roles);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(List<UserRole> roles) {
    return Row(
      children: [
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoleInfoCard(roles),
              const SizedBox(height: 16),
              _buildRoleLegend(roles),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildUserList(roles)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<UserRole> roles) {
    return Column(
      children: [
        _buildSearchBar(),
        _buildRoleInfoCardCompact(roles),
        Expanded(child: _buildUserList(roles)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Benutzer suchen...',
          prefixIcon: getAdaptiveIcon(
            iconName: 'search',
            defaultIcon: Icons.search,
            color: Colors.grey,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: getAdaptiveIcon(
              iconName: 'close',
              defaultIcon: Icons.close,
              color: Colors.grey,
            ),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      ),
    );
  }

  Widget _buildRoleInfoCard(List<UserRole> roles) {
    final assignable = _permissions.getAssignableRoles(widget.currentUserGroup);
    final currentRole = _permissions.getRole(widget.currentUserGroup);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'admin_panel_settings',
                defaultIcon: Icons.admin_panel_settings,
                color: const Color(0xFF0F4A29),
              ),
              const SizedBox(width: 8),
              const Text(
                'Deine Rechte',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Deine Rolle:', currentRole.name),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Kannst vergeben:',
            assignable.map((r) => r.name).join(', '),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleInfoCardCompact(List<UserRole> roles) {
    final assignable = _permissions.getAssignableRoles(widget.currentUserGroup);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(
            iconName: 'info',
            defaultIcon: Icons.info_outline,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Rollen vergeben: ${assignable.map((r) => r.name).join(", ")}',
              style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleLegend(List<UserRole> roles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'list',
                defaultIcon: Icons.list,
                color: const Color(0xFF0F4A29),
              ),
              const SizedBox(width: 8),
              const Text(
                'Rollen-Übersicht',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...roles.map((role) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: role.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: getAdaptiveIcon(
                      iconName: role.iconName,
                      defaultIcon: Icons.person,
                      color: role.color,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(role.name)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ID: ${role.groupId}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildUserList(List<UserRole> roles) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                getAdaptiveIcon(
                  iconName: 'people',
                  defaultIcon: Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Keine Benutzer gefunden',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        if (users.isEmpty) {
          return Center(
            child: Text(
              'Keine Treffer für "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) => _buildUserCard(users[index], roles),
        );
      },
    );
  }

  Widget _buildUserCard(DocumentSnapshot userDoc, List<UserRole> roles) {
    final data = userDoc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unbekannt';
    final email = data['email'] ?? '';
    final userGroup = data['userGroup'] as int? ?? 1;
    final photoUrl = data['photoUrl'] as String?;
    final role = _permissions.getRole(userGroup);
    final canEdit = _permissions.canEditUser(widget.currentUserGroup, userGroup);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: role.color.withOpacity(0.2),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  color: role.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: role.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  getAdaptiveIcon(
                    iconName: role.iconName,
                    defaultIcon: Icons.person,
                    color: role.color,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    role.name,
                    style: TextStyle(
                      color: role.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (canEdit)
              IconButton(
                icon: getAdaptiveIcon(
                  iconName: 'edit',
                  defaultIcon: Icons.edit,
                  color: const Color(0xFF0F4A29),
                  size: 20,
                ),
                onPressed: () => _showEditRoleDialog(userDoc.id, name, userGroup, roles),
              )
            else
              SizedBox(
                width: 40,
                child: getAdaptiveIcon(
                  iconName: 'lock',
                  defaultIcon: Icons.lock_outline,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditRoleDialog(String userId, String userName, int currentRoleId, List<UserRole> allRoles) {
    final assignableRoles = _permissions.getAssignableRoles(widget.currentUserGroup);
    int selectedRoleId = currentRoleId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'edit',
                defaultIcon: Icons.edit,
                color: const Color(0xFF0F4A29),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Rolle ändern: $userName')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: assignableRoles.map((role) {
              final isSelected = selectedRoleId == role.groupId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<int>(
                  value: role.groupId,
                  groupValue: selectedRoleId,
                  onChanged: (v) => setDialogState(() => selectedRoleId = v!),
                  title: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: role.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: getAdaptiveIcon(
                            iconName: role.iconName,
                            defaultIcon: Icons.person,
                            color: role.color,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(role.name),
                    ],
                  ),
                  activeColor: const Color(0xFF0F4A29),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF0F4A29) : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: selectedRoleId != currentRoleId
                  ? () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({'userGroup': selectedRoleId});
                if (context.mounted) Navigator.pop(context);
                _showSuccessSnackbar(userName, selectedRoleId);
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4A29),
                foregroundColor: Colors.white,
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String userName, int newRoleId) {
    final role = _permissions.getRole(newRoleId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'check_circle',
              defaultIcon: Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text('$userName ist jetzt ${role.name}'),
          ],
        ),
        backgroundColor: const Color(0xFF0F4A29),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}