import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';

import '../constants.dart';

class IconContent extends StatelessWidget {
  const IconContent({super.key, required this.iconStyle,required this.label,required this.iconSize,required this.color});
  final IconData iconStyle;
  final String label;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {


    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(iconStyle, size: iconSize, color: color),
        SizedBox(
          height: iconSize/9,
        ),
        Text(label,style:  TextStyle(fontSize: iconSize*0.45, fontWeight: FontWeight.w600, color: standardTextColor,),textAlign: TextAlign.center,
          )
      ],
    );
  }
}
class IconContentPermission extends StatelessWidget {
  const IconContentPermission({super.key, required this.iconStyle,required this.label,required this.explanation,required this.color,required this.shadow});
  final IconData iconStyle;
  final String label;
  final String explanation;
  final Color color;
  final double shadow;

  @override
  Widget build(BuildContext context) {
  //   double
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Container(height:h*0.04 , decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: lighterBlackColour) ,boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: shadow, blurRadius: shadow*2/3, offset: Offset(0, shadow), ),],),
         child: Center(child: Icon(iconStyle, size: h*0.02, color: color ),)),
        SizedBox(height: h*0.005,),
        Text(label,style:  TextStyle(fontSize: h*textFactor15, fontWeight: FontWeight.w600, color: standardTextColor,),textAlign: TextAlign.center,),
        SizedBox(height: h*0.010, child: const Divider(color: lighterBlackColour)),
        Text(explanation,style:  TextStyle(fontSize: h*textFactor13, fontWeight: FontWeight.w600, color: standardTextColor,),textAlign: TextAlign.center,)
      ],);
  }
}

class IconContentNoText extends StatelessWidget {
  const IconContentNoText({super.key, required this.iconStyle,required this.iconSize,required this.color,required this.toolTipMessage});
  final IconData iconStyle;
  final double iconSize;
  final Color color;
final String toolTipMessage;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Tooltip(
          triggerMode: TooltipTriggerMode.tap,
          message: toolTipMessage,
          child: Icon(
            iconStyle,
            size: iconSize,
            color: color
          ),
        ),
      ],
    );
  }
}



class IconRow extends StatelessWidget {
  const IconRow({super.key, required this.iconStyle,required this.label,required this.iconSize,required this.color});
  final IconData iconStyle;
  final String label;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // double
  //   double
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            iconStyle,
            size: iconSize,
            color: color
          ),
          SizedBox(width: iconSize/2,
          ),
          Text(label,style:  TextStyle(fontSize:h*0.02, fontWeight: FontWeight.w600, color: Colors.black,)

          )
        ],
      ),
    );
  }
}
class IconCircledTransparent extends StatelessWidget {
  const IconCircledTransparent({super.key, required this.iconStyle,required this.iconSize,required this.iconColor,required this.shadow,required this.toolTip});
  final IconData iconStyle;
  final Color iconColor;
  final double iconSize;
  final String toolTip;
  final double shadow;

  @override
  Widget build(BuildContext context) {

    return Tooltip(
      message: toolTip,
      triggerMode: TooltipTriggerMode.tap,

      child: Container(
          height:iconSize*2 ,
          width: iconSize*2,
          decoration: BoxDecoration( shape: BoxShape.circle,
            border: Border.all(color: lighterBlackColour) ,

          ),

          child: Center(child: FaIcon(iconStyle, size: iconSize,color:  iconColor,))),
    );
  }




}

class IconCircled extends StatelessWidget {
  const IconCircled({super.key, required this.iconStyle,required this.iconSize,required this.iconColor,required this.shadow,required  this.toolTip});
  final IconData iconStyle;
  final Color iconColor;
  final double iconSize;
  final String toolTip;
  final double shadow;

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: (){ AppToast.show(message: toolTip, height: h);},
      child: Container(
          height:iconSize*1.7 ,
          width: iconSize*1.7,
          decoration: BoxDecoration(color: Colors.white70, shape: BoxShape.circle,
            border: Border.all(color: Colors.black12) ,
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: shadow, blurRadius: shadow*2/3, offset: Offset(0, shadow), // changes position of shadow
              ),
            ],

          ),

          child: Center(child: FaIcon(iconStyle, size: iconSize,color:  iconColor,))),
    );
  }




}

class IconCircledText extends StatelessWidget {
  const IconCircledText({super.key, required this.iconStyle,required this.iconSize,required this.iconColor,required this.shadow,required this.toolTip,required this.explanation});
  final IconData iconStyle;
  final Color iconColor;
  final double iconSize;
  final String toolTip;
  final double shadow;
  final String explanation;

