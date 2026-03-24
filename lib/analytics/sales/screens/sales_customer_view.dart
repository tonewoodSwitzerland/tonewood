// lib/analytics/sales/screens/sales_customer_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/icon_helper.dart';
import '../models/sales_filter.dart';
import '../models/customer_sales_stats.dart';
import '../services/customer_stats_service.dart';

/// Kunden-Analyse View — aggregiert direkt aus orders-Collection
class SalesCustomerView extends StatefulWidget {
  final SalesFilter filter;
  const SalesCustomerView({Key? key, required this.filter}) : super(key: key);

  @override
  State<SalesCustomerView> createState() => _SalesCustomerViewState();
}

class _SalesCustomerViewState extends State<SalesCustomerView> {
  CustomerSegmentConfig _segmentConfig = const CustomerSegmentConfig();
  final _cf = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);
  final _df = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _loadSegmentConfig();
  }

  Future<void> _loadSegmentConfig() async {
    try {
      final c = await CustomerStatsService.getSegmentConfig();
      if (mounted) setState(() => _segmentConfig = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Fehler: ${snapshot.error}'),
            ],
          ));
        }

        final customers = _aggregate(snapshot.data?.docs ?? []);
        if (customers.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Keine Kundendaten vorhanden'),
            ],
          ));
        }

        // Default-Sort: Umsatz absteigend
        customers.sort((a, b) => b.rev.compareTo(a.rev));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKpiRow(context, customers),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (ctx, box) {
                if (box.maxWidth > 900) {
                  return IntrinsicHeight(child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _buildTop10(context, customers)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildSegments(context, customers)),
                    ],
                  ));
                }
                return Column(children: [
                  _buildTop10(context, customers),
                  const SizedBox(height: 16),
                  _buildSegments(context, customers),
                ]);
              }),
              const SizedBox(height: 16),
              _buildInsights(context, customers),
            ],
          ),
        );
      },
    );
  }

  // ── QUERY ──────────────────────────────────────────────────
  Stream<QuerySnapshot> _buildQuery() {
    Query q = FirebaseFirestore.instance.collection('orders');
    if (widget.filter.selectedCustomers?.isNotEmpty ?? false) {
      q = q.where('customer.id', whereIn: widget.filter.selectedCustomers);
    } else if (widget.filter.selectedFairs?.isNotEmpty ?? false) {
      q = q.where('fair.id', whereIn: widget.filter.selectedFairs);
    }
    return q.snapshots();
  }

  // ── AGGREGATION ────────────────────────────────────────────
  List<_CRow> _aggregate(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final prevYearStart = DateTime(now.year - 1, 1, 1);
    final prevYearEnd = DateTime(now.year - 1, 12, 31, 23, 59, 59);

    DateTime? fStart = widget.filter.startDate;
    DateTime? fEnd = widget.filter.endDate;
    if (widget.filter.timeRange != null) {
      switch (widget.filter.timeRange) {
        case 'week':
          fStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
          fEnd = now; break;
        case 'month':
          fStart = DateTime(now.year, now.month, 1); fEnd = now; break;
        case 'quarter':
          fStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1); fEnd = now; break;
        case 'year':
          fStart = DateTime(now.year, 1, 1); fEnd = now; break;
      }
    }

    final Map<String, _Agg> map = {};

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['status'] == 'cancelled' || d['status'] != 'shipped') continue;

      DateTime? od;
      final odr = d['orderDate'];
      if (odr is Timestamp) od = odr.toDate();
      if (odr is String) od = DateTime.tryParse(odr);
      if (od == null) continue;

      if (fStart != null && od.isBefore(fStart)) continue;
      if (fEnd != null && od.isAfter(DateTime(fEnd.year, fEnd.month, fEnd.day, 23, 59, 59))) continue;

      if (widget.filter.countries?.isNotEmpty ?? false) {
        final cust = d['customer'] as Map<String, dynamic>? ?? {};
        final cc = cust['countryCode']?.toString() ?? cust['country']?.toString() ?? '';
        if (!widget.filter.countries!.contains(cc)) continue;
      }

      final cust = d['customer'] as Map<String, dynamic>? ?? {};
      final cid = cust['id']?.toString() ?? '';
      if (cid.isEmpty) continue;

      final calc = d['calculations'] as Map<String, dynamic>? ?? {};
      final sub = (calc['subtotal'] as num?)?.toDouble() ?? 0;
      final disc1 = (calc['item_discounts'] as num?)?.toDouble() ?? 0;
      final disc2 = (calc['total_discount_amount'] as num?)?.toDouble() ?? 0;
      final net = sub - (disc1 > 0 ? disc1 : disc2);
      final gross = (calc['total'] as num?)?.toDouble() ?? 0;

      final items = d['items'] as List<dynamic>? ?? [];
      int qty = 0;
      for (final it in items) {
        qty += ((it as Map<String, dynamic>)['quantity'] as num?)?.toInt() ?? 0;
      }

      final co = cust['company']?.toString() ?? '';
      final fn = cust['firstName']?.toString() ?? '';
      final ln = cust['lastName']?.toString() ?? '';
      final nm = co.isNotEmpty ? co : '$fn $ln'.trim();

      if (!map.containsKey(cid)) {
        map[cid] = _Agg(id: cid, name: nm.isEmpty ? 'Unbekannt' : nm);
      }

      final a = map[cid]!;
      a.rev += net; a.revG += gross; a.orders++; a.qty += qty;
      if (od.isAfter(yearStart) || od.isAtSameMomentAs(yearStart)) { a.yRev += net; a.yOrd++; }
      if (od.isAfter(prevYearStart) && od.isBefore(prevYearEnd)) { a.pRev += net; }
      if (a.first == null || od.isBefore(a.first!)) a.first = od;
      if (a.last == null || od.isAfter(a.last!)) a.last = od;
    }

    return map.values.map((a) {
      final avg = a.orders > 0 ? a.rev / a.orders : 0.0;
      final dsl = a.last != null ? now.difference(a.last!).inDays : -1;
      final yc = a.pRev > 0 ? ((a.yRev - a.pRev) / a.pRev * 100) : 0.0;

      String seg;
      if (a.orders >= _segmentConfig.vipMinOrders && a.yRev >= _segmentConfig.vipMinYearRevenue) {
        seg = 'VIP';
      } else if (a.orders >= _segmentConfig.regularMinOrders && a.yRev >= _segmentConfig.regularMinYearRevenue) {
        seg = 'Stammkunde';
      } else if (dsl > _segmentConfig.inactiveDaysThreshold) {
        seg = 'Inaktiv';
      } else if (a.orders == 1) {
        seg = 'Neukunde';
      } else {
        seg = 'Gelegentlich';
      }

      return _CRow(id: a.id, name: a.name, rev: a.rev, revG: a.revG,
          yRev: a.yRev, pRev: a.pRev, orders: a.orders, yOrd: a.yOrd,
          qty: a.qty, avg: avg, first: a.first, last: a.last,
          dsl: dsl, yc: yc, seg: seg);
    }).toList();
  }

  // ── KPI ROW ────────────────────────────────────────────────
  Widget _buildKpiRow(BuildContext context, List<_CRow> cs) {
    final totRev = cs.fold<double>(0, (s, c) => s + c.rev);
    final totOrd = cs.fold<int>(0, (s, c) => s + c.orders);
    final avgCv = cs.isNotEmpty ? totRev / cs.length : 0.0;
    final top = cs.first; // already sorted desc

    return LayoutBuilder(builder: (ctx, box) {
      final wide = box.maxWidth > 800;
      final cards = [
        _kpi(context, 'Aktive Kunden', cs.length.toString(), Icons.people, 'people', Colors.blue, sub: '$totOrd Bestellungen'),
        _kpi(context, 'Top Kunde', top.name, Icons.star, 'star', Colors.amber.shade700, sub: _cf.format(top.rev)),
      ];
      if (wide) {
        return IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
        ));
      }
      return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList());
    });
  }

  Widget _kpi(BuildContext ctx, String title, String value, IconData icon, String iconName, Color color, {String? sub}) {
    final th = Theme.of(ctx);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: th.colorScheme.outlineVariant)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 13, color: th.colorScheme.onSurfaceVariant))),
          ]),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (sub != null) ...[const SizedBox(height: 4), Text(sub, style: TextStyle(fontSize: 11, color: th.colorScheme.onSurfaceVariant))],
        ],
      )),
    );
  }

  // ── TOP 10 ─────────────────────────────────────────────────
  Widget _buildTop10(BuildContext context, List<_CRow> cs) {
    final th = Theme.of(context);
    final top = cs.take(10).toList();
    if (top.isEmpty) return const SizedBox();
    final maxR = top.first.rev;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: th.colorScheme.outlineVariant)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: getAdaptiveIcon(iconName: 'leaderboard', defaultIcon: Icons.leaderboard, color: Colors.blue, size: 20)),
            const SizedBox(width: 12),
            const Text('Top 10 Kunden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          ...top.asMap().entries.map((e) {
            final i = e.key; final c = e.value;
            final bw = maxR > 0 ? c.rev / maxR : 0.0;
            return InkWell(
              onTap: () => _showDetail(context, c),
              borderRadius: BorderRadius.circular(8),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                SizedBox(width: 24, child: Text('${i + 1}.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: i < 3 ? Colors.amber.shade700 : th.colorScheme.onSurfaceVariant))),
                Expanded(flex: 2, child: Text(c.name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: Stack(children: [
                  Container(height: 20, decoration: BoxDecoration(color: th.colorScheme.surfaceContainerHighest.withOpacity(0.5), borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(widthFactor: bw, child: Container(height: 20, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.7), borderRadius: BorderRadius.circular(4)))),
                ])),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: Text(_cf.format(c.rev), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ])),
            );
          }),
        ],
      )),
    );
  }

  // ── SEGMENTS ───────────────────────────────────────────────
  Widget _buildSegments(BuildContext context, List<_CRow> cs) {
    final th = Theme.of(context);
    final Map<String, int> counts = {};
    for (final c in cs) counts[c.seg] = (counts[c.seg] ?? 0) + 1;
    final sc = _segColors;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: th.colorScheme.outlineVariant)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: getAdaptiveIcon(iconName: 'donut_large', defaultIcon: Icons.donut_large, color: Colors.purple, size: 20)),
            const SizedBox(width: 12),
            const Text('Kundensegmente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          SizedBox(height: 180, child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40,
            sections: counts.entries.map((e) {
              final pct = cs.isNotEmpty ? e.value / cs.length * 100 : 0.0;
              return PieChartSectionData(value: e.value.toDouble(), title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                  radius: 50, color: sc[e.key] ?? Colors.grey, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white));
            }).toList(),
          ))),
          const SizedBox(height: 12),
          ...counts.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: sc[e.key] ?? Colors.grey, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
            Text('${e.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: th.colorScheme.onSurfaceVariant)),
          ]))),
        ],
      )),
    );
  }

  // ── INSIGHTS ───────────────────────────────────────────────
  Widget _buildInsights(BuildContext context, List<_CRow> cs) {
    final chips = <Widget>[];
    final inact = cs.where((c) => (c.seg == 'VIP' || c.seg == 'Stammkunde') && c.dsl > 90).length;
    if (inact > 0) chips.add(_chip(context, Icons.warning_amber, 'warning', Colors.orange, '$inact wichtige Kunden seit 90+ Tagen inaktiv'));
    final newY = cs.where((c) => c.first != null && c.first!.year == DateTime.now().year).length;
    if (newY > 0) chips.add(_chip(context, Icons.person_add, 'person_add', Colors.green, '$newY Neukunden in ${DateTime.now().year}'));
    final grow = cs.where((c) => c.yc > 20).length;
    if (grow > 0) chips.add(_chip(context, Icons.trending_up, 'trending_up', Colors.blue, '$grow Kunden mit >20% Wachstum'));
    if (chips.isEmpty) return const SizedBox();
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: chips));
  }

  Widget _chip(BuildContext ctx, IconData icon, String iconName, Color color, String text) {
    return Padding(padding: const EdgeInsets.only(right: 8), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    ));
  }

  // ── DETAIL BOTTOM SHEET ────────────────────────────────────
  void _showDetail(BuildContext context, _CRow c) {
    final th = Theme.of(context);
    final segCol = _segColors[c.seg] ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: th.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: th.colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: th.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: getAdaptiveIcon(iconName: 'person', defaultIcon: Icons.person, color: th.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _badge(c.seg, segCol),
                        if (c.first != null)
                          Text('Kunde seit ${_df.format(c.first!)}',
                              style: TextStyle(fontSize: 12, color: th.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                )),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ]),
            ),

            const Divider(),

            // Scrollable Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  // KPIs
                  Row(children: [
                    _dkpi('Umsatz netto', _cf.format(c.rev), Colors.green),
                    const SizedBox(width: 8),
                    _dkpi('Bestellungen', c.orders.toString(), Colors.blue),
                    const SizedBox(width: 8),
                    _dkpi('Ø Bestellwert', _cf.format(c.avg), Colors.purple),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _dkpi('Umsatz ${DateTime.now().year}', _cf.format(c.yRev), Colors.teal, trend: c.yc),
                    const SizedBox(width: 8),
                    _dkpi('Vorjahr', _cf.format(c.pRev), Colors.blueGrey),
                    const SizedBox(width: 8),
                    _dkpi('Menge', '${c.qty} Stk', Colors.orange),
                  ]),

                  const SizedBox(height: 20),

                  // Details aus Subcollection
                  FutureBuilder<CustomerSalesStats>(
                    future: CustomerStatsService.getStats(c.id),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                      }
                      final st = snap.data;
                      if (st == null || st.totalOrders == 0) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: th.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline, size: 20, color: th.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(child: Text(
                              'Führe die Migration aus für Top-Produkte, Holzarten und monatlichen Umsatzverlauf.',
                              style: TextStyle(fontSize: 12, color: th.colorScheme.onSurfaceVariant),
                            )),
                          ]),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (st.monthlyRevenue.isNotEmpty) ...[
                            const Text('Monatlicher Umsatz', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SizedBox(height: 150, child: _miniBar(st.monthlyRevenue, Colors.blue)),
                            const SizedBox(height: 20),
                          ],
                          if (st.topProducts.isNotEmpty) ...[
                            const Text('Top Produkte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...st.topProducts.take(5).map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(children: [
                                Expanded(child: Text(p.productName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Text('${p.quantity} Stk', style: TextStyle(fontSize: 12, color: th.colorScheme.onSurfaceVariant)),
                                const SizedBox(width: 12),
                                Text(_cf.format(p.revenue), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                            )),
                            const SizedBox(height: 20),
                          ],
                          if (st.woodTypeRevenue.isNotEmpty || st.instrumentRevenue.isNotEmpty)
                            LayoutBuilder(builder: (ctx, box) {
                              if (box.maxWidth > 400) {
                                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (st.woodTypeRevenue.isNotEmpty) Expanded(child: _distList('Holzarten', st.woodTypeRevenue, Colors.brown)),
                                  if (st.woodTypeRevenue.isNotEmpty && st.instrumentRevenue.isNotEmpty) const SizedBox(width: 16),
                                  if (st.instrumentRevenue.isNotEmpty) Expanded(child: _distList('Instrumente', st.instrumentRevenue, Colors.indigo)),
                                ]);
                              }
                              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (st.woodTypeRevenue.isNotEmpty) _distList('Holzarten', st.woodTypeRevenue, Colors.brown),
                                if (st.woodTypeRevenue.isNotEmpty && st.instrumentRevenue.isNotEmpty) const SizedBox(height: 16),
                                if (st.instrumentRevenue.isNotEmpty) _distList('Instrumente', st.instrumentRevenue, Colors.indigo),
                              ]);
                            }),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────

  static final _segColors = {
    'VIP': Colors.amber.shade700, 'Stammkunde': Colors.green,
    'Gelegentlich': Colors.blue, 'Neukunde': Colors.purple, 'Inaktiv': Colors.grey,
  };

  Widget _badge(String seg, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: col.withOpacity(0.4))),
      child: Text(seg, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: col)),
    );
  }

  Widget _dkpi(String label, String value, Color color, {double? trend}) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))),
        if (trend != null && trend != 0)
          Text('${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 10, color: trend >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
      ]),
    ));
  }

  Widget _distList(String title, Map<String, double> data, Color color) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = data.values.fold<double>(0, (s, v) => s + v);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 8),
      ...sorted.take(5).map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('${(total > 0 ? e.value / total * 100 : 0).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]))),
    ]);
  }

  Widget _miniBar(Map<String, double> data, Color color) {
    final keys = data.keys.toList()..sort();
    final l12 = keys.length > 12 ? keys.sublist(keys.length - 12) : keys;
    if (l12.isEmpty) return const SizedBox();
    final mx = l12.map((k) => data[k] ?? 0).reduce((a, b) => a > b ? a : b);
    if (mx == 0) return const SizedBox();

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround, maxY: mx * 1.15,
      barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => Colors.grey[800]!,
        getTooltipItem: (g, gi, r, ri) {
          final k = l12[g.x.toInt()];
          return BarTooltipItem('${_fm(k)}\n${_cf.format(data[k] ?? 0)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11));
        },
      )),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
          if (v < 0 || v >= l12.length) return const SizedBox();
          return Text(_fm(l12[v.toInt()]), style: TextStyle(fontSize: 8, color: Colors.grey[600]));
        })),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(l12.length, (i) => BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: data[l12[i]] ?? 0, color: color.withOpacity(0.7), width: l12.length > 6 ? 10 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
      ])),
    ));
  }

  String _fm(String k) {
    final p = k.split('-');
    if (p.length != 2) return k;
    const m = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    final mi = int.tryParse(p[1]);
    if (mi == null || mi < 1 || mi > 12) return k;
    return '${m[mi - 1]} ${p[0].substring(2)}';
  }
}

// ── DATA ─────────────────────────────────────────────────────
class _Agg {
  final String id, name;
  double rev = 0, revG = 0, yRev = 0, pRev = 0;
  int orders = 0, yOrd = 0, qty = 0;
  DateTime? first, last;
  _Agg({required this.id, required this.name});
}

class _CRow {
  final String id, name, seg;
  final double rev, revG, yRev, pRev, avg, yc;
  final int orders, yOrd, qty, dsl;
  final DateTime? first, last;
  _CRow({required this.id, required this.name, required this.rev,
    required this.revG, required this.yRev, required this.pRev, required this.orders,
    required this.yOrd, required this.qty, required this.avg, this.first, this.last,
    required this.dsl, required this.yc, required this.seg});
}