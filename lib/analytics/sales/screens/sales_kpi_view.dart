// lib/analytics/sales/screens/sales_kpi_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/icon_helper.dart';
import '../models/sales_filter.dart';
import '../models/sales_analytics_models.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/order_summary_sheet.dart';

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

              // Aufschlüsselung: Dienstleistungen, Fracht, Rabatte, Abschläge/Zuschläge
              _buildBreakdownRow(context, analytics, currencyFormat),
              const SizedBox(height: 16),

              // NEU: Rechnungsbetrag netto
              _buildNetRevenueRow(context, analytics, currencyFormat),
              const SizedBox(height: 16),

              // Gesamtbeträge (Brutto)
              _buildGrossRevenueRow(context, analytics, currencyFormat),
              const SizedBox(height: 16),

              // Thermo-Anteil
              _buildThermoCard(context, analytics),
              const SizedBox(height: 16),

              // Detailtabelle
              _buildOrdersTable(context, analytics, currencyFormat),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // HELPER
  // ============================================================

  String? _discountSubtitle(double discount, NumberFormat format) {
    if (discount <= 0) return null;
    return '${format.format(discount)} Rabatt gewährt';
  }

  String _getCurrentMonthName() {
    final months = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];
    return months[DateTime.now().month - 1];
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

  // ============================================================
  // KPI ROWS
  // ============================================================

  Widget _buildMainKpiRow(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final List<_KpiCardData> cards = [];

        if (_isFilteredByDate) {
          cards.add(_KpiCardData(
            title: 'Warenwert Zeitraum (nach Rabatt)',
            value: format.format(analytics.revenue.yearRevenue),
            icon: Icons.date_range,
            iconName: 'date_range',
            color: Colors.blue,
            subtitle: _discountSubtitle(analytics.revenue.yearDiscount, format),
            onTap: () => _showRevenueDetailDialog(context, analytics, format),
          ));
        } else {
          cards.add(_KpiCardData(
            title: 'Warenwert ${DateTime.now().year}',
            value: format.format(analytics.revenue.yearRevenue),
            icon: Icons.calendar_today,
            iconName: 'calendar_today',
            color: Colors.blue,
            trend: analytics.revenue.yearChangePercent,
            trendLabel: 'vs. Vorjahr',
            subtitle: _discountSubtitle(analytics.revenue.yearDiscount, format),
            onTap: () => _showRevenueDetailDialog(context, analytics, format),
          ));
          cards.add(_KpiCardData(
            title: 'Warenwert ${_getCurrentMonthName()}',
            value: format.format(analytics.revenue.monthRevenue),
            icon: Icons.today,
            iconName: 'today',
            color: Colors.green,
            trend: analytics.revenue.monthChangePercent,
            trendLabel: 'vs. Vormonat',
            subtitle: _discountSubtitle(analytics.revenue.monthDiscount, format),
            onTap: () => _showMonthlyRevenueDialog(context, analytics.revenue.monthlyRevenue, 'Monatliche Warenwerte', Colors.green),
          ));
        }

        cards.add(_KpiCardData(
          title: 'Anzahl Verkäufe',
          value: analytics.orderCount.toString(),
          icon: Icons.shopping_cart,
          iconName: 'shopping_cart',
          color: Colors.orange,
          subtitle: _isFilteredByDate
              ? null
              : '${analytics.revenue.monthOrderCount} im ${_getCurrentMonthName()}',
          onTap: () => _showOrderCountDetailDialog(context, analytics, format),
        ));
        cards.add(_KpiCardData(
          title: 'Ø Warenwert / Verkauf',
          value: format.format(analytics.averageOrderValue),
          icon: Icons.analytics,
          iconName: 'analytics',
          color: Colors.purple,
          onTap: () => _showAverageOrderDetailDialog(context, analytics, format),
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
            title: 'Gesamt Brutto Zeitraum',
            value: format.format(analytics.revenue.yearRevenueGross),
            icon: Icons.account_balance,
            iconName: 'account_balance',
            color: Colors.teal,
            onTap: () => _showGrossRevenueDetailDialog(context, analytics, format),
          ));
        } else {
          cards.add(_KpiCardData(
            title: 'Gesamt Brutto ${DateTime.now().year}',
            value: format.format(analytics.revenue.yearRevenueGross),
            icon: Icons.account_balance,
            iconName: 'account_balance',
            color: Colors.teal,
            trend: analytics.revenue.yearChangePercentGross,
            trendLabel: 'vs. Vorjahr',
            onTap: () => _showGrossRevenueDetailDialog(context, analytics, format),
          ));
          cards.add(_KpiCardData(
            title: 'Gesamt Brutto ${_getCurrentMonthName()}',
            value: format.format(analytics.revenue.monthRevenueGross),
            icon: Icons.receipt_long,
            iconName: 'receipt_long',
            color: Colors.indigo,
            trend: analytics.revenue.monthChangePercentGross,
            trendLabel: 'vs. Vormonat',
            onTap: () => _showMonthlyRevenueDialog(context, analytics.revenue.monthlyRevenueGross, 'Monatliche Gesamtbeträge', Colors.teal),
          ));
        }

        cards.add(_KpiCardData(
          title: 'Ø Gesamt Brutto / Verkauf',
          value: format.format(analytics.averageOrderValueGross),
          icon: Icons.receipt,
          iconName: 'receipt',
          color: Colors.blueGrey,
          onTap: () => _showAverageGrossDetailDialog(context, analytics, format),
        ));

        return _renderCardLayout(context, cards, isWide, constraints.maxWidth);
      },
    );
  }

  // ============================================================
  // AUFSCHLÜSSELUNG: Dienstleistungen, Fracht, Rabatte
  // ============================================================

  Widget _buildBreakdownRow(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final rev = analytics.revenue;

    final hasService    = rev.totalServiceRevenue > 0 || rev.yearServiceRevenue > 0;
    final hasFreight    = rev.totalFreight > 0 || rev.yearFreight > 0;
    final hasPhyto      = rev.totalPhytosanitary > 0 || rev.yearPhytosanitary > 0;
    final hasDiscount   = rev.totalDiscount > 0 || rev.yearDiscount > 0
        || rev.totalGratisValue > 0 || rev.yearGratisValue > 0;
    final hasDeductions = rev.totalDeductions > 0 || rev.yearDeductions > 0;
    final hasSurcharges = rev.totalSurcharges > 0 || rev.yearSurcharges > 0;

    if (!hasService && !hasFreight && !hasPhyto && !hasDiscount
        && !hasDeductions && !hasSurcharges) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final List<_KpiCardData> cards = [];

        if (hasService) {
          cards.add(_KpiCardData(
            title: _isFilteredByDate
                ? 'Dienstleistungen'
                : 'Dienstleistungen ${DateTime.now().year}',
            value: format.format(
                _isFilteredByDate ? rev.totalServiceRevenue : rev.yearServiceRevenue),
            icon: Icons.build,
            iconName: 'build',
            color: Colors.blueAccent,
            subtitle: _isFilteredByDate
                ? null
                : '${_getCurrentMonthName()}: ${format.format(rev.monthServiceRevenue)}',
            onTap: () => _showBreakdownOrderList(
              context, analytics, format,
              title: 'Aufträge mit Dienstleistungen',
              icon: Icons.build, iconName: 'build', color: Colors.blueAccent,
              filterFn: (o) => o.serviceRevenue > 0,
              valueFn: (o) => o.serviceRevenue,
              valueLabel: 'DL',
            ),
          ));
        }

        if (hasFreight) {
          cards.add(_KpiCardData(
            title: _isFilteredByDate ? 'Fracht' : 'Fracht ${DateTime.now().year}',
            value: format.format(
                _isFilteredByDate ? rev.totalFreight : rev.yearFreight),
            icon: Icons.local_shipping,
            iconName: 'local_shipping',
            color: Colors.brown,
            subtitle: _isFilteredByDate
                ? null
                : '${_getCurrentMonthName()}: ${format.format(rev.monthFreight)}',
            onTap: () => _showBreakdownOrderList(
              context, analytics, format,
              title: 'Aufträge mit Fracht',
              icon: Icons.local_shipping, iconName: 'local_shipping', color: Colors.brown,
              filterFn: (o) => o.freight > 0,
              valueFn: (o) => o.freight,
              valueLabel: 'Fracht',
            ),
          ));
        }

        if (hasPhyto) {
          cards.add(_KpiCardData(
            title: _isFilteredByDate ? 'Phytosanitary' : 'Phytosanitary ${DateTime.now().year}',
            value: format.format(
                _isFilteredByDate ? rev.totalPhytosanitary : rev.yearPhytosanitary),
            icon: Icons.eco,
            iconName: 'eco',
            color: Colors.green,
            subtitle: _isFilteredByDate
                ? null
                : '${_getCurrentMonthName()}: ${format.format(rev.monthPhytosanitary)}',
            onTap: () => _showBreakdownOrderList(
              context, analytics, format,
              title: 'Aufträge mit Phytosanitary',
              icon: Icons.eco, iconName: 'eco', color: Colors.green,
              filterFn: (o) => o.phytosanitary > 0,
              valueFn: (o) => o.phytosanitary,
              valueLabel: 'Phyto',
            ),
          ));
        }

        if (hasDiscount) {
          final discountVal = _isFilteredByDate ? rev.totalDiscount    : rev.yearDiscount;
          final gratisVal   = _isFilteredByDate ? rev.totalGratisValue : rev.yearGratisValue;
          final totalVal    = discountVal + gratisVal;

          cards.add(_KpiCardData(
            title: _isFilteredByDate ? 'Rabatte gewährt' : 'Rabatte ${DateTime.now().year}',
            value: format.format(totalVal),
            icon: Icons.discount,
            iconName: 'discount',
            color: Colors.orange,
            subtitle: gratisVal > 0
                ? '(davon ${format.format(gratisVal)} Gratisartikel)'
                : null,
            onTap: () => _showBreakdownOrderList(
              context, analytics, format,
              title: 'Aufträge mit Rabatten',
              icon: Icons.discount, iconName: 'discount', color: Colors.orange,
              filterFn: (o) => o.discount > 0,
              valueFn: (o) => o.discount,
              valueLabel: 'Rabatt',
            ),
          ));
        }

        if (hasDeductions || hasSurcharges) {
          final deductVal   = _isFilteredByDate ? rev.totalDeductions : rev.yearDeductions;
          final surchargeVal = _isFilteredByDate ? rev.totalSurcharges : rev.yearSurcharges;
          final netVal      = surchargeVal - deductVal;
          final isPositive  = netVal >= 0;

          cards.add(_KpiCardData(
            title: _isFilteredByDate
                ? 'Abschläge / Zuschläge'
                : 'Abschläge / Zuschläge ${DateTime.now().year}',
            value: '${isPositive ? "+" : ""}${format.format(netVal)}',
            icon: Icons.tune,
            iconName: 'tune',
            color: isPositive ? Colors.teal : Colors.deepOrange,
            subtitle: 'Abschläge: -${format.format(deductVal)} / Zuschläge: +${format.format(surchargeVal)}',
            onTap: () => _showBreakdownOrderList(
              context, analytics, format,
              title: 'Aufträge mit Abschlägen / Zuschlägen',
              icon: Icons.tune, iconName: 'tune', color: Colors.teal,
              filterFn: (o) => o.deductions > 0 || o.surcharges > 0,
              valueFn: (o) => o.surcharges - o.deductions,
              valueLabel: '+/-',
            ),
          ));
        }

        return _renderCardLayout(context, cards, isWide, constraints.maxWidth);
      },
    );
  }
  // ============================================================
