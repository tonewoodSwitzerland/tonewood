import 'package:flutter/material.dart';

class RoundwoodStatsCard extends StatelessWidget {
  final String value;
  final IconData icon;
  final Color? cardColor;
  final Widget? trend;

  const RoundwoodStatsCard({
    Key? key,
    required this.value,
    required this.icon,
    this.cardColor,
    this.trend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = cardColor ?? theme.colorScheme.primary;

    return Card(
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
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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