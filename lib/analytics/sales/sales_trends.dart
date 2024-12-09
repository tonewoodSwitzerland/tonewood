// // lib/screens/analytics/sales/sales_trends.dart
//
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart';
// import 'models/sales_models.dart';
// import 'services/sales_services.dart';
// import 'constants/constants.dart';
// import 'widgets/sales_stats_card.dart';
// import 'widgets/sales_chart_card.dart';
// import 'dart:math' as math;
//
// class SalesTrends extends StatefulWidget {
//   const SalesTrends({Key? key}) : super(key: key);
//
//   @override
//   SalesTrendsState createState() => SalesTrendsState();
// }
//
// class SalesTrendsState extends State<SalesTrends> {
//   final SalesService _service = SalesService();
//   String selectedTimeRange = 'year';
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildTimeSelector(),
//           const SizedBox(height: 24),
//           _buildTrendStats(),
//           const SizedBox(height: 24),
//           _buildRevenueTrend(),
//           const SizedBox(height: 24),
//           _buildSeasonalAnalysis(),
//           const SizedBox(height: 24),
//           _buildProductTrends(),
//           const SizedBox(height: 24),
//           _buildFairComparison(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTimeSelector() {
//     return SegmentedButton<String>(
//       segments: const [
//         ButtonSegment(value: 'quarter', label: Text('Quartal')),
//         ButtonSegment(value: 'year', label: Text('Jahr')),
//         ButtonSegment(value: 'all', label: Text('Gesamt')),
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
//   Widget _buildTrendStats() {
//     return FutureBuilder<SalesStats>(
//       future: _service.getSalesStats(selectedTimeRange),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         final stats = snapshot.data!;
//         final previousPeriodRevenue = stats.revenueTrend.values.isEmpty ? 0.0 :
//         stats.revenueTrend.values.reduce((a, b) => a + b);
//         final currentPeriodRevenue = stats.totalRevenue;
//         final growthRate = previousPeriodRevenue > 0
//             ? ((currentPeriodRevenue - previousPeriodRevenue) / previousPeriodRevenue * 100)
//             : 0.0;
//
//         return Wrap(
//           spacing: 16,
//           runSpacing: 16,
//           children: [
//             SalesStatsCard(
//               title: 'Wachstumsrate',
//               value: '${growthRate.toStringAsFixed(1)}%',
//               icon: Icons.trending_up,
//               color: growthRate >= 0 ? Colors.green : Colors.red,
//               trend: _buildTrendIndicator(growthRate),
//             ),
//             SalesStatsCard(
//               title: 'Durchschn. Monatsumsatz',
//               value: NumberFormat.currency(
//                 locale: 'de_CH',
//                 symbol: 'CHF',
//               ).format(stats.totalRevenue / 12),
//               icon: Icons.calendar_month,
//               color: Theme.of(context).colorScheme.secondary,
//             ),
//             SalesStatsCard(
//               title: 'Trend Stabilität',
//               value: '${_calculateTrendStability(stats.revenueTrend)}%',
//               icon: Icons.auto_graph,
//               color: Theme.of(context).colorScheme.tertiary,
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Widget _buildRevenueTrend() {
//     return FutureBuilder<SalesStats>(
//       future: _service.getSalesStats(selectedTimeRange),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         final stats = snapshot.data!;
//         final sortedEntries = stats.revenueTrend.entries.toList()
//           ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));
//
//         return SalesChartCard(
//           title: 'Umsatzentwicklung',
//           subtitle: 'Monatlicher Verlauf',
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
//                       reservedSize: 60,
//                       getTitlesWidget: (value, meta) {
//                         return Text(
//                           NumberFormat.currency(
//                             locale: 'de_CH',
//                             symbol: 'CHF',
//                             decimalDigits: 0,
//                           ).format(value),
//                           style: const TextStyle(fontSize: 10),
//                         );
//                       },
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       interval: 2,
//                       getTitlesWidget: (value, meta) {
//                         if (value >= 0 && value < sortedEntries.length) {
//                           final date = DateTime.parse('${sortedEntries[value.toInt()].key}-01');
//                           return Transform.rotate(
//                             angle: -0.5,
//                             child: Text(
//                               DateFormat('MMM yy').format(date),
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
//   Widget _buildSeasonalAnalysis() {
//     return FutureBuilder<SalesStats>(
//       future: _service.getSalesStats('year'),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         final stats = snapshot.data!;
//         final seasonalData = _calculateSeasonalPattern(stats.revenueByMonth);
//
//         return SalesChartCard(
//           title: 'Saisonale Muster',
//           subtitle: 'Durchschnittlicher Umsatz pro Monat',
//           child: SizedBox(
//             height: 300,
//             child: BarChart(
//               BarChartData(
//                 alignment: BarChartAlignment.spaceAround,
//                 maxY: seasonalData.values.reduce((a, b) => a > b ? a : b) * 1.2,
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: false,
//                 ),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: 60,
//                       getTitlesWidget: (value, meta) {
//                         return Text(
//                           NumberFormat.currency(
//                             locale: 'de_CH',
//                             symbol: 'CHF',
//                             decimalDigits: 0,
//                           ).format(value),
//                           style: const TextStyle(fontSize: 10),
//                         );
//                       },
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       getTitlesWidget: (value, meta) {
//                         if (value >= 0 && value < 12) {
//                           return Text(
//                             DateFormat('MMM').format(DateTime(2024, value.toInt() + 1)),
//                             style: const TextStyle(fontSize: 10),
//                           );
//                         }
//                         return const SizedBox.shrink();
//                       },
//                     ),
//                   ),
//                 ),
//                 barGroups: List.generate(
//                   12,
//                       (index) => BarChartGroupData(
//                     x: index,
//                     barRods: [
//                       BarChartRodData(
//                         toY: seasonalData[index + 1] ?? 0,
//                         color: Theme.of(context).colorScheme.primary,
//                         width: 16,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildProductTrends() {
//     return FutureBuilder<SalesStats>(
//       future: _service.getSalesStats(selectedTimeRange),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         return SalesChartCard(
//           title: 'Produkttrends',
//           subtitle: 'Umsatzentwicklung nach Produkt',
//           child: SizedBox(
//             height: 300,
//             child: BarChart(
//               BarChartData(
//                 alignment: BarChartAlignment.spaceAround,
//                 maxY: snapshot.data!.revenueByProduct.isEmpty ? 0 :
//                 snapshot.data!.revenueByProduct.values.reduce((a, b) => a > b ? a : b) * 1.2,
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: false,
//                 ),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: 60,
//                       getTitlesWidget: (value, meta) {
//                         return Text(
//                           NumberFormat.currency(
//                             locale: 'de_CH',
//                             symbol: 'CHF',
//                             decimalDigits: 0,
//                           ).format(value),
//                           style: const TextStyle(fontSize: 10),
//                         );
//                       },
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       getTitlesWidget: (value, meta) {
//                         final products = snapshot.data!.revenueByProduct.keys.toList();
//                         if (value >= 0 && value < products.length) {
//                           return Transform.rotate(
//                             angle: -0.5,
//                             child: Text(
//                               products[value.toInt()],
//                               style: const TextStyle(fontSize: 10),
//                             ),
//                           );
//                         }
//                         return const SizedBox.shrink();
//                       },
//                     ),
//                   ),
//                 ),
//                 barGroups: snapshot.data!.revenueByProduct.entries.map((entry) {
//                   final index = snapshot.data!.revenueByProduct.keys.toList().indexOf(entry.key);
//                   return BarChartGroupData(
//                     x: index,
//                     barRods: [
//                       BarChartRodData(
//                         toY: entry.value,
//                         color: SalesColors.getProductColor(entry.key.toLowerCase()),
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
//   Widget _buildFairComparison() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Messeverkäufe',
//               style: Theme.of(context).textTheme.titleLarge,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Vergleich der Verkaufszahlen auf Messen',
//               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                 color: Theme.of(context).colorScheme.onSurfaceVariant,
//               ),
//             ),
//             const SizedBox(height: 16),
//             // Hier könnte eine DetailAnalyse der Messeverkäufe implementiert werden
//             const Center(
//               child: Text('Detailanalyse der Messeverkäufe wird implementiert...'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTrendIndicator(double value) {
//     final isPositive = value >= 0;
//     final color = isPositive ? Colors.green : Colors.red;
//
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
//
//   double _calculateTrendStability(Map<String, double> revenueData) {
//     if (revenueData.isEmpty) return 0;
//
//     final values = revenueData.values.toList();
//     final mean = values.reduce((a, b) => a + b) / values.length;
//     final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
//     final stdDev = math.sqrt(variance);
//
//     // Berechne den Variationskoeffizienten und wandle ihn in ein Stabilitätsmaß um
//     final cv = (stdDev / mean) * 100;
//     return 100 - cv.clamp(0, 100); // Je niedriger der CV, desto stabiler der Trend
//   }
//
//
//
// // Fortsetzung der _calculateSeasonalPattern Methode
//   Map<int, double> _calculateSeasonalPattern(Map<String, double> monthlyData) {
//     final seasonalPattern = <int, List<double>>{};
//     final result = <int, double>{};
//
//     // Gruppiere Daten nach Monaten
//     for (var entry in monthlyData.entries) {
//       final date = DateTime.parse('${entry.key}-01');
//       final month = date.month;
//       seasonalPattern.putIfAbsent(month, () => []).add(entry.value);
//     }
//
//     // Berechne Durchschnitt pro Monat
//     for (var month in seasonalPattern.keys) {
//       final values = seasonalPattern[month]!;
//       result[month] = values.reduce((a, b) => a + b) / values.length;
//     }
//
//     return result;
//   }
// }
//
// // Zusätzliche Helper-Klasse für Trend-Berechnungen
// class TrendCalculator {
//   static double calculateGrowthRate(double current, double previous) {
//     if (previous == 0) return 0;
//     return ((current - previous) / previous) * 100;
//   }
//
//   static Map<String, double> calculateMovingAverage(
//       Map<String, double> data,
//       int windowSize,
//       ) {
//     final sortedKeys = data.keys.toList()..sort();
//     final result = <String, double>{};
//
//     for (int i = windowSize - 1; i < sortedKeys.length; i++) {
//       double sum = 0;
//       for (int j = 0; j < windowSize; j++) {
//         sum += data[sortedKeys[i - j]]!;
//       }
//       result[sortedKeys[i]] = sum / windowSize;
//     }
//
//     return result;
//   }
//
//   static Map<String, double> calculateYearOverYearGrowth(
//       Map<String, double> data,
//       ) {
//     final result = <String, double>{};
//     final sortedEntries = data.entries.toList()
//       ..sort((a, b) => a.key.compareTo(b.key));
//
//     for (int i = 12; i < sortedEntries.length; i++) {
//       final currentValue = sortedEntries[i].value;
//       final previousValue = sortedEntries[i - 12].value;
//
//       if (previousValue != 0) {
//         result[sortedEntries[i].key] =
//             ((currentValue - previousValue) / previousValue) * 100;
//       }
//     }
//
//     return result;
//   }
// }
//
// // Zusätzliche Erweiterung für den ListView im FairComparison
// extension on SalesTrendsState {
//   Widget _buildFairComparisonList() {
//     return FutureBuilder<List<Map<String, dynamic>>>(
//       future: _service.getFairComparisons(selectedTimeRange),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         final comparisons = snapshot.data!;
//         return ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: comparisons.length,
//           itemBuilder: (context, index) {
//             final fair = comparisons[index];
//             final yearOverYearGrowth = fair['growth'] as double;
//
//             return ListTile(
//               title: Text(fair['name'] as String),
//               subtitle: Text(
//                 '${fair['location']}\n${DateFormat('dd.MM.yyyy').format(fair['date'])}',
//               ),
//               trailing: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     NumberFormat.currency(
//                       locale: 'de_CH',
//                       symbol: 'CHF',
//                     ).format(fair['revenue']),
//                   ),
//                   _buildTrendIndicator(yearOverYearGrowth),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }