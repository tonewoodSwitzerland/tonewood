import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/analytics/production/production_bateches.dart';
import 'package:tonewood/analytics/production/services/production_csv_service.dart';
import 'package:tonewood/analytics/production/services/production_pdf_service.dart';
import 'package:tonewood/analytics/production/services/production_service.dart';
import 'package:tonewood/analytics/production/widgets/production_filter_dialog.dart';
import '../../constants.dart';
import '../../services/icon_helper.dart';
import 'constants/production_constants.dart';
import 'models/production_filter.dart';
import 'models/production_models.dart';
import 'production_overview.dart';
import 'production_special_wood.dart';
import 'production_efficiency.dart';
import 'production_fsc.dart';

import 'package:intl/intl.dart';

class ProductionScreen extends StatefulWidget {
  final bool isDesktopLayout;

  const ProductionScreen({
    Key? key,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  ProductionScreenState createState() => ProductionScreenState();
}

class ProductionScreenState extends State<ProductionScreen> with SingleTickerProviderStateMixin {
  bool isQuickFilterActive = false;
  late TabController _tabController;
  ProductionFilter _activeFilter = ProductionFilter(); // You'll need to create this class
  final ProductionService _service = ProductionService(); // Hier wird der Service initialisiert

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

  Future<void> _exportBatchList() async {
    try {
      final batches = await _service.getFilteredBatches(_activeFilter);
      if (!mounted) return;

      final fileName = 'Chargenliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final pdfBytes = await ProductionPdfService.generateBatchList(
        batches,
        filter: _activeFilter,

         // Reduced font size for better table readability
      );

      await file.writeAsBytes(pdfBytes);
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      Future.delayed(const Duration(minutes: 1), () => file.delete());
      AppToast.show(message: ProductionStrings.exportSuccess, height: h);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: '${ProductionStrings.exportError}$e', height: h);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final snapshot = await _service.getProductionStream(_activeFilter).first;
      final items = snapshot.docs
          .map((doc) => ProductionItem.fromFirestore(doc))
          .toList();

      final fileName = 'Produktion_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final csvBytes = await ProductionCsvService.generateCsv(items);
      await file.writeAsBytes(csvBytes);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      Future.delayed(const Duration(minutes: 1), () => file.delete());
      AppToast.show(message: ProductionStrings.exportSuccess, height: h);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(message: '${ProductionStrings.exportError}$e', height: h);
    }
  }

  void _toggleQuickFilter() {
    setState(() {
      isQuickFilterActive = !isQuickFilterActive;

      if (isQuickFilterActive) {
        // Filter setzen mit den gleichen Werten wie im Warehouse Screen
        _activeFilter = ProductionFilter(
          instruments: [
            '10',  // Steelstring Gitarre
            '11',  // Klassische Gitarre
            '12',  // Parlor Gitarre
            '16', // Bouzuki/Mandoline flach
            '20', // Violine
            '22', // Cello
          ],
          parts: ['10'], // Decke
        );
      } else {
        // Filter zurücksetzen
        _activeFilter = ProductionFilter();
      }
    });
  }

  Future<void> _showExportDialog() async {
    // Hole erst die Daten
    final snapshot = await _service.getProductionStream(_activeFilter).first;
    final items = snapshot.docs
        .map((doc) => ProductionItem.fromFirestore(doc))
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
            // PDF Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:  getAdaptiveIcon(iconName: 'picture_as_pdf', defaultIcon: Icons.picture_as_pdf, color: Colors.red),
              ),
              title: const Text('Als PDF exportieren'),
              subtitle: const Text('Chargenliste als PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportBatchList();
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

  // Future<void> _exportPdf(List<ProductionItem> items, {required bool includeAnalytics}) async {
  //   try {
  //     final fileName = 'Produktion_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf';
  //     final tempDir = await getTemporaryDirectory();
  //     final file = File('${tempDir.path}/$fileName');
  //
  //     final pdfBytes = await ProductionPdfService.generatePdf(
  //       items,
  //       includeAnalytics: includeAnalytics,
  //     );
  //
  //     await file.writeAsBytes(pdfBytes);
  //
  //     if (!mounted) return;
  //
  //     await Share.shareXFiles(
  //       [XFile(file.path)],
  //       subject: fileName,
  //     );
  //
  //     Future.delayed(const Duration(minutes: 1), () => file.delete());
  //     AppToast.show(message: ProductionStrings.exportSuccess, height: h);
  //
  //   } catch (e) {
  //     if (!mounted) return;
  //     AppToast.show(message: '${ProductionStrings.exportError}$e', height: h);
  //   }
  // }

  void _handleFilterChange(ProductionFilter newFilter) {
    setState(() {
      _activeFilter = newFilter;
    });
  }

  void _showFilterDialog() async {
    final result = await showDialog<ProductionFilter>(
      context: context,
      builder: (context) => ProductionFilterDialog(
        initialFilter: _activeFilter,
      ),
    );

    if (result != null) {
      setState(() {
        _activeFilter = result;
      });
    }
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
                           getAdaptiveIcon(iconName: 'dashboard',defaultIcon:Icons.dashboard, size: 20),
                          const SizedBox(width: 8),
                          Text(ProductionStrings.overviewTab),
                        ],
                      ),
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           getAdaptiveIcon(iconName: 'list',defaultIcon:Icons.list_alt, size: 20),
                          const SizedBox(width: 8),
                          Text('Chargen'),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
              // Action Buttons Container with extra padding
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                margin: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                      isQuickFilterActive ?
                      getAdaptiveIcon(iconName: 'star_fill', defaultIcon: Icons.star,)
                          :
                      getAdaptiveIcon(iconName: 'star',defaultIcon:Icons.star_outline,
                      ),
                      onPressed: _toggleQuickFilter,
                      tooltip: isQuickFilterActive
                          ? 'Schnellfilter deaktivieren'
                          : 'Schnellfilter aktivieren',
                    ),
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
                    // Download Button - nur bei Chargen Tab
                    AnimatedOpacity(
                      opacity: _tabController.index == 1 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _tabController.index != 1,
                        child: IconButton(
                          onPressed: () => _showExportDialog(),
                          icon: getAdaptiveIcon(iconName: 'download',defaultIcon:Icons.download),
                          tooltip: 'Exportieren',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ProductionOverview(
                service: _service,
                filter: _activeFilter,
              ),
              ProductionBatches(
                service: _service,
                filter: _activeFilter,
              ),
           //   const  ProductionEfficiency(),
            //  const ProductionEfficiency(),
            //  const  ProductionEfficiency(),
            ],
          ),
        ),
      ],
    );
  }
}