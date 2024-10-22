
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../components/reusable_cart.dart';

import '../constants.dart';



class AdminForm extends StatefulWidget {
const AdminForm({super.key,});

  @override
  AdminFormState createState() => AdminFormState();
}

class AdminFormState extends State<AdminForm> {

  Future<void> _updateData() async {


   QuerySnapshot snapshot2 = await FirebaseFirestore.instance.collection('companies').doc('100').collection('packages').get();
   snapshot2.docs.forEach((document) async {

      if(document.exists) {

        FirebaseFirestore.instance.collection('companies').doc('100').collection('packages').doc(document.id).set({'Id27': "Nein"}, SetOptions(merge:true));

 }

 });

  }


  @override
  Widget build(BuildContext context) {

          return SingleChildScrollView(reverse: true,
            child:
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(height: w*0.05),


                Column(

                  children: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(FontAwesomeIcons.penToSquare, size: 20.5 * w * 0.003,color: lighterBlackColour,),
                        SizedBox(width: w*0.02),
                        Text("Admin", style: TextStyle( fontSize: w*0.04, color:lighterBlackColour)),
                      ],
                    ),

                    SizedBox(height: w*0.08),
                    ReusableCardTouch( cardChild: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                      FaIcon(FontAwesomeIcons.cloudArrowUp, color: lighterBlackColour, size: SizeConfig.blockSizeHorizontal * 6,),
                      Padding(padding: const EdgeInsets.all(6), child: Text('Update', style: TextStyle(fontSize:  0.05*w, fontWeight: FontWeight.w400, color: lighterBlackColour,)),)
                    ],),
                      colour: Colors.black12,
                      onPress:() async {_updateData();}, touched: true ,
                    ),

                    SizedBox(height: w*0.05, child: const Divider(color:primaryAppColor)),
                  ],
                ),

              ],
            ),

          );

  }
}
