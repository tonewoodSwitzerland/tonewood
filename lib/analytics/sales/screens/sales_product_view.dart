// lib/analytics/sales/screens/sales_product_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/icon_helper.dart';
import '../models/sales_filter.dart';
import '../models/sales_analytics_models.dart';
import '../services/sales_analytics_service.dart';

class SalesProductView extends StatelessWidget {
  final SalesFilter filter;

  const SalesProductView({Key? key, required this.filter}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = SalesAnalyticsService();

    return StreamBuilder<SalesAnalytics>(
      stream: service.getAnalyticsStream(filter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        }

        final analytics = snapshot.data ?? SalesAnalytics.empty();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top 10 Produkt-Kombinationen
              _buildTop10ProductCombos(context, analytics.topProductCombos),
              const SizedBox(height: 24),

              // Umsatz nach Holzart
              _buildWoodTypeAnalysis(context, analytics.woodTypeStats),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTop10ProductCombos(BuildContext context, List<ProductComboStats> combos) {
    final theme = Theme.of(context);
    final format = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);

    if (combos.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Keine Daten verfügbar')),
        ),
      );
    }

    final maxRevenue = combos.first.revenue;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'emoji_events',
                    defaultIcon: Icons.emoji_events,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Top 10 Produkte',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kombination aus Instrument und Bauteil',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Top 10 Liste mit Balken
            ...List.generate(combos.length, (index) {
              final combo = combos[index];
              final barWidth = maxRevenue > 0 ? combo.revenue / maxRevenue : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Rang
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _getRankColor(index),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                combo.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${combo.quantity} Stück',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Umsatz
                        Text(
                          format.format(combo.revenue),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: barWidth.toDouble(),
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(_getRankColor(index).withOpacity(0.7)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWoodTypeAnalysis(BuildContext context, Map<String, WoodTypeStats> woodStats) {
    final theme = Theme.of(context);
    final format = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);

    final sortedWoodTypes = woodStats.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final totalRevenue = sortedWoodTypes.fold<double>(0, (sum, w) => sum + w.revenue);

    if (sortedWoodTypes.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Keine Holzarten-Daten verfügbar')),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.brown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'forest',
                    defaultIcon: Icons.forest,
                    color: Colors.brown,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Umsatz nach Holzart',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pie Chart
                      Expanded(
                        flex: 2,
                        child: _buildWoodTypePieChart(context, sortedWoodTypes, totalRevenue),
                      ),
                      const SizedBox(width: 24),
                      // Liste
                      Expanded(
                        flex: 3,
                        child: _buildWoodTypeList(context, sortedWoodTypes, totalRevenue, format),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildWoodTypePieChart(context, sortedWoodTypes, totalRevenue),
                      const SizedBox(height: 20),
                      _buildWoodTypeList(context, sortedWoodTypes, totalRevenue, format),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWoodTypePieChart(BuildContext context, List<WoodTypeStats> woodTypes, double totalRevenue) {
    final topWoodTypes = woodTypes.take(6).toList();
    final otherRevenue = woodTypes.skip(6).fold<double>(0, (sum, w) => sum + w.revenue);

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 35,
          sections: [
            ...List.generate(topWoodTypes.length, (index) {
              final wood = topWoodTypes[index];
              final percent = totalRevenue > 0 ? (wood.revenue / totalRevenue * 100) : 0;
              return PieChartSectionData(
                value: wood.revenue,
                title: percent > 7 ? '${percent.toStringAsFixed(0)}%' : '',
                color: _getWoodColor(index),
                radius: 70,
                titleStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }),
            if (otherRevenue > 0)
              PieChartSectionData(
                value: otherRevenue,
                title: '',
                color: Colors.grey[400],
                radius: 70,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWoodTypeList(BuildContext context, List<WoodTypeStats> woodTypes, double totalRevenue, NumberFormat format) {
    final theme = Theme.of(context);
    final topWoodTypes = woodTypes.take(10).toList();

    return Column(
      children: List.generate(topWoodTypes.length, (index) {
        final wood = topWoodTypes[index];
        final percent = totalRevenue > 0 ? (wood.revenue / totalRevenue * 100) : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              // Farbindikator
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _getWoodColor(index),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Name
              Expanded(
                flex: 2,
                child: Text(
                  wood.woodName,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              // Menge
              Expanded(
                child: Text(
                  '${wood.quantity} Stk',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // Prozent
              SizedBox(
                width: 50,
                child: Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // Umsatz
              SizedBox(
                width: 90,
                child: Text(
                  format.format(wood.revenue),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return const Color(0xFFFFD700); // Gold
    if (index == 1) return const Color(0xFFC0C0C0); // Silber
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return Colors.indigo.withOpacity(0.7);
  }

  Color _getWoodColor(int index) {
    const colors = [
      Color(0xFF8D6E63), // Braun
      Color(0xFF6D4C41), // Dunkelbraun
      Color(0xFFBCAAA4), // Hellbraun
      Color(0xFF795548), // Mittelbraun
      Color(0xFF5D4037), // Sehr dunkel
      Color(0xFFA1887F), // Graubraun
    ];
    return colors[index % colors.length];
  }
}