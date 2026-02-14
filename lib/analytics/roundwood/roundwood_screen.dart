import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:tonewood/analytics/roundwood/services/roundwood_export_service.dart';
import 'package:tonewood/analytics/roundwood/widgets/roundwood_filter_dialog.dart';
import '../../constants.dart';
import '../../services/icon_helper.dart';
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
Map<String, String> _woodTypeNames = {};
  Map<String, String> _qualityNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
    _loadNames(); // NEU
  }
Future<void> _loadNames() async {
  final woodSnap = await FirebaseFirestore.instance.collection('wood_types').get();
  final qualSnap = await FirebaseFirestore.instance.collection('qualities').get();
  if (mounted) {
    setState(() {
      for (final doc in woodSnap.docs) {
        final data = doc.data();
        _woodTypeNames[data['code'] as String? ?? doc.id] = data['name'] as String? ?? doc.id;
      }
      for (final doc in qualSnap.docs) {
        final data = doc.data();
        _qualityNames[data['code'] as String? ?? doc.id] = data['name'] as String? ?? doc.id;
      }
    });
  }
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
              child:
              getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download,
                color: Color(0xFF0F4A29),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Export'),
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
                child: getAdaptiveIcon(iconName: 'table_chart', defaultIcon: Icons.table_chart, color: Colors.blue),
              ),
              title: const Text('CSV'),
              subtitle: const Text('Daten im CSV-Format'),
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
                child:
    getAdaptiveIcon(iconName: 'list_alt', defaultIcon: Icons.list_alt,color: Colors.red),
              ),
              title: const Text('PDF Liste'),
              subtitle: const Text('Rundholz-Liste'),
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
                child:
                getAdaptiveIcon(iconName: 'analytics', defaultIcon: Icons.analytics,color: Colors.red),

              ),
              title: const Text('PDF mit Analyse'),
              subtitle: const Text('Rundholz-Liste inkl. Auswertung'),
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

                          getAdaptiveIcon(iconName: 'format_list_bulleted', defaultIcon: Icons.format_list_bulleted,size: 20),
                          const SizedBox(width: 8),
                          Text(RoundwoodStrings.listTabTitle),
                        ],
                      ),
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          getAdaptiveIcon(iconName: 'analytics', defaultIcon: Icons.analytics,size: 20),
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
                          icon:getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list,),

                        tooltip: 'Filter',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Download Button
                    IconButton(
                      onPressed: _showExportDialog,
                      icon:   getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download,

                      ),
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
      // Filter-Info für das PDF zusammenbauen
      final activeFilters = <String, dynamic>{};

      if (_activeFilter.timeRange != null) {
        activeFilters['timeRange'] = _activeFilter.timeRange;
      }
      if (_activeFilter.startDate != null && _activeFilter.endDate != null) {
        activeFilters['startDate'] = DateFormat('dd.MM.yyyy').format(_activeFilter.startDate!);
        activeFilters['endDate'] = DateFormat('dd.MM.yyyy').format(_activeFilter.endDate!);
      }
      if (_activeFilter.year != null) {
        activeFilters['year'] = _activeFilter.year;
      }

      if (_activeFilter.woodTypes?.isNotEmpty == true) {
        activeFilters['woodTypes'] = _activeFilter.woodTypes!
            .map((code) => _woodTypeNames[code] ?? code)
            .toList();
      }
      if (_activeFilter.qualities?.isNotEmpty == true) {
        activeFilters['qualities'] = _activeFilter.qualities!
            .map((code) => _qualityNames[code] ?? code)
            .toList();
      }
      if (_activeFilter.purposes?.isNotEmpty == true) {
        activeFilters['purposes'] = _activeFilter.purposes;
      }
      if (_activeFilter.origin != null) {
        activeFilters['origin'] = _activeFilter.origin;
      }
      if (_activeFilter.isMoonwood == true) {
        activeFilters['isMoonwood'] = true;
      }
      if (_activeFilter.isFSC == true) {
        activeFilters['isFSC'] = true;
      }
      if (_activeFilter.showClosed == true) {
        activeFilters['showClosed'] = true;
      }

      await RoundwoodExportService.exportPdf(
        items,
        includeAnalytics: includeAnalytics,
        activeFilters: activeFilters.isNotEmpty ? activeFilters : null,
      );

      if (!mounted) return;
      AppToast.show(
        message: 'PDF ${includeAnalytics ? 'mit Analyse ' : ''}erfolgreich erstellt (${items.length} Einträge)',
        height: h,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: 'Fehler beim Export: $e', height: h);
    }
  }

// 4. ERSETZE die _exportCsv Methode mit:

  Future<void> _exportCsv() async {
    try {
      final snapshot = await _service.getRoundwoodStream(_activeFilter).first;
      final items = snapshot.docs
          .map((doc) => RoundwoodItem.fromFirestore(doc))
          .toList();

      await RoundwoodExportService.exportCsv(items);

      if (!mounted) return;
      AppToast.show(
        message: 'CSV Export erfolgreich (${items.length} Einträge)',
        height: h,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: 'Fehler beim CSV-Export: $e', height: h);
    }
  }
}