// lib/analytics/sales/sales_screen.dart

import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/analytics/sales/screens/sales_country_view.dart';
import 'package:tonewood/analytics/sales/screens/sales_kpi_view.dart';
import 'package:tonewood/analytics/sales/screens/sales_product_view.dart';
import 'package:tonewood/analytics/sales/widgets/sales_info_dialog.dart';
import 'package:tonewood/analytics/sales/widgets/sales_filter_dialog.dart';

import '../../../services/icon_helper.dart';
import '../../../services/countries.dart';
import '../../services/download_helper_web.dart';

import 'models/sales_filter.dart';
import 'models/sales_analytics_models.dart';
import 'services/sales_analytics_service.dart';
import 'services/sales_csv_service.dart';
import 'services/sales_pdf_service.dart';

class SalesScreenAnalytics extends StatefulWidget {
  final bool isDesktopLayout;

  const SalesScreenAnalytics({
    Key? key,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  State<SalesScreenAnalytics> createState() => _SalesScreenAnalyticsState();
}

class _SalesScreenAnalyticsState extends State<SalesScreenAnalytics> {
  String _selectedView = 'kpi';
  SalesFilter _currentFilter = SalesFilter();

  bool get _hasActiveFilters =>
      (_currentFilter.timeRange != null) ||
          (_currentFilter.startDate != null) ||
          (_currentFilter.minAmount != null) ||
          (_currentFilter.maxAmount != null) ||
          (_currentFilter.selectedFairs?.isNotEmpty ?? false) ||
          (_currentFilter.selectedProducts?.isNotEmpty ?? false) ||
          (_currentFilter.woodTypes?.isNotEmpty ?? false) ||
          (_currentFilter.parts?.isNotEmpty ?? false) ||
          (_currentFilter.instruments?.isNotEmpty ?? false) ||
          (_currentFilter.qualities?.isNotEmpty ?? false) ||
          (_currentFilter.selectedCustomers?.isNotEmpty ?? false) ||
          (_currentFilter.costCenters?.isNotEmpty ?? false) ||
          (_currentFilter.distributionChannels?.isNotEmpty ?? false) ||
          (_currentFilter.countries?.isNotEmpty ?? false);

  int _countActiveFilters() {
    int count = 0;
    if (_currentFilter.timeRange != null || _currentFilter.startDate != null) count++;
    if (_currentFilter.minAmount != null || _currentFilter.maxAmount != null) count++;
    if (_currentFilter.selectedFairs?.isNotEmpty ?? false) count++;
    if (_currentFilter.selectedProducts?.isNotEmpty ?? false) count++;
    if (_currentFilter.woodTypes?.isNotEmpty ?? false) count++;
    if (_currentFilter.parts?.isNotEmpty ?? false) count++;
    if (_currentFilter.instruments?.isNotEmpty ?? false) count++;
    if (_currentFilter.qualities?.isNotEmpty ?? false) count++;
    if (_currentFilter.selectedCustomers?.isNotEmpty ?? false) count++;
    if (_currentFilter.costCenters?.isNotEmpty ?? false) count++;
    if (_currentFilter.distributionChannels?.isNotEmpty ?? false) count++;
    if (_currentFilter.countries?.isNotEmpty ?? false) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildNavButton(id: 'kpi', icon: Icons.dashboard, iconName: 'dashboard', label: 'Übersicht', tooltip: 'KPI-Übersicht'),
                      _buildNavButton(id: 'country', icon: Icons.public, iconName: 'public', label: 'Länder', tooltip: 'Länder-Analyse'),
                      _buildNavButton(id: 'product', icon: Icons.category, iconName: 'category', label: 'Produkte', tooltip: 'Produkt-Analyse'),
                    ],
                  ),
                ),
              ),
              _buildExportButton(theme),
              const SizedBox(width: 4),
              _buildFilterButton(theme),
              const SizedBox(width: 4),
              _buildInfoButton(theme),
            ],
          ),
        ),

        if (_hasActiveFilters) _buildActiveFilterBar(theme),

        Expanded(child: _buildSelectedView()),
      ],
    );
  }

  // ============================================================
  // NAV BUTTONS
  // ============================================================

  Widget _buildNavButton({
    required String id, required IconData icon, required String iconName,
    required String label, required String tooltip,
  }) {
    final isSelected = _selectedView == id;
    final theme = Theme.of(context);
    final isCompact = MediaQuery.of(context).size.width < 500;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => setState(() => _selectedView = id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: isCompact ? 18 : 20,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: isCompact ? 12 : 14,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXPORT
  // ============================================================

  Widget _buildExportButton(ThemeData theme) {
    return Tooltip(
      message: 'Daten exportieren',
      child: InkWell(
        onTap: _showExportDialog,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: getAdaptiveIcon(iconName: 'file_download', defaultIcon: Icons.file_download,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Future<void> _showExportDialog() async {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4A29).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: getAdaptiveIcon(iconName: 'file_download', defaultIcon: Icons.file_download, color: const Color(0xFF0F4A29)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daten exportieren', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          _hasActiveFilters
                              ? '${_countActiveFilters()} Filter aktiv – Export berücksichtigt Filter'
                              : 'Alle Daten werden exportiert',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildExportOption(icon: Icons.picture_as_pdf, iconName: 'picture_as_pdf',
                  title: 'Analyse-Bericht (PDF)', subtitle: 'KPIs, Länder & Produkte – 3 Seiten',
                  color: Colors.red, onTap: () { Navigator.pop(ctx); _performExport('analytics_pdf'); }),
              const SizedBox(height: 10),

              _buildExportOption(icon: Icons.table_chart, iconName: 'table_chart',
                  title: 'Analyse-Zusammenfassung (CSV)', subtitle: 'KPIs, Länder & Holzarten für Excel',
                  color: Colors.green, onTap: () { Navigator.pop(ctx); _performExport('analytics_csv'); }),
              const SizedBox(height: 10),

              _buildExportOption(icon: Icons.list_alt, iconName: 'list_alt',
                  title: 'Auftragsliste (PDF)', subtitle: 'Alle Aufträge einzeln aufgelistet',
                  color: Colors.deepOrange, onTap: () { Navigator.pop(ctx); _performExport('detail_pdf'); }),
              const SizedBox(height: 10),

              _buildExportOption(icon: Icons.grid_on, iconName: 'grid_on',
                  title: 'Artikelliste (CSV)', subtitle: 'Jeder Artikel einzeln – für Buchhaltung',
                  color: Colors.teal, onTap: () { Navigator.pop(ctx); _performExport('detail_csv'); }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon, required String iconName, required String title,
    required String subtitle, required Color color, required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            getAdaptiveIcon(iconName: 'chevron_right', defaultIcon: Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _performExport(String format) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Export wird erstellt...'),
        ]),
        duration: Duration(seconds: 15),
      ),
    );

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      Uint8List bytes;
      String filename;

      if (format == 'analytics_pdf') {
        final analytics = await SalesAnalyticsService().getAnalyticsStream(_currentFilter).first;
        bytes = await SalesPdfService.generateAnalyticsReport(analytics, filter: _currentFilter);
        filename = 'Verkaufsanalyse_$dateStr.pdf';

      } else if (format == 'analytics_csv') {
        final analytics = await SalesAnalyticsService().getAnalyticsStream(_currentFilter).first;
        bytes = Uint8List.fromList(SalesCsvService.generateAnalyticsSummary(analytics));
        filename = 'Verkaufsanalyse_$dateStr.csv';

      } else if (format == 'detail_pdf') {
        final sales = await _loadFilteredOrders();
        bytes = await SalesPdfService.generateSalesDetailList(sales, filter: _currentFilter);
        filename = 'Auftragsliste_$dateStr.pdf';

      } else if (format == 'detail_csv') {
        final sales = await _loadFilteredOrders();
        bytes = Uint8List.fromList(await SalesCsvService.generateSalesDetailList(sales));
        filename = 'Artikelliste_$dateStr.csv';

      } else {
        throw Exception('Unbekanntes Format');
      }

      await _downloadOrShare(bytes, filename);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          getAdaptiveIcon(iconName: 'check_circle', defaultIcon: Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('$filename exportiert'),
        ]),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
    }
  }

  Future<List<Map<String, dynamic>>> _loadFilteredOrders() async {
    Query query = FirebaseFirestore.instance.collection('orders');

    if (_currentFilter.selectedCustomers?.isNotEmpty ?? false) {
      query = query.where('customer.id', whereIn: _currentFilter.selectedCustomers);
    } else if (_currentFilter.selectedFairs?.isNotEmpty ?? false) {
      query = query.where('fair.id', whereIn: _currentFilter.selectedFairs);
    }

    final snapshot = await query.get();
    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    // Zeitraum berechnen
    DateTime? filterStart = _currentFilter.startDate;
    DateTime? filterEnd = _currentFilter.endDate;
    if (_currentFilter.timeRange != null) {
      switch (_currentFilter.timeRange) {
        case 'week':
          filterStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
          filterEnd = now;
          break;
        case 'month':
          filterStart = DateTime(now.year, now.month, 1);
          filterEnd = now;
          break;
        case 'quarter':
          filterStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
          filterEnd = now;
          break;
        case 'year':
          filterStart = DateTime(now.year, 1, 1);
          filterEnd = now;
          break;
      }
    }

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'cancelled') continue;

      DateTime? orderDate;
      final od = data['orderDate'];
      if (od is Timestamp) orderDate = od.toDate();
      if (orderDate == null) continue;

      if (filterStart != null && orderDate.isBefore(filterStart)) continue;
      if (filterEnd != null && orderDate.isAfter(DateTime(filterEnd.year, filterEnd.month, filterEnd.day, 23, 59, 59))) continue;

      // Kostenstelle
      if (_currentFilter.costCenters?.isNotEmpty ?? false) {
        final cc = data['costCenter'] as Map<String, dynamic>?;
        if (cc == null || !_currentFilter.costCenters!.contains(cc['code']?.toString())) continue;
      }

      // Bestellart
      if (_currentFilter.distributionChannels?.isNotEmpty ?? false) {
        final meta = data['metadata'] as Map<String, dynamic>? ?? {};
        final dc = meta['distributionChannel'] as Map<String, dynamic>?;
        if (dc == null || !_currentFilter.distributionChannels!.contains(dc['name']?.toString())) continue;
      }

      result.add(data);
    }

    return result;
  }

  Future<void> _downloadOrShare(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      await DownloadHelper.downloadFile(bytes, filename);
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: filename);
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  Widget _buildFilterButton(ThemeData theme) {
    final count = _countActiveFilters();
    final active = count > 0;

    return Tooltip(
      message: 'Filter',
      child: InkWell(
        onTap: _openFilterDialog,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0F4A29).withOpacity(0.15) : theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list, size: 20,
                  color: active ? const Color(0xFF0F4A29) : theme.colorScheme.onSurfaceVariant),
              if (active)
                Positioned(right: -6, top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFF0F4A29), shape: BoxShape.circle),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilterDialog() async {
    final result = await showDialog<SalesFilter>(
      context: context,
      builder: (context) => SalesFilterDialog(initialFilter: _currentFilter),
    );
    if (result != null) setState(() => _currentFilter = result);
  }

  Widget _buildActiveFilterBar(ThemeData theme) {
    const brandColor = Color(0xFF0F4A29);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: brandColor.withOpacity(0.06),
        border: Border(bottom: BorderSide(color: brandColor.withOpacity(0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header-Zeile: Anzahl + Zurücksetzen
          Row(
            children: [
              getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list, size: 16, color: brandColor),
              const SizedBox(width: 6),
              Text('${_countActiveFilters()} Filter aktiv',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brandColor)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _currentFilter = SalesFilter()),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close, size: 14, color: brandColor),
                    const SizedBox(width: 4),
                    const Text('Alle zurücksetzen', style: TextStyle(fontSize: 11, color: brandColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _buildFilterChipsList(theme),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChipsList(ThemeData theme) {
    final chips = <Widget>[];
    final dateFormat = DateFormat('dd.MM.yyyy');

    // Zeitraum
    if (_currentFilter.timeRange != null) {
      String label;
      switch (_currentFilter.timeRange) {
        case 'week': label = 'Diese Woche'; break;
        case 'month': label = 'Dieser Monat'; break;
        case 'quarter': label = 'Dieses Quartal'; break;
        case 'year': label = 'Dieses Jahr'; break;
        default: label = _currentFilter.timeRange!;
      }
      chips.add(_buildFilterChip(
        icon: Icons.calendar_today,
        label: label,
        onRemove: () => setState(() => _currentFilter = _currentFilter.copyWith(timeRange: null)),
      ));
    } else if (_currentFilter.startDate != null || _currentFilter.endDate != null) {
      final start = _currentFilter.startDate != null ? dateFormat.format(_currentFilter.startDate!) : '...';
      final end = _currentFilter.endDate != null ? dateFormat.format(_currentFilter.endDate!) : '...';
      chips.add(_buildFilterChip(
        icon: Icons.date_range,
        label: '$start – $end',
        onRemove: () => setState(() => _currentFilter = SalesFilter(
          minAmount: _currentFilter.minAmount, maxAmount: _currentFilter.maxAmount,
          selectedFairs: _currentFilter.selectedFairs, selectedProducts: _currentFilter.selectedProducts,
          woodTypes: _currentFilter.woodTypes, parts: _currentFilter.parts,
          instruments: _currentFilter.instruments, qualities: _currentFilter.qualities,
          selectedCustomers: _currentFilter.selectedCustomers, costCenters: _currentFilter.costCenters,
          distributionChannels: _currentFilter.distributionChannels, countries: _currentFilter.countries,
        )),
      ));
    }

    // Betrag
    if (_currentFilter.minAmount != null || _currentFilter.maxAmount != null) {
      String label;
      if (_currentFilter.minAmount != null && _currentFilter.maxAmount != null) {
        label = 'CHF ${_currentFilter.minAmount!.toStringAsFixed(0)} – ${_currentFilter.maxAmount!.toStringAsFixed(0)}';
      } else if (_currentFilter.minAmount != null) {
        label = 'ab CHF ${_currentFilter.minAmount!.toStringAsFixed(0)}';
      } else {
        label = 'bis CHF ${_currentFilter.maxAmount!.toStringAsFixed(0)}';
      }
      chips.add(_buildFilterChip(
        icon: Icons.savings,
        label: label,
        onRemove: () => setState(() => _currentFilter = _currentFilter.copyWith(
          minAmount: null, maxAmount: null,
        )),
      ));
    }

    // Länder
    if (_currentFilter.countries?.isNotEmpty ?? false) {
      for (final code in _currentFilter.countries!) {
        final name = Countries.getCountryByCode(code).name;
        chips.add(_buildFilterChip(
          icon: Icons.public,
          label: name,
          onRemove: () => setState(() {
            final updated = _currentFilter.countries!.where((c) => c != code).toList();
            _currentFilter = _currentFilter.copyWith(countries: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Holzarten
    if (_currentFilter.woodTypes?.isNotEmpty ?? false) {
      for (final code in _currentFilter.woodTypes!) {
        chips.add(_buildFirestoreChip(
          collection: 'wood_types',
          docId: code,
          fallbackLabel: code,
          icon: Icons.forest,
          onRemove: () => setState(() {
            final updated = _currentFilter.woodTypes!.where((w) => w != code).toList();
            _currentFilter = _currentFilter.copyWith(woodTypes: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Qualitäten
    if (_currentFilter.qualities?.isNotEmpty ?? false) {
      for (final code in _currentFilter.qualities!) {
        chips.add(_buildFirestoreChip(
          collection: 'qualities',
          docId: code,
          fallbackLabel: code,
          icon: Icons.star,
          onRemove: () => setState(() {
            final updated = _currentFilter.qualities!.where((q) => q != code).toList();
            _currentFilter = _currentFilter.copyWith(qualities: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Instrumente
    if (_currentFilter.instruments?.isNotEmpty ?? false) {
      for (final code in _currentFilter.instruments!) {
        chips.add(_buildFirestoreChip(
          collection: 'instruments',
          docId: code,
          fallbackLabel: code,
          icon: Icons.music_note,
          onRemove: () => setState(() {
            final updated = _currentFilter.instruments!.where((i) => i != code).toList();
            _currentFilter = _currentFilter.copyWith(instruments: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Bauteile
    if (_currentFilter.parts?.isNotEmpty ?? false) {
      for (final code in _currentFilter.parts!) {
        chips.add(_buildFirestoreChip(
          collection: 'parts',
          docId: code,
          fallbackLabel: code,
          icon: Icons.category,
          onRemove: () => setState(() {
            final updated = _currentFilter.parts!.where((p) => p != code).toList();
            _currentFilter = _currentFilter.copyWith(parts: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Kostenstellen
    if (_currentFilter.costCenters?.isNotEmpty ?? false) {
      for (final id in _currentFilter.costCenters!) {
        chips.add(_buildFirestoreChip(
          collection: 'cost_centers',
          docId: id,
          nameField: 'code',
          fallbackLabel: id,
          icon: Icons.account_balance_wallet,
          onRemove: () => setState(() {
            final updated = _currentFilter.costCenters!.where((c) => c != id).toList();
            _currentFilter = _currentFilter.copyWith(costCenters: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Bestellarten
    if (_currentFilter.distributionChannels?.isNotEmpty ?? false) {
      for (final id in _currentFilter.distributionChannels!) {
        chips.add(_buildFirestoreChip(
          collection: 'distribution_channel',
          docId: id,
          fallbackLabel: id,
          icon: Icons.storefront,
          onRemove: () => setState(() {
            final updated = _currentFilter.distributionChannels!.where((d) => d != id).toList();
            _currentFilter = _currentFilter.copyWith(distributionChannels: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Kunden
    if (_currentFilter.selectedCustomers?.isNotEmpty ?? false) {
      for (final id in _currentFilter.selectedCustomers!) {
        chips.add(_buildFirestoreChip(
          collection: 'customers',
          docId: id,
          nameField: 'company',
          fallbackLabel: 'Kunde',
          icon: Icons.person,
          onRemove: () => setState(() {
            final updated = _currentFilter.selectedCustomers!.where((c) => c != id).toList();
            _currentFilter = _currentFilter.copyWith(selectedCustomers: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Messen
    if (_currentFilter.selectedFairs?.isNotEmpty ?? false) {
      for (final id in _currentFilter.selectedFairs!) {
        chips.add(_buildFirestoreChip(
          collection: 'fairs',
          docId: id,
          fallbackLabel: 'Messe',
          icon: Icons.event,
          onRemove: () => setState(() {
            final updated = _currentFilter.selectedFairs!.where((f) => f != id).toList();
            _currentFilter = _currentFilter.copyWith(selectedFairs: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    // Artikel
    if (_currentFilter.selectedProducts?.isNotEmpty ?? false) {
      for (final id in _currentFilter.selectedProducts!) {
        chips.add(_buildFirestoreChip(
          collection: 'inventory',
          docId: id,
          nameField: 'product_name',
          fallbackLabel: 'Artikel',
          icon: Icons.inventory,
          onRemove: () => setState(() {
            final updated = _currentFilter.selectedProducts!.where((p) => p != id).toList();
            _currentFilter = _currentFilter.copyWith(selectedProducts: updated.isEmpty ? null : updated);
          }),
        ));
      }
    }

    return chips;
  }

  /// Einzelner Filter-Chip mit Icon, Label und X-Button
  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
  }) {
    const brandColor = Color(0xFF0F4A29);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: brandColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandColor.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: brandColor),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: brandColor)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 13, color: brandColor.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip der den Namen aus Firestore lädt (für IDs wie Kunden, Messen, etc.)
  Widget _buildFirestoreChip({
    required String collection,
    required String docId,
    required String fallbackLabel,
    required IconData icon,
    required VoidCallback onRemove,
    String nameField = 'name',
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).doc(docId).snapshots(),
      builder: (context, snapshot) {
        String label = fallbackLabel;
        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          label = data[nameField]?.toString() ?? data['name']?.toString() ?? fallbackLabel;
        }
        return _buildFilterChip(icon: icon, label: label, onRemove: onRemove);
      },
    );
  }

  // ============================================================
  // INFO
  // ============================================================

  Widget _buildInfoButton(ThemeData theme) {
    return Tooltip(
      message: 'Hilfe & Informationen',
      child: InkWell(
        onTap: () => SalesInfoDialog.show(context, isDesktop: widget.isDesktopLayout),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info, size: 20, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  // ============================================================
  // VIEWS
  // ============================================================

  Widget _buildSelectedView() {
    switch (_selectedView) {
      case 'country': return SalesCountryView(filter: _currentFilter);
      case 'product': return SalesProductView(filter: _currentFilter);
      case 'kpi':
      default: return SalesKpiView(filter: _currentFilter);
    }
  }
}