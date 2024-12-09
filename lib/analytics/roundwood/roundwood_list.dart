import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tonewood/analytics/roundwood/services/roundwood_csv_service.dart';
import 'package:tonewood/analytics/roundwood/services/roundwood_export_service.dart';
import 'package:tonewood/analytics/roundwood/services/roundwood_pdf_service.dart';
import '../../constants.dart';
import 'models/roundwood_models.dart';
import 'services/roundwood_service.dart';
import 'widgets/roundwood_filter_dialog.dart';
import 'widgets/roundwood_list_item.dart';
import 'widgets/roundwood_edit_dialog.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';



class RoundwoodList extends StatefulWidget {
  final RoundwoodFilter filter;
  final Function(RoundwoodFilter) onFilterChanged;
  final RoundwoodService service;
  final bool isDesktopLayout;
  final bool showHeaderActions;

  const RoundwoodList({
    Key? key,
    required this.showHeaderActions,
    required this.filter,
    required this.onFilterChanged,
    required this.service,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  RoundwoodListState createState() => RoundwoodListState();
}

class RoundwoodListState extends State<RoundwoodList> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
    //    _buildFilterHeader(),
        SizedBox(height: h*0.01,),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.service.getRoundwoodStream(widget.filter),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final roundwoods = snapshot.data!.docs;

              if (roundwoods.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Einträge gefunden',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (widget.filter.toMap().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => widget.onFilterChanged(RoundwoodFilter()),
                          icon: const Icon(Icons.filter_list_off),
                          label: const Text('Filter zurücksetzen'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: roundwoods.length,
                itemBuilder: (context, index) {
                  final item = RoundwoodItem.fromFirestore(roundwoods[index]);
                  return RoundwoodListItem(
                    item: item,
                    onTap: () => _showEditDialog(item),
                    isDesktopLayout: widget.isDesktopLayout,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Badge(
            isLabelVisible: widget.filter.toMap().isNotEmpty,
            label: Text(widget.filter.toMap().length.toString()),
            child: IconButton(
              onPressed: _showFilterDialog,
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter',
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: widget.service.getRoundwoodStream(widget.filter),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${snapshot.data!.docs.length} Einträge',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          IconButton(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Als PDF exportieren',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _exportCsv,
            icon: const Icon(Icons.table_chart),
            tooltip: 'Als CSV exportieren',
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() async {
    final result = await showDialog<RoundwoodFilter>(
      context: context,
      builder: (context) => RoundwoodFilterDialog(
        initialFilter: widget.filter,
      ),
    );

    if (result != null) {
      widget.onFilterChanged(result);
    }
  }

  void _showEditDialog(RoundwoodItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RoundwoodEditDialog(
        item: item,
        isDesktopLayout: widget.isDesktopLayout,
      ),
    );

    if (result != null) {
      await widget.service.updateRoundwood(item.id, result);
    }
  }

  Future<void> _exportPdf() async {
    try {
      final snapshot = await widget.service.getRoundwoodStream(widget.filter).first;
      final items = snapshot.docs
          .map((doc) => RoundwoodItem.fromFirestore(doc))
          .toList();

      final fileName = 'Rundholzliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      // Generiere PDF
      final pdfBytes = await RoundwoodPdfService.generatePdf(items);
      await file.writeAsBytes(pdfBytes);

      // Teile Datei
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      // Optional: Lösche temporäre Datei nach kurzer Verzögerung
      Future.delayed(const Duration(minutes: 1), () => file.delete());

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final snapshot = await widget.service.getRoundwoodStream(widget.filter).first;
      final items = snapshot.docs
          .map((doc) => RoundwoodItem.fromFirestore(doc))
          .toList();

      final fileName = 'Rundholzliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      // Generiere CSV
      final csvBytes = await RoundwoodCsvService.generateCsv(items);
      await file.writeAsBytes(csvBytes);

      // Teile Datei
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      // Optional: Lösche temporäre Datei nach kurzer Verzögerung
      Future.delayed(const Duration(minutes: 1), () => file.delete());

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } }