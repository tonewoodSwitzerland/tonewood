// // lib/screens/analytics/production/production_special_wood.dart
//
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart';
// import 'models/production_models.dart';
// import 'services/production_service.dart';
// import 'constants/production_constants.dart';
// import 'widgets/production_stats_card.dart';
// import 'widgets/production_chart_card.dart';
//
// class ProductionSpecialWood extends StatefulWidget {
//   const ProductionSpecialWood({Key? key}) : super(key: key);
//
//   @override
//   ProductionSpecialWoodState createState() => ProductionSpecialWoodState();
// }
//
// class ProductionSpecialWoodState extends State<ProductionSpecialWood> {
//   final ProductionService _service = ProductionService();
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: FutureBuilder<SpecialWoodStats>(
//         future: _service.getSpecialWoodStats(),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           final stats = snapshot.data!;
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildSummaryStats(stats),
//               const SizedBox(height: 24),
//               _buildHaselfichteAnalysis(stats),
//               const SizedBox(height: 24),
//               _buildMoonwoodAnalysis(stats),
//               const SizedBox(height: 24),
//               _buildComparisonChart(stats),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildSummaryStats(SpecialWoodStats stats) {
//     final theme = Theme.of(context);
//
//     return Wrap(
//       spacing: 16,
//       runSpacing: 16,
//       children: [
//         ProductionStatsCard(
//           title: 'Haselfichte Chargen',
//           value: NumberFormat('#,###').format(stats.haselfichteBatches),
//           icon: Icons.forest,
//           color: theme.colorScheme.primary,
//           trend: _buildTrendIndicator(stats.haselfichteEfficiency),
//         ),
//         ProductionStatsCard(
//           title: 'Mondholz Chargen',
//           value: NumberFormat('#,###').format(stats.moonwoodBatches),
//           icon: Icons.nightlight,
//           color: theme.colorScheme.secondary,
//           trend: _buildTrendIndicator(stats.moonwoodEfficiency),
//         ),
//         ProductionStatsCard(
//           title: 'Effizienz',
//           value: '${((stats.haselfichteEfficiency + stats.moonwoodEfficiency) / 2).toStringAsFixed(1)}%',
//           icon: Icons.speed,
//           color: theme.colorScheme.tertiary,
//           subtitle: 'Durchschnittliche Produktionseffizienz',
//         ),
//       ],
//     );
//   }
//
//   Widget _buildHaselfichteAnalysis(SpecialWoodStats stats) {
//     return ProductionChartCard(
//       title: 'Haselfichte Verteilung',
//       subtitle: 'Nach Instrumententyp',
//       child: SizedBox(
//         height: 300,
//         child: _buildInstrumentChart(
//           stats.haselfichteByInstrument,
//           Theme.of(context).colorScheme.primary,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMoonwoodAnalysis(SpecialWoodStats stats) {
//     return ProductionChartCard(
//       title: 'Mondholz Verteilung',
//       subtitle: 'Nach Instrumententyp',
//       child: SizedBox(
//         height: 300,
//         child: _buildInstrumentChart(
//           stats.moonwoodByInstrument,
//           Theme.of(context).colorScheme.secondary,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildInstrumentChart(Map<String, int> data, Color color) {
//     if (data.isEmpty) {
//       return const Center(child: Text('Keine Daten verfügbar'));
//     }
//
//     return BarChart(
//       BarChartData(
//         alignment: BarChartAlignment.spaceAround,
//         maxY: (data.values.reduce((a, b) => a > b ? a : b) * 1.2),
//         gridData: FlGridData(
//           show: true,
//           drawVerticalLine: false,
//           horizontalInterval: 1,
//           getDrawingHorizontalLine: (value) => FlLine(
//             color: Colors.grey.withOpacity(0.2),
//             strokeWidth: 1,
//           ),
//         ),
//         titlesData: FlTitlesData(
//           leftTitles: AxisTitles(
//             sideTitles: SideTitles(
//               showTitles: true,
//               reservedSize: 40,
//               getTitlesWidget: (value, meta) {
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: Text(
//                     value.toInt().toString(),
//                     style: const TextStyle(fontSize: 12),
//                   ),
//                 );
//               },
//             ),
//           ),
//           bottomTitles: AxisTitles(
//             sideTitles: SideTitles(
//               showTitles: true,
//               getTitlesWidget: (value, meta) {
//                 if (value >= 0 && value < data.length) {
//                   return Transform.rotate(
//                     angle: -0.5,
//                     child: Text(
//                       data.keys.elementAt(value.toInt()),
//                       style: const TextStyle(fontSize: 12),
//                     ),
//                   );
//                 }
//                 return const SizedBox.shrink();
//               },
//             ),
//           ),
//         ),
//         borderData: FlBorderData(show: false),
//         barGroups: data.entries.map((entry) {
//           return BarChartGroupData(
//             x: data.keys.toList().indexOf(entry.key),
//             barRods: [
//               BarChartRodData(
//                 toY: entry.value.toDouble(),
//                 color: color,
//                 width: ChartConfig.barChartMaxWidth,
//                 borderRadius: BorderRadius.circular(4),
//               ),
//             ],
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildComparisonChart(SpecialWoodStats stats) {
//     return ProductionChartCard(
//       title: 'Effizienzvergleich',
//       subtitle: 'Haselfichte vs. Mondholz',
//       child: SizedBox(
//         height: 300,
//         child: _buildStackedComparisonChart(stats),
//       ),
//     );
//   }
//
//   Widget _buildStackedComparisonChart(SpecialWoodStats stats) {
//     // Kombiniere die Daten für einen Vergleich
//     final List<Map<String, dynamic>> compareData = [];
//
//     // Finde alle eindeutigen Instrumente
//     final instruments = {...stats.haselfichteByInstrument.keys, ...stats.moonwoodByInstrument.keys};
//
//     for (var instrument in instruments) {
//       compareData.add({
//         'instrument': instrument,
//         'haselfichte': stats.haselfichteByInstrument[instrument] ?? 0,
//         'mondholz': stats.moonwoodByInstrument[instrument] ?? 0,
//       });
//     }
//
//     return BarChart(
//       BarChartData(
//         alignment: BarChartAlignment.spaceAround,
//         maxY: compareData.map((d) => (d['haselfichte'] as int) + (d['mondholz'] as int))
//             .reduce((a, b) => a > b ? a : b) * 1.2,
//         gridData: FlGridData(
//           show: true,
//           drawVerticalLine: false,
//         ),
//         titlesData: FlTitlesData(
//           leftTitles: AxisTitles(
//             sideTitles: SideTitles(
//               showTitles: true,
//               reservedSize: 40,
//               getTitlesWidget: (value, meta) {
//                 return Text(value.toInt().toString());
//               },
//             ),
//           ),
//           bottomTitles: AxisTitles(
//             sideTitles: SideTitles(
//               showTitles: true,
//               getTitlesWidget: (value, meta) {
//                 if (value >= 0 && value < compareData.length) {
//                   return Padding(
//                     padding: const EdgeInsets.only(top: 8),
//                     child: Transform.rotate(
//                       angle: -0.5,
//                       child: Text(
//                         compareData[value.toInt()]['instrument'] as String,
//                         style: const TextStyle(fontSize: 12),
//                       ),
//                     ),
//                   );
//                 }
//                 return const SizedBox.shrink();
//               },
//             ),
//           ),
//         ),
//         borderData: FlBorderData(show: false),
//         barGroups: List.generate(compareData.length, (index) {
//           final data = compareData[index];
//           return BarChartGroupData(
//             x: index,
//             barRods: [
//               BarChartRodData(
//                 toY: (data['haselfichte'] + data['mondholz']).toDouble(),
//                 width: ChartConfig.barChartMaxWidth,
//                 borderRadius: BorderRadius.circular(4),
//                 rodStackItems: [
//                   BarChartRodStackItem(
//                     0,
//                     data['haselfichte'].toDouble(),
//                     Theme.of(context).colorScheme.primary,
//                   ),
//                   BarChartRodStackItem(
//                     data['haselfichte'].toDouble(),
//                     (data['haselfichte'] + data['mondholz']).toDouble(),
//                     Theme.of(context).colorScheme.secondary,
//                   ),
//                 ],
//               ),
//             ],
//           );
//         }),
//       ),
//     );
//   }
//
//   Widget _buildTrendIndicator(double value) {
//     final isPositive = value >= 0;
//     final color = isPositive ? Colors.green : Colors.red;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(
//           isPositive ? Icons.trending_up : Icons.trending_down,
//           color: color,
//           size: 16,
//         ),
//         const SizedBox(width: 4),
//         Text(
//           '${value.abs().toStringAsFixed(1)}%',
//           style: TextStyle(
//             color: color,
//             fontSize: 12,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // Zusätzliches Widget für die Legende
// class ChartLegend extends StatelessWidget {
//   final Map<String, Color> items;
//
//   const ChartLegend({
//     Key? key,
//     required this.items,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: items.entries.map((entry) {
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 8),
//           child: Row(
//             children: [
//               Container(
//                 width: 12,
//                 height: 12,
//                 decoration: BoxDecoration(
//                   color: entry.value,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//               const SizedBox(width: 4),
//               Text(
//                 entry.key,
//                 style: const TextStyle(fontSize: 12),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
// }