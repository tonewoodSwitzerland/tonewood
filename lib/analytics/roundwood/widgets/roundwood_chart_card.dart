// lib/screens/analytics/roundwood/widgets/roundwood_chart_card.dart

import 'package:flutter/material.dart';

class RoundwoodChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const RoundwoodChartCard({
    Key? key,
    required this.title,
    required this.child,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: child,
          ),
        ],
      ),
    );
  }
}

