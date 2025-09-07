
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


import 'package:package_info_plus/package_info_plus.dart';

import '../services/icon_helper.dart';


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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _auth3 = FirebaseAuth.instance;
  PackageInfo? packageInfo;
  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      packageInfo = info;
    });
  }
  void showUserManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
               getAdaptiveIcon(iconName: 'manage_accounts',defaultIcon:Icons.manage_accounts, color: const Color(0xFF0F4A29)),
              SizedBox(width: 8),
              Text('Benutzerverwaltung'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: StreamBuilder<QuerySnapshot>(
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
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                          child: Text(
                            user['name'][0].toUpperCase(),
                            style: TextStyle(
                              color: const Color(0xFF3E9C37),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(user['name']),
                        subtitle: Row(
                          children: [
                            Text('Benutzergruppe: '),
                            DropdownButton<int>(
                              value: user['userGroup'],
                              items: List.generate(8, (index) => index + 1).map((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: value == user['userGroup']
                                          ? const Color(0xFF0F4A29).withOpacity(0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      value.toString(),
                                      style: TextStyle(
                                        color: value == user['userGroup']
                                            ? const Color(0xFF0F4A29)
                                            : Colors.black87,
                                        fontWeight: value == user['userGroup']
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (user['userGroup'] == 4) {
                                  AppToast.show(
                                      message: "Administratorrechte können nicht geändert werden",
                                      height: h
                                  );
                                } else if (value != null && value != 4) {
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.id)
                                      .update({'userGroup': value});
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  @override

  void initState() {
    super.initState();
    _initPackageInfo();

  }



  Widget build(BuildContext context) {
    User? user = _auth3.currentUser;
    String? email = user?.email;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          int userGroup = snapshot.data?['userGroup'] ?? 1;

          return Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User Info Card
                Text(
                  'Version: ${packageInfo?.version ?? ""}',
                  style: smallestHeadline,
                ),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Benutzer-Informationen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F4A29),
                          ),
                        ),
                        Divider(height: 24),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F4A29).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:

                              getAdaptiveIcon(iconName: 'person', defaultIcon:
                                Icons.person,
                                color: const Color(0xFF3E9C37),
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Benutzergruppe: ${getUserGroupStatus(userGroup)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Admin Button wenn Benutzergruppe 8
                if (userGroup == 8)
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    child: ElevatedButton.icon(
                      onPressed: () => showUserManagementDialog(context),
                      icon:  getAdaptiveIcon(iconName: 'admin_panel_settings',defaultIcon:Icons.admin_panel_settings),
                      label: Text('Benutzerverwaltung'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3E9C37),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                // Logout Button
                ElevatedButton.icon(
                  onPressed: () => logout(widget.contextApp, widget.dialogContextBox),
                  icon:  getAdaptiveIcon(iconName: 'logout',defaultIcon:Icons.logout,color: Colors.white,),
                  label: Text('Abmelden'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAppColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

void logout(contextApp,dialogContextBox) async{
  final AuthService auth = AuthService();
  await auth.signOut();
  SharedPreferences pref =await SharedPreferences.getInstance();
  pref.setBool("isLogin",false);
  Navigator.pop(dialogContextBox);
  Navigator.pushNamed(contextApp, LoginScreen.id);

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