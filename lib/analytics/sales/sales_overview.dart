import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/analytics/sales/services/sales_services.dart';
import '../../services/icon_helper.dart';
import 'models/sales_filter.dart';
import 'models/sales_models.dart';


class SalesOverview extends StatelessWidget {
  final SalesFilter filter;
  final SalesService _service = SalesService();

   SalesOverview({
    Key? key,
    required this.filter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SalesStats>(
      stream: _service.getSalesStatsStream(filter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      context,
                      title: 'Umsatz netto',
                      value: NumberFormat.currency(
                        locale: 'de_CH',
                        symbol: 'CHF',
                      ).format(stats.totalRevenue),
                      icon: Icons.attach_money,
                      iconName: 'attach_money',
                      trend: stats.revenueTrend,
                      subtitle: _getFilterTimeRange(),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildKpiCard(
                      context,
                      title: 'Top Kunde (brutto)',
                      value: stats.topCustomer.name,
                      icon: Icons.person,
                      iconName: 'person',
                      subtitle: NumberFormat.currency(
                        locale: 'de_CH',
                        symbol: 'CHF',
                      ).format(stats.topCustomer.revenue),
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      context,
                      title: 'Top Produkt',
                      value: stats.topProduct.name,
                      icon: Icons.inventory,
                      iconName: 'inventory',
                      subtitle: '${stats.topProduct.quantity} Stück verkauft',
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildKpiCard(
                      context,
                      title: '⌀ Auftrag',
                      value: NumberFormat.currency(
                        locale: 'de_CH',
                        symbol: 'CHF',
                      ).format(stats.averageOrderValue),
                      icon:    Icons.shopping_cart,
                     iconName: 'shopping_cart',
                      trend: stats.orderValueTrend,
                      subtitle: 'Pro Verkauf',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Top Products Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                            getAdaptiveIcon(iconName: 'bar_chart', defaultIcon: Icons.bar_chart, color: Colors.blue,),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top 10 Produkte',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Umsatz: ${_getFilterTimeRange()}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 400,
                        child: stats.topProducts.isEmpty
                            ? const Center(child: Text('Keine Verkaufsdaten vorhanden'))
                            : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: getMaxY(stats.topProducts),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: getInterval(getMaxY(stats.topProducts)),
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey[300]!,
                                  strokeWidth: 1,
                                  dashArray: [5, 5], // Gestrichelte Linien
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 60,
                                  interval: getInterval(getMaxY(stats.topProducts)), // Gleicher Interval wie Grid
                                  getTitlesWidget: (value, meta) {
                                    // Nur anzeigen, wenn es ein ganzzahliges Vielfaches des Intervals ist
                                    if (value % getInterval(getMaxY(stats.topProducts)) != 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        NumberFormat.compactCurrency( // Kompaktes Format für große Zahlen
                                          locale: 'de_CH',
                                          symbol: 'CHF',
                                          decimalDigits: 0,
                                        ).format(value),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value >= 0 && value < stats.topProducts.length) {
                                      return Transform.rotate(
                                        angle: -0.5,
                                        child: SizedBox(
                                          width: 80,
                                          child: Text(
                                            stats.topProducts[value.toInt()].name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[300]!),
                                left: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            barGroups: stats.topProducts.map((product) {
                              final index = stats.topProducts.indexOf(product);
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: product.revenue > 0 ? product.revenue : 0.1,
                                    color: Colors.blue.withOpacity(0.8),
                                    width: 20,
                                    borderRadius: BorderRadius.circular(4),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: getMaxY(stats.topProducts),
                                      color: Colors.grey[200],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Optional: Zusätzliche Visualisierungen
              // z.B. Umsatzverteilung nach Holzart oder Qualität
              if (stats.woodTypeDistribution.isNotEmpty)
                _buildDistributionPieChart(
                  context,
                  'Umsatzverteilung nach Holzart',
                  stats.woodTypeDistribution,
                ),
            ],
          ),
        );
      },
    );
  }

  double getMaxY(List<ProductStats> products) {
    if (products.isEmpty) return 100;  // Default wenn keine Produkte
    final maxRevenue = products.map((p) => p.revenue).reduce(max);
    return maxRevenue <= 0 ? 100 : maxRevenue * 1.2;  // Mindestens 100 als Maximum
  }

  double getInterval(double maxY) {
    if (maxY <= 100) return 20;  // Default-Intervall für kleine Werte
    return maxY / 5;  // 5 Intervalle
  }

  Widget _buildKpiCard(
      BuildContext context, {
        required String title,
        required String value,
        required IconData icon,
        String? subtitle,
        double? trend,
        required Color color,
        String? iconName, // Neuer Parameter für adaptiveIcon
        String? trendUpIconName, // Für den Trend-Up-Icon
        String? trendDownIconName, // Für den Trend-Down-Icon
      }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(
                        red: 0,
                        green:0,
                        blue: 0,
                        alpha: 0.1
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: iconName != null
                      ? getAdaptiveIcon(
                    iconName: iconName,
                    defaultIcon: icon,
                    color: color,
                  )
                      : Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (trend != null) ...[
                    const SizedBox(width: 8),
                    trend >= 0
                        ? getAdaptiveIcon(
                      iconName: trendUpIconName ?? 'trending_up',
                      defaultIcon: Icons.trending_up,
                      color: Colors.green,
                      size: 16,
                    )
                        : getAdaptiveIcon(
                      iconName: trendDownIconName ?? 'trending_down',
                      defaultIcon: Icons.trending_down,
                      color: Colors.red,
                      size: 16,
                    ),
                    Text(
                      '${trend.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: trend >= 0 ? Colors.green : Colors.red,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionPieChart(
      BuildContext context,
      String title,
      Map<String, double> distribution,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: distribution.entries.map((entry) {
                    final total = distribution.values.reduce((a, b) => a + b);
                    final percentage = entry.value / total * 100;
                    return PieChartSectionData(
                      value: entry.value,
                      title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      color: Colors.primaries[
                      distribution.keys.toList().indexOf(entry.key) %
                          Colors.primaries.length
                      ],
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: distribution.entries.map((entry) {
                final index = distribution.keys.toList().indexOf(entry.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.primaries[index % Colors.primaries.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(entry.key),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterTimeRange() {
    if (filter.timeRange != null) {
      switch (filter.timeRange) {
        case 'week':
          return 'Letzte Woche';
        case 'month':
          return 'Letzter Monat';
        case 'quarter':
          return 'Letztes Quartal';
        case 'year':
          return 'Letztes Jahr';
      }
    }

    if (filter.startDate != null && filter.endDate != null) {
      return '${DateFormat('dd.MM.yy').format(filter.startDate!)} - '
          '${DateFormat('dd.MM.yy').format(filter.endDate!)}';
    }

    return 'insgesamt';
  }
}