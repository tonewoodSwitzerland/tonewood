// lib/screens/analytics/production/widgets/production_stats_card.dart

import 'package:flutter/material.dart';

import '../../../services/icon_helper.dart';

class ProductionStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String iconName;
  final Color? color;
  final String? subtitle;
  final Widget? trend;

  const ProductionStatsCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconName,
    this.color,
    this.subtitle,
    this.trend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: getAdaptiveIcon(iconName: iconName, defaultIcon:icon, color: cardColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null || trend != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (trend != null) trend!,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


