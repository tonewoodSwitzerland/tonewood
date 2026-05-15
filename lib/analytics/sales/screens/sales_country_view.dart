// lib/analytics/sales/screens/sales_country_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/icon_helper.dart';

import '../models/sales_filter.dart';
import '../models/sales_analytics_models.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_world_map.dart';

class SalesCountryView extends StatefulWidget {
  final SalesFilter filter;
  final ValueChanged<SalesFilter>? onFilterChanged;

  const SalesCountryView({
    Key? key,
    required this.filter,
    this.onFilterChanged,
  }) : super(key: key);

  @override
  State<SalesCountryView> createState() => _SalesCountryViewState();
}

class _SalesCountryViewState extends State<SalesCountryView> {
  String _sortBy = 'revenue';
  bool _showMap = false; // Default: Liste (false)

  bool get _useShippingAddress => widget.filter.useShippingAddress;

  void _setUseShippingAddress(bool value) {
    if (value == _useShippingAddress) return;
    final newFilter = widget.filter.copyWith(useShippingAddress: value);
    widget.onFilterChanged?.call(newFilter);
  }

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
              // Header mit den Stats - HIER sitzt jetzt der Toggle
              _buildHeaderStats(context, countries.length, totalRevenue, totalOrders),
              const SizedBox(height: 12),

              _buildAddressToggle(context),
              const SizedBox(height: 16),

              // Dynamisches Layout basierend auf _showMap
              if (_showMap)
              // RIESIGES MAP WIDGET
                _buildFullscreenMap(countries, totalRevenue)
              else
              // STANDARD LISTE / CHART LAYOUT
                _buildStandardLayout(countries, totalRevenue, totalOrders),
            ],
          ),
        );
      },
    );
  }

  // Die große Kartenansicht
  Widget _buildFullscreenMap(List<CountryStats> countries, double totalRevenue) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12, left: 4),
          child: Text(
            'Globale Umsatzverteilung',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // Wir nutzen hier eine größere feste Höhe oder einen LayoutBuilder
        SalesWorldMap(
          countries: countries,
          totalRevenue: totalRevenue,
          // Hinweis: Falls deine SalesWorldMap eine height intern berechnet,
          // kannst du sie hier in einen Container mit z.B. height: 700 packen.
        ),
      ],
    );
  }

  // Das klassische Layout (PieChart + Tabelle)
  Widget _buildStandardLayout(List<CountryStats> countries, double totalRevenue, int totalOrders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildPieChartCard(context, countries, totalRevenue)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _buildCountryTable(context, countries, totalRevenue, totalOrders)),
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
    );
  }

  Widget _buildHeaderStats(BuildContext context, int countryCount, double totalRevenue, int totalOrders) {
    final theme = Theme.of(context);

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
                    child: const Icon(Icons.public, color: Colors.teal, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$countryCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Länder', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  // const Spacer(),
                  // // DER NEUE TOGGLE
                  // SegmentedButton<bool>(
                  //   segments: const [
                  //     ButtonSegment(value: false, icon: Icon(Icons.list), tooltip: 'Listenansicht'),
                  //     ButtonSegment(value: true, icon: Icon(Icons.map_outlined), tooltip: 'Kartenansicht'),
                  //   ],
                  //   selected: {_showMap},
                  //   onSelectionChanged: (val) => setState(() => _showMap = val.first),
                  //   showSelectedIcon: false,
                  //   style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  // ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Die zweite Card (Lieferungen) bleibt wie sie ist
        Expanded(
          child: _buildSimpleStatCard(
              context,
              '$totalOrders',
              'Lieferungen',
              Icons.local_shipping,
              Colors.blue
          ),
        ),
      ],
    );
  }

  // Hilfswidget für die Lieferungen-Card
  Widget _buildSimpleStatCard(BuildContext context, String value, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
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
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ... (Die restlichen Methoden _buildAddressToggle, _buildPieChartCard, _buildCountryTable bleiben gleich,
  // nur im _buildPieChartCard solltest du den alten Toggle jetzt entfernen)

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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Umsatz nach Land (Warenwert)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: List.generate(topCountries.length, (index) {
                    final country = topCountries[index];
                    final percent = totalRevenue > 0 ? (country.revenue / totalRevenue * 100) : 0;
                    return PieChartSectionData(
                      value: country.revenue,
                      title: percent > 5 ? '${percent.toStringAsFixed(0)}%' : '',
                      color: _getCountryColor(index),
                      radius: 80,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }),
                ),
              ),
            ),
            // ... (Legende etc.)
          ],
        ),
      ),
    );
  }

  // Toggle-Leiste zwischen Header-Stats und Chart/Tabelle
  Widget _buildAddressToggle(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'location_on',
              defaultIcon: Icons.location_on_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auswertung nach',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _useShippingAddress
                        ? 'Lieferadresse — fällt auf Rechnungsadresse zurück, wenn keine abweichende Lieferadresse hinterlegt ist'
                        : 'Rechnungsadresse des Kunden',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Rechnungsadr.')),
                ButtonSegment(value: true, label: Text('Lieferadr.')),
              ],
              selected: {_useShippingAddress},
              onSelectionChanged: (selection) {
                _setUseShippingAddress(selection.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
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
                  style: const ButtonStyle(
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