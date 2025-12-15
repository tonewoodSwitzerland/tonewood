// lib/authenticate/forget_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

import '../constants.dart';
import '../services/auth.dart';
import '../services/icon_helper.dart';
import 'login_screen.dart';

class ForgetScreen extends StatefulWidget {
  static String id = 'forget_screen';
  const ForgetScreen({super.key});

  @override
  ForgetScreenState createState() => ForgetScreenState();
}

class ForgetScreenState extends State<ForgetScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _focusMail = FocusNode();

  late AnimationController _animationController;

  bool _showSpinner = false;
  String _email = '';
  String _error = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animationController.forward();
    _focusMail.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusMail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final logoHeight = screenHeight * 0.08;
    final contentPadding = screenWidth > 600 ? 40.0 : 24.0;
    final formWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ModalProgressHUD(
        inAsyncCall: _showSpinner,
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
                    children: [
                      // Logo
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

                      // Header
                      FadeTransition(
                        opacity: _animationController,
                        child: Text(
                          'Passwort vergessen?',
                          style: TextStyle(
                            fontSize: screenHeight * 0.028,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      FadeTransition(
                        opacity: _animationController,
                        child: Text(
                          'Gib deine E-Mail-Adresse ein und wir senden\ndir einen Link zum Zurücksetzen.',
                          style: TextStyle(
                            fontSize: screenHeight * 0.016,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.04),

                      // Form
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
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Success Message
                              if (_isSuccess)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      getAdaptiveIcon(
                                        iconName: 'check_circle',
                                        defaultIcon: Icons.check_circle,
                                        color: Colors.green.shade700,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'E-Mail wurde gesendet!\nPrüfe deinen Posteingang.',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: screenHeight * 0.016,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // E-Mail Feld
                              _buildEmailField(),

                              // Error
                              if (_error.isNotEmpty && !_isSuccess)
                                Padding(
                                  padding: EdgeInsets.only(top: screenHeight * 0.02),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _error,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: screenHeight * 0.016,
                                      ),
                                    ),
                                  ),
                                ),

                              SizedBox(height: screenHeight * 0.035),

                              // Reset Button
                              _buildResetButton(screenHeight),

                              SizedBox(height: screenHeight * 0.02),

                              // Back to Login
                              Center(
                                child: TextButton.icon(
                                  onPressed: () => Navigator.pushReplacementNamed(
                                      context, LoginScreen.id),
                                  icon: getAdaptiveIcon(
                                    iconName: 'arrow_back',
                                    defaultIcon: Icons.arrow_back,
                                    color: Colors.black87,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Zurück zum Login',
                                    style: TextStyle(
                                      fontSize: screenHeight * 0.016,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildEmailField() {
    return TextFormField(
      focusNode: _focusMail,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      validator: (v) => v?.isEmpty ?? true ? 'emptyMail'.tr : null,
      onChanged: (v) => _email = v,
      onTap: () => setState(() {
        _error = '';
        _isSuccess = false;
      }),
      decoration: InputDecoration(
        hintText: 'mail'.tr,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: getAdaptiveIcon(
            iconName: 'mail',
            defaultIcon: Icons.mail,
            color: _focusMail.hasFocus ? primaryAppColor : Colors.grey,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: _focusMail.hasFocus ? Colors.white : Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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

  Widget _buildResetButton(double height) {
    return ElevatedButton(
      onPressed: _handleResetPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAppColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: height * 0.018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          getAdaptiveIcon(
            iconName: 'lock_reset',
            defaultIcon: Icons.lock_reset,
            color: Colors.white,
            size: height * 0.025,
          ),
          const SizedBox(width: 12),
          Text(
            'resetPassword'.tr,
            style: TextStyle(
              fontSize: height * 0.02,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSpinner = true;
      _error = '';
      _isSuccess = false;
    });

    if (_formKey.currentState?.validate() ?? false) {
      dynamic result = await _authService.resetPassword(_email);

      setState(() {
        if (result == null) {
          _error = 'emailUnknown'.tr;
          _isSuccess = false;
        } else {
          _isSuccess = true;
          _error = '';
        }
      });
    }

    setState(() => _showSpinner = false);
  }
}