  @override
  Widget build(BuildContext context) {

    return Tooltip(
      message: toolTip,
      triggerMode: TooltipTriggerMode.tap,
      textStyle: TextStyle(fontSize: iconSize*0.5, fontWeight: FontWeight.w400, color: Colors.white,),
      decoration: const BoxDecoration(color: standardTextColor

      ),
      child: Column(
        children: [
          Container(
              height:iconSize*2 ,
              width: iconSize*2,
              decoration: BoxDecoration(color: Colors.white70, shape: BoxShape.circle,
                border: Border.all(color: Colors.black12) ,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: shadow, blurRadius: shadow*2/3, offset: Offset(0, shadow), // changes position of shadow
                  ),
                ],
              ),
              child: Center(child: FaIcon(iconStyle, size: iconSize,color:  iconColor,))),
          SizedBox(height: iconSize/4,
          ),
      Text(explanation,style:  TextStyle(fontSize: iconSize*0.5, fontWeight: FontWeight.w300, color: lighterBlackColour,))
        ],
      ),
    );
  }




}

class IconCircledEmpty extends StatelessWidget {
  const IconCircledEmpty({super.key, required this.iconSize,});


  final double iconSize;


  @override
  Widget build(BuildContext context) {

    return SizedBox(
        height:iconSize*2 ,
        width: iconSize*2,
        );
  }
}



class Button extends StatelessWidget {

  const Button({super.key, required this.buttonTap,required this.buttonVerticalPadding,required this.buttonHorizontalPadding ,required this.buttonTitle, required this.buttonIcon, required this.textSize,required this.buttonColor, required this.buttonSize});
  final void Function() buttonTap;
  final String buttonTitle;
  final double textSize;
  final IconData buttonIcon;
  final Color buttonColor;
  final double buttonSize;
  final double buttonVerticalPadding;
  final double buttonHorizontalPadding;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: buttonTap,
      child: Padding(
        padding:  EdgeInsets.symmetric(vertical:buttonVerticalPadding, horizontal: buttonHorizontalPadding),
        child: Row(
          children: [
            Icon(buttonIcon, color: buttonColor,size: buttonSize,),
            const SizedBox(width: 10),
            Text(buttonTitle, style: regularText.copyWith(fontSize:textSize)),
          ],),
      ),
    );
  }
}



class IconCircledText2 extends StatelessWidget {
  const IconCircledText2({super.key, required this.iconStyle,required this.iconSize,required this.iconColor,required this.shadow,required this.text});
  final IconData iconStyle;
  final Color iconColor;
  final double iconSize;
  final double shadow;
  final String text;

  @override
  Widget build(BuildContext context) {

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
            height:iconSize*2 ,
            width: iconSize*2,
            decoration: BoxDecoration(color: Colors.white70, shape: BoxShape.circle,
              border: Border.all(color: lighterBlackColour) ,
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: shadow, blurRadius: shadow*2/3, offset: Offset(0, shadow), // changes position of shadow
                ),
              ],

            ),

            child: Center(child: FaIcon(iconStyle, size: iconSize,color:  iconColor,))),
        SizedBox(height: iconSize*0.2),
        Text(text,
          style:  TextStyle(fontSize: iconSize*0.5, fontWeight: FontWeight.w600, color: standardTextColor,),textAlign: TextAlign.center,)

      ],
    );
  }
}


class IconCircledNoToolTip extends StatelessWidget {
  const IconCircledNoToolTip({super.key, required this.iconStyle,required this.iconSize,required this.iconColor,required this.shadow});
  final IconData iconStyle;
  final Color iconColor;
  final double iconSize;
  final double shadow;

  @override
  Widget build(BuildContext context) {

    return Container(
        height:iconSize*2 ,
        width: iconSize*2,
        decoration: BoxDecoration(color: Colors.white70, shape: BoxShape.circle,
          border: Border.all(color: lighterBlackColour) ,
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: shadow, blurRadius: shadow*2/3, offset: Offset(0, shadow), // changes position of shadow
            ),
          ],

        ),

        child: Center(child: FaIcon(iconStyle, size: iconSize,color:  iconColor,)));
  }
}

class IconCircledChoosePlayer extends StatelessWidget {
  const IconCircledChoosePlayer({super.key, required this.iconStyle,required this.iconSize,required this.iconColor,required this.shadow});
  final IconData iconStyle;
  final Color iconColor;
  final double iconSize;
  final double shadow;

  @override
  Widget build(BuildContext context) {

    return Container(
        height:iconSize*2 ,
        width: iconSize*2,
        decoration: BoxDecoration(color: Colors.white70, shape: BoxShape.circle,
          border: Border.all(color: lighterBlackColour) ,
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0), spreadRadius: shadow, blurRadius: shadow*2/3, offset: Offset(0, shadow), // changes position of shadow
            ),
          ],

        ),

        child: Center(child: FaIcon(iconStyle, size: iconSize,color:  iconColor,)));
  }
}

class FaIconToolTip extends StatelessWidget {
  const FaIconToolTip({super.key, required this.iconStyle,required this.iconSize,required this.iconColor,required this.toolTip});
  final IconData iconStyle;
  final Color iconColor;
  final double iconSize;
  final String toolTip;


  @override
  Widget build(BuildContext context) {

  return Tooltip(
    triggerMode: TooltipTriggerMode.tap,
  message: toolTip,
  child: FaIcon(iconStyle, size: iconSize,color:  iconColor,),




  );
  }
}


class FaIconPermission extends StatelessWidget {
  const FaIconPermission({super.key, required this.accepted,required this.w});

