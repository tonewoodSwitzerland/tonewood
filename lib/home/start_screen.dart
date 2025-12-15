import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tonewood/general_data_screen/general_data_screen.dart';
import 'package:tonewood/home/printer_screen.dart';
import '../components/circular_avatar_shadowed.dart';
import '../constants.dart';
import '../home/settings_form.dart';
import '../home/warehouse_screen.dart';
import '../home/product_management_screen.dart';
import '../home/sales_screen.dart';
import '../services/icon_helper.dart';
import '../user_management/app_drawer.dart';
import '../user_management/permission_service.dart';
import '../user_management/user_management_screen.dart';
import 'analytics_screen2.dart';

class StartScreen extends StatefulWidget {
  static String id = 'start_screen';
  const StartScreen({required Key key}) : super(key: key);

  @override
  StartScreenState createState() => StartScreenState();
}

class StartScreenState extends State<StartScreen> {
  final _permissions = PermissionService(); // NEU
  int _userGroup = 1; // NEU - speichert aktuelle userGroup
  final _auth3 = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late Future<User> getCurrUserFuture;
  late User user;
  int _currentIndex = 0;
  int userGroup = 1;
  String name = '';
  PackageInfo? packageInfo;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  void initState() {
    super.initState();
    getCurrUserFuture = getCurrUser();
    _setOrientation();
    initPackageInfo();
    _permissions.initialize();
  }
  Future<void> initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      packageInfo = info;
    });
  }
  void _setOrientation() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  Future<User> getCurrUser() async {
    late User userTemp;
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) userTemp = user;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    return userTemp;
  }

  List<Widget> _getScreens() {
    return [
      if (_permissions.hasAccess(_userGroup, 'nav_warehouse'))
        WarehouseScreen(key: UniqueKey()),
      if (_permissions.hasAccess(_userGroup, 'nav_product'))
        ProductManagementScreen(key: UniqueKey()),
      if (_permissions.hasAccess(_userGroup, 'nav_sales'))
        SalesScreen(key: UniqueKey()),
      if (_permissions.hasAccess(_userGroup, 'nav_barcodes'))
        PrinterScreen(key: UniqueKey()),
      if (_permissions.hasAccess(_userGroup, 'nav_analytics'))
        AnalyticsScreen(key: UniqueKey()),
    ];
  }


  List<BottomNavigationBarItem> _getNavigationItems() {
    return [
      if (_permissions.hasAccess(_userGroup, 'nav_warehouse'))
        BottomNavigationBarItem(
          icon: getAdaptiveIcon(iconName: 'warehouse', defaultIcon: Icons.warehouse),
          label: "Lager",
        ),
      if (_permissions.hasAccess(_userGroup, 'nav_product'))
        BottomNavigationBarItem(
          icon: getAdaptiveIcon(iconName: 'precision_manufacturing', defaultIcon: Icons.precision_manufacturing),
          label: "Produkt",
        ),
      if (_permissions.hasAccess(_userGroup, 'nav_sales'))
        BottomNavigationBarItem(
          icon: getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon: Icons.shopping_cart),
          label: "Verkauf",
        ),
      if (_permissions.hasAccess(_userGroup, 'nav_barcodes'))
        BottomNavigationBarItem(
          icon: getAdaptiveIcon(iconName: 'print', defaultIcon: Icons.print, color: Colors.black87),
          label: "Barcodes",
        ),
      if (_permissions.hasAccess(_userGroup, 'nav_analytics'))
        BottomNavigationBarItem(
          icon: getAdaptiveIcon(iconName: 'analytics', defaultIcon: Icons.analytics, color: Colors.black87),
          label: "Analyse",
        ),
    ];
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: FutureBuilder<User>(
        future: getCurrUserFuture,
        builder: (context, snapshotUser) {
          if (!snapshotUser.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          user = snapshotUser.data!;
          return _buildMainScaffold();
        },
      ),
    );
  }


  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 10,
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: Column(
        children: [
          _buildAppBarContent(),
          Divider(
            height: 2,
            color: lightGrayColor,
            thickness: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final userGroup = userData?['userGroup'] as int? ?? 1;

        // Hier direkt die Items mit dem aktuellen userGroup erstellen
        final items = <BottomNavigationBarItem>[];

        if (_permissions.hasAccess(userGroup, 'nav_warehouse')) {
          items.add(BottomNavigationBarItem(
            icon: getAdaptiveIcon(iconName: 'warehouse', defaultIcon: Icons.warehouse),
            label: "Lager",
          ));
        }
        if (_permissions.hasAccess(userGroup, 'nav_product')) {
          items.add(BottomNavigationBarItem(
            icon: getAdaptiveIcon(iconName: 'precision_manufacturing', defaultIcon: Icons.precision_manufacturing),
            label: "Produkt",
          ));
        }
        if (_permissions.hasAccess(userGroup, 'nav_sales')) {
          items.add(BottomNavigationBarItem(
            icon: getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon: Icons.shopping_cart),
            label: "Verkauf",
          ));
        }
        if (_permissions.hasAccess(userGroup, 'nav_barcodes')) {
          items.add(BottomNavigationBarItem(
            icon: getAdaptiveIcon(iconName: 'print', defaultIcon: Icons.print, color: Colors.black87),
            label: "Barcodes",
          ));
        }
        if (_permissions.hasAccess(userGroup, 'nav_analytics')) {
          items.add(BottomNavigationBarItem(
            icon: getAdaptiveIcon(iconName: 'analytics', defaultIcon: Icons.analytics, color: Colors.black87),
            label: "Analyse",
          ));
        }

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        // Index korrigieren falls nötig
        final safeIndex = _currentIndex.clamp(0, items.length - 1);

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            onTap: _onTappedBar,
            currentIndex: safeIndex,
            items: items,
          ),
        );
      },
    );
  }

