// lib/user_management/role_editor_dialog.dart

import 'package:flutter/material.dart';
import '../services/icon_helper.dart';
import 'permission_service.dart';

class RoleEditorDialog extends StatefulWidget {
  final UserRole? role;

  const RoleEditorDialog({super.key, this.role});

  /// Zeigt den Editor als Dialog (Desktop) oder BottomSheet (Mobile)
  static void show(BuildContext context, {UserRole? role}) {
    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      showDialog(
        context: context,
        builder: (context) => RoleEditorDialog(role: role),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => RoleEditorDialog(role: role),
      );
    }
  }

  @override
  State<RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends State<RoleEditorDialog> {
  final _permissions = PermissionService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  late int _groupId;
  late Color _selectedColor;
  late String _selectedIcon;
  bool _isSaving = false;

  bool get _isNew => widget.role == null;
  bool get _isWideScreen => MediaQuery.of(context).size.width > 600;

  static const List<Color> _colors = [
    Color(0xFF757575),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFF8E24AA),
    Color(0xFFF57C00),
    Color(0xFFD32F2F),
    Color(0xFF00ACC1),
    Color(0xFF6D4C41),
  ];

  static const List<Map<String, dynamic>> _icons = [
    {'name': 'person', 'icon': Icons.person},
    {'name': 'badge', 'icon': Icons.badge},
    {'name': 'work', 'icon': Icons.work},
    {'name': 'engineering', 'icon': Icons.engineering},
    {'name': 'local_shipping', 'icon': Icons.local_shipping},
    {'name': 'inventory', 'icon': Icons.inventory},
    {'name': 'support_agent', 'icon': Icons.support_agent},
    {'name': 'admin_panel_settings', 'icon': Icons.admin_panel_settings},
    {'name': 'shield', 'icon': Icons.shield},
    {'name': 'star', 'icon': Icons.star},
    {'name': 'verified_user', 'icon': Icons.verified_user},
    {'name': 'supervisor_account', 'icon': Icons.supervisor_account},
  ];

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _groupId = _permissions.getNextAvailableGroupId();
      _selectedColor = _colors[0];
      _selectedIcon = 'person';
    } else {
      _groupId = widget.role!.groupId;
      _nameController.text = widget.role!.name;
      _descController.text = widget.role!.description;
      _selectedColor = widget.role!.color;
      _selectedIcon = widget.role!.iconName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final role = UserRole(
        groupId: _groupId,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        color: _selectedColor,
        iconName: _selectedIcon,
        isSystemRole: widget.role?.isSystemRole ?? false,
      );

      await _permissions.saveRole(role);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                getAdaptiveIcon(iconName: 'check_circle', defaultIcon: Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(_isNew ? 'Rolle erstellt' : 'Rolle aktualisiert'),
              ],
            ),
            backgroundColor: const Color(0xFF0F4A29),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isWideScreen ? _buildDialog() : _buildBottomSheet();
  }

  // ===== DESKTOP: DIALOG =====
  Widget _buildDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== MOBILE: BOTTOM SHEET =====
  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
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
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _selectedColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: getAdaptiveIcon(
                iconName: _selectedIcon,
                defaultIcon: Icons.person,
                color: _selectedColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isNew ? 'Neue Rolle erstellen' : 'Rolle bearbeiten',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group ID (nur bei neuer Rolle)
          if (_isNew) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'tag', defaultIcon: Icons.tag, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 12),
                  Text('Gruppen-ID: ', style: TextStyle(color: Colors.grey.shade600)),
                  Text('$_groupId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text('(automatisch)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Name
          TextFormField(
            controller: _nameController,
            enabled: !(widget.role?.isSystemRole ?? false),
            decoration: InputDecoration(
              labelText: 'Rollenname *',
              hintText: 'z.B. Lagerarbeiter',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.badge),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Name erforderlich' : null,
          ),
          const SizedBox(height: 16),

          // Beschreibung
          TextFormField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: 'Beschreibung',
              hintText: 'Kurze Beschreibung der Rolle',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.description),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Farbe
          const Text('Farbe', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors.map((color) {
              final isSelected = color.value == _selectedColor.value;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                    boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Icon
          const Text('Icon', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _icons.map((iconData) {
              final isSelected = iconData['name'] == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = iconData['name']),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? _selectedColor.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border.all(color: _selectedColor, width: 2) : null,
                  ),
                  child: Icon(
                    iconData['icon'] as IconData,
                    color: isSelected ? _selectedColor : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4A29),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isNew ? 'Erstellen' : 'Speichern'),
                ),
              ),
            ],
          ),

          // Extra padding für Mobile (wegen Keyboard)
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 0),
        ],
      ),
    );
  }
}