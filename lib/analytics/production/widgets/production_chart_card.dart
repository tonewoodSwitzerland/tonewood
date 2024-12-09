
import 'package:flutter/material.dart';

class ProductionChartCard extends StatelessWidget {
final String title;
final Widget child;
final List<Widget>? actions;
final String? subtitle;

const ProductionChartCard({
Key? key,
required this.title,
required this.child,
this.actions,
this.subtitle,
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
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: Text(
title,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
if (actions != null) ...actions!,
],
),
if (subtitle != null) ...[
const SizedBox(height: 4),
Text(
subtitle!,
style: TextStyle(
fontSize: 12,
color: Theme.of(context).colorScheme.onSurfaceVariant,
),
),
],
],
),
),
Padding(
padding: const EdgeInsets.all(16),
child: child,
),
],
),
);
}
}