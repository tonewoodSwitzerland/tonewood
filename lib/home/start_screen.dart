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
import 'package:tonewood/home/quotes_overview_screen.dart';
import 'package:tonewood/home/standardized_packages_screen.dart';
import 'package:tonewood/home/standardized_product_management_screen.dart';
import '../components/admin_form.dart';
import '../components/circular_avatar_shadowed.dart';
import '../components/custom_dialog_box_crew.dart';
import '../components/feedback_list.dart';
import '../constants.dart';
import '../services/admin_additional_text_manager.dart';
import '../services/customer_export_service.dart';
import '../services/customer_import_service.dart';
import '../services/feedback_functions.dart';
import '../home/settings_form.dart';
import '../home/warehouse_screen.dart';
import '../home/product_management_screen.dart';
import '../home/sales_screen.dart';
import '../services/icon_helper.dart';
import 'analytics_screen2.dart';
import 'customer_management_screen.dart';
import 'customer_selection.dart';
import 'orders_overview_screen.dart';


import 'package:package_info_plus/package_info_plus.dart';






class StartScreen extends StatefulWidget {
  static String id = 'start_screen';
  const StartScreen({required Key key}) : super(key: key);

  @override
  StartScreenState createState() => StartScreenState();
}

class StartScreenState extends State<StartScreen> {
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
    final screens = [
    //  if (PlatformInfo.isMobilePlatform)
     //   ScannerScreen(key: UniqueKey()),
      WarehouseScreen(key: UniqueKey()),
      ProductManagementScreen(key: UniqueKey()),
      SalesScreen(key: UniqueKey()),
    //  GeneralDataScreen(key: UniqueKey()),
     PrinterScreen(key: UniqueKey()),
     // SalesHistoryScreen(key: UniqueKey()),
      AnalyticsScreen(key: UniqueKey()),
    // StockEntryScreen(key: UniqueKey()),
    ];
    return screens;
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    return [
      BottomNavigationBarItem(icon: getAdaptiveIcon(iconName: 'warehouse', defaultIcon: Icons.warehouse,) ,  label: "Lager",),
      BottomNavigationBarItem(icon: getAdaptiveIcon(iconName: 'precision_manufacturing', defaultIcon: Icons.precision_manufacturing,), label: "Produkt",),
      BottomNavigationBarItem(icon: getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon: Icons.shopping_cart,), label: "Verkauf",),
      BottomNavigationBarItem(icon: getAdaptiveIcon(iconName: 'print', defaultIcon: Icons.print, color: Colors.black87,), label: "Barcodes",),
      BottomNavigationBarItem(icon: getAdaptiveIcon(iconName: 'analytics', defaultIcon: Icons.analytics, color: Colors.black87,), label: "Analyse",),
    ];
  }

  Widget _buildBottomNavigation() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

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
            currentIndex: _currentIndex,
            items: _getNavigationItems(),
          ),
        );
      },
    );
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

  Widget _buildMainScaffold() {
    return Scaffold(
      key: _scaffoldKey, // Hier den GlobalKey hinzufügen
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(context),
      body: _getScreens()[_currentIndex],
      bottomNavigationBar: _buildBottomNavigation(),
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

        return SizedBox(
          width: double.infinity,
          height: kToolbarHeight - 4, // Feste Höhe für den Inhalt, etwas kleiner als die Toolbar
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
             // _buildFeedbackButton(),
              _buildLogo(),

              // Gruppiere die letzten beiden Elemente in einer eigenen Row ohne Abstand
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48, // Feste Breite für den IconButton
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: getAdaptiveIcon(
                        iconName: 'settings',
                        defaultIcon: Icons.settings,
                      ),
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
                    width: 60, // Feste Breite für das Avatar-Widget
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

  Widget _buildFeedbackButton() {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0,0,0),
        child: Container(
          alignment: Alignment.centerLeft, // Richtet den Inhalt links aus
          child: GestureDetector(
            child: getAdaptiveIcon(
              iconName: 'comment',
              defaultIcon: Icons.comment,
            ),
            onLongPress: () => _adminPanel(user.uid),
            onDoubleTap: () => _feedbackPanel(user.uid),
            onTap: () => _showFeedbackDialog(),
          ),
        ),
      ),
    );
  }

  // Aktualisiere die _buildLogo Methode, um sie anklickbar zu machen:

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

  void _showFeedbackDialog() async {
    BetterFeedback.of(context).show((feedback) async {
      WidgetsFlutterBinding.ensureInitialized();
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      await alertFeedbackFunction2(
        name,
        user.uid,
        feedback,
        packageInfo.packageName,
        packageInfo.version,
        packageInfo.buildNumber,
      );

      AppToast.show(message: "feedbackSent".tr, height: AppSizes.h);
    });
  }

  void _adminPanel(String userId) {
    if (userId == "0Twdd2EtJGcymHCA31GY6moAmU33") {
      showModalBottomSheet(
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
        ),
        context: context,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const AdminForm(),
        ),
      );
    }
  }

  void _feedbackPanel(String userId) {
    if (userId == "0Twdd2EtJGcymHCA31GY6moAmU33") {
      showDialog(
        useRootNavigator: false,
        context: context,
        builder: (BuildContext context) => CustomDialogBoxCrew(
          key: UniqueKey(),
          title: "feedback".tr,
          descriptions: SizedBox(
            height: 0.7 * AppSizes.h,
            child: GestureDetector(
              onTap: () {},
              child: FeedbackList(key: UniqueKey()),
            ),
          ),
        ),
      );
    }
  }

  void _showSettingsPanel2() {
    showDialog(
      useRootNavigator: false,
      context: context,
      builder: (BuildContext dialogContext) => CustomDialogBoxCrew(
        key: UniqueKey(),
        title: "Profil",
        descriptions: SettingsForm(
          kIsWebTemp: false,
          dialogContextBox: dialogContext,
          contextApp: context,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Logo und Header-Bereich
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            color: Theme.of(context).primaryColor,
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  padding: const EdgeInsets.all(15), // Padding innerhalb des Containers
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    color: Colors.white, // Hintergrundfarbe
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('images/logo3.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
                const Text(
                  'Tonewood Switzerland',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Admin-Bereich',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Menüpunkte
          // Menüpunkte
          ListTile(
            leading:
            getAdaptiveIcon(iconName: 'people', defaultIcon: Icons.people),
            title: const Text('Kundenverwaltung'),
            onTap: () {
              // Schließe das Drawer-Menü
              Navigator.pop(context);

              // Öffne die Kundenverwaltung im Vollbild-Modus
              CustomerSelectionSheet.showCustomerManagementScreen(context);
            },
          ),

          const Divider(),

          ListTile(
            leading: getAdaptiveIcon(iconName: 'inventory', defaultIcon: Icons.inventory),
            title: const Text('Standardprodukte'),
            onTap: () {
              // Schließe das Drawer-Menü
              Navigator.pop(context);

              // Öffne die Standardproduktverwaltung
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StandardizedProductManagementScreen(),
                ),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: getAdaptiveIcon(iconName: 'inventory', defaultIcon: Icons.inventory),
            title: const Text('Standardpakete'),
            subtitle: const Text('Verpackungsarten verwalten'),
            onTap: () {

              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StandardizedPackagesScreen(),
                ),
              );
            },
          ),



// Nach der Divider nach Standardprodukte
          const Divider(),

          ListTile(
            leading: getAdaptiveIcon(iconName: 'request_quote', defaultIcon: Icons.request_quote),
            title: const Text('Angebote'),
            subtitle: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('quotes')
                  .where('status', whereNotIn: ['accepted'])
                  .get(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return Text('$count offene Angebote');
              },
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuotesOverviewScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: getAdaptiveIcon(iconName: 'shopping_bag', defaultIcon: Icons.shopping_bag),
            title: const Text('Aufträge'),
            subtitle: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('orders')
                  .where('status', whereNotIn: ['delivered', 'cancelled'])
                  .get(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return Text('$count aktive Aufträge');
              },
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrdersOverviewScreen(),
                ),
              );
            },
          ),
          // const Divider(),
          //
          // ListTile(
          //   leading: getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download),
          //   title: const Text('Kundendatenbank exportieren'),
          //   subtitle: const Text('Als CSV-Datei herunterladen'),
          //   onTap: () {
          //     // Schließe das Drawer-Menü
          //     Navigator.pop(context);
          //
          //     // Export starten
          //     CustomerExportService.exportCustomersCsv(context);
          //   },
          // ),

          // const Divider(),
          // ListTile(
          //   leading: getAdaptiveIcon(iconName: 'upload', defaultIcon: Icons.upload),
          //   title: const Text('Kundendatenbank importieren'),
          //   subtitle: const Text('Aus CSV-Datei'),
          //   onTap: () {
          //     // Schließe das Drawer-Menü
          //     Navigator.pop(context);
          //
          //     // Import-Dialog öffnen
          //     CustomerImportService.showImportDialog(context);
          //   },
          // ),

          const Divider(),

          ListTile(
            leading: getAdaptiveIcon(iconName: 'text_fields', defaultIcon: Icons.text_fields),
            title: const Text('Standardtexte'),

            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminTextsEditor(),
                ),
              );
            },
          ),
          const Divider(),



          // Footer mit Version und Copyright
          const Spacer(),
          const Divider(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  'Version: ${packageInfo?.version ?? ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '© ${DateTime.now().year} Tonewood Switzerland',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

