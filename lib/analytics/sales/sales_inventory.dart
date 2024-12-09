// // lib/screens/analytics/sales/sales_inventory.dart
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'models/sales_models.dart';
// import 'services/sales_services.dart';
// import 'constants/constants.dart';
// import 'widgets/sales_stats_card.dart';
// import 'widgets/sales_chart_card.dart';
//
// class SalesInventory extends StatefulWidget {
//   const SalesInventory({Key? key}) : super(key: key);
//
//   @override
//   SalesInventoryState createState() => SalesInventoryState();
// }
//
// class SalesInventoryState extends State<SalesInventory> {
//   final SalesService _service = SalesService();
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildInventoryStats(),
//           const SizedBox(height: 24),
//           _buildLowStockWarnings(),
//           const SizedBox(height: 24),
//           _buildStockMovements(),
//           const SizedBox(height: 24),
//           _buildCategoryDistribution(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInventoryStats() {
//     return FutureBuilder<InventoryStats>(
//       future: _service.getInventoryStats(),
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
//               title: 'Artikel im Lager',
//               value: NumberFormat('#,###').format(stats.totalItems),
//               icon: Icons.inventory_2,
//               color: Theme.of(context).colorScheme.primary,
//             ),
//             SalesStatsCard(
//               title: 'Niedriger Bestand',
//               value: stats.lowStockItems.toString(),
//               icon: Icons.warning,
//               color: Colors.orange,
//             ),
//             SalesStatsCard(
//               title: 'Kategorien',
//               value: stats.valueByCategory.length.toString(),
//               icon: Icons.category,
//               color: Theme.of(context).colorScheme.tertiary,
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Widget _buildLowStockWarnings() {
//     return FutureBuilder<InventoryStats>(
//       future: _service.getInventoryStats(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         final stats = snapshot.data!;
//         if (stats.lowStockItems == 0) {
//           return const SizedBox.shrink();
//         }
//
//         // Finde Produkte mit niedrigem Bestand
//         final lowStockProducts = stats.stockByProduct.entries
//             .where((entry) => entry.value < 10) // Schwellenwert für niedrigen Bestand
//             .toList();
//
//         return Card(
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     const Icon(Icons.warning, color: Colors.orange),
//                     const SizedBox(width: 8),
//                     Text(
//                       'Niedriger Lagerbestand',
//                       style: Theme.of(context).textTheme.titleMedium,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 ...lowStockProducts.map((product) => ListTile(
//                   title: Text(product.key),
//                   subtitle: Text('Aktueller Bestand: ${product.value} Stück'),
//                   trailing: FilledButton.tonal(
//                     onPressed: () {
//                       // Hier könnte eine Nachbestellung ausgelöst werden
//                     },
//                     child: const Text('Nachbestellen'),
//                   ),
//                 )),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildStockMovements() {
//     return FutureBuilder<InventoryStats>(
//       future: _service.getInventoryStats(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         return SalesChartCard(
//           title: 'Lagerbewegungen',
//           subtitle: 'Letzte Bewegungen',
//           child: SizedBox(
//             height: 400,
//             child: ListView.builder(
//               itemCount: snapshot.data!.recentMovements.length,
//               itemBuilder: (context, index) {
//                 final movement = snapshot.data!.recentMovements[index];
//                 final isPositive = movement['quantity_change'] as int > 0;
//
//                 return ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: isPositive
//                         ? Colors.green.withOpacity(0.1)
//                         : Colors.red.withOpacity(0.1),
//                     child: Icon(
//                       isPositive ? Icons.add : Icons.remove,
//                       color: isPositive ? Colors.green : Colors.red,
//                     ),
//                   ),
//                   title: Text(movement['product_name'] as String),
//                   subtitle: Text(
//                     DateFormat('dd.MM.yyyy HH:mm').format(
//                       (movement['timestamp'] as Timestamp).toDate(),
//                     ),
//                   ),
//                   trailing: Text(
//                     '${isPositive ? '+' : ''}${movement['quantity_change']}',
//                     style: TextStyle(
//                       color: isPositive ? Colors.green : Colors.red,
//                       fontWeight: FontWeight.bold,
//                     ),
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
//   Widget _buildCategoryDistribution() {
//     return FutureBuilder<InventoryStats>(
//       future: _service.getInventoryStats(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         return SalesChartCard(
//           title: 'Bestand nach Kategorie',
//           subtitle: 'Wertverteilung im Lager',
//           child: SizedBox(
//             height: 300,
//             child: BarChart(
//               BarChartData(
//                 alignment: BarChartAlignment.spaceAround,
//                 maxY: snapshot.data!.valueByCategory.isEmpty ? 0 :
//                 snapshot.data!.valueByCategory.values.reduce((a, b) => a > b ? a : b) * 1.2,
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
//                         final categories = snapshot.data!.valueByCategory.keys.toList();
//                         if (value >= 0 && value < categories.length) {
//                           return Transform.rotate(
//                             angle: -0.5,
//                             child: Text(
//                               categories[value.toInt()],
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
//                 barGroups: snapshot.data!.valueByCategory.entries.map((entry) {
//                   final index = snapshot.data!.valueByCategory.keys.toList().indexOf(entry.key);
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
// }