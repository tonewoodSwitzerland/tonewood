// lib/customers/widgets/customer_purchase_stats_header.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../services/icon_helper.dart';
import '../../analytics/sales/models/customer_sales_stats.dart';
import '../../analytics/sales/services/customer_stats_service.dart';

/// Kompakter Stats-Header für die Kaufhistorie eines Kunden.
/// Zeigt Segment-Badge, KPIs, Sparkline und Jahresvergleich.
/// Fällt automatisch auf eine einfache Ansicht zurück wenn
/// keine vorberechneten Stats vorhanden sind.
class CustomerPurchaseStatsHeader extends StatefulWidget {
  final String customerId;

  const CustomerPurchaseStatsHeader({
    Key? key,
    required this.customerId,
  }) : super(key: key);

  @override
  State<CustomerPurchaseStatsHeader> createState() =>
      _CustomerPurchaseStatsHeaderState();
}

class _CustomerPurchaseStatsHeaderState
    extends State<CustomerPurchaseStatsHeader> {
  CustomerSegmentConfig _segmentConfig = const CustomerSegmentConfig();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final c = await CustomerStatsService.getSegmentConfig();
      if (mounted) setState(() => _segmentConfig = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CustomerSalesStats>(
      stream: CustomerStatsService.getStatsStream(widget.customerId),
      builder: (context, statsSnap) {
        return FutureBuilder<int>(
          future: _countQuotes(),
          builder: (context, quotesSnap) {
            final stats = statsSnap.data;
            final quoteCount = quotesSnap.data ?? 0;

            if (statsSnap.connectionState == ConnectionState.waiting &&
                stats == null) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }

            // Fallback: keine vorberechneten Stats
            if (stats == null || stats.totalOrders == 0) {
              return _LegacyHeader(
                customerId: widget.customerId,
                quoteCount: quoteCount,
              );
            }

            return _StatsHeader(
              stats: stats,
              quoteCount: quoteCount,
              segmentConfig: _segmentConfig,
            );
          },
        );
      },
    );
  }

  Future<int> _countQuotes() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('quotes')
          .where('customer.id', isEqualTo: widget.customerId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Stats-Header (mit vorberechneten Daten)
// ═══════════════════════════════════════════════════════════════

class _StatsHeader extends StatelessWidget {
  final CustomerSalesStats stats;
  final int quoteCount;
  final CustomerSegmentConfig segmentConfig;

  const _StatsHeader({
    required this.stats,
    required this.quoteCount,
    required this.segmentConfig,
  });

  static final _cf = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);

  static const _segColors = {
    'VIP': Color(0xFFF9A825),
    'Stammkunde': Color(0xFF4CAF50),
    'Gelegentlich': Color(0xFF2196F3),
    'Neukunde': Color(0xFF9C27B0),
    'Inaktiv': Color(0xFF9E9E9E),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segment = stats.getSegment(segmentConfig);
    final segColor = _segColors[segment] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Zeile 1: Segment + Kunde seit + letzte Bestellung
          Row(
            children: [
              _SegmentBadge(segment: segment, color: segColor),
              const SizedBox(width: 8),
              if (stats.firstOrderDate != null)
                Text(
                  'seit ${DateFormat('MM/yyyy').format(stats.firstOrderDate!)}',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              const Spacer(),
              if (stats.daysSinceLastOrder >= 0)
                Text(
                  stats.daysSinceLastOrder == 0
                      ? 'Heute bestellt'
                      : 'vor ${stats.daysSinceLastOrder} T.',
                  style: TextStyle(
                    fontSize: 11,
                    color: stats.daysSinceLastOrder > 180
                        ? Colors.red
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Zeile 2: KPIs
          Row(
            children: [
              _KpiCell(value: quoteCount.toString(), label: 'Angebote'),
              _KpiCell(value: stats.totalOrders.toString(), label: 'Aufträge'),
              _KpiCell(value: _cf.format(stats.totalRevenueGross), label: 'Gesamt'),
              _KpiCell(value: _cf.format(stats.averageOrderValueGross), label: 'Ø Auftrag'),
            ],
          ),

          // Sparkline
          if (stats.monthlyRevenue.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: _Sparkline(data: stats.monthlyRevenue, color: segColor),
            ),
          ],

          // Jahresvergleich
          if (stats.yearRevenue > 0) ...[
            const SizedBox(height: 12),
            _YearComparison(stats: stats),
          ],

          const SizedBox(height: 8),

          // Info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info,
                  size: 12, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Alle Beträge in CHF (Basis-Währung)',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Segment Badge
// ═══════════════════════════════════════════════════════════════

class _SegmentBadge extends StatelessWidget {
  final String segment;
  final Color color;
  const _SegmentBadge({required this.segment, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        segment,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// KPI Cell
// ═══════════════════════════════════════════════════════════════

class _KpiCell extends StatelessWidget {
  final String value;
  final String label;
  const _KpiCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Sparkline (Mini-Bar-Chart, 12 Monate)
// ═══════════════════════════════════════════════════════════════

class _Sparkline extends StatelessWidget {
  final Map<String, double> data;
  final Color color;
  const _Sparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final keys = data.keys.toList()..sort();
    final last12 = keys.length > 12 ? keys.sublist(keys.length - 12) : keys;
    if (last12.isEmpty) return const SizedBox();

    final values = last12.map((k) => data[k] ?? 0.0).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.1,
        barTouchData: BarTouchData(enabled: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(last12.length, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: color.withOpacity(0.5),
              width: last12.length > 8 ? 6 : 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ],
        )),
      ),

    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Year Comparison Row
// ═══════════════════════════════════════════════════════════════

class _YearComparison extends StatelessWidget {
  final CustomerSalesStats stats;
  const _YearComparison({required this.stats});

  static final _cf = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yc = stats.yearChangePercent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${DateTime.now().year}: ${_cf.format(stats.yearRevenue)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant),
        ),
        if (yc != 0) ...[
          const SizedBox(width: 8),
          Icon(
            yc >= 0 ? Icons.trending_up : Icons.trending_down,
            size: 14, color: yc >= 0 ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 2),
          Text(
            '${yc >= 0 ? '+' : ''}${yc.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: yc >= 0 ? Colors.green : Colors.red),
          ),
          Text(' vs. Vorjahr', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Legacy Header (Fallback ohne vorberechnete Stats)
// ═══════════════════════════════════════════════════════════════

class _LegacyHeader extends StatelessWidget {
  final String customerId;
  final int quoteCount;
  const _LegacyHeader({required this.customerId, required this.quoteCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('orders')
          .where('customer.id', isEqualTo: customerId)
          .get(),
      builder: (context, snapshot) {
        int orderCount = 0;
        double totalSpent = 0;

        if (snapshot.hasData) {
          orderCount = snapshot.data!.docs.length;
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final calc = data['calculations'] as Map<String, dynamic>? ?? {};
            totalSpent += (calc['total'] as num?)?.toDouble() ?? 0;
          }
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _KpiCell(value: quoteCount.toString(), label: 'Angebote'),
                  _KpiCell(value: orderCount.toString(), label: 'Aufträge'),
                  _KpiCell(
                    value: 'CHF ${totalSpent.toStringAsFixed(0)}',
                    label: 'Gesamt',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info,
                      size: 12, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Alle Beträge in CHF (Basis-Währung)',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}