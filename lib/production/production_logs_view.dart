// lib/production/production_logs_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/production/production_batch_service.dart';
import '../../services/icon_helper.dart';

class ProductionLogsView extends StatefulWidget {
  final ProductionBatchService service;
  final Function(int year)? onYearChanged;

  const ProductionLogsView({
    Key? key,
    required this.service,
    this.onYearChanged,
  }) : super(key: key);

  @override
  State<ProductionLogsView> createState() => _ProductionLogsViewState();
}

class _ProductionLogsViewState extends State<ProductionLogsView> {
  final _currencyFormat = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF');
  final _numberFormat = NumberFormat('#,##0', 'de_CH');
  final _dateFormat = DateFormat('dd.MM.yyyy');

  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = [];
  bool _isLoading = true;
  String _viewMode = 'byLog'; // 'byLog' oder 'chronological'
  bool _showEmptyLogs = false; // Stämme ohne Produktion einblenden

  List<Map<String, dynamic>> _batches = [];
  Map<String, List<Map<String, dynamic>>> _batchesByLog = {};
  Map<String, Map<String, dynamic>> _logDetails = {};

  // Alle Stämme des Jahrgangs (inkl. ohne Produktion)
  List<Map<String, dynamic>> _allLogsOfYear = [];

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    final years = await widget.service.getAvailableRoundwoodYears();
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
      // Alle Stämme des Jahrgangs laden
      final allLogsSnapshot = await FirebaseFirestore.instance
          .collection('roundwood')
          .where('year', isEqualTo: _selectedYear)
          .get();

      final allLogs = allLogsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Batches für diese Stämme laden
      final batches = await widget.service.getBatchesForRoundwoodYear(_selectedYear);

      // Gruppiere Batches nach Stamm
      final byLog = <String, List<Map<String, dynamic>>>{};
      final withoutLog = <Map<String, dynamic>>[];

      for (final batch in batches) {
        final logId = batch['roundwood_id'] as String?;
        if (logId != null && logId.isNotEmpty) {
          byLog.putIfAbsent(logId, () => []).add(batch);
        } else {
          withoutLog.add(batch);
        }
      }

      // Stamm-Details aus allLogs zusammenstellen
      final logDetails = <String, Map<String, dynamic>>{};
      for (final log in allLogs) {
        logDetails[log['id'] as String] = log;
      }

      // Stämme ohne Produktion: in allLogs vorhanden aber nicht in byLog
      for (final log in allLogs) {
        final logId = log['id'] as String;
        if (!byLog.containsKey(logId)) {
          byLog['_empty_$logId'] = []; // leere Liste = kein Batch
          logDetails['_empty_$logId'] = log;
        }
      }

      // Stämme ohne Zuordnung
      if (withoutLog.isNotEmpty) {
        byLog['_unassigned'] = withoutLog;
      }

      setState(() {
        _batches = batches;
        _batchesByLog = byLog;
        _logDetails = logDetails;
        _allLogsOfYear = allLogs;
        _isLoading = false;
      });

      widget.onYearChanged?.call(_selectedYear);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Hilfsmethoden für Statistiken
  int get _logsWithProduction =>
      _batchesByLog.keys.where((k) => !k.startsWith('_empty_') && k != '_unassigned').length;

  int get _logsWithoutProduction =>
      _batchesByLog.keys.where((k) => k.startsWith('_empty_')).length;

