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
import '../services/icon_helper.dart';

class LoginScreen extends StatefulWidget {
  static String id = 'login_screen';
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final FocusNode _focusMail = FocusNode();
  final FocusNode _focusPW = FocusNode();
  final formKey = GlobalKey<FormState>();
  final AuthService _auth2 = AuthService();

  late AnimationController _animationController;

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

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _focusMail.dispose();
    _focusPW.dispose();
    _animationController.dispose();
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
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    final double logoHeight = screenHeight * 0.10;
    final double contentPadding = screenWidth > 600 ? 40.0 : 24.0;
    final double formWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;

    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: ModalProgressHUD(
        inAsyncCall: showSpinner,
        progressIndicator: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryAppColor),
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: contentPadding,
                    vertical: contentPadding * 0.5,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo-Bereich mit optimiertem Hero-Widget
                      SizedBox(
                        height: logoHeight,
                        child: Hero(
                          tag: 'logo',
                          child: Image.asset(
                            'images/tonewood_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.03),

                      // Willkommenstext
                      FadeTransition(
                        opacity: _animationController,
                        child: Text(
                          'Willkommen!',
                          style: TextStyle(
                            fontSize: screenHeight * 0.028,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      FadeTransition(
                        opacity: _animationController,
                        child: Text(
                          'Melde dich an, um fortzufahren.',
                          style: TextStyle(
                            fontSize: screenHeight * 0.016,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Anmeldeformular
                      Container(
                        width: formWidth,
                        padding: EdgeInsets.all(screenWidth > 600 ? 32.0 : 24.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: formKey,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Email-Feld
                                _buildTextField(
                                  focusNode: _focusMail,
                                  hintText: 'mail'.tr,
                                  icon: Icons.mail,
                                  iconName: 'mail',
                                  isPassword: false,
                                  initialValue: email,
                                  onChanged: (value) => email = value,
                                  validator: (value) => value!.isEmpty ? 'emptyMail'.tr : null,
                                  autofillHints: const [AutofillHints.email],
                                ),

                                SizedBox(height: screenHeight * 0.02),

                                // Passwort-Feld
                                _buildTextField(
                                  focusNode: _focusPW,
                                  hintText: 'password'.tr,
                                  icon: Icons.lock,
                                  iconName: 'visibility',
                                  isPassword: true,
                                  initialValue: password,
                                  onChanged: (value) => password = value,
                                  validator: (value) => value!.length < 6 ? 'passwordError'.tr : null,
                                  autofillHints: const [AutofillHints.password],
                                  onEditingComplete: () => TextInput.finishAutofillContext(),
                                ),

                                // Fehlermeldung
                                if (error.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: screenHeight * 0.02),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        error,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: screenHeight * 0.016,
                                        ),
                                      ),
                                    ),
                                  ),

                                SizedBox(height: screenHeight * 0.035),

                                // Login-Button
                                _buildLoginButton(screenHeight),

                                SizedBox(height: screenHeight * 0.02),

                                // Links
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pushReplacementNamed(context, ForgetScreen.id),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.black87,
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: Text(
                                        'forget'.tr,
                                        style: TextStyle(
                                          fontSize: screenHeight * 0.016,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pushNamed(context, RegistrationScreen.id),
                                      style: TextButton.styleFrom(
                                        foregroundColor: primaryAppColor,
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: Text(
                                        'register'.tr,
                                        style: TextStyle(
                                          fontSize: screenHeight * 0.016,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.02),
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

  Widget _buildTextField({
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required String iconName,
    required bool isPassword,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    List<String>? autofillHints,
    String initialValue = '',
    VoidCallback? onEditingComplete,
  }) {
    return TextFormField(
      focusNode: focusNode,
      obscureText: isPassword ? _obscureText : false,
      initialValue: initialValue,
      style: TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
      autofillHints: autofillHints,
      onEditingComplete: onEditingComplete,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: getAdaptiveIcon(
            iconName: isPassword ? 'lock' : iconName,
            defaultIcon: isPassword ? Icons.lock : icon,
            color: focusNode.hasFocus ? primaryAppColor : Colors.grey,
            size: 20,
          ),
        ),
        suffixIcon: isPassword
            ? IconButton(
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: getAdaptiveIcon(
            iconName: _obscureText ? 'visibility' : 'visibility_off_outlined',
            defaultIcon: _obscureText ? Icons.visibility : Icons.visibility_off_outlined,
            color: focusNode.hasFocus ? primaryAppColor : Colors.grey,
            size: 20,
          ),
        )
            : null,
        filled: true,
        fillColor: focusNode.hasFocus ? Colors.white : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryAppColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton(double height) {
    return ElevatedButton(
      onPressed: () => _handleLogin(),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAppColor,
        foregroundColor: whiteColour,
        padding: EdgeInsets.symmetric(vertical: height * 0.018),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          getAdaptiveIcon(
            iconName: 'login',
            defaultIcon: Icons.login,
            color: whiteColour,
            size: height * 0.025,
          ),
          SizedBox(width: 12),
          Text(
            'loginButton'.tr,
            style: TextStyle(
              fontSize: height * 0.02,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

        // Bei Fehlschlag Autofill nicht speichern
        TextInput.finishAutofillContext(shouldSave: false);
      } else {
        SharedPreferences pref = await SharedPreferences.getInstance();
        pref.setBool("isLogin", true);
        pref.setString("userName", email);

        // Bei Erfolg dem Passwortmanager signalisieren, dass er speichern soll
        TextInput.finishAutofillContext(shouldSave: true);

        Navigator.pushReplacementNamed(context, StartScreen.id);
      }
    }

    setState(() => showSpinner = false);
  }
}