
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import '/../components/icon_content.dart';
import '/../constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../home/feedback_text_panel.dart';
import 'custom_dialog_box_crew.dart';
class FeedbackList extends StatefulWidget {

  const FeedbackList({required Key key,}) : super(key: key);

  @override
  FeedbackListState createState() => FeedbackListState();
}

class FeedbackListState extends State<FeedbackList> {

  late String selectedName;
  late String selectedPlayer;
  late  int playerNum;
  late  int lastMatch;
  late  String lastMatchPlayers;
  String gameType ="2vs2";
  late String modus;
  Map<String, int> mapOpp ={};
  bool showDeletedFeedbackLocal=false;
  @override
  Widget build(BuildContext context) {

    final FirebaseFirestore db= FirebaseFirestore.instance;
    ScrollController scrollBarControllerTournamentDashboard = ScrollController(initialScrollOffset: 0.0);
    return

      RawScrollbar(thumbVisibility: true, thumbColor: lighterBlackColour,
    controller: scrollBarControllerTournamentDashboard,
        child: SingleChildScrollView(
        controller: scrollBarControllerTournamentDashboard,
      child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              checkColor: Colors.white,
              activeColor: Colors.blueGrey,
              value: showDeletedFeedbackLocal,
              onChanged: (value) {
                setState(() {
                  showDeletedFeedbackLocal = !showDeletedFeedbackLocal;
                });
              },
            ),
            Text('showDeletedFeedback'.tr, style: smallHeadline.copyWith(fontSize: h*textFactor13)),

          ],
        ),
        StreamBuilder(

            stream:  db.collection('feedbacks').where('alreadyChecked', isEqualTo: showDeletedFeedbackLocal).orderBy('timeStamp', descending: true).snapshots(),
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot){
              if (!snapshot.hasData) {return const Center(child: CircularProgressIndicator(),);}else{

                return
                  snapshot.data!.docs.isEmpty==true?

                  Text("noFeedbackToAnswer".tr,style: TextStyle(fontSize: h * 0.02,fontWeight: FontWeight.w600,color: standardTextColor),textAlign: TextAlign.center)

                  :

                    MasonryGridView.count(

                        shrinkWrap: true, primary: false, crossAxisCount: 1,   itemCount: snapshot.data?.docs.length, itemBuilder: (context, index) {

                      DocumentSnapshot feedback= snapshot.data!.docs[index];
                      String screenshot=feedback['screenshot'] ?? "";
                      String userID=feedback['userID'] ?? "";
                      String feedbackText=feedback['feedbackText'] ?? "";
                      bool alreadyChecked=feedback['alreadyChecked']??false;

                      bool feedbackAnswerSendToUser=feedback['feedbackAnswerSendToUser']??false;
                      String feedbackVersion=feedback['version'] ?? "";
                      String feedbackModel=feedback['model'] ?? "";
                      String feedbackManufacturer=feedback['manufacturer'] ?? "";
                      var timestamp =feedback['timeStamp'];


                      return Padding(padding: EdgeInsets.only(top: h * 0.001,bottom: h * 0.01),
                          child: GestureDetector(

                            child:   ListTile(
                              title: Container(
                                height:       h*0.75,
                                padding: EdgeInsets.all(h*0.01), decoration: BoxDecoration(shape: BoxShape.rectangle, color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black,offset: Offset(0,1), blurRadius: 1),]),
                                child:

                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Text(DateFormat('dd-MM-yyy').format(timestamp.toDate()), style: TextStyle(fontSize: h * 0.02, fontWeight: FontWeight.w600, color: standardTextColor)),
                                      Text(" - ",style: TextStyle(fontSize: h * 0.02,fontWeight: FontWeight.w600,color: standardTextColor),textAlign: TextAlign.center),
                                    ],),
                                    Text(feedbackText,style: TextStyle(fontSize: h * 0.02,fontWeight: FontWeight.w600,color: standardTextColor),textAlign: TextAlign.center),

                                    Column(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(1.0), // Du kannst die Ecken nach deinem Wunsch anpassen
                                              child: Container(
                                                width: w*0.5, // Breite basierend auf dem Radius des CircleAvatar
                                                height: h*0.5, // Höhe basierend auf dem Radius des CircleAvatar
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1.0), // Grauer Rand
                                                  borderRadius: BorderRadius.circular(1.0),
                                                  image: DecorationImage(
                                                    fit: BoxFit.cover,
                                                    image: screenshot == ""
                                                        ? const AssetImage("images/k1.png")
                                                        : NetworkImage(screenshot) as ImageProvider,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          ],
                                        ),
                                    Text(feedbackVersion,style: TextStyle(fontSize: h * 0.02,fontWeight: FontWeight.w300,color: standardTextColor),textAlign: TextAlign.center),
                                    Text(feedbackManufacturer,style: TextStyle(fontSize: h * 0.02,fontWeight: FontWeight.w300,color: standardTextColor),textAlign: TextAlign.center),
                                    Text(feedbackModel,style: TextStyle(fontSize: h * 0.02,fontWeight: FontWeight.w300,color: standardTextColor),textAlign: TextAlign.center),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        GestureDetector(
                                          onTap: (){
                                           if(feedbackAnswerSendToUser==false){sendFeedbackToUser(context,feedback.id,userID,"");
                                           }else{
                                             AppToast.show(message: "feedbackAlreadySent".tr, height: h);
                                           }

                                          },child: IconContent(iconStyle:  Icons.question_answer, iconSize: h * textFactor25, label:  "answerFeedback".tr,color: feedbackAnswerSendToUser==false?primaryAppColor:Colors.grey)),

                                        GestureDetector(
                                            onTap: (){
                                              if(alreadyChecked==false){
                                              db.collection('feedbacks').doc(feedback.id).set({'alreadyChecked':true},SetOptions(merge: true));
                                              AppToast.show(message: "feedbackDeleted".tr, height: h);
}else{ AppToast.show(message: "feedbackAlreadyDeleted".tr, height: h);}
                                            },
                                            child: IconContent(iconStyle:  Icons.delete, iconSize: h * textFactor25, label:  "deleteFeedback".tr,color: alreadyChecked==false?primaryAppColor:Colors.grey)),
                                      ],
                                    )


                                  ],
                                  ),
                              ),
                            )
                      ));

                    });

              }}
        ),
      ],
    )
    )); }

  void sendFeedbackToUser(BuildContext context,String feedbackID, String userID,String leagueName){showDialog(useRootNavigator:false, context:context, builder: (BuildContext context)  {return CustomDialogBoxCrew(key:UniqueKey(), title: "feedbackToUser".tr, descriptions: FeedbackTextPanel(feedbackID: feedbackID,userID: userID,leagueName: leagueName,));});}

}


