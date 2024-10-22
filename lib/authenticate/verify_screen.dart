import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'dart:async';
import '../home/start_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../authenticate/login_screen.dart';
import '../services/auth.dart';
import '../constants.dart';

class VerifyScreen extends StatefulWidget {

  const VerifyScreen({super.key});
  @override

  VerifyScreenState createState() => VerifyScreenState();
}

class VerifyScreenState extends State<VerifyScreen> {
final auth = FirebaseAuth.instance;
late User user;
late Timer timer;
final AuthService _auth = AuthService();

  @override
  void initState() {
   user = auth.currentUser!;
   user.sendEmailVerification();

  timer= Timer.periodic((const Duration(seconds: 5)), (timer) {
     checkEmailVerified(context);
   });
    super.initState();
  }

  @override
  void dispose(){
    timer.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:  Row(
          children: [

            GestureDetector(child: Image.asset('images/logo2.png',fit:BoxFit.scaleDown, height: 50,)),
            const SizedBox(width: 20,),
            //  Text("Liga BP6", style: TextStyle(color:Colors.white, fontFamily: CupertinoIcons.iconFont),),
          ],
        ),
        backgroundColor: basicBackgroundColour,
        elevation: .5,
        actions: <Widget>[
          TextButton.icon(
            icon: const Icon(Icons.person, color: Colors.white,), label: const Text('logout', style: TextStyle(color:Colors.white),),onPressed: () async{
            await logout(context);

          },
          ),

          const SizedBox(width:20),

        ],
      ),
      body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height:50),
          Text("emailSent".tr),
        ],
      )),//Text("Email has been send"),
      bottomNavigationBar: BottomNavigationBar(
backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      unselectedItemColor: lighterBlackColour,
      showSelectedLabels: false,
      showUnselectedLabels: false,

      items:
      [BottomNavigationBarItem(icon: const FaIcon(FontAwesomeIcons.house), label: "dashboard".tr),
        BottomNavigationBarItem(icon: const Icon(Icons.document_scanner_outlined), label: "scanner".tr),
      ],
      ),
    );
  }

  Future<void> logout(context) async {
     await _auth.signOut();
    SharedPreferences pref =await SharedPreferences.getInstance();
    pref.setBool("isLogin",false);
    Navigator.pushNamed(context, LoginScreen.id);
  }

  Future<void> checkEmailVerified(context) async{
    user=auth.currentUser!;
    await user.reload();
    if(user.emailVerified){
      timer.cancel();
      Navigator.pushNamed(context, StartScreen.id);
    }
  }


}