import 'package:flutter/material.dart';

import '../../../services/icon_helper.dart';

class RoundwoodStatsCard extends StatelessWidget {
  final String value;
  final dynamic icon; // Can be IconData or a Widget
  final Color? cardColor;
  final Widget? trend;
  final String? iconName; // Optional: For getAdaptiveIcon
  final bool hasActiveIndicator; // Similar to hasActiveFilters

  const RoundwoodStatsCard({
    Key? key,
    required this.value,
    required this.icon,
    this.cardColor,
    this.trend,
    this.iconName,
    this.hasActiveIndicator = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hasActiveIndicator
        ? (cardColor ?? const Color(0xFF0F4A29))
        : Colors.grey;

    return Card(
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: iconName != null
                  ? getAdaptiveIcon(
                iconName: iconName!,
                defaultIcon: icon is IconData ? icon : Icons.analytics,
                color: color,
                size: 24,
              )
                  : icon is IconData
                  ? Icon(
                icon,
                color: color,
                size: 24,
              )
                  : icon, // Direct use if already a Widget
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: hasActiveIndicator ? Colors.black : Colors.grey,
              ),
            ),
            if (trend != null) ...[
              const SizedBox(height: 8),
              trend!,
            ],
          ],
        ),
      ),
    );
  }
}