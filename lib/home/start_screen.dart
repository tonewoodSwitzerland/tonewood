import 'package:feedback/feedback.dart';

import 'package:get/get.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../components/admin_form.dart';
import '../components/circular_avatar_shadowed.dart';
import '../constants.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../home/settings_form.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


import '../components/custom_dialog_box_crew.dart';
import '../components/feedback_list.dart';

import '../services/feedback_functions.dart';
import 'calculator_screen.dart';


class StartScreen extends StatefulWidget {
  static String id ='start_screen';

  const StartScreen({required Key key}) : super(key: key);

  @override
  StartScreenState createState() => StartScreenState();
}

class StartScreenState extends State<StartScreen> {
  final _auth3 = FirebaseAuth.instance;
  final FirebaseFirestore _db= FirebaseFirestore.instance;

  late Future<User>getCurrUserFuture;


  bool animationStop=false; /// Wird genutzt, um zu triggern, ob die Beispielliga Text Animation fertig ist
  late  String firstCreated;
  late String loginType;
   int userGroup=1;
  late  String companyName;
  late int leagueCount;
  late   int playersCount;
  late  int gamesCount;
  late  int goalsCount;
  late String name;

  late int cC;
  late Map playersData;
  late  User user;


  @override
  void initState() {super.initState();
  getCurrUserFuture=  getCurrUser();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,]);



  }





  _adminPanel(user) {

    if(user=="0Twdd2EtJGcymHCA31GY6moAmU33"){

      showModalBottomSheet(isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.0))),
          context: context, builder: (context){

            return Container(padding:EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: const AdminForm(),);
          });

    }
  }




  Future<User> getCurrUser() async {
    late  User userTemp;
    FirebaseAuth.instance.authStateChanges()
        .listen((User? user) {if (user != null) {userTemp=user;}
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    await Future.delayed(const Duration(milliseconds: 1500));

    return userTemp;

  }

  void _showSettingsPanel2(){
    showDialog(
        useRootNavigator:false,
        context: context,
        builder: (BuildContext dialogContext){
          return CustomDialogBoxCrew( key: UniqueKey(), title: "Profil", descriptions:  SettingsForm(kIsWebTemp: false,dialogContextBox: dialogContext,contextApp: context));
        }

    );

  }

  _feedbackPanel(user) {

    if(user=="0Twdd2EtJGcymHCA31GY6moAmU33"){

      showDialog(useRootNavigator:false, context:context, builder: (BuildContext context) {return CustomDialogBoxCrew(

          key:UniqueKey(),title: "feedback".tr,descriptions: SizedBox(

          height: 0.7*h,
          child:  GestureDetector(onTap:(){},child:
          FeedbackList( key: UniqueKey(),)

          )));});




    }
  }


  int _currentIndex =0;



  Future<void>onTappedBar(int index) async {
    User? user =  _auth3.currentUser;
    setState(() {
      if(user!.providerData.isEmpty==true){
        _currentIndex=index;}else{
        if(user.emailVerified ||user.providerData[0].providerId=="apple.com"){_currentIndex=index;}else{
        //  _registerPanel();
        }}})
    ;}



  @override
  Widget build(BuildContext context) {
    final List<Widget>_children=[


        CalculatorScreen(key: UniqueKey()),
      CalculatorScreen(key: UniqueKey()),
    ];

    String photoPic;
    bool _useCustomFeedback = false;

    return Padding(
      padding:  const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: FutureBuilder<User>(
            future: getCurrUserFuture,
            builder: (context, snapshotUser) {
              if (snapshotUser.hasData) {
                user=snapshotUser.data!;

                return Scaffold(
                  resizeToAvoidBottomInset: false,
                  appBar: AppBar(
                    //  toolbarHeight: platF == 1 ? h * 0.051 : h * 0.051,
                    automaticallyImplyLeading: false,
                    titleSpacing: 10,
                    title:
                    Column(
                      children: [
                        StreamBuilder<DocumentSnapshot>(
                            stream: _db.collection('users').doc(
                                user.uid).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return
                                  const Center(child:
                                    CircularProgressIndicator(
                                    color: Colors.blue,
                                    ),

                                );
                              } else {
                                photoPic =  snapshot.data?['photoUrl'];


                                name  =snapshot.data?['name'];
                              }


                                      return Row(

                                        mainAxisAlignment: MainAxisAlignment
                                            .spaceBetween, children: [

                                        SizedBox(width: w * 0.01,),

                                        Expanded(flex: 3,
                                            child: GestureDetector(child: const FaIcon(FontAwesomeIcons.solidComment, color: Color(0xFFE6E6E6)),
                                              onLongPress: () => _adminPanel(user.uid),
                                              onDoubleTap:  () => _feedbackPanel(user.uid),
                                              onTap: () {
                                                BetterFeedback.of(context).show(
                                                      (feedback) async {
                                                    // upload to server, share whatever
                                                    // for example purposes just show it to the user
                                                    WidgetsFlutterBinding.ensureInitialized();
                                                    PackageInfo packageInfo = await PackageInfo.fromPlatform();

                                                    String packageName = packageInfo.packageName;
                                                    String version = packageInfo.version;
                                                    String buildNumber = packageInfo.buildNumber;

                                                    alertFeedbackFunction2( name, user.uid,  feedback,packageName,version,buildNumber);




                                                    AppToast.show(message: "feedbackSent".tr, height: h);
                                                  },
                                                );
                                              },)),


                                        Expanded(flex: 15,
                                          child: SizedBox(
                                            height: kToolbarHeight,
                                            child: Padding(
                                              padding:  EdgeInsets.all( isMobile/10),
                                              child: Image.asset('images/logo3.png',   fit: BoxFit.contain,),
                                            ),
                                          ),
                                        ),


                                        Expanded(
                                          flex:  4,
                                          child:
                                            Center(
                                              child: GestureDetector(

                                                child: Padding(
                                                  padding: const EdgeInsets.all(15.0),
                                                  child: CircleAvatarShadowedNoImage(
                                                      key: UniqueKey(),  shadow: 0, w: 350, photoPlayer: photoPic),
                                                ), onTap: () => _showSettingsPanel2(),),
                                            ),

                                        ),


                                      ],
                                      );
                                    }

                        ),
                        Divider(
                          height: 2, // Höhe des Dividers
                          color: lightGrayColor, // Farbe des Dividers
                          thickness: 2, // Dicke des Dividers
                        ),
                      ],
                    ),

                    backgroundColor:Colors.white,
                    elevation: .5,
                    actions: const <Widget>[
                    ],
                  ),
                  body: _children[_currentIndex],
                  bottomNavigationBar:
                  StreamBuilder<DocumentSnapshot>(
                      stream: _db.collection('users').doc(user.uid).snapshots(),
                      builder:
                          (BuildContext context,
                          AsyncSnapshot<DocumentSnapshot> snapshot2) {
                        if (!snapshot2.hasData) {
                          return  Center(child: CircularProgressIndicator(

                              )
                          );
                        } else {

                          try {
                            loginType = snapshot2.data?['loginType'];
                           userGroup = snapshot2.data?['userGroup'];
                          } catch (error) {
                            loginType="unknown";
                          }

                          return SizedBox(
                            child: BottomNavigationBar(
                              backgroundColor: Colors.white,
                              type: BottomNavigationBarType.fixed,
                              unselectedItemColor: lighterBlackColour,
                              selectedItemColor: primaryAppColor,
                              showSelectedLabels: false,
                              showUnselectedLabels: false,


                              onTap:  onTappedBar,
                              currentIndex: _currentIndex,
                              items:
                              [


                                BottomNavigationBarItem(icon: const FaIcon(FontAwesomeIcons.map), label: "map".tr),
                                BottomNavigationBarItem(icon: const FaIcon(FontAwesomeIcons.tree), label: "wood".tr),

                              ],
                            ),
                          );
                        }
                      }
                  ),
                );
              } else {

                return  //Column(
                  //children: [
                    const Center(
                      child:
                      CircularProgressIndicator(
                  //  color: Colors.green,
                      ),

                  //  ),
                  //  Button(buttonTap:(){logout(context,context);},buttonVerticalPadding:20,buttonHorizontalPadding:10, buttonIcon: Icons.logout,textSize: h*textFactor15,buttonTitle: 'logout',buttonColor:highlightColour,buttonSize: h*smallIconFactor,),

                //  ],
                );
              }
            }
        ),
      ),
    );
  }

}




