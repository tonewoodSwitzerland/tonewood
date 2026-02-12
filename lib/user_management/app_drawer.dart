// lib/components/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../cost_center/cost_center_management_screen.dart';
import '../customers/customer_selection.dart';
import '../inventory/inventory_screen.dart';
import '../services/icon_helper.dart';
import '../user_management/permission_service.dart';
import '../user_management/user_management_screen.dart';
import '../quotes/quotes_overview_screen.dart';
import '../orders/orders_overview_screen.dart';
import '../home/standardized_packages_screen.dart';
import '../home/standardized_product_management_screen.dart';
import '../services/admin_additional_text_manager.dart';
import '../services/pdf_settings_screen.dart';
import '../user_management/permission_config_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _permissions = PermissionService();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final userGroup = userData?['userGroup'] as int? ?? 1;
          final userName = userData?['name'] as String? ?? '';

          return Column(
            children: [
              _buildHeader(context, userName, userGroup),
              Expanded(child: _buildMenuList(context, userGroup)),
              _buildFooter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName, int userGroup) {
    final role = _permissions.getRole(userGroup);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, bottom: 16),
      color: Theme.of(context).primaryColor,
      child: Column(
        children: [
          // Logo
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.white,
            ),
            child: Image.asset('images/logo3.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          // Firmenname
          const Text(
            'Tonewood Switzerland',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Username & Rolle
          if (userName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                userName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 6),
          // Rollen-Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, int userGroup) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // === AUFTRÄGE & ANGEBOTE ===
        if (_permissions.hasAccess(userGroup, 'drawer_quotes') ||
            _permissions.hasAccess(userGroup, 'drawer_orders')) ...[
          _buildSectionHeader('Aufträge & Angebote'),
          if (_permissions.hasAccess(userGroup, 'drawer_quotes'))
            _buildDrawerItemWithBadge(
              context: context,
              icon: Icons.request_quote,
              iconName: 'request_quote',
              title: 'Angebote',
              badgeQuery: _db.collection('quotes').where('status', whereNotIn: ['accepted']),
              onTap: () => _navigateTo(context, const QuotesOverviewScreen()),
            ),
          if (_permissions.hasAccess(userGroup, 'drawer_orders'))
            _buildDrawerItemWithBadge(
              context: context,
              icon: Icons.shopping_bag,
              iconName: 'shopping_bag',
              title: 'Aufträge',
              badgeQuery: _db.collection('orders').where('status', whereNotIn: ['delivered', 'cancelled']),
              onTap: () => _navigateTo(context, const OrdersOverviewScreen()),
            ),
        ],

        // === STAMMDATEN ===
        if (_permissions.hasAccess(userGroup, 'drawer_customers') ||
            _permissions.hasAccess(userGroup, 'drawer_std_products') ||
            _permissions.hasAccess(userGroup, 'drawer_std_packages')) ...[
          _buildSectionHeader('Stammdaten'),
          if (_permissions.hasAccess(userGroup, 'drawer_customers'))
            _buildDrawerItem(
              icon: Icons.people,
              iconName: 'people',
              title: 'Kundenverwaltung',
              onTap: () {
                Navigator.pop(context);
                CustomerSelectionSheet.showCustomerManagementScreen(context);
              },
            ),
          if (_permissions.hasAccess(userGroup, 'drawer_std_products'))
            _buildDrawerItem(
              icon: Icons.inventory,
              iconName: 'inventory',
              title: 'Standardprodukte',
              onTap: () => _navigateTo(context, const StandardizedProductManagementScreen()),
            ),
          if (_permissions.hasAccess(userGroup, 'drawer_std_packages'))
            _buildDrawerItem(
              icon: Icons.inventory_2,
              iconName: 'inventory_2',
              title: 'Standardpakete',
              onTap: () => _navigateTo(context, const StandardizedPackagesScreen()),
            ),
        ],

        // === EINSTELLUNGEN ===
        if (_permissions.hasAccess(userGroup, 'drawer_texts') ||
            _permissions.hasAccess(userGroup, 'drawer_pdf') ||
            _permissions.hasAccess(userGroup, 'drawer_cost_centers')) ...[
          _buildSectionHeader('Einstellungen'),
          if (_permissions.hasAccess(userGroup, 'drawer_cost_centers'))
            _buildDrawerItem(
              icon: Icons.account_balance_wallet,
              iconName: 'account_balance_wallet',
              title: 'Kostenstellen',
              onTap: () => _navigateTo(context, const CostCenterManagementScreen()),
            ),
          if (_permissions.hasAccess(userGroup, 'drawer_texts'))
            _buildDrawerItem(
              icon: Icons.text_fields,
              iconName: 'text_fields',
              title: 'Standardtexte',
              onTap: () => _navigateTo(context, const AdminTextsEditor()),
            ),
          if (_permissions.hasAccess(userGroup, 'drawer_pdf'))
            _buildDrawerItem(
              icon: Icons.picture_as_pdf,
              iconName: 'picture_as_pdf',
              title: 'PDF Einstellungen',
              onTap: () => _navigateTo(context, const PdfSettingsScreen()),
            ),
        ],

        // === ADMINISTRATION (nur Admin+) ===
        if (_permissions.hasMinAdminAccess(userGroup)) ...[
          _buildSectionHeader('Administration'),
          _buildDrawerItem(
            icon: Icons.manage_accounts,
            iconName: 'manage_accounts',
            title: 'Benutzerverwaltung',
            onTap: () => _navigateTo(
              context,
              UserManagementScreen(currentUserGroup: userGroup),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.security,
            iconName: 'security',
            title: 'Berechtigungen',
            onTap: () => _navigateTo(context, const PermissionConfigScreen()),
          ),
          _buildDrawerItem(
            icon: Icons.fact_check,
            iconName: 'fact_check',
            title: 'Inventur',
            onTap: () => _navigateTo(context, const InventoryScreen()),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Text(
            'v${_packageInfo?.version ?? ""}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const Spacer(),
          Text(
            '© ${DateTime.now().year} Tonewood',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // === HELPER METHODS ===

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String iconName,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: getAdaptiveIcon(iconName: iconName, defaultIcon: icon),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }

  Widget _buildDrawerItemWithBadge({
    required BuildContext context,
    required IconData icon,
    required String iconName,
    required String title,
    required Query badgeQuery,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: getAdaptiveIcon(iconName: iconName, defaultIcon: icon),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: StreamBuilder<QuerySnapshot>(
        stream: badgeQuery.snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          );
        },
      ),
      onTap: onTap,
    );
  }
}