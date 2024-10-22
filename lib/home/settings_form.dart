
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';

import '../components/circular_avatar_shadowed.dart';
import '../components/icon_content.dart';

import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../authenticate/login_screen.dart';
import '../services/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';


import '../components/standard_text_field.dart';



class SettingsForm extends StatefulWidget {
  const SettingsForm({super.key, required this.kIsWebTemp,required this.dialogContextBox, required this.contextApp,});
  final bool kIsWebTemp;

  final BuildContext dialogContextBox;
  final BuildContext contextApp;
  @override

  SettingsFormState createState() => SettingsFormState();
}

class SettingsFormState extends State<SettingsForm> {
  static final _formKey = GlobalKey<FormState>();


  late   bool pushNotification;
  late bool pushNotificationLocal;
  final FirebaseFirestore _db= FirebaseFirestore.instance;
  late  String languageLocal;
  final _auth3 = FirebaseAuth.instance;

  //final ImagePickerHelper imagePickerHelper = ImagePickerHelper();

  Uint8List webImage = Uint8List(10);



  @override
  void initState(){
    super.initState();

  }
  @override
  Widget build(BuildContext context) {

    BuildContext dialogContextBox=widget.dialogContextBox;
    BuildContext contextApp=widget.contextApp;


    void showUserManagementDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white, // Setzt den Hintergrund auf weiß
            content: Container(
              color: Colors.white,
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Benutzerverwaltung",style:headline4_0,),

                    SizedBox(height: h*0.02,child: const Divider(),),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final users = snapshot.data!.docs;
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadius),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    ListTile(
                                      leading:
                                      CircleAvatar(backgroundImage: NetworkImage(user['photoUrl']),),
                                      title: Text(user['name']),
                                      subtitle: Row(
                                        children: [
                                          const Text('Rang: '),
                                          DropdownButton<int>(
                                            dropdownColor: Colors.white,

                                            value: user['userGroup'],
                                            items: const [
                                              DropdownMenuItem(value: 1, child: Text('1'),),
                                              DropdownMenuItem(value: 2, child: Text('2'),),
                                              DropdownMenuItem(value: 3, child: Text('3'),),
                                              DropdownMenuItem(value: 4, child: Text('4'),),
                                              DropdownMenuItem(value: 5, child: Text('5'),),
                                              DropdownMenuItem(value: 6, child: Text('6'),),
                                              DropdownMenuItem(value: 7, child: Text('7'),),
                                              DropdownMenuItem(value: 8, child: Text('8'),),
                                            ],
                                            onChanged: (value) {
                                              if (user['userGroup'] == 4) {
                                               AppToast.show(message:"Administratorrechte können nicht geändert werden",height:h);
                                              } else if (value != null && value != 4) {FirebaseFirestore.instance.collection('users').doc(user.id).update({'userGroup': value});}
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Schließen'),
              ),
            ],
          );
        },
      );
    }


    Widget getUserGroupIcon(int userGroup) {
      switch (userGroup) {
        case 1:
          return const FaIcon(FontAwesomeIcons.user,size: 30,color:  primaryAppColor,);
        case 2:
          return const FaIcon(FontAwesomeIcons.userGroup,size: 30,color:  primaryAppColor);
        case 3:
          return const FaIcon(FontAwesomeIcons.helmetSafety,size: 30,color: primaryAppColor,);
        case 4:
          return const FaIcon(FontAwesomeIcons.dolly,size: 30,color: primaryAppColor,);
        case 5:
          return const FaIcon(FontAwesomeIcons.universalAccess,size: 30,color:  primaryAppColor,);
        case 6:
          return const FaIcon(FontAwesomeIcons.user,size: 30,color:  primaryAppColor);
        case 7:
          return const FaIcon(FontAwesomeIcons.user,size: 30,color: primaryAppColor,);
        case 8:
          return const FaIcon(FontAwesomeIcons.crown,size: 30,color: primaryAppColor,);
        default:
          return const FaIcon(FontAwesomeIcons.user,size: 30,color: Colors.black87,); // Standard-Icon
      }
    }



    User? user =  _auth3.currentUser;
String? email=user?.email;

    return


      Padding(
        padding: const EdgeInsets.all(8.0),
        child: StreamBuilder<DocumentSnapshot>(stream:  _db.collection('users').doc(user!.uid).snapshots(),


          builder: (context, snapshot) {
            if(!snapshot.hasData) {const Center(child: CircularProgressIndicator(),);}
            else{

             int userGroup=snapshot.data?['userGroup'];

              return Form(key: _formKey, child: SingleChildScrollView(reverse: true,
                  child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[


                      Text(email!),
                      SizedBox(height: h*0.02),


                          Column(
                            children: [

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              getUserGroupIcon(userGroup),

                              Text(" Userprofil - ",style: regularText.copyWith(fontSize:h*textFactor15),),
                                  Text(getUserGroupStatus(userGroup),style: regularText.copyWith(fontSize:h*textFactor15)),
                            ],
                          ),

                              if (userGroup == 8)
                                Column(
                                  children: [
                                    SizedBox(height: h*0.01),
                                    ElevatedButton(
                                      onPressed: () {
                                        showUserManagementDialog(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryAppColor, // Hintergrundfarbe des Buttons
                                      ),
                                      child: const Text('Benutzerverwaltung', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),


                            ],
                          ),


                      SizedBox(height: h*0.05),

                      SizedBox(height: h*0.01,child: const Divider(),),

                                Button(buttonTap:(){logout(contextApp,dialogContextBox);},buttonVerticalPadding:5,buttonHorizontalPadding:10, buttonIcon: Icons.logout,textSize: h*textFactor15,buttonTitle: 'logout',buttonColor:highlightColour,buttonSize: h*smallIconFactor,),


                    ],),
                ),
              );
            }
            return Container();
          }
        ),
      );
  }



  String getUserGroupStatus(int userGroup) {
    switch (userGroup) {
      case 1:
        return "1";
      case 2:
        return "2";
      case 3:
        return "3";
      case 4:
        return "4";
      case 5:
        return "5";
      case 6:
        return "6";
      case 7:
        return "7";
      case 8:
        return "8";
      default:
        return "Unknown user group";
    }
  }



}
void logout(contextApp,dialogContextBox) async{
  final AuthService auth = AuthService();
  await auth.signOut();
  SharedPreferences pref =await SharedPreferences.getInstance();
  pref.setBool("isLogin",false);
  Navigator.pop(dialogContextBox);
  Navigator.pushNamed(contextApp, LoginScreen.id);

}