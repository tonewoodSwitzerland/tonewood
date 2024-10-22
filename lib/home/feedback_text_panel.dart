
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:flutter/material.dart';
import '/../constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/icon_content.dart';

class FeedbackTextPanel extends StatefulWidget {
const FeedbackTextPanel({super.key,required this.feedbackID,required this.userID,required this.leagueName});
final String feedbackID;
final String userID;
final String leagueName;
  @override
  FeedbackTextPanelState createState() => FeedbackTextPanelState();
}

class FeedbackTextPanelState extends State<FeedbackTextPanel> {
  final FocusNode _focusName = FocusNode(); /// Der Wert detektiert, ob die Logo Auswahl ausgeblendet werden soll

  final _formKey = GlobalKey<FormState>();



  String error="";

  String feedbackText="";

  final FirebaseFirestore db= FirebaseFirestore.instance;


  @override
  void initState() {super.initState();

  _focusName.addListener(_onFocusChange);

  }


  void _onFocusChange(){

  }

  @override
  Widget build(BuildContext context) {
    String feedbackID=widget.feedbackID;
    String leagueName=widget.leagueName;
    String userID=widget.userID;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[

          TextFormField(
            onTap: (){setState(() {});},
            focusNode: _focusName,
            style:regularText.copyWith(fontSize:h*textFactor20), decoration: kTextFieldDecoration.copyWith(hintText: 'feedbackStandardText'.tr,), validator: (value) =>value!.length >25 ? 'maxChars'.tr : null, onChanged: (val) => setState(({error=" "}) =>   feedbackText=val),),
          SizedBox(height: h*0.02),

          error==""?Container():Text(error, style: TextStyle(color: Colors.red, fontSize:h*textFactor15)),

        GestureDetector(
            onTap: () async {

              db.collection('feedbacks').doc('feedbackAnswer').set({'feedbackText':feedbackText==""?'feedbackStandardText'.tr:feedbackText,'leagueName':leagueName,'userID':userID},SetOptions(merge: true));
              db.collection('feedbacks').doc(feedbackID).set({'feedbackAnswerSendToUser':true},SetOptions(merge: true));
              Navigator.pop(context);
              AppToast.show(message: "feedbackAnswerSent".tr, height: h);
            },
            child: IconRow(iconStyle:  Icons.message_outlined, iconSize: h * textFactor25, label:  "sendFeedbackToUser".tr,color: Colors.pink)),


        ],
      ),
      ),
    );
  }



}







