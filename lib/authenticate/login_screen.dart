import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:get/get_utils/src/extensions/internacionalization.dart';
import '../authenticate/registration_screen.dart';
import '../authenticate/forget_screen.dart';
import '../constants.dart';
import '../home/start_screen.dart';
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import '../services/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/reusable_cart.dart';

class LoginScreen extends StatefulWidget {
  static String id = 'login_screen';
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final FocusNode _focusMail = FocusNode();
  final FocusNode _focusPW = FocusNode();
  final formKey = GlobalKey<FormState>();
  final AuthService _auth2 = AuthService();
  bool showSpinner = false;
  bool _obscureText = true;
  String email = "";
  String password = "";
  String error = '';

  @override
  void initState() {
    super.initState();
    _checkLogin(context);
    _focusMail.addListener(_onFocusChange);
    _focusPW.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusMail.dispose();
    _focusPW.dispose();
    super.dispose();
  }

  Future _checkLogin(context) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    if (pref.getString("userName") != null) {
      if (pref.getBool("isLogin") == true) {
        Navigator.pushReplacementNamed(context, StartScreen.id);
        FocusManager.instance.primaryFocus?.unfocus();
      }
      email = pref.getString("userName")!;
    }
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
                  key: formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(screenWidth),
                      SizedBox(height: screenHeight * 0.04),
                      _buildLoginFields(),
                      SizedBox(height: screenHeight * 0.02),
                      if (error.isNotEmpty) _buildErrorText(),
                      SizedBox(height: screenHeight * 0.03),
                      _buildLoginButton(),
                      SizedBox(height: screenHeight * 0.04),
                      _buildBottomLinks(),
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
    bool isFocused = _focusMail.hasFocus || _focusPW.hasFocus;

    return Hero(
      tag: 'logo',
      child: SizedBox(
        width: isFocused ? logoSize * 0.8 : logoSize,
        child: Image.asset(
          'images/tonewood_logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildLoginFields() {
    return Column(
      children: [
        _buildTextField(
          focusNode: _focusMail,
          hintText: 'mail'.tr,
          icon:
          Icons.mail,
          isPassword: false,
          onChanged: (value) => email = value,
          validator: (value) => value!.isEmpty ? 'emptyMail'.tr : null,
          autofillHints: const [AutofillHints.email],
        ),
        SizedBox(height: AppSizes.h * 0.02),
        _buildTextField(
          focusNode: _focusPW,
          hintText: 'password'.tr,
          icon: Icons.remove_red_eye_outlined,
          isPassword: true,
          onChanged: (value) => password = value,
          validator: (value) => value!.length < 6 ? 'passwordError'.tr : null,
          autofillHints: const [AutofillHints.password],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required bool isPassword,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    List<String>? autofillHints,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: TextFormField(
        focusNode: focusNode,
        obscureText: isPassword ? _obscureText : false,
        style: TextStyle(fontSize: AppSizes.h * 0.02, color: Colors.black),
        textAlign: TextAlign.center,
        autofillHints: autofillHints,
        onChanged: onChanged,
        validator: validator,
        decoration: kTextFieldDecoration.copyWith(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black54),
          icon: isPassword
              ? GestureDetector(
            onTap: () => setState(() => _obscureText = !_obscureText),
            child: Icon(icon, size: AppSizes.h * 0.03, color: primaryAppColor),
          )
              : Icon(icon, size: AppSizes.h * 0.03, color: primaryAppColor),
        ),
      ),
    );
  }

  Widget _buildErrorText() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        error,
        style: TextStyle(
          color: Colors.red,
          fontSize: AppSizes.h * 0.02,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return ReusableCardTouch(
      touched: true,
      colour: primaryAppColor,
      cardChild: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.w * 0.02),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.login, color: whiteColour, size: AppSizes.h * 0.03),
            Padding(
              padding: EdgeInsets.all(AppSizes.h * 0.01),
              child: Text(
                'loginButton'.tr,
                style: labelButtons.copyWith(
                  fontSize: AppSizes.h * textFactor20,
                  color: whiteColour,
                ),
              ),
            ),
          ],
        ),
      ),
      onPress: () => _handleLogin(),
    );
  }

  Widget _buildBottomLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLink('forget'.tr, () => Navigator.pushReplacementNamed(context, ForgetScreen.id)),
        _buildLink('register'.tr, () => Navigator.pushNamed(context, RegistrationScreen.id)),
      ],
    );
  }

  Widget _buildLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.black,
            fontSize: AppSizes.h * 0.015,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() => showSpinner = true);

    if (formKey.currentState!.validate()) {
      dynamic result = await _auth2.signInWithEmailAndPassword(email, password);

      if (result == null) {
        SharedPreferences pref = await SharedPreferences.getInstance();
        pref.setBool("isLogin", false);
        setState(() => error = 'wrongEmailCombo'.tr);
      } else {
        SharedPreferences pref = await SharedPreferences.getInstance();
        pref.setBool("isLogin", true);
        pref.setString("userName", email);
        Navigator.pushReplacementNamed(context, LoginScreen.id);
      }
    }

    setState(() => showSpinner = false);
  }
}