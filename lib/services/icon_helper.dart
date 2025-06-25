
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Widget getAdaptiveIcon({
  required String iconName,
  required IconData defaultIcon,
  double size = 24,                // zurück auf 24
  Color? color = Colors.black54,   // standardmäßig leicht transparent schwarz
}) {
  if (kIsWeb) {
    return Image.asset(
      '/icons/$iconName.png',   // korrekter Pfad
      height: size,
      width: size,
      color: color,
      fit: BoxFit.contain,           // besseres fitting
      filterQuality: FilterQuality.high,  // bessere Qualität
      errorBuilder: (context, error, stackTrace) {
        return Icon(defaultIcon, size: size, color: color);
      },
    );
  }
  return Icon(defaultIcon, size: size, color: color);
}