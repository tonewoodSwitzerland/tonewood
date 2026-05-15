import 'package:flutter/material.dart';

import '../constants.dart';
import 'dart:io';

import '../services/icon_helper.dart';
class CircleAvatarShadowedNoImage extends StatelessWidget {
  const CircleAvatarShadowedNoImage({ required Key key,required this.w,required this.shadow,required this.photoPlayer}) : super(key: key);

  final double w;

  final String photoPlayer;
  final double shadow;

  @override
  Widget build(BuildContext context) {

    return
      photoPlayer == ""?
      getAdaptiveIcon(iconName: 'account_circle', defaultIcon: Icons.account_circle,):

      Container(
          decoration: BoxDecoration(color: Colors.white70, shape: BoxShape.circle,
            border: Border.all(color: lighterBlackColour) ,
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: shadow, blurRadius: shadow*2/3, offset: Offset(0, shadow), // changes position of shadow
              ),
            ],
          ),
          child:

          CircleAvatar(backgroundColor: Colors.transparent, radius: w * 0.051, backgroundImage:photoPlayer == ""?  AssetImage("images/logo_oak.png"):null,  foregroundImage: photoPlayer == "" ?  AssetImage("images/logo_oak.png") as ImageProvider<Object>? : NetworkImage(photoPlayer),
          ));

  }
}

