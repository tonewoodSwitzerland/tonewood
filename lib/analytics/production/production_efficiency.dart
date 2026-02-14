// // lib/screens/analytics/production/production_efficiency.dart
//
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart';
// import 'models/production_models.dart';
// import 'services/production_service.dart';
// import 'widgets/production_stats_card.dart';
// import 'widgets/production_chart_card.dart';
//
// class ProductionEfficiency extends StatefulWidget {
//   const ProductionEfficiency({Key? key}) : super(key: key);
//
//   @override
//   ProductionEfficiencyState createState() => ProductionEfficiencyState();
// }
//
// class ProductionEfficiencyState extends State<ProductionEfficiency> {
//   final ProductionService _service = ProductionService();
//   String selectedTimeRange = 'month';
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildTimeRangeSelector(),
//           const SizedBox(height: 16),
//           _buildEfficiencyStats(),
//           const SizedBox(height: 24),
//           _buildWeekdayDistribution(),
//           const SizedBox(height: 24),
//           _buildEfficiencyTrend(),
//           const SizedBox(height: 24),
//           _buildTimingAnalysis(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTimeRangeSelector() {
//     return SegmentedButton<String>(
//       segments: const [
//         ButtonSegment(value: 'week', label: Text('Woche')),
//         ButtonSegment(value: 'month', label: Text('Monat')),
//         ButtonSegment(value: 'quarter', label: Text('Quartal')),
//         ButtonSegment(value: 'year', label: Text('Jahr')),
//       ],
//       selected: {selectedTimeRange},
//       onSelectionChanged: (Set<String> selection) {
//         setState(() {
//           selectedTimeRange = selection.first;
//         });
//       },
//     );
//   }
//
//   Widget _buildEfficiencyStats() {
//     return FutureBuilder<Map<String, dynamic>>(
//       future: _service.getBatchEfficiencyStats(selectedTimeRange),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         final stats = snapshot.data!;
//         return Wrap(
//           spacing: 16,
//           runSpacing: 16,
//           children: [
//             ProductionStatsCard(
//               iconName: 'timer',
//               title: 'Durchschnittliche Zeit',
//               value: '${stats['avg_time_between_batches'].toStringAsFixed(1)}h',
//               icon: Icons.timer,
//               color: Theme.of(context).colorScheme.primary,
//               subtitle: 'Zwischen Chargen',
//             ),
//             ProductionStatsCard(
//               iconName: 'speed',
//               title: 'Effizienz',
//               value: '${(stats['avg_efficiency'] * 100).toStringAsFixed(1)}%',
//               icon: Icons.speed,
//               color: Theme.of(context).colorScheme.secondary,
//               subtitle: 'Durchschnittlich',
//             ),
//             ProductionStatsCard(
//               iconName: 'layers',
//               title: 'Chargen',
//               value: stats['total_batches'].toString(),
//               icon: Icons.layers,
//               color: Theme.of(context).colorScheme.tertiary,
//               subtitle: _getTimeRangeText(),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Widget _buildWeekdayDistribution() {
//     return FutureBuilder<Map<String, dynamic>>(
//       future: _service.getBatchEfficiencyStats(selectedTimeRange),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         final weekdayData = snapshot.data!['batches_by_weekday'] as Map<String, int>;
//
//         return ProductionChartCard(
//           title: 'Produktion nach Wochentag',
//           subtitle: 'Anzahl Chargen pro Tag',
//           child: SizedBox(
//             height: 300,
//             child: BarChart(
//               BarChartData(
//                 alignment: BarChartAlignment.spaceAround,
//                 maxY: (weekdayData.values.isEmpty ? 0 :
//                 weekdayData.values.reduce((a, b) => a > b ? a : b)) * 1.2,
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: false,
//                   getDrawingHorizontalLine: (value) => FlLine(
//                     color: Colors.grey.withOpacity(0.2),
//                     strokeWidth: 1,
//                   ),
//                 ),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: 40,
//                       getTitlesWidget: (value, meta) {
//                         return Text(value.toInt().toString());
//                       },
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       getTitlesWidget: (value, meta) {
//                         if (value >= 0 && value < weekdayData.length) {
//                           return Text(
//                             weekdayData.keys.elementAt(value.toInt()).substring(0, 2),
//                             style: const TextStyle(fontSize: 12),
//                           );
//                         }
//                         return const SizedBox.shrink();
//                       },
//                     ),
//                   ),
//                 ),
//                 borderData: FlBorderData(show: false),
//                 barGroups: weekdayData.entries.map((entry) {
//                   return BarChartGroupData(
//                     x: weekdayData.keys.toList().indexOf(entry.key),
//                     barRods: [
//                       BarChartRodData(
//                         toY: entry.value.toDouble(),
//                         color: Theme.of(context).colorScheme.primary,
//                         width: 20,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                     ],
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildEfficiencyTrend() {
//     return FutureBuilder<Map<String, dynamic>>(
//       future: _service.getBatchEfficiencyStats(selectedTimeRange),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         final efficiencyByDay = snapshot.data!['efficiency_by_day'] as Map<String, double>;
//
//         // Sortiere die Daten nach Datum
//         final sortedEntries = efficiencyByDay.entries.toList()
//           ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));
//
//         return ProductionChartCard(
//           title: 'Effizienzentwicklung',
//           subtitle: 'Tägliche Produktionseffizienz',
//           child: SizedBox(
//             height: 300,
//             child: LineChart(
//               LineChartData(
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: false,
//                 ),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: 40,
//                       getTitlesWidget: (value, meta) {
//                         return Text('${(value * 100).toInt()}%');
//                       },
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       interval: 5,
//                       getTitlesWidget: (value, meta) {
//                         if (value.toInt() >= 0 && value.toInt() < sortedEntries.length) {
//                           final date = DateTime.parse(sortedEntries[value.toInt()].key);
//                           return Transform.rotate(
//                             angle: -0.5,
//                             child: Text(
//                               DateFormat('dd.MM').format(date),
//                               style: const TextStyle(fontSize: 10),
//                             ),
//                           );
//                         }
//                         return const SizedBox.shrink();
//                       },
//                     ),
//                   ),
//                 ),
//                 borderData: FlBorderData(show: false),
//                 lineBarsData: [
//                   LineChartBarData(
//                     spots: List.generate(sortedEntries.length, (index) {
//                       return FlSpot(
//                         index.toDouble(),
//                         sortedEntries[index].value,
//                       );
//                     }),
//                     isCurved: true,
//                     color: Theme.of(context).colorScheme.primary,
//                     barWidth: 2,
//                     dotData: const FlDotData(show: false),
//                     belowBarData: BarAreaData(
//                       show: true,
//                       color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildTimingAnalysis() {
//     return ProductionChartCard(
//       title: 'Zeitanalyse',
//       subtitle: 'Durchschnittliche Produktionszeiten nach Typ',
//       child: FutureBuilder<Map<String, dynamic>>(
//         future: _service.getBatchEfficiencyStats(selectedTimeRange),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const SizedBox(height: 300);
//           }
//
//           // Hier könnte eine detaillierte Zeitanalyse implementiert werden
//           return const SizedBox(height: 300);
//         },
//       ),
//     );
//   }
//
//   String _getTimeRangeText() {
//     switch (selectedTimeRange) {
//       case 'week':
//         return 'Letzte 7 Tage';
//       case 'month':
//         return 'Letzten 30 Tage';
//       case 'quarter':
//         return 'Letzten 90 Tage';
//       case 'year':
//         return 'Letztes Jahr';
//       default:
//         return 'Letzten 30 Tage';
//     }
//   }
// }