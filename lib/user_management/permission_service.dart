// lib/user_management/permission_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Dynamische Rolle aus Firestore
class UserRole {
  final int groupId;
  final String name;
  final String description;
  final Color color;
  final String iconName;
  final bool isSystemRole; // Kann nicht gelöscht werden

  const UserRole({
    required this.groupId,
    required this.name,
    this.description = '',
    this.color = Colors.grey,
    this.iconName = 'person',
    this.isSystemRole = false,
  });

  factory UserRole.fromFirestore(Map<String, dynamic> data, int groupId) {
    return UserRole(
      groupId: groupId,
      name: data['name'] ?? 'Unbenannt',
      description: data['description'] ?? '',
      color: Color(data['color'] ?? Colors.grey.value),
      iconName: data['iconName'] ?? 'person',
      isSystemRole: data['isSystemRole'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'color': color.value,
      'iconName': iconName,
      'isSystemRole': isSystemRole,
    };
  }

  // Default-Rollen als Fallback
  static const List<UserRole> defaultRoles = [
    UserRole(
      groupId: 1,
      name: 'Mitarbeiter',
      description: 'Basis-Zugriff auf Lager und Produktion',
      color: Color(0xFF757575),
      iconName: 'person',
      isSystemRole: true,
    ),
    UserRole(
      groupId: 5,
      name: 'Büro',
      description: 'Erweiterter Zugriff auf Verwaltung',
      color: Color(0xFF1E88E5),
      iconName: 'badge',
      isSystemRole: false,
    ),
    UserRole(
      groupId: 9,
      name: 'Admin',
      description: 'Benutzerverwaltung und Konfiguration',
      color: Color(0xFFF57C00),
      iconName: 'admin_panel_settings',
      isSystemRole: true,
    ),
    UserRole(
      groupId: 10,
      name: 'SuperAdmin',
      description: 'Vollzugriff auf alle Funktionen',
      color: Color(0xFFD32F2F),
      iconName: 'shield',
      isSystemRole: true,
    ),
  ];
}

/// Feature-Definition
class FeatureDefinition {
  final String id;
  final String name;
  final String description;
  final String category;
  final String iconName;
  final int defaultMinRole;

