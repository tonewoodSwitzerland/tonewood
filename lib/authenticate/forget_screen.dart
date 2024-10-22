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
  bool isLogin = false;
  bool showSpinner = false;
  String email = "";
  String password = "";
  String error = '';
  final formKey = GlobalKey<FormState>();
  final AuthService _auth2 = AuthService();
  final FocusNode _focusMail = FocusNode(); // Fokusvariable für E-Mail

  @override
  void initState() {
    super.initState();
    _focusMail.addListener(() {
      setState(() {}); // Aktualisiert den State, wenn der Fokus sich ändert
    });

  }

  @override
  void dispose() {
    _focusMail.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: whiteColour,
            body: Padding(
              padding: EdgeInsets.fromLTRB(isMobile, 0, isMobile, 0),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(height: h * 0.1),
                      Hero(
                        tag: 'logo',
                        child: SizedBox(
                          width:  _focusMail.hasFocus ? w * isHero*mobileFactor : w * isHero*mobileFactor,
                          child: Image.asset('images/logo2.png'),
                        ),
                      ),
                      SizedBox(height: w * 0.03),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          validator: (value) => value == "" ? 'emptyMail'.tr : null,
                          style: TextStyle(
                            color: darkerBlackColour,
                            fontSize: h * 0.02,
                          ),
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.emailAddress,
                          onTap: () {
                            setState(() => error = '');
                          },
                          onChanged: (value) {
                            email = value;
                          },
                          focusNode: _focusMail,
                          decoration: kTextFieldDecoration.copyWith(
                            contentPadding: EdgeInsets.fromLTRB(0, h * 0.01, 0, h * 0.01),
                            hintText: 'mail'.tr,
                            hintStyle: const TextStyle(color: Colors.white70),
                            icon: Icon(Icons.mail, size: h * 0.02,color:primaryAppColor),
                          ),
                        ),
                      ),
                      SizedBox(height: w * 0.03),
                      ReusableCardTouch(
                        touched: true,
                        colour:primaryAppColor,
                        cardChild: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.local_attraction, color: whiteColour, size: h * 0.05),
                            Padding(
                              padding: EdgeInsets.all(h * 0.01),
                              child: Text(
                                'resetPassword'.tr,
                                style: labelButtons.copyWith(fontSize: h * textFactor20, color: whiteColour),
                              ),
                            ),
                          ],
                        ),
                        onPress: () async {
                          setState(() {
                            showSpinner = true;
                            FocusScope.of(context).requestFocus(FocusNode());
                          });
                          dynamic result = await _auth2.resetPassword(email);
                          if (result == null) {
                            setState(() => error = 'emailUnknown'.tr);
                          } else {
                            setState(() => error = 'resetSuccess'.tr);
                          }
                          setState(() {
                            showSpinner = false;
                          });
                        },
                      ),
                      _focusMail.hasFocus ? SizedBox(height: w * 0) : SizedBox(height: w * 0.1),
                      Text(
                        error,
                        style: TextStyle(color: Colors.red, fontSize: w * 0.03),
                      ),
                      _focusMail.hasFocus  ? Container(height: 0) : SizedBox(height: w * 0.05, child: const Divider(color: Colors.white70)),
                      Center(
                        child: GestureDetector(
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Text(
                              'backLogin'.tr,
                              style: TextStyle(color: Colors.black, fontSize: h * 0.015, fontWeight: FontWeight.w300),
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, LoginScreen.id);
                          },
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
}
