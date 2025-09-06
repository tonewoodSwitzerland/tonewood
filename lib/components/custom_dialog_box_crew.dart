
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../components/circular_avatar_shadowed.dart';
import '../constants.dart';

import '../services/auto_size_text.dart';
import '../services/icon_helper.dart';


class CustomDialogBoxCrew extends StatefulWidget {
  const CustomDialogBoxCrew ({required Key key,required this.title,required  this.descriptions}) : super(key: key);
  final String title;
  final Widget descriptions;




  @override
  CustomDialogBoxCrewState createState() => CustomDialogBoxCrewState();
}

class CustomDialogBoxCrewState extends State<CustomDialogBoxCrew> {
late double w2;

  @override



  Widget build(BuildContext context) {



    w2=w*0.025;

    return Dialog(insetPadding:  EdgeInsets.symmetric(vertical: 20,horizontal: 20),


      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius),), elevation: 0, backgroundColor: Colors.transparent, child: contentBox(context),
    );
  }
  contentBox(context){
    return
      Stack(
          alignment: Alignment.bottomRight,

        children: [
          Container(
            padding: EdgeInsets.only(left: w2/3,top:  w2, right: w2/2,bottom: w2),
            margin: EdgeInsets.only(top: w2),
          decoration: BoxDecoration(shape: BoxShape.rectangle, color: Colors.white, borderRadius: BorderRadius.circular(borderRadius*2), boxShadow: const [BoxShadow(color: Colors.grey,offset: Offset(0,2), blurRadius: 2),]
          ),
          child: Column(

            mainAxisSize: MainAxisSize.min,
            children: <Widget>[


Center(child: Text( widget.title.length > 15 ? " ${ widget.title.substring(0, 13)}..." :  widget.title,style:headline4_0 ,)),


              SizedBox(height: h*0.02,child: const Divider(),),
              Container(child:widget.descriptions),
              SizedBox(height: h*0.04),
            ],
          ),
              ),
    GestureDetector(
    onTap: (){Navigator.pop(context);},
    child:  //  getAdaptiveIcon(iconName: 'arrow_drop_down',defaultIcon:Icons.arrow_drop_down, color:  blackColor, size: h * 0.03),)
    getAdaptiveIcon(iconName: 'arrow_drop_down',defaultIcon:Icons.arrow_drop_down, size: h*0.07,color:   blackColor,)

    )],
      );

  }
}


