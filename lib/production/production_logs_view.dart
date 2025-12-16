import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/production/production_batch_service.dart';
import '../../services/icon_helper.dart';

/// Ansicht für Produktions-Einträge gruppiert nach Stämmen
/// Ersetzt die alte "Chargen" Ansicht
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

  List<Map<String, dynamic>> _batches = [];
  Map<String, List<Map<String, dynamic>>> _batchesByLog = {};
  Map<String, Map<String, dynamic>> _logDetails = {};

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    final years = await widget.service.getAvailableYears();
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
      final batches = await widget.service.getBatchesForYear(_selectedYear);

      // Gruppiere nach Stamm
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

      // Lade Stamm-Details
      final logDetails = <String, Map<String, dynamic>>{};
      for (final logId in byLog.keys) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('roundwood')
              .doc(logId)
              .get();
          if (doc.exists) {
            logDetails[logId] = doc.data()!;
          }
        } catch (e) {
          // Ignoriere Fehler bei einzelnen Stämmen
        }
      }

      // Füge "ohne Zuordnung" als virtuelle Gruppe hinzu
      if (withoutLog.isNotEmpty) {
        byLog['_unassigned'] = withoutLog;
      }

      setState(() {
        _batches = batches;
        _batchesByLog = byLog;
        _logDetails = logDetails;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _batches.isEmpty
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          if (isNarrow) {
            // Mobile: Vertikal stapeln
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Erste Zeile: Jahr + Statistik
                Row(
                  children: [
                    _buildYearSelector(),
                    const Spacer(),
                    _buildStatsBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                // Zweite Zeile: Ansicht-Toggle
                _buildViewToggle(),
              ],
            );
          }

          // Desktop: Horizontal
          return Row(
            children: [
              _buildYearSelector(),
              const Spacer(),
              _buildStatsBadge(),
              const SizedBox(width: 12),
              _buildViewToggle(),
            ],
          );
        },
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
        '${_batches.length} Einträge • ${_batchesByLog.length - (_batchesByLog.containsKey('_unassigned') ? 1 : 0)} Stämme',
        style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F4A29)),
      ),
    );
  }

  Widget _buildViewToggle() {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'byLog',
          icon: getAdaptiveIcon(iconName: 'forest', defaultIcon: Icons.forest, size: 18),
          label: const Text('Nach Stamm'),
        ),
        ButtonSegment(
          value: 'chronological',
          icon: getAdaptiveIcon(iconName: 'list', defaultIcon: Icons.list, size: 18),
          label: const Text('Chronologisch'),
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
            'Keine Produktionsdaten für $_selectedYear',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLogGroupedView() {
    // Sortiere: Stämme mit Daten zuerst, dann ohne Zuordnung
    final sortedKeys = _batchesByLog.keys.toList()
      ..sort((a, b) {
        if (a == '_unassigned') return 1;
        if (b == '_unassigned') return -1;
        return a.compareTo(b);
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

  Widget _buildLogCard(String logId, List<Map<String, dynamic>> batches, Map<String, dynamic>? logData) {
    final isUnassigned = logId == '_unassigned';

    // Berechne Summen
    double totalValue = 0;
    double totalQuantity = 0;
    for (final b in batches) {
      totalValue += (b['value'] as num?)?.toDouble() ?? 0;
      totalQuantity += (b['quantity'] as num?)?.toDouble() ?? 0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnassigned ? Colors.orange.withOpacity(0.3) : Colors.grey[200]!,
        ),
      ),
      child: Theme(
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
              color: isUnassigned ? Colors.orange : const Color(0xFF0F4A29),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (!isUnassigned && logData != null)
                      Text(
                        '${logData['wood_name'] ?? ''} ${logData['original_number'] != null ? '• ${logData['original_number']}' : ''}',
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
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4A29)),
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
            child: Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
    // Sortiere nach Datum absteigend
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
        final batch = sortedBatches[index];
        return _buildBatchCard(batch);
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
            // Datum
            SizedBox(
              width: 80,
              child: Text(date, style: TextStyle(color: Colors.grey[600])),
            ),

            // Produkt-Info
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

            // Stamm-Zuordnung
            if (hasLog)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

            // Menge & Wert
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
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}