  final int accepted;
  final double w;
  @override
  Widget build(BuildContext context) {

    return
      FaIcon(
        accepted == -5?  FontAwesomeIcons.kiwiBird:
        accepted == -3?  FontAwesomeIcons.kiwiBird:
        accepted == 0?  FontAwesomeIcons.hand:
        accepted == 1?  FontAwesomeIcons.userSecret:
        accepted == 2? FontAwesomeIcons.baby:
        accepted == 3? FontAwesomeIcons.userPen:
        accepted == 4? FontAwesomeIcons.userGraduate:
        accepted == 5? FontAwesomeIcons.hatWizard:
        FontAwesomeIcons.crown
        , color:
      accepted == -5?   blackColor:
      accepted == -3?   blackColor:
      accepted == 0?  lighterBlackColour:
      accepted == 1?  lighterBlackColour:
      accepted == 2?   blackColor:
      accepted == 3?   blackColor:
      accepted == 4?   blackColor:
      accepted == 5?  highlightColour:
      primaryAppColor
        , size: w * 0.03,);

  }
}

class IconCircledPermission extends StatelessWidget {
  const IconCircledPermission({super.key, required this.accepted,required this.w});
  final double w;
  final int accepted;
  @override
  Widget build(BuildContext context) {
return IconCircled(iconStyle:
accepted == -5?  FontAwesomeIcons.kiwiBird:
accepted == -3?  FontAwesomeIcons.personWalkingArrowRight:
accepted == 0?  FontAwesomeIcons.hand:
accepted == 1?  FontAwesomeIcons.userSecret:
accepted == 2? FontAwesomeIcons.baby:
accepted == 3? FontAwesomeIcons.userPen:
accepted == 4? FontAwesomeIcons.userGraduate:
accepted == 5? FontAwesomeIcons.hatWizard:
accepted == 6? FontAwesomeIcons.crown:
FontAwesomeIcons.crown,
iconSize:w*0.025 ,iconColor:
    accepted == -5?   blackColor:
    accepted == -3?   blackColor:
    accepted == 0?  lighterBlackColour:
accepted == 1?  lighterBlackColour:
accepted == 2?   blackColor:
accepted == 3?   blackColor:
accepted == 4?   blackColor:
accepted == 5?  highlightColour:
accepted == 6?  primaryAppColor:
Colors.transparent,
shadow:1,toolTip:

accepted == -5?  "localPlayer".tr:
accepted == -3?  "leftLeaguePlayer".tr:
accepted == 0?  "blocked".tr:
accepted == 1?  "requester".tr:
accepted == 2?  "player".tr:
accepted == 3?  "ikone".tr:
accepted == 4?  "captain".tr:
accepted == 5?  "shiningLight".tr:
"founder".tr
);
  }
}
class IconCircledPermissionN extends StatelessWidget {
  const IconCircledPermissionN({super.key, required this.accepted,required this.r});
  final double r;
  final int accepted;
  @override
  Widget build(BuildContext context) {
    return IconCircled(iconStyle:
    accepted == -5?  FontAwesomeIcons.kiwiBird:
    accepted == -3?  FontAwesomeIcons.personWalkingArrowRight:
    accepted == 0?  FontAwesomeIcons.hand:
    accepted == 1?  FontAwesomeIcons.userSecret:
    accepted == 2? FontAwesomeIcons.baby:
    accepted == 3? FontAwesomeIcons.userPen:
    accepted == 4? FontAwesomeIcons.userGraduate:
    accepted == 5? FontAwesomeIcons.hatWizard:
    accepted == 6? FontAwesomeIcons.crown:
    FontAwesomeIcons.crown,
        iconSize:r ,iconColor:
        accepted == -5?   blackColor:
        accepted == -3?   blackColor:
        accepted == 0?  lighterBlackColour:
        accepted == 1?  lighterBlackColour:
        accepted == 2?   blackColor:
        accepted == 3?   blackColor:
        accepted == 4?   blackColor:
        accepted == 5?  highlightColour:
        accepted == 6?  primaryAppColor:
        Colors.transparent,
        shadow:1,toolTip:
        accepted == -5?  "localPlayer".tr:
        accepted == -3?  "leftLeaguePlayer".tr:
        accepted == 0?  "blocked".tr:
        accepted == 1?  "requester".tr:
        accepted == 2?  "player".tr:
        accepted == 3?  "ikone".tr:
        accepted == 4?  "captain".tr:
        accepted == 5?  "shiningLight".tr:
        "founder".tr
    );
  }
}




















class PermissionName extends StatelessWidget {
  const PermissionName({super.key, required this.accepted,required this.w});

  final int accepted;
  final double w;
  @override
  Widget build(BuildContext context) {

    return   Text(accepted == 0?
    "blocked".tr: accepted == 2?
    "player".tr: accepted == 3?
    "ikone".tr: accepted == 4?
    "captain".tr: accepted == 5?
    "shiningLight".tr: "founder".tr,
      style:  TextStyle(fontSize: w*0.03, fontWeight: FontWeight.w600, color: standardTextColor,),textAlign: TextAlign.center,);





  }
}
