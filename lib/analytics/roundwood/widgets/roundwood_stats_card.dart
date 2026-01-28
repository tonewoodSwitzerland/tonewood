import 'package:flutter/material.dart';

import '../../../services/icon_helper.dart';

class RoundwoodStatsCard extends StatelessWidget {
  final String value;
  final String? subtitle; // NEU
  final dynamic icon;
  final Color? cardColor;
  final Widget? trend;
  final String? iconName;
  final bool hasActiveIndicator;

  const RoundwoodStatsCard({
    Key? key,
    required this.value,
    this.subtitle, // NEU
    required this.icon,
    this.cardColor,
    this.trend,
    required this.iconName,
    this.hasActiveIndicator = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = hasActiveIndicator
        ? (cardColor ?? const Color(0xFF0F4A29))
        : Colors.grey;

    return Card(
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: getAdaptiveIcon(
                iconName: iconName!,
                defaultIcon: icon is IconData ? icon : Icons.analytics,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: hasActiveIndicator ? Colors.black : Colors.grey,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (trend != null) ...[
              const SizedBox(height: 4),
              trend!,
            ],
          ],
        ),
      ),
    );
  }
}