import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants.dart';
import 'dart:io';
class CircleAvatarShadowedNoImage extends StatelessWidget {
  const CircleAvatarShadowedNoImage({ required Key key,required this.w,required this.shadow,required this.photoPlayer}) : super(key: key);

  final double w;

  final String photoPlayer;
  final double shadow;

  @override
  Widget build(BuildContext context) {

    return
      photoPlayer == ""?const FaIcon(FontAwesomeIcons.userSecret,color:  primaryAppColor,):
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


class CircleAvatarShadowedWithTemporaryImageOrWebImage extends StatelessWidget {
  const CircleAvatarShadowedWithTemporaryImageOrWebImage({
    required Key key,
    required this.webImage,
    required this.kIsWebTemp,
    required this.w,
    required this.shadow,
    required this.photoPlayer,
    required this.image,
  }) : super(key: key);

  final bool kIsWebTemp;
  final double w;
  final String photoPlayer;
  final double shadow;
  final File? image;
  final Image webImage;

  @override
  Widget build(BuildContext context) {
    return
      photoPlayer.isEmpty? Column(
        children: [
          FaIcon(FontAwesomeIcons.userSecret,size:0.1*h,color:  primaryAppColor),
    Text("Profilbild",style: smallestHeadline,)
        ],
      ):

      Container(
      width: w * 0.102,
      height: w * 0.102,
      decoration: BoxDecoration(
        color: Colors.white70,
        shape: BoxShape.circle,
        border: Border.all(color: lighterBlackColour),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: shadow,
            blurRadius: shadow * 2 / 3,
            offset: Offset(0, shadow),
          ),
        ],
      ),
      child: ClipOval(
    child: AspectRatio(
    aspectRatio: 1,
        child: kIsWebTemp
            ? webImage
            : image != null
            ? Image.file(image!, fit: BoxFit.cover)
            : (photoPlayer.isEmpty
            ? Image.asset("images/k1.png", fit: BoxFit.cover)
            : Image.network(photoPlayer, fit: BoxFit.cover)),
    ),),
    );
  }
}
