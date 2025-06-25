import 'package:flutter/material.dart';

import '../services/icon_helper.dart';

Widget buildFilterCategory({
  required dynamic icon,  // Can be IconData or a Widget from getAdaptiveIcon
  required String title,
  required Widget child,
  String? iconName,      // Optional: For getAdaptiveIcon
  bool hasActiveFilters = false, // New parameter from your code
}) {
  final Color activeColor = const Color(0xFF0F4A29);

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasActiveFilters
                ? activeColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: iconName != null
              ? getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon is IconData ? icon : Icons.category,
            color: hasActiveFilters ? activeColor : Colors.grey,
            size: 24,
          )
              : icon is IconData
              ? Icon(
            icon,
            color: hasActiveFilters ? activeColor : Colors.grey,
            size: 24,
          )
              : icon, // Direct use if already a Widget
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: hasActiveFilters ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
            color: hasActiveFilters ? activeColor : Colors.black,
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [child],
      ),
    ),
  );
}