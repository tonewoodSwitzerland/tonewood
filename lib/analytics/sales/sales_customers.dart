// // lib/screens/analytics/sales/sales_customers.dart
//
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart';
// import 'models/sales_models.dart';
// import 'services/sales_services.dart';
// import 'constants/constants.dart';
// import 'widgets/sales_stats_card.dart';
// import 'widgets/sales_chart_card.dart';
//
// class SalesCustomers extends StatefulWidget {
//   const SalesCustomers({Key? key}) : super(key: key);
//
//   @override
//   SalesCustomersState createState() => SalesCustomersState();
// }
//
// class SalesCustomersState extends State<SalesCustomers> {
//   final SalesService _service = SalesService();
//   String selectedView = 'overview';
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16),
//           child: SegmentedButton<String>(
//             segments: const [
//               ButtonSegment(
//                 value: 'overview',
//                 icon: Icon(Icons.dashboard),
//                 label: Text('Übersicht'),
//               ),
//               ButtonSegment(
//                 value: 'details',
//                 icon: Icon(Icons.list),
//                 label: Text('Details'),
//               ),
//               ButtonSegment(
//                 value: 'analysis',
//                 icon: Icon(Icons.analytics),
//                 label: Text('Analyse'),
//               ),
//             ],
//             selected: {selectedView},
//             onSelectionChanged: (Set<String> selection) {
//               setState(() {
//                 selectedView = selection.first;
//               });
//             },
//           ),
//         ),
//         Expanded(
//           child: _buildSelectedView(),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildSelectedView() {
//     switch (selectedView) {
//       case 'overview':
//         return _buildOverview();
//       case 'details':
//         return _buildDetails();
//       case 'analysis':
//         return _buildAnalysis();
//       default:
//         return _buildOverview();
//     }
//   }
//
//   Widget _buildOverview() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildCustomerStats(),
//           const SizedBox(height: 24),
//           _buildTopCustomers(),
//           const SizedBox(height: 24),
//           _buildRegionalDistribution(),
//           const SizedBox(height: 24),
//           _buildCustomerTrends(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCustomerStats() {
//     return FutureBuilder<CustomerStats>(
//       future: _service.getCustomerStats(),
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
//             SalesStatsCard(
//               title: 'Aktive Kunden',
//               value: stats.totalCustomers.toString(),
//               icon: Icons.people,
//               color: Theme.of(context).colorScheme.primary,
//             ),
//             SalesStatsCard(
//               title: 'Ø Kundenwert',
//               value: NumberFormat.currency(
//                 locale: 'de_CH',
//                 symbol: 'CHF',
//               ).format(stats.averageCustomerValue),
//               icon: Icons.person,
//               color: Theme.of(context).colorScheme.secondary,
//             ),
//             SalesStatsCard(
//               title: 'Regionen',
//               value: stats.ordersByRegion.length.toString(),
//               icon: Icons.public,
//               color: Theme.of(context).colorScheme.tertiary,
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Widget _buildTopCustomers() {
//     return FutureBuilder<CustomerStats>(
//       future: _service.getCustomerStats(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         return SalesChartCard(
//           title: 'Top Kunden',
//           subtitle: 'Nach Umsatz',
//           child: SizedBox(
//             height: 400,
//             child: ListView.builder(
//               itemCount: snapshot.data!.topCustomers.length,
//               itemBuilder: (context, index) {
//                 final customer = snapshot.data!.topCustomers[index];
//                 return ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: Theme.of(context).colorScheme.primaryContainer,
//                     child: Text(
//                       '${index + 1}',
//                       style: TextStyle(
//                         color: Theme.of(context).colorScheme.onPrimaryContainer,
//                       ),
//                     ),
//                   ),
//                   title: Text('Kunde ${customer['customer_id']}'),
//                   subtitle: Text(NumberFormat.currency(
//                     locale: 'de_CH',
//                     symbol: 'CHF',
//                   ).format(customer['total_value'])),
//                   trailing: IconButton(
//                     icon: const Icon(Icons.chevron_right),
//                     onPressed: () => _showCustomerDetails(customer),
//                   ),
//                 );
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildRegionalDistribution() {
//     return FutureBuilder<CustomerStats>(
//       future: _service.getCustomerStats(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         return SalesChartCard(
//           title: 'Regionale Verteilung',
//           subtitle: 'Bestellungen nach Region',
//           child: SizedBox(
//             height: 300,
//             child: PieChart(
//               PieChartData(
//                 sections: _buildRegionSections(snapshot.data!.ordersByRegion),
//                 sectionsSpace: 2,
//                 centerSpaceRadius: 40,
//                 pieTouchData: PieTouchData(
//                   touchCallback: (FlTouchEvent event, pieTouchResponse) {
//                     // Interaktive Funktionen könnten hier hinzugefügt werden
//                   },
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   List<PieChartSectionData> _buildRegionSections(Map<String, int> regionData) {
//     final total = regionData.values.reduce((a, b) => a + b);
//
//     return regionData.entries.map((entry) {
//       final percentage = entry.value / total * 100;
//       final color = SalesColors.getRegionColor(entry.key.toLowerCase());
//
//       return PieChartSectionData(
//         value: entry.value.toDouble(),
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
//   Widget _buildCustomerTrends() {
//     return FutureBuilder<CustomerStats>(
//       future: _service.getCustomerStats(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         // Sortiere nach Kundenwert für die Entwicklung
//         final sortedCustomers = Map.fromEntries(
//             snapshot.data!.customerLifetimeValue.entries.toList()
//               ..sort((a, b) => b.value.compareTo(a.value))
//         );
//
//         return SalesChartCard(
//           title: 'Kundenentwicklung',
//           subtitle: 'Lifetime Value',
//           child: SizedBox(
//             height: 300,
//             child: BarChart(
//               BarChartData(
//                 alignment: BarChartAlignment.spaceAround,
//                 maxY: sortedCustomers.isEmpty ? 0 :
//                 sortedCustomers.values.first * 1.2,
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
//                         if (value >= 0 && value < sortedCustomers.length) {
//                           return Transform.rotate(
//                             angle: -0.5,
//                             child: Text(
//                               'Kunde ${value.toInt() + 1}',
//                               style: const TextStyle(fontSize: 10),
//                             ),
//                           );
//                         }
//                         return const SizedBox.shrink();
//                       },
//                     ),
//                   ),
//                 ),
//                 barGroups: List.generate(
//                   sortedCustomers.length,
//                       (index) => BarChartGroupData(
//                     x: index,
//                     barRods: [
//                       BarChartRodData(
//                         toY: sortedCustomers.values.elementAt(index),
//                         color: Theme.of(context).colorScheme.primary,
//                         width: 20,
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
//   Widget _buildDetails() {
//     // Detaillierte Kundenübersicht
//     return const Center(child: Text('Detailansicht wird implementiert...'));
//   }
//
//   Widget _buildAnalysis() {
//     // Erweiterte Kundenanalyse
//     return const Center(child: Text('Analyseansicht wird implementiert...'));
//   }
//
//   void _showCustomerDetails(Map<String, dynamic> customer) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Kunde ${customer['customer_id']}'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 title: const Text('Gesamtumsatz'),
//                 trailing: Text(
//                   NumberFormat.currency(
//                     locale: 'de_CH',
//                     symbol: 'CHF',
//                   ).format(customer['total_value']),
//                 ),
//               ),
//               // Weitere Kundendetails könnten hier hinzugefügt werden
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Schließen'),
//           ),
//         ],
//       ),
//     );
//   }
// }