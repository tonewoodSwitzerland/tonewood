
import 'package:flutter/material.dart';

import '../constants.dart';



class ReusableCardFancy extends StatelessWidget {
  const ReusableCardFancy({super.key, required this.colour, required this.cardChild, required this.onPress});
  final Color colour;
  final Widget cardChild;
  final VoidCallback  onPress;

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: GestureDetector(
        onTap: onPress,
        child:
          Material(borderRadius: BorderRadius.all( Radius.circular(borderRadius)), elevation: w * 0.005 , color: colour,
      child:
        Padding(padding: const EdgeInsets.fromLTRB(2,6,2,6),child: cardChild,),
          ),
      ),
    );
  }

}

class ReusableCardTouch extends StatelessWidget {
  const ReusableCardTouch({
    super.key,
    required this.colour,
    required this.cardChild,
    required this.onPress,
    required this.touched,
  });

  final Color colour;
  final bool touched;

  final Widget cardChild;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: GestureDetector(
        onTap: onPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: colour,
            boxShadow: [
              if (touched)
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              if (!touched)
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
            child: cardChild,
          ),
        ),
      ),
    );
  }
}



class ReusableCardTouchFixedSize extends StatelessWidget {
  const ReusableCardTouchFixedSize({
    super.key,
    required this.colour,
    required this.cardChild,
    required this.onPress,
    required this.touched,
    required this.width,
    required this.height
  });

  final Color colour;
  final bool touched;
  final double width;
  final double height;
  final Widget cardChild;

  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: GestureDetector(
        onTap: onPress,
        child: Container(
          width: w*width,
          height: h*height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: colour,
            boxShadow: [
              if (touched)
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              if (!touched)
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
            child: cardChild,
          ),
        ),
      ),
    );
  }
}



class InputButton extends StatelessWidget {
  const InputButton({
    super.key,
    required this.colour,
    required this.cardChild,
    required this.onPress,
    required this.touched,
    required this.width,
    required this.height,
    required this.borderColour
  });

  final Color colour;
  final Color borderColour;
  final bool touched;
  final double width;
  final double height;
  final Widget cardChild;

  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: GestureDetector(
        onTap: onPress,
        child: Container(

          width: w*width,
          height: h*height,
          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(borderRadius),

            color: colour,
            boxShadow: [
              if (touched)
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius:1,
                  offset: const Offset(0, 1),
                ),
              if (!touched)
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
            child: cardChild,
          ),
        ),
      ),
    );
  }
}
