import 'dart:io';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/analytics/roundwood/services/roundwood_csv_service.dart';
import 'package:tonewood/analytics/roundwood/services/roundwood_pdf_service.dart';
import 'package:tonewood/analytics/roundwood/widgets/roundwood_filter_dialog.dart';
import '../../constants.dart';
import 'models/roundwood_models.dart';
import 'services/roundwood_service.dart';
import 'constants/roundwood_constants.dart';
import 'roundwood_list.dart';
import 'roundwood_analysis.dart';

class RoundwoodScreen extends StatefulWidget {
  final bool isDesktopLayout;

  const RoundwoodScreen({
    Key? key,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  RoundwoodScreenState createState() => RoundwoodScreenState();
}

class RoundwoodScreenState extends State<RoundwoodScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RoundwoodService _service = RoundwoodService();
  RoundwoodFilter _activeFilter = RoundwoodFilter();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showExportDialog() async {
    // Hole erst die Daten
    final snapshot = await _service.getRoundwoodStream(_activeFilter).first;
    final items = snapshot.docs
        .map((doc) => RoundwoodItem.fromFirestore(doc))
        .toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4A29).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.download,
                color: Color(0xFF0F4A29),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Export Format wählen'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CSV Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart, color: Colors.blue),
              ),
              title: const Text('Als CSV exportieren'),
              subtitle: const Text('Tabellarische Daten im CSV-Format'),
              onTap: () {
                Navigator.pop(context);
                _exportCsv();
              },
            ),
            const Divider(),
            // PDF Liste Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.list_alt, color: Colors.red),
              ),
              title: const Text('PDF Liste'),
              subtitle: const Text('Nur Rundholz-Liste als PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportPdf(items, includeAnalytics: false);
              },
            ),
            // PDF mit Analyse Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics, color: Colors.red),
              ),
              title: const Text('PDF mit Analyse'),
              subtitle: const Text('Liste und Auswertungen als PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportPdf(items, includeAnalytics: true);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                          Icon(Icons.format_list_bulleted, size: 20),
                          const SizedBox(width: 8),
                          Text(RoundwoodStrings.listTabTitle),
                        ],
                      ),
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.analytics, size: 20),
                          const SizedBox(width: 8),
                          Text(RoundwoodStrings.analysisTabTitle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons Container with extra padding
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                // Add top padding to ensure badge is fully visible
                margin: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    // Filter Badge
                    Badge(
                      isLabelVisible: _activeFilter.toMap().isNotEmpty,
                      label: Text(_activeFilter.toMap().length.toString()),
                      child: IconButton(
                        onPressed: _showFilterDialog,
                        icon: const Icon(Icons.filter_list),
                        tooltip: 'Filter',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Download Button
                    IconButton(
                      onPressed: _showExportDialog,
                      icon: const Icon(Icons.download),
                      tooltip: 'Exportieren',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              RoundwoodList(
                filter: _activeFilter,
                onFilterChanged: _handleFilterChange,
                service: _service,
                isDesktopLayout: widget.isDesktopLayout,
                showHeaderActions: false, // Neue Property um Header-Aktionen zu verstecken
              ),
              RoundwoodAnalysis(
                filter: _activeFilter,
                service: _service,
                isDesktopLayout: widget.isDesktopLayout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleFilterChange(RoundwoodFilter newFilter) {
    setState(() {
      _activeFilter = newFilter;
    });
  }

  void _showFilterDialog() async {
    final result = await showDialog<RoundwoodFilter>(
      context: context,
      builder: (context) => RoundwoodFilterDialog(
        initialFilter: _activeFilter,
      ),
    );

    if (result != null) {
      _handleFilterChange(result);
    }
  }

  Future<void> _exportPdf(List<RoundwoodItem> items, {required bool includeAnalytics}) async {
    try {
      final fileName = 'Rundholzliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      // Generiere PDF mit Option für Analytics
      final pdfBytes = await RoundwoodPdfService.generatePdf(
        items,
        includeAnalytics: includeAnalytics,
      );

      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      Future.delayed(const Duration(minutes: 1), () => file.delete());
      AppToast.show(message: 'PDF ${includeAnalytics ? 'mit Analyse ' : ''}erfolgreich erstellt', height: h);


    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: 'Fehler beim Export: $e', height: h);

    }
  }
// Hilfsmethoden zur Datenvorbereitung für die Analyse
  Map<String, dynamic> _prepareWoodTypeData(List<RoundwoodItem> items) {
    final woodTypeCount = <String, int>{};
    for (var item in items) {
      woodTypeCount[item.woodName] = (woodTypeCount[item.woodName] ?? 0) + 1;
    }
    return woodTypeCount;
  }

  Map<String, dynamic> _prepareQualityData(List<RoundwoodItem> items) {
    final qualityCount = <String, int>{};
    for (var item in items) {
      qualityCount[item.qualityName] = (qualityCount[item.qualityName] ?? 0) + 1;
    }
    return qualityCount;
  }

  Map<String, dynamic> _prepareVolumeData(List<RoundwoodItem> items) {
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final volumeByDate = <String, double>{};
    var runningTotal = 0.0;

    for (var item in items) {
      final dateStr = DateFormat('yyyy-MM-dd').format(item.timestamp);
      runningTotal += item.volume;
      volumeByDate[dateStr] = runningTotal;
    }

    return volumeByDate;
  }

  Future<void> _exportCsv() async {
    try {
      final snapshot = await _service.getRoundwoodStream(_activeFilter).first;
      final items = snapshot.docs
          .map((doc) => RoundwoodItem.fromFirestore(doc))
          .toList();

      final fileName = 'Rundholzliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final csvBytes = await RoundwoodCsvService.generateCsv(items);
      await file.writeAsBytes(csvBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      Future.delayed(const Duration(minutes: 1), () => file.delete());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim CSV-Export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}