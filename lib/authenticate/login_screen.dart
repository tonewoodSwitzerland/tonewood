import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:local_auth/local_auth.dart';

import 'package:universal_io/io.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import '../authenticate/registration_screen.dart';
import '../authenticate/forget_screen.dart';
import '../constants.dart';
import '../home/start_screen.dart';
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import '../services/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auto_size_text.dart';
import '../components/reusable_cart.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  static String id = 'login_screen';
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final FocusNode _focusMail = FocusNode();
  final FocusNode _focusPW = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
  final AuthService _auth2 = AuthService();
  bool isLogin = false;
  bool showSpinner = false;
  bool _obscureText = true;
  String email = "";
  String password = "";
  String error = '';
  bool fingerprint = false;
  final LocalAuthentication auth = LocalAuthentication();
  final storage = const FlutterSecureStorage();
  String authorized = 'Not Authorized';
  bool isAuthenticating = false;
  bool useTouchId = false;
  bool userHasTouchId = false;

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

  void validateAndSave() {
    final form = formKey.currentState;
    if (form!.validate()) {
    } else {
      showSpinner = false;
    }
  }

  void _onFocusChange() {
    setState(() {}); // Aktualisiert den State, wenn der Fokus sich ändert
  }

  @override
  Widget build(BuildContext context) {

    print(kIsWeb);

    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: SafeArea(
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.white,
            body: Padding(
              padding: EdgeInsets.symmetric(vertical: 0, horizontal: isMobile),
              child: Center(
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          SizedBox(height: h * 0.05),
                          Hero(
                            tag: 'logo',
                            child: SizedBox(
                              width: _focusMail.hasFocus || _focusPW.hasFocus
                                  ?w * isHero*mobileFactor
                                  : w * isHero*mobileFactor,
                              child: Image.asset('images/logo2.png', fit: BoxFit.cover),
                            ),
                          ),
                          SizedBox(height: h * 0.05),
                          AutofillGroup(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: TextFormField(
                                    validator: (value) =>
                                    value!.isEmpty ? 'emptyMail'.tr : null,
                                    style: TextStyle(
                                        fontSize: h * 0.02, color: Colors.black),
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    onChanged: (value) {
                                      email = value;
                                    },
                                    focusNode: _focusMail,
                                    decoration: kTextFieldDecoration.copyWith(
                                      contentPadding:
                                      EdgeInsets.fromLTRB(0, h * 0.01, 0, h * 0.01),
                                      hintText: 'mail'.tr,
                                      hintStyle: const TextStyle(color: Colors.black),
                                      icon: Icon(Icons.mail, size: h * 0.03,color: primaryAppColor,),
                                    ),
                                  ),
                                ),
                                SizedBox(height: h * 0.03),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: TextFormField(
                                    validator: (value) => value!.length < 6
                                        ? 'passwordError'.tr
                                        : null,
                                    obscureText: _obscureText,
                                    style: TextStyle(
                                        fontSize: h * 0.02, color: Colors.black),
                                    textAlign: TextAlign.center,
                                    autofillHints: const [AutofillHints.password],
                                    onEditingComplete: () =>
                                        TextInput.finishAutofillContext(),
                                    onChanged: (value) {
                                      password = value;
                                    },
                                    focusNode: _focusPW,
                                    decoration: kTextFieldDecoration.copyWith(
                                      contentPadding:
                                      EdgeInsets.fromLTRB(0, h * 0.01, 0, h * 0.01),
                                      hintText: 'password'.tr,
                                      hintStyle: const TextStyle(color: Colors.black),
                                      icon: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _obscureText = !_obscureText;
                                          });
                                        },
                                        child: Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: h * 0.03,
                                          color: primaryAppColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: h * 0.01),
                          Text(
                            error,
                            style: TextStyle(color: Colors.red, fontSize: h * 0.02),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                child: ReusableCardTouch(
                                  touched: true,
                                  colour: primaryAppColor,
                                  cardChild: Padding(
                                    padding: EdgeInsets.fromLTRB(w * 0.01, 0, w * 0.01, 0),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(Icons.login, color: whiteColour, size: h * 0.03),
                                        Padding(
                                          padding: EdgeInsets.all(h * 0.01),
                                          child: Text(
                                            'loginButton'.tr,
                                            style: labelButtons.copyWith(
                                                fontSize: h * textFactor20,
                                                color: whiteColour),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onPress: () async {
                                    setState(() {
                                      showSpinner = true;
                                    });
                                    await login(context);
                                    setState(() {
                                      showSpinner = false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: h * 0.05),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Text(
                                    'forget'.tr,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: h * 0.015,
                                        fontWeight: FontWeight.w300),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pushReplacementNamed(context, ForgetScreen.id);
                                },
                              ),
                              GestureDetector(
                                child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Text(
                                    'register'.tr,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: h * 0.015,
                                        fontWeight: FontWeight.w300),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pushNamed(context, RegistrationScreen.id);
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: h * 0.02),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> login(context) async {
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
  }
}
