import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/production/production_batch_service.dart';
import '../../services/icon_helper.dart';


/// Neue ProductionOverview mit performanten Aggregationen
/// Basiert auf der flachen production_batches Collection
class ProductionOverviewNew extends StatefulWidget {
  const ProductionOverviewNew({Key? key}) : super(key: key);

  @override
  State<ProductionOverviewNew> createState() => _ProductionOverviewNewState();
}

class _ProductionOverviewNewState extends State<ProductionOverviewNew> {
  final ProductionBatchService _service = ProductionBatchService();
  final _currencyFormat = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF');
  final _numberFormat = NumberFormat('#,##0', 'de_CH');

  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = [];
  bool _isLoading = true;

  // Daten
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>>? _topProducts;
  Map<String, Map<String, dynamic>>? _qualityDistribution;
  List<Map<String, dynamic>>? _woodTypeStats;
  List<Map<String, dynamic>>? _logYieldStats;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    final years = await _service.getAvailableYears();
    setState(() {
      _availableYears = years.isNotEmpty ? years : [DateTime.now().year];
      if (!_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _service.getYearSummary(_selectedYear),
        _service.getTopProducts(_selectedYear),
        _service.getQualityDistribution(_selectedYear),
        _service.getStatsByWoodType(_selectedYear),
        _service.getAverageYieldPerLog(_selectedYear),
      ]);

      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _topProducts = results[1] as List<Map<String, dynamic>>;
        _qualityDistribution = results[2] as Map<String, Map<String, dynamic>>;
        _woodTypeStats = results[3] as List<Map<String, dynamic>>;
        _logYieldStats = results[4] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildYearSelector(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildTopProductsSection(),
                  const SizedBox(height: 24),
                  _buildQualityDistributionSection(),
                  const SizedBox(height: 24),
                  _buildWoodTypeSection(),
                  const SizedBox(height: 24),
                  _buildLogYieldSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(
            iconName: 'calendar_today',
            defaultIcon: Icons.calendar_today,
            color: const Color(0xFF0F4A29),
          ),
          const SizedBox(width: 12),
          const Text(
            'Produktionsjahr:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                items: _availableYears.map((year) => DropdownMenuItem(
                  value: year,
                  child: Text(
                    '$year',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )).toList(),
                onChanged: (year) {
                  if (year != null) {
                    setState(() => _selectedYear = year);
                    _loadData();
                  }
                },
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'refresh', defaultIcon: Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_summary == null) return const SizedBox.shrink();

    final quantities = _summary!['quantities_by_unit'] as Map<String, double>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Zusammenfassung $_selectedYear', Icons.summarize, 'summarize'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildSummaryCard(
              'Gesamtwert',
              _currencyFormat.format(_summary!['total_value'] ?? 0),
              Icons.payments,
              'payments',
              Colors.green,
            ),
            _buildSummaryCard(
              'Einträge',
              _numberFormat.format(_summary!['total_batches'] ?? 0),
              Icons.layers,
              'layers',
              Colors.blue,
            ),
            _buildSummaryCard(
              'Stämme',
              _numberFormat.format(_summary!['unique_logs_count'] ?? 0),
              Icons.forest,
              'forest',
              Colors.brown,
            ),
            _buildSummaryCard(
              'Stück',
              _numberFormat.format(quantities['Stk'] ?? quantities['Stück'] ?? 0),
              Icons.inventory,
              'inventory',
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, String iconName, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: 20, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsSection() {
    if (_topProducts == null || _topProducts!.isEmpty) {
      return _buildEmptySection('Top 10 Produkte', 'Keine Daten vorhanden');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Top 10 Produkte', Icons.emoji_events, 'emoji_events'),
        const SizedBox(height: 12),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Rang')),
                DataColumn(label: Text('Produkt')),
                DataColumn(label: Text('Menge'), numeric: true),
                DataColumn(label: Text('Wert CHF'), numeric: true),
                DataColumn(label: Text('Einträge'), numeric: true),
              ],
              rows: _topProducts!.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return DataRow(cells: [
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: index < 3 ? Colors.amber.withOpacity(0.2) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  )),
                  DataCell(Text('${item['instrument_name']} ${item['part_name']}')),
                  DataCell(Text(_numberFormat.format(item['total_quantity'] ?? 0))),
                  DataCell(Text(_currencyFormat.format(item['total_value'] ?? 0))),
                  DataCell(Text('${item['batch_count'] ?? 0}')),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityDistributionSection() {
    if (_qualityDistribution == null || _qualityDistribution!.isEmpty) {
      return _buildEmptySection('Qualitätsverteilung (Decken)', 'Keine Daten vorhanden');
    }

    // Sortiere Qualitäten in der richtigen Reihenfolge
    const qualityOrder = ['MA', 'AAAA', 'AAA', 'AA', 'A', 'AB'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Qualitätsverteilung (nur Decken)', Icons.star, 'star'),
        const SizedBox(height: 12),
        ..._qualityDistribution!.entries.map((entry) {
          final instrumentCode = entry.key;
          final data = entry.value;
          final qualities = data['qualities'] as Map<String, dynamic>? ?? {};
          final totalQuantity = (data['total_quantity'] as num?)?.toDouble() ?? 0;

          // Sortiere Qualitäten
          final sortedQualities = qualities.entries.toList()
            ..sort((a, b) {
              final indexA = qualityOrder.indexOf(a.key);
              final indexB = qualityOrder.indexOf(b.key);
              if (indexA == -1 && indexB == -1) return a.key.compareTo(b.key);
              if (indexA == -1) return 1;
              if (indexB == -1) return -1;
              return indexA.compareTo(indexB);
            });

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['instrument_name'] ?? instrumentCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4A29).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Total: ${_numberFormat.format(totalQuantity)} Stk',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F4A29),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Qualitäts-Balken
                  ...sortedQualities.map((q) {
                    final qData = q.value as Map<String, dynamic>;
                    final quantity = (qData['quantity'] as num?)?.toDouble() ?? 0;
                    final percentage = (qData['percentage'] as num?)?.toDouble() ?? 0;
                    final qualityName = qData['quality_name'] ?? q.key;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              qualityName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: percentage / 100,
                                  child: Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _getQualityColor(q.key),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: Text(
                              _numberFormat.format(quantity),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
  Color _getQualityColor(String quality) {
    switch (quality) {
      case 'MA': return Colors.purple;
      case 'AAAA': return Colors.green[700]!;
      case 'AAA': return Colors.green;
      case 'AA': return Colors.lightGreen;
      case 'A': return Colors.amber;
      case 'AB': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildWoodTypeSection() {
    if (_woodTypeStats == null || _woodTypeStats!.isEmpty) {
      return _buildEmptySection('Produktion nach Holzart', 'Keine Daten vorhanden');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Produktion nach Holzart', Icons.forest, 'forest'),
        const SizedBox(height: 12),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Holzart')),
                DataColumn(label: Text('Menge'), numeric: true),
                DataColumn(label: Text('Wert CHF'), numeric: true),
                DataColumn(label: Text('Einträge'), numeric: true),
              ],
              rows: _woodTypeStats!.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item['wood_name'] ?? item['wood_code'] ?? '-')),
                  DataCell(Text(_numberFormat.format(item['total_quantity'] ?? 0))),
                  DataCell(Text(_currencyFormat.format(item['total_value'] ?? 0))),
                  DataCell(Text('${item['batch_count'] ?? 0}')),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogYieldSection() {
    if (_logYieldStats == null || _logYieldStats!.isEmpty) {
      return _buildEmptySection('Durchschnittserlös pro Stamm', 'Keine Daten vorhanden');
    }

    // Filtere nur Einträge mit Stamm-Daten
    final statsWithLogs = _logYieldStats!.where((s) => s['has_log_data'] == true).toList();

    if (statsWithLogs.isEmpty) {
      return _buildEmptySection(
        'Durchschnittserlös pro Stamm',
        'Noch keine Stamm-Zuordnungen vorhanden',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Durchschnittserlös pro Stamm', Icons.trending_up, 'trending_up'),
        const SizedBox(height: 12),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Holzart')),
                DataColumn(label: Text('Stämme'), numeric: true),
                DataColumn(label: Text('Gesamtwert'), numeric: true),
                DataColumn(label: Text('Ø pro Stamm'), numeric: true),
              ],
              rows: statsWithLogs.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item['wood_name'] ?? item['wood_code'] ?? '-')),
                  DataCell(Text('${item['log_count'] ?? 0}')),
                  DataCell(Text(_currencyFormat.format(item['total_value'] ?? 0))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4A29).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _currencyFormat.format(item['average_yield_per_log'] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hinweis: Nur Produktionen mit Stamm-Zuordnung werden berücksichtigt.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String iconName) {
    return Row(
      children: [
        getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: const Color(0xFF0F4A29)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmptySection(String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}