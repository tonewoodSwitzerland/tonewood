// lib/analytics/sales/screens/sales_kpi_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/icon_helper.dart';
import '../models/sales_filter.dart';
import '../models/sales_analytics_models.dart';
import '../services/sales_analytics_service.dart';

class SalesKpiView extends StatelessWidget {
  final SalesFilter filter;

  const SalesKpiView({Key? key, required this.filter}) : super(key: key);

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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Fehler: ${snapshot.error}'),
              ],
            ),
          );
        }

        final analytics = snapshot.data ?? SalesAnalytics.empty();
        final currencyFormat = NumberFormat.currency(locale: 'de_DE', symbol: 'CHF', decimalDigits: 0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hauptzeile: Umsatz Jahr, Monat, Anzahl, Durchschnitt
              _buildMainKpiRow(context, analytics, currencyFormat),
              const SizedBox(height: 16),

              // Zweite Zeile: Thermo-Anteil
              _buildThermoCard(context, analytics),

            ],
          ),
        );
      },
    );
  }

  Widget _buildMainKpiRow(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final cards = [
          _KpiCardData(
            title: 'Umsatz ${DateTime.now().year}',
            value: format.format(analytics.revenue.yearRevenue),
            icon: Icons.calendar_today,
            iconName: 'calendar_today',
            color: Colors.blue,
            trend: analytics.revenue.yearChangePercent,
            trendLabel: 'vs. Vorjahr',
          ),
          _KpiCardData(
            title: 'Umsatz ${_getCurrentMonthName()}',
            value: format.format(analytics.revenue.monthRevenue),
            icon: Icons.today,
            iconName: 'today',
            color: Colors.green,
            trend: analytics.revenue.monthChangePercent,
            trendLabel: 'vs. Vormonat',
            onTap: () => _showMonthlyRevenueDialog(context, analytics.revenue.monthlyRevenue),
          ),
          _KpiCardData(
            title: 'Anzahl Verkäufe',
            value: analytics.orderCount.toString(),
            icon: Icons.shopping_cart,
            iconName: 'shopping_cart',
            color: Colors.orange,
          ),
          _KpiCardData(
            title: 'Ø Erlös / Verkauf',
            value: format.format(analytics.averageOrderValue),
            icon: Icons.analytics,
            iconName: 'analytics',
            color: Colors.purple,
          ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map((card) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildKpiCard(context, card),
              ),
            ))
                .toList(),
          );
        } else {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              child: _buildKpiCard(context, card),
            ))
                .toList(),
          );
        }
      },
    );
  }

  void _showMonthlyRevenueDialog(BuildContext context, Map<String, double> monthlyRevenue) {
    // Sortiere und nimm die letzten 12 Monate
    final sortedMonths = monthlyRevenue.keys.toList()..sort();
    final last12Months = sortedMonths.length > 12
        ? sortedMonths.sublist(sortedMonths.length - 12)
        : sortedMonths;

    final maxRevenue = last12Months.isEmpty
        ? 1.0
        : last12Months.map((m) => monthlyRevenue[m] ?? 0).reduce((a, b) => a > b ? a : b);

    final format = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: getAdaptiveIcon(
                      iconName: 'trending_up',
                      defaultIcon: Icons.trending_up,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Monatliche Umsätze',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Chart
              Expanded(
                child: last12Months.isEmpty
                    ? const Center(child: Text('Keine Daten verfügbar'))
                    : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxRevenue * 1.15,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.grey[800]!,
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final monthKey = last12Months[group.x.toInt()];
                          final value = monthlyRevenue[monthKey] ?? 0;
                          return BarTooltipItem(
                            '${_formatMonthLabel(monthKey)}\n${format.format(value)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                _formatAxisValue(value),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= last12Months.length) {
                              return const SizedBox();
                            }
                            final monthKey = last12Months[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _formatMonthShort(monthKey),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxRevenue / 4,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    barGroups: List.generate(last12Months.length, (index) {
                      final monthKey = last12Months[index];
                      final value = monthlyRevenue[monthKey] ?? 0;
                      final isCurrentMonth = monthKey ==
                          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: value,
                            color: isCurrentMonth ? Colors.green : Colors.green.withOpacity(0.6),
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Legende
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Aktueller Monat', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 24),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Vergangene Monate', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return '${months[month - 1]} $year';
  }

  String _formatMonthShort(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final month = int.tryParse(parts[1]) ?? 1;
    final months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return months[month - 1];
  }

  String _formatAxisValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildKpiCard(BuildContext context, _KpiCardData data) {
    final theme = Theme.of(context);

    final card = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: getAdaptiveIcon(
                    iconName: data.iconName,
                    defaultIcon: data.icon,
                    color: data.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Zeige Klick-Hinweis wenn onTap vorhanden
                if (data.onTap != null)
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (data.trend != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    data.trend! >= 0 ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: data.trend! >= 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${data.trend! >= 0 ? '+' : ''}${data.trend!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: data.trend! >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    data.trendLabel ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    // Wenn onTap vorhanden, wrap in InkWell
    if (data.onTap != null) {
      return InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }

  Widget _buildThermoCard(BuildContext context, SalesAnalytics analytics) {
    final theme = Theme.of(context);
    final thermo = analytics.thermoStats;

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
                    color: Colors.deepOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'whatshot',
                    defaultIcon: Icons.whatshot,
                    color: Colors.deepOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Thermobehandlung',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildThermoStat(
                    context,
                    label: 'Anteil Artikel',
                    value: '${thermo.itemSharePercent.toStringAsFixed(1)}%',
                    detail: '${thermo.thermoItemCount} von ${thermo.totalItemCount}',
                  ),
                ),
                Container(
                  height: 50,
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _buildThermoStat(
                    context,
                    label: 'Anteil Umsatz',
                    value: '${thermo.revenueSharePercent.toStringAsFixed(1)}%',
                    detail: NumberFormat.currency(locale: 'de_CH', symbol: 'CHF')
                        .format(thermo.thermoRevenue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: thermo.itemSharePercent / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThermoStat(BuildContext context, {
    required String label,
    required String value,
    required String detail,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }




  String _getCurrentMonthName() {
    final months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return months[DateTime.now().month - 1];
  }
}

class _KpiCardData {
  final String title;
  final String value;
  final IconData icon;
  final String iconName;
  final Color color;
  final double? trend;
  final String? trendLabel;
  final VoidCallback? onTap;

  _KpiCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconName,
    required this.color,
    this.trend,
    this.trendLabel,
    this.onTap,
  });
}