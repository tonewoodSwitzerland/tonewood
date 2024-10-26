import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/admin_form.dart';
import '../components/circular_avatar_shadowed.dart';
import '../components/custom_dialog_box_crew.dart';
import '../components/feedback_list.dart';
import '../constants.dart';
import '../services/feedback_functions.dart';
import '../home/settings_form.dart';
import '../home/warehouse_screen.dart';
import '../home/product_management_screen.dart';
import '../home/sales_screen.dart';
import '../home/product_scanner_screen.dart';

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

  @override
  void initState() {
    super.initState();
    getCurrUserFuture = getCurrUser();
    _setOrientation();
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
      if (PlatformInfo.isMobilePlatform)
        ScannerScreen(key: UniqueKey()),
      WarehouseScreen(key: UniqueKey()),
      ProductManagementScreen(key: UniqueKey()),
      SalesScreen(key: UniqueKey()),
    ];
    return screens;
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    return [
      if (PlatformInfo.isMobilePlatform)
        const BottomNavigationBarItem(
          icon: Icon(Icons.document_scanner_outlined, color: Colors.black87),
          activeIcon: Icon(Icons.document_scanner_outlined, color: primaryAppColor),
          label: "",
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.search, color: Colors.black87),
        activeIcon: Icon(Icons.search, color: primaryAppColor),
        label: "",
      ),
      const BottomNavigationBarItem(
        icon: FaIcon(FontAwesomeIcons.productHunt),
        label: "",
      ),
      const BottomNavigationBarItem(
        icon:  FaIcon(FontAwesomeIcons.tree),
        label: "",
      ),
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: BottomNavigationBar(
         //   backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
           // unselectedItemColor: lighterBlackColour,
           // selectedItemColor: primaryAppColor,
           // showSelectedLabels: false, // Keine Labels anzeigen
           // showUnselectedLabels: false, // Keine Labels anzeigen
          //  iconSize: PlatformInfo.getBottomNavIconSize(MediaQuery.of(context).size.width),
            onTap: _onTappedBar,
            currentIndex: _currentIndex,
            items: _getNavigationItems(),
          ),
        );
      },
    );
  }

  Widget _buildIcon(IconData icon) {
    return Icon(
      icon,
      size: ResponsiveLayout.getIconSize(MediaQuery.of(context).size.width),
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
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
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

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFeedbackButton(),
            _buildLogo(),
            _buildProfileAvatar(photoPic),
          ],
        );
      },
    );
  }

  Widget _buildFeedbackButton() {
    return Expanded(
      flex: 3,
      child: GestureDetector(
        child: const FaIcon(
          FontAwesomeIcons.solidComment,
          color: Color(0xFFE6E6E6),
        ),
        onLongPress: () => _adminPanel(user.uid),
        onDoubleTap: () => _feedbackPanel(user.uid),
        onTap: () => _showFeedbackDialog(),
      ),
    );
  }

  Widget _buildLogo() {
    return Expanded(
      flex: 15,
      child: SizedBox(
        height: kToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            'images/tonewood_logo_blaetter.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String photoPic) {
    return Expanded(
      flex: 4,
      child: Center(
        child: GestureDetector(
          onTap: _showSettingsPanel2,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: CircleAvatarShadowedNoImage(
              key: UniqueKey(),
              shadow: 0,
              w: 350,
              photoPlayer: photoPic,
            ),
          ),
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
}