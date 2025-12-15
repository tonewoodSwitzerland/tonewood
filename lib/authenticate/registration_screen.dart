// lib/authenticate/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants.dart';
import '../services/auth.dart';
import '../services/icon_helper.dart';
import 'login_screen.dart';
import 'verify_screen.dart';

class RegistrationScreen extends StatefulWidget {
  static String id = 'registration_screen';
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _focusName = FocusNode();
  final _focusMail = FocusNode();
  final _focusPW = FocusNode();
  final _focusInvite = FocusNode();

  late AnimationController _animationController;

  bool _obscureText = true;
  bool _showSpinner = false;
  String _displayName = '';
  String _email = '';
  String _password = '';
  String _invitationCode = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animationController.forward();

    for (final focus in [_focusName, _focusMail, _focusPW, _focusInvite]) {
      focus.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusName.dispose();
    _focusMail.dispose();
    _focusPW.dispose();
    _focusInvite.dispose();
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
                          'Konto erstellen',
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
                          'Registriere dich mit deinem Einladungscode',
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
                              // Anzeigename (optional)
                              _buildTextField(
                                focusNode: _focusName,
                                hintText: 'Anzeigename (optional)',
                                iconName: 'person',
                                icon: Icons.person,
                                onChanged: (v) => _displayName = v,
                                validator: (_) => null,
                                keyboardType: TextInputType.name,
                              ),
                              SizedBox(height: screenHeight * 0.02),

                              // E-Mail
                              _buildTextField(
                                focusNode: _focusMail,
                                hintText: 'mail'.tr,
                                iconName: 'mail',
                                icon: Icons.mail,
                                onChanged: (v) => _email = v,
                                validator: (v) =>
                                v!.isEmpty ? 'emptyMail'.tr : null,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              SizedBox(height: screenHeight * 0.02),

                              // Passwort
                              _buildTextField(
                                focusNode: _focusPW,
                                hintText: 'password'.tr,
                                iconName: 'lock',
                                icon: Icons.lock,
                                isPassword: true,
                                onChanged: (v) => _password = v,
                                validator: (v) =>
                                v!.length < 6 ? 'passwordError'.tr : null,
                              ),
                              SizedBox(height: screenHeight * 0.02),

                              // Einladungscode
                              _buildTextField(
                                focusNode: _focusInvite,
                                hintText: 'inviteCode'.tr,
                                iconName: 'vpn_key',
                                icon: Icons.vpn_key,
                                onChanged: (v) => _invitationCode = v,
                                validator: (v) =>
                                v!.isEmpty ? 'emptyInvite'.tr : null,
                              ),

                              // Fehler
                              if (_error.isNotEmpty)
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

                              // Register Button
                              _buildRegisterButton(screenHeight),

                              SizedBox(height: screenHeight * 0.02),

                              // Back to Login
                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.pushReplacementNamed(
                                      context, LoginScreen.id),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                  ),
                                  child: Text(
                                    'backLogin'.tr,
                                    style: TextStyle(
                                      fontSize: screenHeight * 0.016,
                                      fontWeight: FontWeight.w400,
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

  Widget _buildTextField({
    required FocusNode focusNode,
    required String hintText,
    required String iconName,
    required IconData icon,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      focusNode: focusNode,
      obscureText: isPassword ? _obscureText : false,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            color: focusNode.hasFocus ? primaryAppColor : Colors.grey,
            size: 20,
          ),
        ),
        suffixIcon: isPassword
            ? IconButton(
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: getAdaptiveIcon(
            iconName: _obscureText ? 'visibility' : 'visibility_off',
            defaultIcon:
            _obscureText ? Icons.visibility : Icons.visibility_off,
            color: focusNode.hasFocus ? primaryAppColor : Colors.grey,
            size: 20,
          ),
        )
            : null,
        filled: true,
        fillColor: focusNode.hasFocus ? Colors.white : Colors.grey.shade50,
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

  Widget _buildRegisterButton(double height) {
    return ElevatedButton(
      onPressed: _handleRegistration,
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
            iconName: 'app_registration',
            defaultIcon: Icons.app_registration,
            color: Colors.white,
            size: height * 0.025,
          ),
          const SizedBox(width: 12),
          Text(
            'register'.tr,
            style: TextStyle(
              fontSize: height * 0.02,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegistration() async {
    setState(() => _showSpinner = true);

    if (_formKey.currentState!.validate()) {
      try {
        final inviteDoc =
        await _db.collection('secrets').doc(_invitationCode).get();

        if (!inviteDoc.exists || !inviteDoc.data()!.containsKey('userGroup')) {
          setState(() {
            _error = 'invalidInvite'.tr;
            _showSpinner = false;
          });
          return;
        }

        int userGroup = inviteDoc.data()!['userGroup'];
        dynamic result =
        await _authService.registerWithEmailAndPassword(_email, _password);

        if (result == null) {
          setState(() => _error = 'validEmail'.tr);
        } else {
          await _createUserRecord(userGroup);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const VerifyScreen()),
            );
          }
        }
      } on FirebaseException catch (e) {
        setState(() {
          _error = e.code == 'not-found' ? 'invalidInvite'.tr : 'registrationError'.tr;
        });
      }
    }

    setState(() => _showSpinner = false);
  }

  Future<void> _createUserRecord(int userGroup) async {
    final user = _auth.currentUser;

    await _db.collection('total').doc('stats').set(
      {'usersCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    // Anzeigename: Falls leer, E-Mail-Präfix verwenden
    final displayName = _displayName.trim().isNotEmpty
        ? _displayName.trim()
        : _email.split('@').first;

    await _db.collection('users').doc(user!.uid).set({
      'approvedByAdmin': false,
      'anonymous': false,
      'name': displayName,
      'email': _email, // E-Mail speichern
      'loginType': 'Email',
      'photoUrl': '',
      'userGroup': userGroup,
      'created': 0,
      'language': 'de',
      'createdAt': FieldValue.serverTimestamp(),
      'firstLaunch': false,
    }, SetOptions(merge: true));
  }
}