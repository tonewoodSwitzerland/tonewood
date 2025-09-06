import 'package:get/get_utils/src/extensions/internacionalization.dart';
import '../constants.dart';
import '../services/auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import '../authenticate/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../authenticate/verify_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/reusable_cart.dart';
import '../services/icon_helper.dart';

class RegistrationScreen extends StatefulWidget {
  static String id = 'registration_screen';
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen> {
  final _auth3 = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth2 = AuthService();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _focusMail = FocusNode();
  final FocusNode _focusPW = FocusNode();
  final FocusNode _focusInvite = FocusNode();

  bool _obscureText = true;
  bool showSpinner = false;
  String email = "";
  String password = "";
  String invitationCode = "";
  String error = '';

  @override
  void initState() {
    super.initState();
    _focusMail.addListener(_onFocusChange);
    _focusPW.addListener(_onFocusChange);
    _focusInvite.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusMail.dispose();
    _focusPW.dispose();
    _focusInvite.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double contentWidth = ResponsiveLayout.getLoginWidth(screenWidth);

    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SingleChildScrollView(
              child: Container(
                width: contentWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.getHorizontalPadding(screenWidth),
                  vertical: AppSizes.getVerticalPadding(screenHeight),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(screenWidth),
                      SizedBox(height: screenHeight * 0.04),
                      _buildRegistrationFields(),
                      SizedBox(height: screenHeight * 0.03),
                      _buildRegisterButton(),
                      if (error.isNotEmpty) ...[
                        SizedBox(height: screenHeight * 0.02),
                        _buildErrorText(),
                      ],
                      SizedBox(height: screenHeight * 0.03),
                      _buildBackToLogin(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double screenWidth) {
    double logoSize = ResponsiveLayout.getLogoSize(screenWidth);
    bool isFocused = _focusMail.hasFocus || _focusPW.hasFocus || _focusInvite.hasFocus;

    return Hero(
      tag: 'logo',
      child: SizedBox(
        width: isFocused ? logoSize * 0.8 : logoSize,
        child: Image.asset(
          'images/logo2.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildRegistrationFields() {
    return Column(
      children: [
        _buildTextField(
          focusNode: _focusMail,
          hintText: 'mail'.tr,
          icon: Icons.mail,
          iconName: 'mail',
          onChanged: (value) => email = value,
          validator: (value) => value!.isEmpty ? 'emptyMail'.tr : null,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: AppSizes.h * 0.02),
        _buildTextField(
          focusNode: _focusPW,
          hintText: 'password'.tr,
          icon: Icons.visibility,
          iconName:'visibility',
          isPassword: true,
          onChanged: (value) => password = value,
          validator: (value) => value!.length < 6 ? 'passwordError'.tr : null,
        ),
        SizedBox(height: AppSizes.h * 0.02),
        _buildTextField(
          focusNode: _focusInvite,
          hintText: 'inviteCode'.tr,
          icon: Icons.link,
          iconName: 'link',
          onChanged: (value) => invitationCode = value,
          validator: (value) => value!.isEmpty ? 'emptyInvite'.tr : null,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required String iconName,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: TextFormField(
        focusNode: focusNode,
        obscureText: isPassword ? _obscureText : false,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: AppSizes.h * 0.02,
          color: darkerBlackColour,
        ),
        textAlign: TextAlign.center,
        onChanged: onChanged,
        validator: validator,
        decoration: kTextFieldDecoration.copyWith(
          contentPadding: EdgeInsets.symmetric(vertical: AppSizes.h * 0.01),
          hintText: hintText,
          hintStyle: const TextStyle(color: darkerBlackColour),
          icon: isPassword
              ? GestureDetector(
            onTap: () => setState(() => _obscureText = !_obscureText),
            child:getAdaptiveIcon(iconName: iconName, defaultIcon:icon, size: AppSizes.h * 0.03, color: primaryAppColor),
          )
              : getAdaptiveIcon(iconName: iconName, defaultIcon:icon, size: AppSizes.h * 0.03, color: primaryAppColor),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return ReusableCardTouch(
      touched: true,
      colour: primaryAppColor,
      cardChild: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.w * 0.02),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.app_registration,
              color: whiteColour,
              size: AppSizes.h * 0.03,
            ),
            Padding(
              padding: EdgeInsets.all(AppSizes.h * 0.01),
              child: Text(
                'register'.tr,
                style: labelButtons.copyWith(
                  fontSize: AppSizes.h * textFactor20,
                  color: whiteColour,
                ),
              ),
            ),
          ],
        ),
      ),
      onPress: () => _handleRegistration(),
    );
  }

  Widget _buildErrorText() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        error,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.red,
          fontSize: AppSizes.h * 0.02,
        ),
      ),
    );
  }

  Widget _buildBackToLogin() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, LoginScreen.id),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Text(
          'backLogin'.tr,
          style: TextStyle(
            color: Colors.black,
            fontSize: AppSizes.h * 0.015,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegistration() async {
    setState(() => showSpinner = true);

    if (_formKey.currentState!.validate()) {
      try {
        final inviteDoc = await _db.collection('secrets').doc(invitationCode).get();

        if (!inviteDoc.exists || !inviteDoc.data()!.containsKey('userGroup')) {
          setState(() {
            error = 'invalidInvite'.tr;
            showSpinner = false;
          });
          return;
        }

        int userGroup = inviteDoc.data()!['userGroup'];
        dynamic result = await _auth2.registerWithEmailAndPassword(email, password);

        if (result == null) {
          setState(() => error = 'validEmail'.tr);
        } else {
          await _createUserRecord(userGroup);
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const VerifyScreen())
          );
        }
      } on FirebaseException catch (e) {
        setState(() {
          error = e.code == 'not-found' ? 'invalidInvite'.tr : 'registrationError'.tr;
        });
      }
    }

    setState(() => showSpinner = false);
  }

  Future<void> _createUserRecord(int userGroup) async {
    User? user = _auth3.currentUser;
    await _db.collection('total').doc('stats').set(
        {'usersCount': FieldValue.increment(1)},
        SetOptions(merge: true)
    );

    await _db.collection('users').doc(user!.uid).set({
      'approvedByAdmin': false,
      'anonymous': false,
      'name': 'Name',
      'loginType': "Email",
      'photoUrl': '',
      'userGroup': userGroup,
      'created': 0,
      'language': "de",
      'createdAt': FieldValue.serverTimestamp(),
      'firstLaunch': false
    }, SetOptions(merge: true));
  }
}