// NEU: RECHNUNGSBETRAG NETTO — Zusammenfassung aller Positionen
// ============================================================

  // ============================================================
// RECHNUNGSBETRAG NETTO
// ============================================================

  Widget _buildNetRevenueRow(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final rev = analytics.revenue;

    final warenwert  = _isFilteredByDate ? rev.totalRevenue        : rev.yearRevenue;
    final service    = _isFilteredByDate ? rev.totalServiceRevenue : rev.yearServiceRevenue;
    final fracht     = _isFilteredByDate ? rev.totalFreight        : rev.yearFreight;
    final phyto      = _isFilteredByDate ? rev.totalPhytosanitary  : rev.yearPhytosanitary;
    final deductions = _isFilteredByDate ? rev.totalDeductions     : rev.yearDeductions;
    final surcharges = _isFilteredByDate ? rev.totalSurcharges     : rev.yearSurcharges;
    final netRevenue = warenwert + service + fracht + phyto - deductions + surcharges;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return _renderCardLayout(context, [
          _KpiCardData(
            title: _isFilteredByDate
                ? 'Rechnungsbetrag netto'
                : 'Rechnungsbetrag netto ${DateTime.now().year}',
            value: format.format(netRevenue),
            icon: Icons.receipt_long,
            iconName: 'receipt_long',
            color: Colors.indigo,
            subtitle: 'Warenwert + DL + Fracht + Phyto - Abschläge + Zuschläge',
            onTap: () => _showNetRevenueBreakdownDialog(context, analytics, format),
          ),
        ], isWide, constraints.maxWidth);
      },
    );
  }

  void _showNetRevenueBreakdownDialog(
      BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final rev        = analytics.revenue;
    final isFiltered = _isFilteredByDate;

    final warenwert  = isFiltered ? rev.totalRevenue        : rev.yearRevenue;
    final service    = isFiltered ? rev.totalServiceRevenue : rev.yearServiceRevenue;
    final fracht     = isFiltered ? rev.totalFreight        : rev.yearFreight;
    final phyto      = isFiltered ? rev.totalPhytosanitary  : rev.yearPhytosanitary;
    final deductions = isFiltered ? rev.totalDeductions     : rev.yearDeductions;
    final surcharges = isFiltered ? rev.totalSurcharges     : rev.yearSurcharges;
    final netto      = warenwert + service + fracht + phyto - deductions + surcharges;
    final theme      = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechnungsbetrag netto — Aufschlüsselung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNetRow(theme, 'Warenwert (netto Ware)', format.format(warenwert), Colors.blue),
            if (service > 0)
              _buildNetRow(theme, '+ Dienstleistungen',   format.format(service),    Colors.blueAccent),
            if (fracht > 0)
              _buildNetRow(theme, '+ Fracht',             format.format(fracht),     Colors.brown),
            if (phyto > 0)
              _buildNetRow(theme, '+ Phytosanitary',      format.format(phyto),      Colors.green),
            if (deductions > 0)
              _buildNetRow(theme, '- Abschläge',          format.format(deductions), Colors.deepOrange),
            if (surcharges > 0)
              _buildNetRow(theme, '+ Zuschläge',          format.format(surcharges), Colors.teal),
            const Divider(),
            _buildNetRow(theme, '= Rechnungsbetrag netto', format.format(netto),     Colors.indigo, bold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Widget _buildNetRow(ThemeData theme, String label, String value, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: bold ? theme.colorScheme.onSurface : color,
          )),
          Text(value, style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: bold ? theme.colorScheme.onSurface : color,
          )),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow2(ThemeData theme, String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: bold ? theme.colorScheme.onSurface : color,
          )),
          Text(value, style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: bold ? theme.colorScheme.onSurface : color,
          )),
        ],
      ),
    );
  }
  // ============================================================
  // BREAKDOWN ORDER LIST DIALOG
  // ============================================================

  void _showBreakdownOrderList(
      BuildContext context,
      SalesAnalytics analytics,
      NumberFormat format, {
        required String title,
        required IconData icon,
        required String iconName,
        required Color color,
        required bool Function(OrderSummary) filterFn,
        required double Function(OrderSummary) valueFn,
        required String valueLabel,
      }) {
    final filtered = analytics.orders.where(filterFn).toList()
      ..sort((a, b) => b.relevantDate.compareTo(a.relevantDate));
    final totalValue = filtered.fold<double>(0, (s, o) => s + valueFn(o));
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yy');

    // Web/Desktop: Dialog, Mobile: BottomSheet
    final isWide = MediaQuery.of(context).size.width > 600;

    Widget buildContent({bool isSheet = false}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle (nur Mobile Sheet)
          if (isSheet)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        '${filtered.length} Aufträge · Total: ${format.format(totalValue)}',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(height: 1),

          // Spalten-Header
          Container(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Auftrag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant))),
                Expanded(flex: 3, child: Text('Kunde', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant))),
                SizedBox(width: 56, child: Text('Datum', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant))),
                SizedBox(width: 80, child: Text(valueLabel, textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
              ],
            ),
          ),
          const Divider(height: 1),

          // Liste
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
              itemBuilder: (context, index) {
                final order = filtered[index];
                final isEven = index % 2 == 0;
                return InkWell(
                  onTap: () => OrderSummarySheet.show(context, order),
                  child: Container(
                    color: isEven ? Colors.transparent : theme.colorScheme.surfaceVariant.withOpacity(0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(order.orderNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(order.customerName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(dateFormat.format(order.relevantDate), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            format.format(valueFn(order)),
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Summenzeile
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              border: Border(top: BorderSide(color: color.withOpacity(0.2), width: 1.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('Total (${filtered.length} Aufträge)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 56),
                SizedBox(
                  width: 80,
                  child: Text(
                    format.format(totalValue),
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          ),

          // Safe area padding für Mobile
          if (isSheet) SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      );
    }

    if (isWide) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 600),
            child: buildContent(),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: buildContent(isSheet: true),
        ),
      );
    }
  }

  // ============================================================
  // CARD LAYOUT — einheitliche Höhe via IntrinsicHeight
  // ============================================================

  Widget _renderCardLayout(BuildContext context, List<_KpiCardData> cards, bool isWide, double maxWidth) {
    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards
              .map((card) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildKpiCard(context, card),
            ),
          ))
              .toList(),
        ),
      );
    } else {
      // Auf kleinen Screens: 2er-Grid mit gleicher Höhe pro Zeile
      final List<Widget> rows = [];
      for (int i = 0; i < cards.length; i += 2) {
        final rowCards = cards.skip(i).take(2).toList();
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowCards.map((card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildKpiCard(context, card),
                ),
              )).toList(),
            ),
          ),
        );
        if (i + 2 < cards.length) rows.add(const SizedBox(height: 12));
      }
      return Column(children: rows);
    }
  }

  // ============================================================
  // KPI CARD — alle klickbar
  // ============================================================

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
                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
              ],
            ),
            const SizedBox(height: 12),
            Text(data.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            // Spacer drückt optionale Elemente nach unten → einheitliche Höhe
            const Spacer(),
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
            if (data.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                data.subtitle!,
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
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

  // ============================================================
  // DETAIL DIALOGS
  // ============================================================

  void _showDetailDialog(BuildContext context, {
    required String title,
    required IconData icon,
    required String iconName,
    required Color color,
    required List<_DetailRow> rows,
    Widget? chart,
  }) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
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
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Detail rows
                ...rows.map((row) {
                  // Leerzeile als Spacer
                  if (row.label.isEmpty && row.value.isEmpty) {
                    return const SizedBox(height: 8);
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        if (row.icon != null) ...[
                          Icon(row.icon, size: 16, color: row.color ?? theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            row.label,
                            style: TextStyle(
                              fontSize: row.isHeader ? 14 : 13,
                              fontWeight: row.isHeader ? FontWeight.w600 : FontWeight.normal,
                              color: row.isHeader ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          row.value,
                          style: TextStyle(
                            fontSize: row.isHeader ? 14 : 13,
                            fontWeight: row.isHeader ? FontWeight.bold : FontWeight.w500,
                            color: row.color ?? (row.isHeader ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Optional chart
                if (chart != null) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  SizedBox(height: 200, child: chart),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Warenwert Detail ---
  void _showRevenueDetailDialog(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final rev = analytics.revenue;
    _showDetailDialog(
      context,
      title: 'Warenwert Details',
      icon: Icons.calendar_today,
      iconName: 'calendar_today',
      color: Colors.blue,
      rows: [
        _DetailRow('Gesamt (alle Jahre)', format.format(rev.totalRevenue), isHeader: true),
        _DetailRow('davon Rabatt gewährt', format.format(rev.totalDiscount), color: Colors.orange, icon: Icons.discount),
        const _DetailRow('', ''),
        _DetailRow('${DateTime.now().year}', format.format(rev.yearRevenue), isHeader: true),
        _DetailRow('Vorjahr', format.format(rev.previousYearRevenue)),
        _trendRow('Veränderung', rev.yearChangePercent),
        _DetailRow('Rabatt ${DateTime.now().year}', format.format(rev.yearDiscount), color: Colors.orange, icon: Icons.discount),
        const _DetailRow('', ''),
        _DetailRow(_getCurrentMonthName(), format.format(rev.monthRevenue), isHeader: true),
        _DetailRow('Vormonat', format.format(rev.previousMonthRevenue)),
        _trendRow('Veränderung', rev.monthChangePercent),
        _DetailRow('Rabatt ${_getCurrentMonthName()}', format.format(rev.monthDiscount), color: Colors.orange, icon: Icons.discount),
      ],
      chart: _buildMonthlyBarChart(rev.monthlyRevenue, Colors.blue),
    );
  }

  // --- Gesamt Detail ---
  void _showGrossRevenueDetailDialog(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final rev = analytics.revenue;

    // Warenwert VOR Rabatt = Warenwert nach Rabatt + Rabatt
    final yearWarenwertBrutto = rev.yearRevenue + rev.yearDiscount;
    final monthWarenwertBrutto = rev.monthRevenue + rev.monthDiscount;
    final totalWarenwertBrutto = rev.totalRevenue + rev.totalDiscount;

    _showDetailDialog(
      context,
      title: 'Gesamt Brutto Details',
      icon: Icons.account_balance,
      iconName: 'account_balance',
      color: Colors.teal,
      rows: [
        _DetailRow('Gesamt Brutto (alle Jahre)', format.format(rev.totalRevenueGross), isHeader: true),
        const _DetailRow('', ''),
        _DetailRow('${DateTime.now().year}', format.format(rev.yearRevenueGross), isHeader: true),
        _DetailRow('Warenwert (vor Rabatt)', format.format(yearWarenwertBrutto)),
        if (rev.yearDiscount > 0)
          _DetailRow('Rabatte', '- ${format.format(rev.yearDiscount)}', color: Colors.orange, icon: Icons.discount),
        if (rev.yearServiceRevenue > 0)
          _DetailRow('Dienstleistungen', format.format(rev.yearServiceRevenue)),
        if (rev.yearFreight > 0)
          _DetailRow('Fracht', format.format(rev.yearFreight)),
        if (rev.yearPhytosanitary > 0)
          _DetailRow('Phytosanitary', format.format(rev.yearPhytosanitary)),
        if (rev.yearSurcharges > 0)
          _DetailRow('Zuschläge', format.format(rev.yearSurcharges)),
        if (rev.yearDeductions > 0)
          _DetailRow('Abschläge', '- ${format.format(rev.yearDeductions)}', color: Colors.orange),
        if (rev.yearVat > 0)
          _DetailRow('MwSt', format.format(rev.yearVat)),
        _DetailRow('Vorjahr', format.format(rev.previousYearRevenueGross)),
        _trendRow('Veränderung', rev.yearChangePercentGross),
        const _DetailRow('', ''),
        _DetailRow(_getCurrentMonthName(), format.format(rev.monthRevenueGross), isHeader: true),
        _DetailRow('Warenwert (vor Rabatt)', format.format(monthWarenwertBrutto)),
        if (rev.monthDiscount > 0)
          _DetailRow('Rabatte', '- ${format.format(rev.monthDiscount)}', color: Colors.orange, icon: Icons.discount),
        if (rev.monthServiceRevenue > 0)
          _DetailRow('Dienstleistungen', format.format(rev.monthServiceRevenue)),
        if (rev.monthFreight > 0)
          _DetailRow('Fracht', format.format(rev.monthFreight)),
        if (rev.monthPhytosanitary > 0)
          _DetailRow('Phytosanitary', format.format(rev.monthPhytosanitary)),
        if (rev.monthSurcharges > 0)
          _DetailRow('Zuschläge', format.format(rev.monthSurcharges)),
        if (rev.monthDeductions > 0)
          _DetailRow('Abschläge', '- ${format.format(rev.monthDeductions)}', color: Colors.orange),
        if (rev.monthVat > 0)
          _DetailRow('MwSt', format.format(rev.monthVat)),
        _DetailRow('Vormonat', format.format(rev.previousMonthRevenueGross)),
        _trendRow('Veränderung', rev.monthChangePercentGross),
      ],
      chart: _buildMonthlyBarChart(rev.monthlyRevenueGross, Colors.teal),
    );
  }

  // --- Anzahl Verkäufe Detail ---
  void _showOrderCountDetailDialog(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final rev = analytics.revenue;
    final avgPerMonth = rev.yearOrderCount > 0 && DateTime.now().month > 0
        ? (rev.yearOrderCount / DateTime.now().month).toStringAsFixed(1)
        : '0';

    _showDetailDialog(
      context,
      title: 'Verkäufe Details',
      icon: Icons.shopping_cart,
      iconName: 'shopping_cart',
      color: Colors.orange,
      rows: [
        _DetailRow('Gesamt (alle Jahre)', analytics.orderCount.toString(), isHeader: true),
        const _DetailRow('', ''),
        _DetailRow('${DateTime.now().year}', rev.yearOrderCount.toString(), isHeader: true),
        _DetailRow('Vorjahr', rev.previousYearOrderCount.toString()),
        _trendRow('Veränderung', rev.yearOrderChangePercent),
        _DetailRow('Ø pro Monat (${DateTime.now().year})', avgPerMonth),
        const _DetailRow('', ''),
        _DetailRow(_getCurrentMonthName(), rev.monthOrderCount.toString(), isHeader: true),
        _DetailRow('Vormonat', rev.previousMonthOrderCount.toString()),
        _trendRow('Veränderung', rev.monthOrderChangePercent),
      ],
      chart: _buildMonthlyBarChart(
        rev.monthlyOrderCount.map((k, v) => MapEntry(k, v.toDouble())),
        Colors.orange,
      ),
    );
  }

  // --- Ø Warenwert Detail ---
  void _showAverageOrderDetailDialog(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final rev = analytics.revenue;
    final yearAvg = rev.yearOrderCount > 0 ? rev.yearRevenue / rev.yearOrderCount : 0.0;
    final monthAvg = rev.monthOrderCount > 0 ? rev.monthRevenue / rev.monthOrderCount : 0.0;
    final prevYearAvg = rev.previousYearOrderCount > 0 ? rev.previousYearRevenue / rev.previousYearOrderCount : 0.0;
    final prevMonthAvg = rev.previousMonthOrderCount > 0 ? rev.previousMonthRevenue / rev.previousMonthOrderCount : 0.0;
    final yearAvgChange = prevYearAvg > 0 ? ((yearAvg - prevYearAvg) / prevYearAvg) * 100 : 0.0;
    final monthAvgChange = prevMonthAvg > 0 ? ((monthAvg - prevMonthAvg) / prevMonthAvg) * 100 : 0.0;

    // Monatliche Durchschnittswerte berechnen
    final monthlyAvg = <String, double>{};
    rev.monthlyRevenue.forEach((key, revenue) {
      final count = rev.monthlyOrderCount[key] ?? 0;
      monthlyAvg[key] = count > 0 ? revenue / count : 0;
    });

    _showDetailDialog(
      context,
      title: 'Ø Warenwert / Verkauf',
      icon: Icons.analytics,
      iconName: 'analytics',
      color: Colors.purple,
      rows: [
        _DetailRow('Gesamt', format.format(analytics.averageOrderValue), isHeader: true),
        const _DetailRow('', ''),
        _DetailRow('Ø ${DateTime.now().year}', format.format(yearAvg), isHeader: true),
        _DetailRow('Ø Vorjahr', format.format(prevYearAvg)),
        _trendRow('Veränderung', yearAvgChange),
        const _DetailRow('', ''),
        _DetailRow('Ø ${_getCurrentMonthName()}', format.format(monthAvg), isHeader: true),
        _DetailRow('Ø Vormonat', format.format(prevMonthAvg)),
        _trendRow('Veränderung', monthAvgChange),
      ],
      chart: _buildMonthlyBarChart(monthlyAvg, Colors.purple),
    );
  }

  // --- Ø Gesamt Detail ---
  void _showAverageGrossDetailDialog(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final rev = analytics.revenue;
    final yearAvg = rev.yearOrderCount > 0 ? rev.yearRevenueGross / rev.yearOrderCount : 0.0;
    final monthAvg = rev.monthOrderCount > 0 ? rev.monthRevenueGross / rev.monthOrderCount : 0.0;
    final prevYearAvg = rev.previousYearOrderCount > 0 ? rev.previousYearRevenueGross / rev.previousYearOrderCount : 0.0;
    final prevMonthAvg = rev.previousMonthOrderCount > 0 ? rev.previousMonthRevenueGross / rev.previousMonthOrderCount : 0.0;
    final yearAvgChange = prevYearAvg > 0 ? ((yearAvg - prevYearAvg) / prevYearAvg) * 100 : 0.0;
    final monthAvgChange = prevMonthAvg > 0 ? ((monthAvg - prevMonthAvg) / prevMonthAvg) * 100 : 0.0;

    _showDetailDialog(
      context,
      title: 'Ø Gesamt / Verkauf',
      icon: Icons.receipt,
      iconName: 'receipt',
      color: Colors.blueGrey,
      rows: [
        _DetailRow('Gesamt', format.format(analytics.averageOrderValueGross), isHeader: true),
        const _DetailRow('', ''),
        _DetailRow('Ø ${DateTime.now().year}', format.format(yearAvg), isHeader: true),
        _DetailRow('Ø Vorjahr', format.format(prevYearAvg)),
        _trendRow('Veränderung', yearAvgChange),
        const _DetailRow('', ''),
        _DetailRow('Ø ${_getCurrentMonthName()}', format.format(monthAvg), isHeader: true),
        _DetailRow('Ø Vormonat', format.format(prevMonthAvg)),
        _trendRow('Veränderung', monthAvgChange),
      ],
    );
  }

  // --- Monatliche Umsätze (Bar Chart Dialog) ---
  void _showMonthlyRevenueDialog(BuildContext context, Map<String, double> monthlyRevenue, String title, Color color) {
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
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: getAdaptiveIcon(
                      iconName: 'trending_up',
                      defaultIcon: Icons.trending_up,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
                            color: color,
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

  // ============================================================
  // THERMO / SERVICE DETAIL DIALOG
  // ============================================================

  void _showShareDetailDialog(
      BuildContext context,
      String title,
      IconData icon,
      String iconName,
      Color color,
      List<Map<String, dynamic>> details,
      ) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);
    final dateFormat = DateFormat('dd.MM.yyyy');

    // Nach Datum sortieren (neueste zuerst)
    final sorted = List<Map<String, dynamic>>.from(details)
      ..sort((a, b) {
        final dateA = a['orderDate'] as DateTime?;
        final dateB = b['orderDate'] as DateTime?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
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
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${sorted.length} Positionen', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Spalten-Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text('Auftrag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: Text('Produkt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('Mge', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text('Umsatz', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Liste
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  itemBuilder: (context, index) {
                    final item = sorted[index];
                    final orderDate = item['orderDate'] as DateTime?;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['orderNumber']?.toString() ?? '',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
                                ),
                                if (orderDate != null)
                                  Text(
                                    dateFormat.format(orderDate),
                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item['productName']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${item['quantity'] ?? 0}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              currencyFormat.format(item['revenue'] ?? 0),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CHART HELPERS
  // ============================================================

  Widget _buildMonthlyBarChart(Map<String, double> data, Color color) {
    final sortedMonths = data.keys.toList()..sort();
    final last12 = sortedMonths.length > 12
        ? sortedMonths.sublist(sortedMonths.length - 12)
        : sortedMonths;

    if (last12.isEmpty) return const Center(child: Text('Keine Daten'));

    final maxVal = last12.map((m) => data[m] ?? 0).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.grey[800]!,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final monthKey = last12[group.x.toInt()];
              return BarTooltipItem(
                '${_formatMonthLabel(monthKey)}\n${_formatAxisValue(data[monthKey] ?? 0)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(_formatAxisValue(value), style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= last12.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_formatMonthLabel(last12[value.toInt()]), style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(last12.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[last12[index]] ?? 0,
                color: color,
                width: last12.length > 6 ? 12 : 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ============================================================
  // TREND ROW HELPER
  // ============================================================

  _DetailRow _trendRow(String label, double percent) {
    final prefix = percent >= 0 ? '+' : '';
    final color = percent >= 0 ? Colors.green : Colors.red;
    return _DetailRow(label, '$prefix${percent.toStringAsFixed(1)}%',
      color: color,
      icon: percent >= 0 ? Icons.trending_up : Icons.trending_down,
    );
  }

  // ============================================================
  // THERMO + DIENSTLEISTUNGEN (kompakt, nebeneinander)
  // ============================================================

  // ============================================================
  // AUFTRÄGE DETAILTABELLE
  // ============================================================

  Widget _buildOrdersTable(BuildContext context, SalesAnalytics analytics, NumberFormat format) {
    final orders = analytics.orders;
    if (orders.isEmpty) return const SizedBox.shrink();

    final totalSubtotal = orders.fold<double>(0, (s, o) => s + o.subtotal);
    final totalGross = orders.fold<double>(0, (s, o) => s + o.total);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.table_rows, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Aufträge im Zeitraum',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${orders.length} Aufträge',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabellen-Header
          Container(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Auftrag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                Expanded(flex: 4, child: Text('Kunde', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                SizedBox(width: 56, child: Text('Datum', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                SizedBox(width: 80, child: Text('Warenwert', textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                SizedBox(width: 80, child: Text('Gesamt', textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant))),
              ],
            ),
          ),

          // Zeilen
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
            itemBuilder: (context, index) {
              final order = orders[index];
              final isEven = index % 2 == 0;
              return InkWell(
                onTap: () => OrderSummarySheet.show(context, order),
                child: Container(
                  color: isEven ? Colors.transparent : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          order.orderNumber,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          order.customerName,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          DateFormat('dd.MM.yy').format(order.relevantDate),
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          format.format(order.subtotal),
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          format.format(order.total),
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Summenzeile
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 1.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Text(
                    'Total',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 56),
                SizedBox(
                  width: 80,
                  child: Text(
                    format.format(totalSubtotal),
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    format.format(totalGross),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThermoCard(BuildContext context, SalesAnalytics analytics) {
    final theme = Theme.of(context);
    final thermo = analytics.thermoStats;
    final service = analytics.serviceStats;
    final currencyFormat = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;

        final thermoCard = _buildShareCard(
          context,
          icon: Icons.whatshot,
          iconName: 'whatshot',
          color: Colors.deepOrange,
          title: 'Thermobehandlung',
          itemSharePercent: thermo.itemSharePercent,
          itemDetail: '${thermo.thermoItemCount} von ${thermo.totalItemCount} Artikel',
          revenueSharePercent: thermo.revenueSharePercent,
          revenueDetail: currencyFormat.format(thermo.thermoRevenue),
          onTap: thermo.thermoItemCount > 0
              ? () => _showShareDetailDialog(context, 'Thermobehandlung', Icons.whatshot, 'whatshot', Colors.deepOrange, thermo.details)
              : null,
        );

        final serviceCard = _buildShareCard(
          context,
          icon: Icons.build,
          iconName: 'build',
          color: Colors.blueAccent,
          title: 'Dienstleistungen',
          itemSharePercent: service.itemSharePercent,
          itemDetail: '${service.serviceItemCount} von ${service.totalItemCount} Artikel',
          revenueSharePercent: service.revenueSharePercent,
          revenueDetail: currencyFormat.format(service.serviceRevenue),
          onTap: service.serviceItemCount > 0
              ? () => _showShareDetailDialog(context, 'Dienstleistungen', Icons.build, 'build', Colors.blueAccent, service.details)
              : null,
        );

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: thermoCard),
                const SizedBox(width: 12),
                Expanded(child: serviceCard),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              thermoCard,
              const SizedBox(height: 12),
              serviceCard,
            ],
          );
        }
      },
    );
  }

  Widget _buildShareCard(
      BuildContext context, {
        required IconData icon,
        required String iconName,
        required Color color,
        required String title,
        required double itemSharePercent,
        required String itemDetail,
        required double revenueSharePercent,
        required String revenueDetail,
        VoidCallback? onTap,
      }) {
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Anteil Artikel', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('${itemSharePercent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                      Text(itemDetail, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(height: 40, width: 1, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: Column(
                    children: [
                      Text('Anteil Umsatz', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('${revenueSharePercent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                      Text(revenueDetail, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: revenueSharePercent / 100,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: card);
    }
    return card;
  }
}

// ============================================================
// DATA CLASSES
// ============================================================

class _KpiCardData {
  final String title;
  final String value;
  final IconData icon;
  final String iconName;
  final Color color;
  final double? trend;
  final String? trendLabel;
  final String? subtitle;
  final VoidCallback? onTap;

  _KpiCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconName,
    required this.color,
    this.trend,
    this.trendLabel,
    this.subtitle,
    this.onTap,
  });
}

class _DetailRow {
  final String label;
  final String value;
  final bool isHeader;
  final Color? color;
  final IconData? icon;

  const _DetailRow(this.label, this.value, {this.isHeader = false, this.color, this.icon});
}