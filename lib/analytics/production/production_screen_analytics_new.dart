// lib/analytics/production/production_screen_analytics_new.dart
//
// Hauptscreen für Produktionsauswertung (Analytics).
// Verwendet die neue flache production_batches Collection.
// Export über den neuen ProductionExportService (Web + Mobile).

import 'package:flutter/material.dart';
import 'package:tonewood/production/production_batch_service.dart';

import '../../constants.dart';
import '../../services/icon_helper.dart';
import 'services/production_export_service.dart';
import '../../production/production_overview_new.dart';
import '../../production/production_logs_view.dart';

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
  bool _isExporting = false;

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
              // Export Button (nur bei Stämme-Tab sichtbar)
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
                        child: _isExporting
                            ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                            : IconButton(
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
              const ProductionOverviewNew(),
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

  // =============================================
  // EXPORT DIALOG & METHODEN
  // =============================================

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
              subtitle: const Text('Chargenliste mit Zusammenfassung'),
              onTap: () {
                Navigator.pop(context);
                _exportPdf();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: getAdaptiveIcon(iconName: 'analytics', defaultIcon: Icons.analytics, color: Colors.deepPurple),
              ),
              title: const Text('PDF mit Analyse'),
              subtitle: const Text('Chargenliste + Verteilungsanalyse'),
              onTap: () {
                Navigator.pop(context);
                _exportPdf(includeAnalytics: true);
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
    setState(() => _isExporting = true);
    try {
      final batches = await _service.getBatchesForYear(_selectedYear);
      await ProductionExportService.exportCsv(batches);
      if (mounted) AppToast.show(message: 'CSV Export erfolgreich', height: h);
    } catch (e) {
      if (mounted) AppToast.show(message: 'Fehler beim Export: $e', height: h);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf({bool includeAnalytics = false}) async {
    setState(() => _isExporting = true);
    try {
      final batches = await _service.getBatchesForYear(_selectedYear);
      await ProductionExportService.exportPdf(
        batches,
        includeAnalytics: includeAnalytics,
        activeFilters: {'years': [_selectedYear.toString()]},
      );
      if (mounted) AppToast.show(message: 'PDF Export erfolgreich', height: h);
    } catch (e) {
      if (mounted) AppToast.show(message: 'Fehler beim Export: $e', height: h);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}