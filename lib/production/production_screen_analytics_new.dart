import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/production/production_batch_service.dart';

import '../../constants.dart';
import '../../services/icon_helper.dart';

import 'production_overview_new.dart';
import 'production_logs_view.dart';  // Neue Datei für Stämme-Ansicht

/// Hauptscreen für Produktionsauswertung (Analytics)
/// Verwendet die neue flache production_batches Collection
class ProductionAnalyticsScreen extends StatefulWidget {
  final bool isDesktopLayout;

  const ProductionAnalyticsScreen({
    Key? key,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  State<ProductionAnalyticsScreen> createState() => _ProductionAnalyticsScreenState();
}

class _ProductionAnalyticsScreenState extends State<ProductionAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductionBatchService _service = ProductionBatchService();
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar Header
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.surfaceVariant,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Tab Bar
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          getAdaptiveIcon(iconName: 'dashboard', defaultIcon: Icons.dashboard, size: 20),
                          const SizedBox(width: 8),
                          const Text('Übersicht'),
                        ],
                      ),
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          getAdaptiveIcon(iconName: 'forest', defaultIcon: Icons.forest, size: 20),
                          const SizedBox(width: 8),
                          const Text('Stämme'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Export Button (nur bei Stämme-Tab)
              ListenableBuilder(
                listenable: _tabController,
                builder: (context, child) {
                  return AnimatedOpacity(
                    opacity: _tabController.index == 1 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: _tabController.index != 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: IconButton(
                          onPressed: _showExportDialog,
                          icon: getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download),
                          tooltip: 'Exportieren',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Übersicht Tab
              const ProductionOverviewNew(),

              // Stämme Tab
              ProductionLogsView(
                service: _service,
                onYearChanged: (year) {
                  setState(() => _selectedYear = year);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showExportDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4A29).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: getAdaptiveIcon(
                iconName: 'download',
                defaultIcon: Icons.download,
                color: const Color(0xFF0F4A29),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Export'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: getAdaptiveIcon(iconName: 'table_chart', defaultIcon: Icons.table_chart, color: Colors.blue),
              ),
              title: const Text('CSV'),
              subtitle: const Text('Alle Produktionsdaten als CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportCsv();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: getAdaptiveIcon(iconName: 'picture_as_pdf', defaultIcon: Icons.picture_as_pdf, color: Colors.red),
              ),
              title: const Text('PDF Report'),
              subtitle: const Text('Produktionsbericht als PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportPdf();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    try {
      final batches = await _service.getBatchesForYear(_selectedYear);

      // CSV Header
      final lines = <String>[
        'Datum;Produkt;Instrument;Bauteil;Holzart;Qualität;Menge;Einheit;Wert CHF;Stamm-Nr;Stamm-Jahr',
      ];

      // CSV Daten
      for (final batch in batches) {
        final date = batch['stock_entry_date'] != null
            ? DateFormat('dd.MM.yyyy').format((batch['stock_entry_date'] as dynamic).toDate())
            : '';

        lines.add([
          date,
          '${batch['instrument_name']} ${batch['part_name']}',
          batch['instrument_name'] ?? '',
          batch['part_name'] ?? '',
          batch['wood_name'] ?? '',
          batch['quality_name'] ?? '',
          batch['quantity']?.toString() ?? '0',
          batch['unit'] ?? 'Stk',
          batch['value']?.toString() ?? '0',
          batch['roundwood_internal_number'] ?? '',
          batch['roundwood_year']?.toString() ?? '',
        ].join(';'));
      }

      final csv = lines.join('\n');
      final fileName = 'Produktion_${_selectedYear}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], subject: fileName);

      Future.delayed(const Duration(minutes: 1), () => file.delete());

      if (mounted) {
        AppToast.show(message: 'Export erfolgreich', height: h);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(message: 'Fehler beim Export: $e', height: h);
      }
    }
  }

  Future<void> _exportPdf() async {
    // TODO: PDF Export implementieren
    AppToast.show(message: 'PDF Export wird implementiert...', height: h);
  }
}

// ============================================================
// AnimatedBuilder Helper (falls nicht vorhanden)
// ============================================================
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    Key? key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(key: key, listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}