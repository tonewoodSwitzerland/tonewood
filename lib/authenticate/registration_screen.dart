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
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(height: h * 0.05),
                      Hero(
                        tag: 'logo',
                        child: SizedBox(

                          width: _focusMail.hasFocus || _focusPW.hasFocus || _focusInvite.hasFocus
                              ? w *isHero*mobileFactor
                              : w * isHero*mobileFactor,
                          child: Image.asset('images/logo2.png'),
                        ),
                      ),
                      SizedBox(height: h * 0.03),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextFormField(
                          validator: (value) => value!.isEmpty ? 'emptyMail'.tr : null,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: h * 0.02, color: darkerBlackColour),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            email = value;
                          },
                          focusNode: _focusMail,
                          decoration: kTextFieldDecoration.copyWith(
                            contentPadding: EdgeInsets.fromLTRB(0, h * 0.01, 0, h * 0.01),
                            hintText: 'mail'.tr,
                            hintStyle: const TextStyle(color: darkerBlackColour),
                            icon: Icon(Icons.mail, size: h * 0.02,color:primaryAppColor),
                          ),
                        ),
                      ),
                      SizedBox(height: h * 0.03),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextFormField(
                          validator: (value) =>
                          value!.length < 6 ? 'passwordError'.tr : null,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: h * 0.02, color: darkerBlackColour),
                          obscureText: _obscureText,
                          onChanged: (value) {
                            password = value;
                          },
                          focusNode: _focusPW,
                          decoration: kTextFieldDecoration.copyWith(
                            contentPadding: EdgeInsets.fromLTRB(0, h * 0.01, 0, h * 0.01),
                            hintText: 'password'.tr,
                            hintStyle: const TextStyle(color: darkerBlackColour),
                            icon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                              child: Icon(Icons.remove_red_eye_outlined, size: h * 0.02,color:primaryAppColor),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: h * 0.03),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextFormField(
                          validator: (value) => value!.isEmpty ? 'emptyInvite'.tr : null,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: h * 0.02, color: darkerBlackColour),
                          onChanged: (value) {
                            invitationCode = value;
                          },
                          focusNode: _focusInvite,
                          decoration: kTextFieldDecoration.copyWith(
                            contentPadding: EdgeInsets.fromLTRB(0, h * 0.01, 0, h * 0.01),
                            hintText: 'inviteCode'.tr,
                            hintStyle: const TextStyle(color: darkerBlackColour),
                            icon: Icon(Icons.link, size: h * 0.02,color:primaryAppColor),
                          ),
                        ),
                      ),
                      SizedBox(height: h * 0.03),
                      ReusableCardTouch(
                        touched: true,
                        colour:primaryAppColor,
                        cardChild: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.app_registration, color: whiteColour, size: h * 0.05),
                            Padding(
                              padding: EdgeInsets.all(h * 0.01),
                              child: Text(
                                'register'.tr,
                                style: labelButtons.copyWith(
                                    fontSize: h * textFactor20, color: whiteColour),
                              ),
                            ),
                          ],
                        ),
                        onPress: () async {
                          setState(() {
                            showSpinner = true;
                          });
                          await register(context);
                          setState(() {
                            showSpinner = false;
                          });
                        },
                      ),
                      SizedBox(height: h * 0.05),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontSize: 25),
                      ),
                      SizedBox(height: h * 0.05),
                      SizedBox(height: w * 0.05, child: const Divider(color: Colors.white70)),
                      Center(
                        child: GestureDetector(
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Text(
                              'backLogin'.tr,
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: h * 0.015,
                                  fontWeight: FontWeight.w300),
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

  Future<void> register(context) async {
    if (_formKey.currentState!.validate()) {
      try {
        // Validate the invitation code
        final inviteDoc = await _db.collection('secrets').doc(invitationCode).get();

        // Check if document exists and has the 'userGroup' field
        if (!inviteDoc.exists || !inviteDoc.data()!.containsKey('userGroup')) {
          setState(() {
            error = 'invalidInvite'.tr;
            showSpinner = false;
          });
          return;
        }

        // Retrieve user group from the invite document
        int userGroup = inviteDoc.data()!['userGroup'];

        dynamic result = await _auth2.registerWithEmailAndPassword(email, password);
        if (result == null) {
          setState(() => error = 'validEmail'.tr);
        } else {
          _db.collection('total').doc('stats').set(
              {'usersCount': FieldValue.increment(1)}, SetOptions(merge: true)); // Daten für die Gesamtstatistik
          User? user = _auth3.currentUser;
          _db.collection('users').doc(user!.uid).set(
              {
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
              },
              SetOptions(merge: true));

          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const VerifyScreen()));
        }
      } on FirebaseException catch (e) {
        print(e.code);
        if (e.code == 'not-found') {
          setState(() {
            error = 'invalidInvite'.tr;
          });
        } else {
          setState(() {
            error = 'registrationError'.tr;
          });
        }
      } finally {
        setState(() {
          showSpinner = false;
        });
      }
    }
  }


}
