// lib/analytics/sales/screens/sales_country_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/icon_helper.dart';

import '../models/sales_filter.dart';
import '../models/sales_analytics_models.dart';
import '../services/sales_analytics_service.dart';

class SalesCountryView extends StatefulWidget {
  final SalesFilter filter;

  const SalesCountryView({Key? key, required this.filter}) : super(key: key);

  @override
  State<SalesCountryView> createState() => _SalesCountryViewState();
}

class _SalesCountryViewState extends State<SalesCountryView> {
  String _sortBy = 'revenue'; // 'revenue' oder 'orders'

  @override
  Widget build(BuildContext context) {
    final service = SalesAnalyticsService();

    return StreamBuilder<SalesAnalytics>(
      stream: service.getAnalyticsStream(widget.filter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        }

        final analytics = snapshot.data ?? SalesAnalytics.empty();
        final countries = analytics.countryStats.values.toList();

        // Sortieren
        if (_sortBy == 'revenue') {
          countries.sort((a, b) => b.revenue.compareTo(a.revenue));
        } else {
          countries.sort((a, b) => b.orderCount.compareTo(a.orderCount));
        }

        final totalRevenue = countries.fold<double>(0, (sum, c) => sum + c.revenue);
        final totalOrders = countries.fold<int>(0, (sum, c) => sum + c.orderCount);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header mit Gesamt-Stats
              _buildHeaderStats(context, countries.length, totalRevenue, totalOrders),
              const SizedBox(height: 24),

              // Chart + Tabelle Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pie Chart
                        Expanded(
                          flex: 2,
                          child: _buildPieChartCard(context, countries, totalRevenue),
                        ),
                        const SizedBox(width: 16),
                        // Tabelle
                        Expanded(
                          flex: 3,
                          child: _buildCountryTable(context, countries, totalRevenue, totalOrders),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildPieChartCard(context, countries, totalRevenue),
                        const SizedBox(height: 16),
                        _buildCountryTable(context, countries, totalRevenue, totalOrders),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderStats(BuildContext context, int countryCount, double totalRevenue, int totalOrders) {
    final theme = Theme.of(context);
    final format = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF');

    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: getAdaptiveIcon(
                      iconName: 'public',
                      defaultIcon: Icons.public,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$countryCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Länder',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: getAdaptiveIcon(
                      iconName: 'local_shipping',
                      defaultIcon: Icons.local_shipping,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalOrders',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Lieferungen',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartCard(BuildContext context, List<CountryStats> countries, double totalRevenue) {
    final theme = Theme.of(context);
    final topCountries = countries.take(6).toList();
    final otherRevenue = countries.skip(6).fold<double>(0, (sum, c) => sum + c.revenue);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Umsatz nach Land (Warenwert)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: [
                    ...List.generate(topCountries.length, (index) {
                      final country = topCountries[index];
                      final percent = totalRevenue > 0 ? (country.revenue / totalRevenue * 100) : 0;
                      return PieChartSectionData(
                        value: country.revenue,
                        title: percent > 5 ? '${percent.toStringAsFixed(0)}%' : '',
                        color: _getCountryColor(index),
                        radius: 80,
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
                        radius: 80,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legende
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ...List.generate(topCountries.length, (index) {
                  return _buildLegendItem(
                    topCountries[index].countryName,
                    _getCountryColor(index),
                  );
                }),
                if (otherRevenue > 0)
                  _buildLegendItem('Andere', Colors.grey[400]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildCountryTable(BuildContext context, List<CountryStats> countries, double totalRevenue, int totalOrders) {
    final theme = Theme.of(context);
    final format = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);

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
                const Text(
                  'Länder-Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Sort Toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'revenue', label: Text('Umsatz')),
                    ButtonSegment(value: 'orders', label: Text('Lief.')),
                  ],
                  selected: {_sortBy},
                  onSelectionChanged: (selection) {
                    setState(() => _sortBy = selection.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Land', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Warenwert', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text('%', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text('Lfg.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Rows
            ...countries.take(15).map((country) {
              final revenuePercent = totalRevenue > 0 ? (country.revenue / totalRevenue * 100) : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Text(
                            _getCountryFlag(country.countryCode),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              country.countryName,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        format.format(country.revenue),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${revenuePercent.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        country.orderCount.toString(),
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (countries.length > 15) ...[
              const SizedBox(height: 8),
              Text(
                '+ ${countries.length - 15} weitere Länder',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getCountryColor(int index) {
    const colors = [
      Color(0xFF2196F3), // Blau
      Color(0xFF4CAF50), // Grün
      Color(0xFFFF9800), // Orange
      Color(0xFF9C27B0), // Violett
      Color(0xFF00BCD4), // Cyan
      Color(0xFFE91E63), // Pink
    ];
    return colors[index % colors.length];
  }

  String _getCountryFlag(String countryCode) {
    // Konvertiert Ländercode zu Emoji-Flag
    if (countryCode.length != 2) return '🏳️';
    final flag = countryCode.toUpperCase().codeUnits
        .map((c) => String.fromCharCode(c + 127397))
        .join();
    return flag;
  }
}