// lib/home/settings_form.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants.dart';
import '../authenticate/login_screen.dart';
import '../services/auth.dart';
import '../services/icon_helper.dart';
import '../user_management/permission_service.dart';
import '../user_management/user_management_screen.dart';

class SettingsForm extends StatefulWidget {
  const SettingsForm({
    super.key,
    required this.kIsWebTemp,
    required this.dialogContextBox,
    required this.contextApp,
  });

  final bool kIsWebTemp;
  final BuildContext dialogContextBox;
  final BuildContext contextApp;

  /// Zeigt das Settings-Panel als BottomSheet (Mobile) oder Dialog (Desktop)
  static void show(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    if (isWideScreen) {
      // Desktop: Dialog
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
            child: SettingsForm(
              kIsWebTemp: kIsWeb,
              dialogContextBox: dialogContext,
              contextApp: context,
            ),
          ),
        ),
      );
    } else {
      // Mobile: BottomSheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
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
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SettingsForm(
                      kIsWebTemp: kIsWeb,
                      dialogContextBox: sheetContext,
                      contextApp: context,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  SettingsFormState createState() => SettingsFormState();
}

class SettingsFormState extends State<SettingsForm> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _permissions = PermissionService();
  final _nameController = TextEditingController();

  PackageInfo? _packageInfo;
  bool _isEditingName = false;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _packageInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final userGroup = userData?['userGroup'] as int? ?? 1;
          final userName = userData?['name'] as String? ?? '';
          final userEmail = userData?['email'] as String? ?? user.email ?? '';
          final photoUrl = userData?['photoUrl'] as String? ?? '';
          final role = _permissions.getRole(userGroup);

          // Name Controller initialisieren
          if (!_isEditingName && _nameController.text != userName) {
            _nameController.text = userName;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'settings',
                    defaultIcon: Icons.settings,
                    color: const Color(0xFF0F4A29),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Profil & Einstellungen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F4A29),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'v${_packageInfo?.version ?? ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // User Info Card
              _buildUserInfoCard(
                userId: user.uid,
                userName: userName,
                userEmail: userEmail,
                photoUrl: photoUrl,
                role: role,
              ),
              const SizedBox(height: 16),

              // Admin-Bereich
              if (_permissions.canManageUsers(userGroup))
                _buildAdminSection(userGroup),

              // Logout Button
              _buildLogoutButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserInfoCard({
    required String userId,
    required String userName,
    required String userEmail,
    required String photoUrl,
    required UserRole role,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + Name Row
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 32,
                  backgroundColor: role.color.withOpacity(0.2),
                  backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: role.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 16),

                // Name + Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Anzeigename mit Edit-Button
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName.isNotEmpty ? userName : 'Kein Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!_isEditingName)
                            IconButton(
                              icon: getAdaptiveIcon(
                                iconName: 'edit',
                                defaultIcon: Icons.edit,
                                color: Colors.grey.shade600,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _isEditingName = true),
                              tooltip: 'Name ändern',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // E-Mail
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Edit-Feld (eigene Zeile)
            if (_isEditingName) ...[
              const SizedBox(height: 16),
              _buildNameEditField(userId),
            ],
            const SizedBox(height: 16),

            // Rollen-Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: role.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  getAdaptiveIcon(
                    iconName: role.iconName,
                    defaultIcon: Icons.person,
                    color: role.color,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    role.name,
                    style: TextStyle(
                      color: role.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameDisplay(String userName) {
    return Row(
      children: [
        Expanded(
          child: Text(
            userName.isNotEmpty ? userName : 'Kein Name',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: getAdaptiveIcon(
            iconName: 'edit',
            defaultIcon: Icons.edit,
            color: Colors.grey.shade600,
            size: 18,
          ),
          onPressed: () {
            setState(() => _isEditingName = true);
          },
          tooltip: 'Name ändern',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(8),
        ),
      ],
    );
  }

  Widget _buildNameEditField(String userId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anzeigename ändern',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Neuer Anzeigename',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0F4A29), width: 2),
              ),
            ),
            onSubmitted: (_) => _saveName(userId),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditingName = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSavingName ? null : () => _saveName(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4A29),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSavingName
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Speichern'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveName(String userId) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name darf nicht leer sein')),
      );
      return;
    }

    setState(() => _isSavingName = true);

    try {
      await _db.collection('users').doc(userId).update({'name': newName});
      setState(() {
        _isEditingName = false;
        _isSavingName = false;
      });
      if (mounted) {
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
                const Text('Name gespeichert'),
              ],
            ),
            backgroundColor: const Color(0xFF0F4A29),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSavingName = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  Widget _buildAdminSection(int userGroup) {
    return Column(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.pop(widget.dialogContextBox);
              Navigator.push(
                widget.contextApp,
                MaterialPageRoute(
                  builder: (_) => UserManagementScreen(
                    currentUserGroup: userGroup,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: getAdaptiveIcon(
                      iconName: 'manage_accounts',
                      defaultIcon: Icons.manage_accounts,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Benutzerverwaltung',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Rollen und Berechtigungen verwalten',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  getAdaptiveIcon(
                    iconName: 'chevron_right',
                    defaultIcon: Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: _logout,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAppColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          getAdaptiveIcon(
            iconName: 'logout',
            defaultIcon: Icons.logout,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Text(
            'Abmelden',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final authService = AuthService();
    await authService.signOut();
    final pref = await SharedPreferences.getInstance();
    pref.setBool("isLogin", false);
    if (mounted) {
      Navigator.pop(widget.dialogContextBox);
      Navigator.pushNamedAndRemoveUntil(
        widget.contextApp,
        LoginScreen.id,
            (route) => false,
      );
    }
  }

  Color _getRoleColor(UserRole role) => role.color;
}