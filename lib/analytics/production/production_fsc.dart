// // lib/screens/analytics/production/production_fsc.dart
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
// class ProductionFSC extends StatefulWidget {
//   const ProductionFSC({Key? key}) : super(key: key);
//
//   @override
//   ProductionFSCState createState() => ProductionFSCState();
// }
//
// class ProductionFSCState extends State<ProductionFSC> {
//   final ProductionService _service = ProductionService();
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: FutureBuilder<FSCStats>(
//         future: _service.getFSCStats(),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           final stats = snapshot.data!;
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildFSCStats(stats),
//               const SizedBox(height: 24),
//               _buildWoodTypeDistribution(stats),
//               const SizedBox(height: 24),
//               _buildTrendAnalysis(stats),
//               const SizedBox(height: 24),
//               _buildCertificationInfo(),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildFSCStats(FSCStats stats) {
//     return Wrap(
//       spacing: 16,
//       runSpacing: 16,
//       children: [
//         ProductionStatsCard(
//           title: 'FSC-Produkte',
//           value: NumberFormat('#,###').format(stats.totalFSCProducts),
//           icon: Icons.eco,
//           color: Theme.of(context).colorScheme.primary,
//           subtitle: 'Letzte 12 Monate',
//         ),
//         ProductionStatsCard(
//           title: 'FSC-Anteil',
//           value: '${stats.fscPercentage.toStringAsFixed(1)}%',
//           icon: Icons.pie_chart,
//           color: Theme.of(context).colorScheme.secondary,
//           subtitle: 'An Gesamtproduktion',
//         ),
//         ProductionStatsCard(
//           title: 'Holzarten',
//           value: stats.fscByWoodType.length.toString(),
//           icon: Icons.forest,
//           color: Theme.of(context).colorScheme.tertiary,
//           subtitle: 'Mit FSC-Zertifizierung',
//         ),
//       ],
//     );
//   }
//
//   Widget _buildWoodTypeDistribution(FSCStats stats) {
//     return ProductionChartCard(
//       title: 'FSC-Verteilung nach Holzart',
//       subtitle: 'Anteil der verschiedenen Holzarten',
//       child: SizedBox(
//         height: 300,
//         child: PieChart(
//           PieChartData(
//             sections: _buildPieSections(stats.fscByWoodType),
//             sectionsSpace: 2,
//             centerSpaceRadius: 40,
//             pieTouchData: PieTouchData(
//               touchCallback: (FlTouchEvent event, pieTouchResponse) {
//                 // Hier könnte Interaktivität hinzugefügt werden
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   List<PieChartSectionData> _buildPieSections(Map<String, int> data) {
//     final total = data.values.reduce((a, b) => a + b);
//
//     return data.entries.map((entry) {
//       final percentage = entry.value / total * 100;
//       final index = data.keys.toList().indexOf(entry.key);
//       final color = ChartConfig.defaultColorScheme[
//       index % ChartConfig.defaultColorScheme.length];
//
//       return PieChartSectionData(
//         value: percentage,
//         title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
//         radius: 110,
//         titleStyle: const TextStyle(
//           fontSize: 12,
//           fontWeight: FontWeight.bold,
//           color: Colors.white,
//         ),
//         color: color,
//       );
//     }).toList();
//   }
//
//   Widget _buildTrendAnalysis(FSCStats stats) {
//     final sortedEntries = stats.fscTrend.entries.toList()
//
//           ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));
//
//     return ProductionChartCard(
//     title: 'FSC-Entwicklung',
//     subtitle: 'Trend über die letzten 12 Monate',
//     child: SizedBox(
//     height: 300,
//     child: LineChart(
//     LineChartData(
//     gridData: FlGridData(
//     show: true,
//     drawVerticalLine: false,
//     getDrawingHorizontalLine: (value) => FlLine(
//     color: Colors.grey.withOpacity(0.2),
//     strokeWidth: 1,
//     ),
//     ),
//     titlesData: FlTitlesData(
//     leftTitles: AxisTitles(
//     sideTitles: SideTitles(
//     showTitles: true,
//     reservedSize: 40,
//     getTitlesWidget: (value, meta) {
//     return Text('${value.toInt()}%');
//     },
//     ),
//     ),
//     bottomTitles: AxisTitles(
//     sideTitles: SideTitles(
//     showTitles: true,
//     interval: 2,
//     getTitlesWidget: (value, meta) {
//     if (value.toInt() >= 0 && value.toInt() < sortedEntries.length) {
//     final date = DateTime.parse(sortedEntries[value.toInt()].key);
//     return Transform.rotate(
//     angle: -0.5,
//     child: Text(
//     DateFormat('MM.yy').format(date),
//     style: const TextStyle(fontSize: 12),
//     ),
//     );
//     }
//     return const SizedBox.shrink();
//     },
//     ),
//     ),
//     ),
//     borderData: FlBorderData(show: false),
//     lineBarsData: [
//     LineChartBarData(
//     spots: List.generate(sortedEntries.length, (index) {
//     return FlSpot(
//     index.toDouble(),
//     sortedEntries[index].value,
//     );
//     }),
//     isCurved: true,
//     color: Theme.of(context).colorScheme.primary,
//     barWidth: 2,
//     dotData: const FlDotData(show: false),
//     belowBarData: BarAreaData(
//     show: true,
//     color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
//     ),
//     ),
//     ],
//     ),
//     ),
//     ),
//     );
//   }
//
//   Widget _buildCertificationInfo() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(
//                     Icons.info,
//                     color: Theme.of(context).colorScheme.primary,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 const Text(
//                   'FSC-Zertifizierung',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Der Forest Stewardship Council (FSC) ist eine internationale gemeinnützige Organisation, '
//                   'die sich für eine umweltgerechte, sozialverträgliche und wirtschaftlich tragfähige '
//                   'Waldwirtschaft einsetzt.',
//               style: TextStyle(fontSize: 14),
//             ),
//             const SizedBox(height: 16),
//             _buildInfoRow(
//               icon: Icons.check_circle_outline,
//               title: 'Nachhaltige Waldwirtschaft',
//               description: 'Gewährleistet die nachhaltige Nutzung und den Erhalt der Wälder',
//             ),
//             const SizedBox(height: 8),
//             _buildInfoRow(
//               icon: Icons.people_outline,
//               title: 'Soziale Standards',
//               description: 'Sicherung der Rechte von Waldarbeitern und lokalen Gemeinschaften',
//             ),
//             const SizedBox(height: 8),
//             _buildInfoRow(
//               icon: Icons.eco_outlined,
//               title: 'Ökologische Verantwortung',
//               description: 'Schutz bedrohter Tier- und Pflanzenarten sowie der Biodiversität',
//             ),
//             const SizedBox(height: 16),
//             OutlinedButton.icon(
//               onPressed: () {
//                 // Hier könnte ein Link zur FSC-Webseite oder zu Details implementiert werden
//               },
//               icon: const Icon(Icons.open_in_new),
//               label: const Text('Mehr über FSC erfahren'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildInfoRow({
//     required IconData icon,
//     required String title,
//     required String description,
//   }) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Icon(
//           icon,
//           size: 20,
//           color: Theme.of(context).colorScheme.primary,
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 14,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               Text(
//                 description,
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Theme.of(context).colorScheme.onSurfaceVariant,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }