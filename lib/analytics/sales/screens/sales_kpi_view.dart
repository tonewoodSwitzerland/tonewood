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

  bool get _isFilteredByDate => filter.startDate != null || filter.endDate != null || filter.timeRange != null;

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
              // Hauptzeile: Warenwerte
              _buildMainKpiRow(context, analytics, currencyFormat),
              const SizedBox(height: 16),

              // Zweite Zeile: Gesamtbeträge (Brutto)
              _buildGrossRevenueRow(context, analytics, currencyFormat),
              const SizedBox(height: 16),

              // Dritte Zeile: Thermo-Anteil
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

        // Dynamische Liste der Karten basierend auf Filterzustand
        final List<_KpiCardData> cards = [];

        if (_isFilteredByDate) {
          // Ansicht wenn gefiltert: Fokus auf den Zeitraum
          cards.add(_KpiCardData(
            title: 'Warenwert Zeitraum',
            value: format.format(analytics.revenue.yearRevenue), // Nutzt den summierten Wert des Streams
            icon: Icons.date_range,
            iconName: 'date_range',
            color: Colors.blue,
          ));
        } else {
          // Standard-Ansicht (Ungefiltert)
          cards.add(_KpiCardData(
            title: 'Warenwert ${DateTime.now().year}',
            value: format.format(analytics.revenue.yearRevenue),
            icon: Icons.calendar_today,
            iconName: 'calendar_today',
            color: Colors.blue,
            trend: analytics.revenue.yearChangePercent,
            trendLabel: 'vs. Vorjahr',
          ));
          cards.add(_KpiCardData(
            title: 'Warenwert ${_getCurrentMonthName()}',
            value: format.format(analytics.revenue.monthRevenue),
            icon: Icons.today,
            iconName: 'today',
            color: Colors.green,
            trend: analytics.revenue.monthChangePercent,
            trendLabel: 'vs. Vormonat',
            onTap: () => _showMonthlyRevenueDialog(context, analytics.revenue.monthlyRevenue),
          ));
        }

        // Diese KPIs sind immer relevant
        cards.add(_KpiCardData(
          title: 'Anzahl Verkäufe',
          value: analytics.orderCount.toString(),
          icon: Icons.shopping_cart,
          iconName: 'shopping_cart',
          color: Colors.orange,
        ));
        cards.add(_KpiCardData(
          title: 'Ø Warenwert / Verkauf',
          value: format.format(analytics.averageOrderValue),
          icon: Icons.analytics,
          iconName: 'analytics',
          color: Colors.purple,
        ));

        return _renderCardLayout(context, cards, isWide, constraints.maxWidth);
      },
    );
  }

  Widget _buildGrossRevenueRow(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final List<_KpiCardData> cards = [];

        if (_isFilteredByDate) {
          cards.add(_KpiCardData(
            title: 'Gesamtbetrag Zeitraum',
            value: format.format(analytics.revenue.yearRevenueGross),
            icon: Icons.account_balance,
            iconName: 'account_balance',
            color: Colors.teal,
          ));
        } else {
          cards.add(_KpiCardData(
            title: 'Gesamtbetrag ${DateTime.now().year}',
            value: format.format(analytics.revenue.yearRevenueGross),
            icon: Icons.account_balance,
            iconName: 'account_balance',
            color: Colors.teal,
            trend: analytics.revenue.yearChangePercentGross,
            trendLabel: 'vs. Vorjahr',
          ));
          cards.add(_KpiCardData(
            title: 'Gesamtbetrag ${_getCurrentMonthName()}',
            value: format.format(analytics.revenue.monthRevenueGross),
            icon: Icons.receipt_long,
            iconName: 'receipt_long',
            color: Colors.indigo,
            trend: analytics.revenue.monthChangePercentGross,
            trendLabel: 'vs. Vormonat',
            onTap: () => _showMonthlyRevenueDialog(context, analytics.revenue.monthlyRevenueGross),
          ));
        }

        cards.add(_KpiCardData(
          title: 'Ø Gesamtbetrag / Verkauf',
          value: format.format(analytics.averageOrderValueGross),
          icon: Icons.receipt,
          iconName: 'receipt',
          color: Colors.blueGrey,
        ));

        return _renderCardLayout(context, cards, isWide, constraints.maxWidth);
      },
    );
  }

  Widget _renderCardLayout(BuildContext context, List<_KpiCardData> cards, bool isWide, double maxWidth) {
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
          width: (maxWidth - 12 - 16) / 2, // Korrigiert für Padding/Spacing
          child: _buildKpiCard(context, card),
        ))
            .toList(),
      );
    }
  }

  // ... (Die restlichen Methoden wie _showMonthlyRevenueDialog, _buildKpiCard, _buildThermoCard bleiben gleich)

  void _showMonthlyRevenueDialog(BuildContext context, Map<String, double> monthlyRevenue) {
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final monthKey = last12Months[group.x.toInt()];
                          final value = monthlyRevenue[monthKey] ?? 0;
                          return BarTooltipItem(
                            '${_formatMonthLabel(monthKey)}\n${format.format(value)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) => Text(_formatAxisValue(value), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value < 0 || value >= last12Months.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_formatMonthLabel(last12Months[value.toInt()]), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(last12Months.length, (index) {
                      final value = monthlyRevenue[last12Months[index]] ?? 0;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: value,
                            color: Colors.green,
                            width: last12Months.length > 6 ? 16 : 24,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
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
    final monthNames = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final monthIndex = int.tryParse(parts[1]);
    if (monthIndex == null || monthIndex < 1 || monthIndex > 12) return monthKey;
    return '${monthNames[monthIndex - 1]} ${parts[0].substring(2)}';
  }

  String _formatAxisValue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
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
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (data.onTap != null)
                  Icon(Icons.touch_app, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 12),
            Text(data.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    style: TextStyle(fontSize: 12, color: data.trend! >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Text(data.trendLabel ?? '', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (data.onTap != null) {
      return InkWell(onTap: data.onTap, borderRadius: BorderRadius.circular(12), child: card);
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
                  child: getAdaptiveIcon(iconName: 'whatshot', defaultIcon: Icons.whatshot, color: Colors.deepOrange, size: 24),
                ),
                const SizedBox(width: 16),
                const Text('Thermobehandlung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                Container(height: 50, width: 1, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: _buildThermoStat(
                    context,
                    label: 'Anteil Umsatz',
                    value: '${thermo.revenueSharePercent.toStringAsFixed(1)}%',
                    detail: NumberFormat.currency(locale: 'de_CH', symbol: 'CHF').format(thermo.thermoRevenue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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

  Widget _buildThermoStat(BuildContext context, {required String label, required String value, required String detail}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        Text(detail, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  String _getCurrentMonthName() {
    final months = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];
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