// Und _buildMainScaffold() anpassen - Body auch mit StreamBuilder:

  Widget _buildMainScaffold() {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      drawer: const AppDrawer(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final userGroup = userData?['userGroup'] as int? ?? 1;

          // Screens mit aktuellem userGroup erstellen
          final screens = <Widget>[];
          if (_permissions.hasAccess(userGroup, 'nav_warehouse')) {
            screens.add(WarehouseScreen(key: UniqueKey()));
          }
          if (_permissions.hasAccess(userGroup, 'nav_product')) {
            screens.add(ProductManagementScreen(key: UniqueKey()));
          }
          if (_permissions.hasAccess(userGroup, 'nav_sales')) {
            screens.add(SalesScreen(key: UniqueKey()));
          }
          if (_permissions.hasAccess(userGroup, 'nav_barcodes')) {
            screens.add(PrinterScreen(key: UniqueKey()));
          }
          if (_permissions.hasAccess(userGroup, 'nav_analytics')) {
            screens.add(AnalyticsScreen(key: UniqueKey()));
          }

          if (screens.isEmpty) {
            return const Center(child: Text('Keine Berechtigung'));
          }

          final safeIndex = _currentIndex.clamp(0, screens.length - 1);
          return screens[safeIndex];
        },
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

// 6. _buildAppBarContent() - AppBar Buttons anpassen:
  Widget _buildAppBarContent() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!;
        final photoPic = userData['photoUrl'] as String;
        name = userData['name'] as String;
        _userGroup = userData['userGroup'] as int? ?? 1;

        return SizedBox(
          width: double.infinity,
          height: kToolbarHeight - 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLogo(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Benutzerverwaltung - nur für Admin+
                  if (_permissions.hasAccess(_userGroup, 'appbar_usermgmt'))
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: getAdaptiveIcon(
                          iconName: 'manage_accounts',
                          defaultIcon: Icons.manage_accounts,
                        ),
                        tooltip: 'Benutzerverwaltung',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserManagementScreen(
                                currentUserGroup: _userGroup,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Einstellungen - dynamisch
                  if (_permissions.hasAccess(_userGroup, 'appbar_settings'))
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: getAdaptiveIcon(
                          iconName: 'settings',
                          defaultIcon: Icons.settings,
                        ),
                        tooltip: 'Einstellungen',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GeneralDataScreen(key: UniqueKey()),
                            ),
                          );
                        },
                      ),
                    ),
                  SizedBox(
                    width: 60,
                    child: _buildProfileAvatar(photoPic),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }




  Widget _buildLogo() {
    print(kIsWeb);
    return Expanded(
      flex: kIsWeb ? 15 : 4, // Erhöhe den Flex-Wert für mobile Geräte von 2 auf 4
      child: GestureDetector(
        onTap: () {
          // Öffnet den Drawer mit Hilfe des GlobalKey
          _scaffoldKey.currentState?.openDrawer();
        },
        child: Row( // Verwende Row für bessere Kontrolle
          mainAxisAlignment: MainAxisAlignment.start, // Linksbündige Ausrichtung
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10), // Mehr Platz auf der linken Seite
              child: SizedBox(
                height: kToolbarHeight - 20,
                child: kIsWeb
                    ? Image.asset(
                  'images/tonewood_logo.png',
                  fit: BoxFit.contain,
                )
                    : Image.asset(
                  'images/tonewood_logo_blaetter.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Fügt Platz nach dem Logo ein
            Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String photoPic) {
    // Kein Expanded mehr verwenden, da es in einer SizedBox liegt
    return GestureDetector(
      onTap: _showSettingsPanel2,
      child: Padding(
        padding: const EdgeInsets.all(8.0), // Reduziertes Padding
        child: CircleAvatarShadowedNoImage(
          key: UniqueKey(),
          shadow: 0,
          w: 40, // Kleinere feste Größe
          photoPlayer: photoPic,
        ),
      ),
    );
  }


  Future<void> _onTappedBar(int index) async {
    final screens = _getScreens();
    if (index >= screens.length) return;

    User? user = _auth3.currentUser;
    setState(() {
      if (user?.providerData.isEmpty ?? true) {
        _currentIndex = index;
      } else {
        if (user?.emailVerified == true || user?.providerData[0].providerId == "apple.com") {
          _currentIndex = index;
        }
      }
    });
  }



  void _showSettingsPanel2() {
    SettingsForm.show(context);
  }




}

