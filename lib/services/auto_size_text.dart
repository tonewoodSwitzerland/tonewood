import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class AText extends StatelessWidget {
  const AText({super.key, required this.input, required this.maxLines, required this.style});
  final String input;

  final int maxLines;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    return AutoSizeText(input,textScaleFactor:1,maxLines: maxLines,minFontSize:4,maxFontSize:40,overflow: TextOverflow.ellipsis, style: style,textAlign: TextAlign.center);
  }
}