  int get _totalLogs => _allLogsOfYear.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _batches.isEmpty && _allLogsOfYear.isEmpty
              ? _buildEmptyState()
              : _viewMode == 'byLog'
              ? _buildLogGroupedView()
              : _buildChronologicalView(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zeile 1: Jahr + Badge
          Row(
            children: [
              _buildYearSelector(),
              const SizedBox(width: 12),
              Flexible(child: _buildStatsBadge()),
            ],
          ),
          const SizedBox(height: 12),
          // Zeile 2: Toggles – horizontal scrollbar gegen Overflow
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildViewToggle(),
                const SizedBox(width: 12),
                _buildEmptyLogsToggle(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildYearSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        getAdaptiveIcon(
          iconName: 'calendar_today',
          defaultIcon: Icons.calendar_today,
          color: const Color(0xFF0F4A29),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              items: _availableYears.map((y) => DropdownMenuItem(
                value: y,
                child: Text('$y', style: const TextStyle(fontWeight: FontWeight.bold)),
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
      ],
    );
  }

  Widget _buildStatsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F4A29).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$_logsWithProduction/$_totalLogs Stämme • ${_batches.length} Einträge',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Color(0xFF0F4A29),
        ),
      ),
    );
  }

  Widget _buildEmptyLogsToggle() {
    if (_logsWithoutProduction == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _showEmptyLogs = !_showEmptyLogs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _showEmptyLogs
              ? Colors.grey.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showEmptyLogs ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              '$_logsWithoutProduction ohne Produktion',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'byLog',
          icon: getAdaptiveIcon(iconName: 'forest', defaultIcon: Icons.forest, size: 18),
          label: const Text('Stamm'),
        ),
        ButtonSegment(
          value: 'chronological',
          icon: getAdaptiveIcon(iconName: 'list', defaultIcon: Icons.list, size: 18),
          label: const Text('Datum'),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (selection) {
        setState(() => _viewMode = selection.first);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Keine Stämme für $_selectedYear',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLogGroupedView() {
    // Filtere Keys je nach _showEmptyLogs
    final sortedKeys = _batchesByLog.keys.where((k) {
      if (k == '_unassigned') return true;
      if (k.startsWith('_empty_')) return _showEmptyLogs;
      return true;
    }).toList()
      ..sort((a, b) {
        if (a == '_unassigned') return 1;
        if (b == '_unassigned') return -1;
        // Leere Stämme ans Ende (aber vor _unassigned)
        if (a.startsWith('_empty_') && !b.startsWith('_empty_')) return 1;
        if (!a.startsWith('_empty_') && b.startsWith('_empty_')) return -1;
        // Nach Stamm-Nummer sortieren
        final logA = _logDetails[a];
        final logB = _logDetails[b];
        final numA = logA?['internal_number']?.toString() ?? '';
        final numB = logB?['internal_number']?.toString() ?? '';
        return numA.compareTo(numB);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final logId = sortedKeys[index];
        final batches = _batchesByLog[logId]!;
        final logData = _logDetails[logId];
        return _buildLogCard(logId, batches, logData);
      },
    );
  }

  Widget _buildLogCard(
      String logId,
      List<Map<String, dynamic>> batches,
      Map<String, dynamic>? logData,
      ) {
    final isUnassigned = logId == '_unassigned';
    final isEmpty = logId.startsWith('_empty_');

    double totalValue = 0;
    double totalQuantity = 0;
    for (final b in batches) {
      totalValue += (b['value'] as num?)?.toDouble() ?? 0;
      totalQuantity += (b['quantity'] as num?)?.toDouble() ?? 0;
    }

    Color borderColor = Colors.grey[200]!;
    if (isUnassigned) borderColor = Colors.orange.withOpacity(0.3);
    if (isEmpty) borderColor = Colors.grey.withOpacity(0.2);

    Color iconColor = const Color(0xFF0F4A29);
    if (isUnassigned) iconColor = Colors.orange;
    if (isEmpty) iconColor = Colors.grey[400]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      color: isEmpty ? Colors.grey[50] : null,
      child: isEmpty
      // Stämme ohne Produktion: kein ExpansionTile
          ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.forest, size: 24, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${logData?['internal_number'] ?? '?'}/${logData?['year'] ?? '?'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (logData != null)
                    Text(
                      '${logData['wood_name'] ?? ''}'
                          '${logData['original_number'] != null ? ' • ${logData['original_number']}' : ''}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Keine Produktion',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      )
      // Stämme mit Produktion: ExpansionTile
          : Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUnassigned
                  ? Colors.orange.withOpacity(0.1)
                  : const Color(0xFF0F4A29).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: getAdaptiveIcon(
              iconName: isUnassigned ? 'help' : 'forest',
              defaultIcon: isUnassigned ? Icons.help_outline : Icons.forest,
              color: iconColor,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnassigned
                          ? 'Ohne Stamm-Zuordnung'
                          : '${logData?['internal_number'] ?? '?'}/${logData?['year'] ?? '?'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (!isUnassigned && logData != null)
                      Text(
                        '${logData['wood_name'] ?? ''}'
                            '${logData['original_number'] != null ? ' • ${logData['original_number']}' : ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(totalValue),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F4A29)),
                  ),
                  Text(
                    '${batches.length} Einträge',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            ...batches.map((batch) => _buildBatchRow(batch)),
            if (!isUnassigned) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (logData?['is_moonwood'] == true)
                          _buildTag('Mondholz', Colors.purple),
                        if (logData?['is_fsc'] == true)
                          _buildTag('FSC', Colors.green),
                        if (logData?['quality'] != null)
                          _buildTag('Qual. ${logData!['quality']}', Colors.blue),
                      ],
                    ),
                    Text(
                      'Gesamt: ${_numberFormat.format(totalQuantity)} Stk',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatchRow(Map<String, dynamic> batch) {
    final date = batch['stock_entry_date'] != null
        ? _dateFormat.format((batch['stock_entry_date'] as dynamic).toDate())
        : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(date,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${batch['instrument_name']} ${batch['part_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${batch['wood_name']} • ${batch['quality_name']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${_numberFormat.format(batch['quantity'] ?? 0)}',
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _currencyFormat.format(batch['value'] ?? 0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChronologicalView() {
    final sortedBatches = List<Map<String, dynamic>>.from(_batches)
      ..sort((a, b) {
        final dateA = a['stock_entry_date'];
        final dateB = b['stock_entry_date'];
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return (dateB as dynamic).compareTo(dateA);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedBatches.length,
      itemBuilder: (context, index) {
        return _buildBatchCard(sortedBatches[index]);
      },
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch) {
    final date = batch['stock_entry_date'] != null
        ? _dateFormat.format((batch['stock_entry_date'] as dynamic).toDate())
        : '-';
    final hasLog = batch['roundwood_id'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(date, style: TextStyle(color: Colors.grey[600])),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${batch['instrument_name']} ${batch['part_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${batch['wood_name']} • ${batch['quality_name']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            if (hasLog)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4A29).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${batch['roundwood_internal_number']}/${batch['roundwood_year']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F4A29),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_numberFormat.format(batch['quantity'] ?? 0)} ${batch['unit'] ?? 'Stk'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _currencyFormat.format(batch['value'] ?? 0),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style:
        TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}