  const FeatureDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconName,
    this.defaultMinRole = 1,
  });
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final _db = FirebaseFirestore.instance;

  // Caches
  List<UserRole>? _rolesCache;
  Map<String, int>? _permissionsCache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  // ===== FEATURE DEFINITIONEN =====
  static const List<FeatureDefinition> allFeatures = [
    // Bottom Navigation
    FeatureDefinition(
      id: 'nav_warehouse',
      name: 'Lager',
      description: 'Lagerverwaltung und Bestandsübersicht',
      category: 'bottomNav',
      iconName: 'warehouse',
      defaultMinRole: 1,
    ),
    FeatureDefinition(
      id: 'nav_product',
      name: 'Produkt',
      description: 'Produktverwaltung und -bearbeitung',
      category: 'bottomNav',
      iconName: 'precision_manufacturing',
      defaultMinRole: 1,
    ),
    FeatureDefinition(
      id: 'nav_sales',
      name: 'Verkauf',
      description: 'Verkaufsübersicht',
      category: 'bottomNav',
      iconName: 'shopping_cart',
      defaultMinRole: 1,
    ),
    FeatureDefinition(
      id: 'nav_barcodes',
      name: 'Barcodes',
      description: 'Barcode-Druck und -Verwaltung',
      category: 'bottomNav',
      iconName: 'print',
      defaultMinRole: 1,
    ),
    FeatureDefinition(
      id: 'nav_analytics',
      name: 'Analyse',
      description: 'Statistiken und Auswertungen',
      category: 'bottomNav',
      iconName: 'analytics',
      defaultMinRole: 5,
    ),
    // Drawer - Aufträge
    FeatureDefinition(
      id: 'drawer_quotes',
      name: 'Angebote',
      description: 'Angebotsverwaltung',
      category: 'drawer_orders',
      iconName: 'request_quote',
      defaultMinRole: 5,
    ),
    FeatureDefinition(
      id: 'drawer_orders',
      name: 'Aufträge',
      description: 'Auftragsverwaltung',
      category: 'drawer_orders',
      iconName: 'shopping_bag',
      defaultMinRole: 5,
    ),
    // Drawer - Stammdaten
    FeatureDefinition(
      id: 'drawer_customers',
      name: 'Kundenverwaltung',
      description: 'Kunden anlegen und bearbeiten',
      category: 'drawer_masterdata',
      iconName: 'people',
      defaultMinRole: 5,
    ),
    FeatureDefinition(
      id: 'drawer_std_products',
      name: 'Standardprodukte',
      description: 'Standardprodukte verwalten',
      category: 'drawer_masterdata',
      iconName: 'inventory',
      defaultMinRole: 5,
    ),
    FeatureDefinition(
      id: 'drawer_std_packages',
      name: 'Standardpakete',
      description: 'Standardpakete verwalten',
      category: 'drawer_masterdata',
      iconName: 'inventory_2',
      defaultMinRole: 5,
    ),
    // Drawer - Einstellungen
    FeatureDefinition(
      id: 'drawer_texts',
      name: 'Standardtexte',
      description: 'Textvorlagen bearbeiten',
      category: 'drawer_settings',
      iconName: 'text_fields',
      defaultMinRole: 5,
    ),
    FeatureDefinition(
      id: 'drawer_pdf',
      name: 'PDF Einstellungen',
      description: 'PDF-Vorlagen konfigurieren',
      category: 'drawer_settings',
      iconName: 'picture_as_pdf',
      defaultMinRole: 5,
    ),
    // AppBar
    FeatureDefinition(
      id: 'appbar_settings',
      name: 'Einstellungen-Button',
      description: 'Schnellzugriff auf Einstellungen',
      category: 'appBar',
      iconName: 'settings',
      defaultMinRole: 5,
    ),
    FeatureDefinition(
      id: 'appbar_usermgmt',
      name: 'Benutzerverwaltung-Button',
      description: 'Schnellzugriff auf Benutzerverwaltung',
      category: 'appBar',
      iconName: 'manage_accounts',
      defaultMinRole: 9,
    ),
  ];

  // ===== ROLLEN LADEN =====

  Future<void> loadRoles({bool forceReload = false}) async {
    if (!forceReload && _rolesCache != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) return;
    }

    try {
      final doc = await _db.collection('settings').doc('roles').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _rolesCache = data.entries.map((e) {
          final groupId = int.tryParse(e.key) ?? 1;
          return UserRole.fromFirestore(e.value as Map<String, dynamic>, groupId);
        }).toList()
          ..sort((a, b) => a.groupId.compareTo(b.groupId));
      } else {
        _rolesCache = List.from(UserRole.defaultRoles);
        // Defaults in Firestore speichern
        await _saveDefaultRoles();
      }
      _cacheTime = DateTime.now();
    } catch (e) {
      print('Error loading roles: $e');
      _rolesCache = List.from(UserRole.defaultRoles);
    }
  }

  Future<void> _saveDefaultRoles() async {
    final Map<String, dynamic> rolesData = {};
    for (final role in UserRole.defaultRoles) {
      rolesData['${role.groupId}'] = role.toFirestore();
    }
    await _db.collection('settings').doc('roles').set(rolesData);
  }

  /// Stream für Live-Updates der Rollen
  Stream<List<UserRole>> get rolesStream {
    return _db.collection('settings').doc('roles').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _rolesCache = data.entries.map((e) {
          final groupId = int.tryParse(e.key) ?? 1;
          return UserRole.fromFirestore(e.value as Map<String, dynamic>, groupId);
        }).toList()
          ..sort((a, b) => a.groupId.compareTo(b.groupId));
        _cacheTime = DateTime.now();
        return _rolesCache!;
      }
      return List.from(UserRole.defaultRoles);
    });
  }

  /// Alle Rollen abrufen (cached)
  List<UserRole> get roles => _rolesCache ?? UserRole.defaultRoles;

  /// Rolle nach GroupId
  UserRole getRole(int? groupId) {
    final roles = _rolesCache ?? UserRole.defaultRoles;
    return roles.firstWhere(
          (r) => r.groupId == groupId,
      orElse: () => roles.first,
    );
  }

  /// Rolle speichern/aktualisieren
  Future<void> saveRole(UserRole role) async {
    await _db.collection('settings').doc('roles').set(
      {'${role.groupId}': role.toFirestore()},
      SetOptions(merge: true),
    );
    await loadRoles(forceReload: true);
  }

  /// Rolle löschen (nur wenn nicht System-Rolle)
  Future<bool> deleteRole(int groupId) async {
    final role = getRole(groupId);
    if (role.isSystemRole) return false;

    // Prüfen ob User diese Rolle haben
    final usersWithRole = await _db
        .collection('users')
        .where('userGroup', isEqualTo: groupId)
        .limit(1)
        .get();

    if (usersWithRole.docs.isNotEmpty) return false;

    await _db.collection('settings').doc('roles').update({
      '$groupId': FieldValue.delete(),
    });
    await loadRoles(forceReload: true);
    return true;
  }

  /// Nächste freie GroupId finden
  int getNextAvailableGroupId() {
    final usedIds = roles.map((r) => r.groupId).toSet();
    for (int i = 2; i < 9; i++) {
      if (!usedIds.contains(i)) return i;
    }
    return -1; // Keine freie ID
  }

  // ===== PERMISSIONS LADEN =====

  Future<void> loadPermissions({bool forceReload = false}) async {
    if (!forceReload && _permissionsCache != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) return;
    }

    try {
      final doc = await _db.collection('settings').doc('permissions').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _permissionsCache = data.map((k, v) => MapEntry(k, v as int));
      } else {
        _permissionsCache = {};
      }
      _cacheTime = DateTime.now();
    } catch (e) {
      print('Error loading permissions: $e');
      _permissionsCache = {};
    }
  }

  Stream<Map<String, int>> get permissionsStream {
    return _db.collection('settings').doc('permissions').snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _permissionsCache = data.map((k, v) => MapEntry(k, v as int));
        return _permissionsCache!;
      }
      return <String, int>{};
    });
  }

  // ===== PERMISSION CHECKS =====

  int getMinRoleForFeature(String featureId) {
    if (_permissionsCache != null && _permissionsCache!.containsKey(featureId)) {
      return _permissionsCache![featureId]!;
    }
    final feature = allFeatures.where((f) => f.id == featureId).firstOrNull;
    return feature?.defaultMinRole ?? 1;
  }

  bool hasAccess(int? userGroup, String featureId) {
    final minRole = getMinRoleForFeature(featureId);
    return (userGroup ?? 1) >= minRole;
  }

  Future<void> setFeaturePermission(String featureId, int minRole) async {
    await _db.collection('settings').doc('permissions').set(
      {featureId: minRole},
      SetOptions(merge: true),
    );
    _permissionsCache ??= {};
    _permissionsCache![featureId] = minRole;
  }

  // ===== ROLLEN-CHECKS =====

  bool hasMinRole(int? userGroup, int minGroupId) => (userGroup ?? 1) >= minGroupId;
  bool hasMinBueroAccess(int? userGroup) => hasMinRole(userGroup, 5);
  bool hasMinAdminAccess(int? userGroup) => hasMinRole(userGroup, 9);
  bool isSuperAdmin(int? userGroup) => userGroup == 10;

  String getRoleDisplayName(int? userGroup) => getRole(userGroup).name;
  Color getRoleColor(int? userGroup) => getRole(userGroup).color;
  String getRoleIcon(int? userGroup) => getRole(userGroup).iconName;

  // ===== ROLLEN-ÄNDERUNGS-LOGIK =====

  List<UserRole> getAssignableRoles(int? currentUserGroup) {
    if (isSuperAdmin(currentUserGroup)) return roles;
    if (hasMinAdminAccess(currentUserGroup)) {
      return roles.where((r) => r.groupId < 9).toList();
    }
    return [];
  }

  bool canAssignRole(int? currentUserGroup, int targetGroupId) {
    return getAssignableRoles(currentUserGroup).any((r) => r.groupId == targetGroupId);
  }

  bool canEditUser(int? currentUserGroup, int? targetUserGroup) {
    if (targetUserGroup == 10 && currentUserGroup != 10) return false;
    if ((targetUserGroup ?? 0) >= 9 && !isSuperAdmin(currentUserGroup)) return false;
    return hasMinAdminAccess(currentUserGroup);
  }

  bool canManageRoles(int? userGroup) => isSuperAdmin(userGroup);

  // ===== LEGACY COMPATIBILITY =====

  bool canSeeSettings(int? userGroup) => hasAccess(userGroup, 'appbar_settings');
  bool canManageUsers(int? userGroup) => hasMinAdminAccess(userGroup);
  bool canEditMasterData(int? userGroup) => hasAccess(userGroup, 'drawer_customers');
  bool canManageOrders(int? userGroup) => hasAccess(userGroup, 'drawer_orders');
  bool canEditPdfSettings(int? userGroup) => hasAccess(userGroup, 'drawer_pdf');

  // ===== INIT =====

  Future<void> initialize() async {
    await loadRoles();
    await loadPermissions();
  }
}