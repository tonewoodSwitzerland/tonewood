import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/analytics/sales/services/sales_csv_service.dart';
import 'package:tonewood/analytics/sales/services/sales_pdf_service.dart';
import 'package:tonewood/analytics/sales/widgets/sales_filter_dialog.dart';

import 'constants/constants.dart';
import 'models/sales_filter.dart';
import 'sales_overview.dart';
import 'sales_list.dart';
import 'sales_inventory.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import '/../components/icon_content.dart';
import '/../constants.dart';
import 'package:intl/intl.dart';

class SalesScreen extends StatefulWidget {
  final bool isDesktopLayout;

  const SalesScreen({
    Key? key,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  SalesScreenState createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SalesFilter _activeFilter = SalesFilter();  // Filter-Zustand
  bool isQuickFilterActive = false;

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

  void _toggleQuickFilter() {
    setState(() {
      isQuickFilterActive = !isQuickFilterActive;

      if (isQuickFilterActive) {
        // Filter setzen mit den gleichen Werten wie im Warehouse Screen
        _activeFilter = SalesFilter(
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
        _activeFilter = SalesFilter();
      }
    });
  }
  void _showFilterDialog() async {
    final result = await showDialog<SalesFilter>(
      context: context,
      builder: (context) => SalesFilterDialog(
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
                          Icon(Icons.dashboard, size: 20),
                          const SizedBox(width: 8),
                          Text(SalesStrings.overviewTab),
                        ],
                      ),
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.point_of_sale, size: 20),
                          const SizedBox(width: 8),
                          Text(SalesStrings.salesTab),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
              // Action Buttons Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                margin: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    // Quick Filter Button
                    IconButton(
                      icon: Icon(
                        isQuickFilterActive ? Icons.star : Icons.star_outline,
                        color: isQuickFilterActive ? const Color(0xFF0F4A29) : null,
                      ),
                      onPressed: _toggleQuickFilter,
                      tooltip: isQuickFilterActive
                          ? 'Schnellfilter deaktivieren'
                          : 'Schnellfilter für Decken aktivieren',
                    ),
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
                    // Download Button - nur bei Verkäufe Tab
                    AnimatedOpacity(
                      opacity: _tabController.index == 1 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _tabController.index != 1,
                        child: IconButton(
                          onPressed: () => _showExportDialog(),
                          icon: const Icon(Icons.download),
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
              SalesOverview(filter: _activeFilter),  // Filter übergeben
              SalesList(filter: _activeFilter),
            //  SalesOverview(filter: _activeFilter),  // Filter übergeben
             // SalesList(),
           //   SalesInventory(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showExportDialog() async {
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
                child: const Icon(Icons.table_chart, color: Colors.blue),
              ),
              title: const Text('CSV'),
              subtitle: const Text('Daten im CSV-Format'),
              onTap: () async {
                Navigator.pop(context);
                await _exportListToCsv();
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
                child: const Icon(Icons.picture_as_pdf, color: Colors.red),
              ),
              title: const Text('Als PDF exportieren'),
              subtitle: const Text('Verkaufsliste als PDF'),
              onTap: () async {
                Navigator.pop(context);
                await _exportListToPdf();
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

  Future<void> _exportListToCsv() async {
    try {
      final snapshot = await _buildExportQuery().get();
      final sales = snapshot.docs.map((doc) => {
        ...doc.data(),
        'receipt_number': doc.id,
      }).toList();

      if (sales.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Daten zum Exportieren vorhanden'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final csvBytes = await SalesCsvService.generateSalesList(sales);

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName = 'Verkaufsliste_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(csvBytes);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        subject: 'Verkaufsliste Export',
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportListToPdf() async {
    try {
      final snapshot = await _buildExportQuery().get();
      final sales = snapshot.docs.map((doc) => {
        ...doc.data(),
        'receipt_number': doc.id,
      }).toList();

      if (sales.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Daten zum Exportieren vorhanden'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final pdfBytes = await SalesPdfService.generateSalesList(
        sales,
        filter: _activeFilter,
      );

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName = 'Verkaufsliste_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        subject: 'Verkaufsliste Export',
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Query<Map<String, dynamic>> _buildExportQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('sales_receipts')
        .orderBy('metadata.timestamp', descending: true);

    if (_activeFilter.startDate != null) {
      query = query.where('metadata.timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_activeFilter.startDate!));
    }
    if (_activeFilter.endDate != null) {
      final endOfDay = DateTime(
        _activeFilter.endDate!.year,
        _activeFilter.endDate!.month,
        _activeFilter.endDate!.day,
        23, 59, 59,
      );
      query = query.where('metadata.timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    if (_activeFilter.selectedCustomers != null) {
      final customerId = _activeFilter.selectedCustomers.toString().replaceAll(RegExp(r'[\[\]]'), '');
      query = query.where('customer.id', isEqualTo: customerId);
    }

    if (_activeFilter.selectedFairs != null) {
      final fairId = _activeFilter.selectedFairs.toString().replaceAll(RegExp(r'[\[\]]'), '');
      query = query.where('metadata.fairId', isEqualTo: fairId);
    }

    if (_activeFilter.selectedProducts != null) {
      final productId = _activeFilter.selectedProducts.toString().replaceAll(RegExp(r'[\[\]]'), '');
      query = query.where('items.product_id', arrayContains: productId);
    }

    return query;
  }
}