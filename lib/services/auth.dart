import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:get/get_utils/src/extensions/internacionalization.dart';

class AppUser {
  final String uid;

  AppUser({required this.uid, });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  AppUser? _userFromFirebaseUser(User? user){ return user != null ? AppUser(uid: user.uid) : null;}
  Stream<AppUser?> get user {return _auth.authStateChanges().map(_userFromFirebaseUser);}
 
  final FirebaseFirestore _db= FirebaseFirestore.instance;
late Map userProfile;
  late String photoUrlFb;
  late String nameFb;
  late String result;

  

  Future signInWithEmailAndPassword(String email, String password) async {

    try {
     UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
     User? user = result.user;
      return _userFromFirebaseUser(user!);
    } catch(e){
      return null;
    }
  }

  Future signInAnonymously()  async{
    var d1= await _db.collection('total').doc('stats').get();
    int anonymousAppUsersCount= d1.data()?['anonymousAppUsersCount'];

    String AppUser='AppUser'.tr;
   await _auth.signInAnonymously().then((result) {
     anonymousAppUsersCount++;
         User? user = result.user;
        _db.collection('users').doc(user!.uid).set({'anonymous':true, 'name': '$AppUser $anonymousAppUsersCount', 'loginType': "Email",'photoUrl': '', 'created': 0, 'currentCompany': "Example Company",'proAccount':3,'pushNotification':false, 'language':"de", 'leagueCount': 0, 'createdAt': FieldValue.serverTimestamp(),'firstLaunch':false}, SetOptions(merge: true));
        _db.collection('users').doc(user.uid).collection('companies').doc('exampleCompany').set({'accepted': 2, 'name': "Example Company",'logo':"" ,'companyID': "currentCompany", 'createdAt': FieldValue.serverTimestamp(),'pushNotification':false,}, SetOptions(merge: true));



    });
    return user;
  }



  Future registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        User? user = result.user;
        user!.sendEmailVerification();
      return _userFromFirebaseUser(user);
    } catch(e){
      return null;
    }
  }

  

  Future resetPassword(String email) async {

    try{
      await _auth.sendPasswordResetEmail(email: email);
      return result="true";
    } catch(e){
      return result="false";
    }
  }

Future signOut() async { try { return await _auth.signOut();}catch(e) { return null;} }

Future<void> checkEmailVerified() async {

}

}
