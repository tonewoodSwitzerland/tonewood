import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import '../components/reusable_cart.dart';
import '../constants.dart';
import '../services/auth.dart';
import 'login_screen.dart';

class ForgetScreen extends StatefulWidget {
  static String id = 'forget_screen';
  const ForgetScreen({super.key});

  @override
  ForgetScreenState createState() => ForgetScreenState();
}

class ForgetScreenState extends State<ForgetScreen> {
  final formKey = GlobalKey<FormState>();
  final AuthService _auth2 = AuthService();
  final FocusNode _focusMail = FocusNode();

  bool showSpinner = false;
  String email = "";
  String error = '';

  @override
  void initState() {
    super.initState();
    _focusMail.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusMail.dispose();
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
                  key: formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(screenWidth),
                      SizedBox(height: screenHeight * 0.04),
                      _buildEmailField(),
                      SizedBox(height: screenHeight * 0.03),
                      _buildResetButton(),
                      if (error.isNotEmpty) ...[
                        SizedBox(height: screenHeight * 0.02),
                        _buildErrorText(),
                      ],
                      SizedBox(height: screenHeight * 0.04),
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
    return Hero(
      tag: 'logo',
      child: SizedBox(
        width: _focusMail.hasFocus ? logoSize * 0.8 : logoSize,
        child: Image.asset(
          'images/logo2.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: TextFormField(
        focusNode: _focusMail,
        validator: (value) => value?.isEmpty ?? true ? 'emptyMail'.tr : null,
        style: TextStyle(
          fontSize: AppSizes.h * 0.02,
          color: darkerBlackColour,
        ),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.emailAddress,
        onTap: () => setState(() => error = ''),
        onChanged: (value) => email = value,
        decoration: kTextFieldDecoration.copyWith(
          contentPadding: EdgeInsets.symmetric(
            vertical: AppSizes.h * 0.01,
          ),
          hintText: 'mail'.tr,
          hintStyle: const TextStyle(color: Colors.black54),
          icon: Icon(
            Icons.mail,
            size: AppSizes.h * 0.03,
            color: primaryAppColor,
          ),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
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
              Icons.local_attraction,
              color: whiteColour,
              size: AppSizes.h * 0.03,
            ),
            Padding(
              padding: EdgeInsets.all(AppSizes.h * 0.01),
              child: Text(
                'resetPassword'.tr,
                style: labelButtons.copyWith(
                  fontSize: AppSizes.h * textFactor20,
                  color: whiteColour,
                ),
              ),
            ),
          ],
        ),
      ),
      onPress: _handleResetPassword,
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

  Future<void> _handleResetPassword() async {
    setState(() {
      showSpinner = true;
      FocusScope.of(context).requestFocus(FocusNode());
    });

    if (formKey.currentState?.validate() ?? false) {
      dynamic result = await _auth2.resetPassword(email);
      setState(() {
        error = result == null ? 'emailUnknown'.tr : 'resetSuccess'.tr;
      });
    }

    setState(() {
      showSpinner = false;
    });
  }
}