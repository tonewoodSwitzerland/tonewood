// lib/analytics/production/production_overview_new.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/analytics/production/widgets/volume_info_sheet.dart';
import 'package:tonewood/production/production_batch_service.dart';
import '../../services/icon_helper.dart';
import 'services/production_cache_service.dart';

// Schweizer Volumenformat: 1'234.567 m³
// (NumberFormat.symbols ist final in neueren Intl-Versionen)
String chVolume(double value) {
  // Auf 3 Dezimalstellen runden
  final formatted = value.toStringAsFixed(3);
  final parts = formatted.split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  // Tausender-Hochkomma einfügen
  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('\'');
    buffer.write(intPart[i]);
  }
  return "${buffer.toString()}.$decPart";
}

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
  bool _isFromCache = false;
  DateTime? _lastBatchAt;

  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>>? _topProducts;
  Map<String, dynamic>? _qualityDistribution;
  List<Map<String, dynamic>>? _woodTypeStats;
  List<Map<String, dynamic>>? _logYieldStats;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    final years = await _service.getAvailableYears();
    if (!mounted) return;
    setState(() {
      _availableYears = years.isNotEmpty ? years : [DateTime.now().year];
      if (!_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }
    });
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> overviewData;

      if (forceRefresh) {
        // Bei manuellem Refresh: Cache invalidieren, dann neu berechnen
        await ProductionCacheService.invalidateYear(_selectedYear);
      }

      overviewData = await ProductionCacheService.getOrCalculateOverview(
        _selectedYear,
        _service,
      );

      // Prüfe ob Daten aus Cache kamen (calculated_at vorhanden)
      final cacheDoc = await _service.firestore
          .collection('production_cache')
          .doc(_selectedYear.toString())
          .get();
      final fromCache = cacheDoc.exists &&
          cacheDoc.data()?['overview_calculated_at'] != null &&
          cacheDoc.data()?['last_batch_at'] != null &&
          (cacheDoc.data()!['overview_calculated_at'] as dynamic)
              .compareTo(cacheDoc.data()!['last_batch_at']) >=
              0;

      final lastBatchAtTs = cacheDoc.data()?['last_batch_at'];
      final lastBatchAt = lastBatchAtTs != null
          ? (lastBatchAtTs as dynamic).toDate() as DateTime
          : null;

      if (!mounted) return;
      setState(() {
        _summary = Map<String, dynamic>.from(overviewData['summary'] ?? {});
        _topProducts = List<Map<String, dynamic>>.from(
            (overviewData['top_products'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)));
        _qualityDistribution =
        Map<String, dynamic>.from(overviewData['quality_distribution'] ?? {});
        _woodTypeStats = List<Map<String, dynamic>>.from(
            (overviewData['wood_type_stats'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)));
        _logYieldStats = List<Map<String, dynamic>>.from(
            (overviewData['log_yield_stats'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)));
        _isFromCache = fromCache;
        _lastBatchAt = lastBatchAt;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fehler beim Laden: $e'),
              backgroundColor: Colors.red),
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
            onRefresh: () => _loadData(forceRefresh: true),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                items: _availableYears
                    .map((year) => DropdownMenuItem(
                  value: year,
                  child: Text('$year',
                      style:
                      const TextStyle(fontWeight: FontWeight.bold)),
                ))
                    .toList(),
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
          // Cache-Status: kleines Info-Icon
          if (!_isLoading)
            _buildCacheInfoButton(),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'refresh', defaultIcon: Icons.refresh),
            onPressed: () => _loadData(forceRefresh: true),
            tooltip: 'Neu berechnen',
          ),
        ],
      ),
    );
  }

  Widget _buildCacheInfoButton() {
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm', 'de_CH');
    final lastBatchStr = _lastBatchAt != null
        ? dateFormat.format(_lastBatchAt!)
        : '–';

    return IconButton(
      icon: Icon(Icons.info_outline, size: 18, color: Colors.grey[400]),
      tooltip: 'Datenstand',
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.history,
                          size: 20, color: Colors.blue[600]),
                    ),
                    const SizedBox(width: 12),
                    const Text('Datenstand',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Letzter berücksichtigter Eintrag', lastBatchStr),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Quelle',
                  _isFromCache ? 'Zwischenspeicher (Cache)' : 'Frisch berechnet',
                ),
                const SizedBox(height: 16),
                Text(
                  'Die Auswertung berücksichtigt alle Produktionen '
                      'bis zum oben genannten Datum. '
                      'Neue Buchungen werden beim nächsten Laden automatisch einbezogen.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.5),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    if (_summary == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'Zusammenfassung $_selectedYear', Icons.summarize, 'summarize'),
        const SizedBox(height: 12),
        // Gesamtwert – große Card über volle Breite
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'payments',
                    defaultIcon: Icons.payments,
                    size: 24,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gesamtwert',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(_summary!['total_value'] ?? 0),
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Einträge + Stämme – zwei Cards nebeneinander
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Einträge',
                _numberFormat.format(_summary!['total_batches'] ?? 0),
                Icons.layers,
                'layers',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Stämme',
                _numberFormat.format(_summary!['unique_logs_count'] ?? 0),
                Icons.forest,
                'forest',
                Colors.brown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Mengen nach Einheit + m³ gesamt
        _buildQuantityCard(),
      ],
    );
  }

  Widget _buildQuantityCard() {
    final quantitiesByUnit = Map<String, dynamic>.from(
        _summary?['quantities_by_unit'] as Map? ?? {});
    final totalVolumeM3 =
        (_summary?['total_volume_m3'] as num?)?.toDouble() ?? 0.0;
    final volumeFromDirectM3 =
        (_summary?['volume_from_direct_m3'] as num?)?.toDouble() ?? 0.0;
    final volumeFromPieces =
        (_summary?['volume_from_pieces'] as num?)?.toDouble() ?? 0.0;
    final pieceBatchesTotal =
        (_summary?['piece_batches_total'] as num?)?.toInt() ?? 0;
    final pieceBatchesWithVolume =
        (_summary?['piece_batches_with_volume'] as num?)?.toInt() ?? 0;
    final piecesWithVolume =
        (_summary?['pieces_with_volume'] as num?)?.toDouble() ?? 0.0;
    final piecesWithoutVolume =
        (_summary?['pieces_without_volume'] as num?)?.toDouble() ?? 0.0;

    const unitOrder = ['Stück', 'Stk', 'm³', 'm²', 'Kg', 'Palette'];

    final sortedUnits = quantitiesByUnit.keys.toList()
      ..sort((a, b) {
        final ia = unitOrder.indexOf(a);
        final ib = unitOrder.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'straighten',
                    defaultIcon: Icons.straighten,
                    size: 20,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Text('Mengen',
                    style:
                    TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),

            // Alle Einheiten einzeln
            ...sortedUnits.map((unit) {
              final qty =
                  (quantitiesByUnit[unit] as num?)?.toDouble() ?? 0.0;
              final isM3 = unit == 'm³';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(unit,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                    Text(
                      isM3
                          ? '${chVolume(qty)} m³'
                          : _numberFormat.format(qty),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),

            // m³ gesamt – nur wenn Stück-Buchungen vorhanden
            if (pieceBatchesTotal > 0 || volumeFromDirectM3 > 0) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('m³ gesamt',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => VolumeInfoSheet.show(context, _summary!),
                        child: Icon(Icons.info,
                            size: 16, color: Colors.teal.withOpacity(0.7)),
                      ),
                    ],
                  ),
                  Text(
                    '${chVolume(totalVolumeM3)} m³',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon,
      String iconName, Color color) {
    return Card(
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
                  child: getAdaptiveIcon(
                      iconName: iconName,
                      defaultIcon: icon,
                      size: 20,
                      color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
        _buildSectionHeader(
            'Top 10 Produkte', Icons.emoji_events, 'emoji_events'),
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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: index < 3
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontWeight:
                        index < 3 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  )),
                  DataCell(Text(
                      '${item['instrument_name']} ${item['part_name']}')),
                  DataCell(Text(
                      _numberFormat.format(item['total_quantity'] ?? 0))),
                  DataCell(
                      Text(_currencyFormat.format(item['total_value'] ?? 0))),
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
      return _buildEmptySection(
          'Qualitätsverteilung (Decken)', 'Keine Daten vorhanden');
    }

    const qualityOrder = ['MA', 'AAAA', 'AAA', 'AA', 'A', 'AB'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'Qualitätsverteilung (nur Decken)', Icons.star, 'star'),
        const SizedBox(height: 12),
        ..._qualityDistribution!.entries.map((entry) {
          final instrumentCode = entry.key;
          final data = Map<String, dynamic>.from(entry.value as Map);
          final qualities =
          Map<String, dynamic>.from(data['qualities'] as Map? ?? {});
          final totalQuantity =
              (data['total_quantity'] as num?)?.toDouble() ?? 0;

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
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
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
                  ...sortedQualities.map((q) {
                    final qData = Map<String, dynamic>.from(q.value as Map);
                    final quantity =
                        (qData['quantity'] as num?)?.toDouble() ?? 0;
                    final percentage =
                        (qData['percentage'] as num?)?.toDouble() ?? 0;
                    final qualityName = qData['quality_name'] ?? q.key;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              qualityName,
                              style:
                              const TextStyle(fontWeight: FontWeight.w500),
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
      case 'MA':
        return Colors.purple;
      case 'AAAA':
        return Colors.green[700]!;
      case 'AAA':
        return Colors.green;
      case 'AA':
        return Colors.lightGreen;
      case 'A':
        return Colors.amber;
      case 'AB':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildWoodTypeSection() {
    if (_woodTypeStats == null || _woodTypeStats!.isEmpty) {
      return _buildEmptySection(
          'Produktion nach Holzart', 'Keine Daten vorhanden');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'Produktion nach Holzart', Icons.forest, 'forest'),
        const SizedBox(height: 12),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Holzart')),
                DataColumn(label: Text('Menge'), numeric: true),
                DataColumn(label: Text('m³'), numeric: true),
                DataColumn(label: Text('Wert CHF'), numeric: true),
                DataColumn(label: Text('Einträge'), numeric: true),
              ],
              rows: [
                ..._woodTypeStats!.map((item) {
                  return DataRow(cells: [
                    DataCell(
                        Text(item['wood_name'] ?? item['wood_code'] ?? '-')),
                    DataCell(Text(
                        _numberFormat.format(item['total_quantity'] ?? 0))),
                    DataCell(Text(
                        '${chVolume((item['total_volume'] as num?)?.toDouble() ?? 0)} m³')),
                    DataCell(
                        Text(_currencyFormat.format(item['total_value'] ?? 0))),
                    DataCell(Text('${item['batch_count'] ?? 0}')),
                  ]);
                }),
                // Summenzeile
                DataRow(
                  color: WidgetStateProperty.all(
                      const Color(0xFF0F4A29).withOpacity(0.07)),
                  cells: [
                    const DataCell(Text('Gesamt',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(
                      _numberFormat.format(_woodTypeStats!.fold<double>(
                          0, (sum, e) => sum + ((e['total_quantity'] as num?)?.toDouble() ?? 0))),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text(
                      '${chVolume(_woodTypeStats!.fold<double>(
                          0, (sum, e) => sum + ((e['total_volume'] as num?)?.toDouble() ?? 0)))} m³',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text(
                      _currencyFormat.format(_woodTypeStats!.fold<double>(
                          0, (sum, e) => sum + ((e['total_value'] as num?)?.toDouble() ?? 0))),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text(
                      '${_woodTypeStats!.fold<int>(
                          0, (sum, e) => sum + ((e['batch_count'] as int?) ?? 0))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogYieldSection() {
    if (_logYieldStats == null || _logYieldStats!.isEmpty) {
      return _buildEmptySection(
          'Durchschnittserlös pro Stamm', 'Keine Daten vorhanden');
    }

    final statsWithLogs =
    _logYieldStats!.where((s) => s['has_log_data'] == true).toList();

    if (statsWithLogs.isEmpty) {
      return _buildEmptySection(
        'Durchschnittserlös pro Stamm',
        'Noch keine Stamm-Zuordnungen vorhanden',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'Durchschnittserlös pro Stamm', Icons.trending_up, 'trending_up'),
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
                  DataCell(
                      Text(item['wood_name'] ?? item['wood_code'] ?? '-')),
                  DataCell(Text('${item['log_count'] ?? 0}')),
                  DataCell(
                      Text(_currencyFormat.format(item['total_value'] ?? 0))),
                  DataCell(Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4A29).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _currencyFormat
                          .format(item['average_yield_per_log'] ?? 0),
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
        getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            color: const Color(0xFF0F4A29)),
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
        Text(title,
            style:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(message,
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}