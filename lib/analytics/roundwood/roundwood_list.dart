import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tonewood/analytics/roundwood/services/roundwood_csv_service.dart';
import 'package:tonewood/analytics/roundwood/services/roundwood_export_service.dart';
import 'package:tonewood/analytics/roundwood/services/roundwood_pdf_service.dart';
import '../../constants.dart';
import '../../services/icon_helper.dart';
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
  final Function(String id, Map<String, dynamic> data)? onItemSelected;

  const RoundwoodList({
    Key? key,
    required this.showHeaderActions,
    required this.filter,
    required this.onFilterChanged,
    required this.service,
    required this.isDesktopLayout,
    this.onItemSelected,
  }) : super(key: key);

  @override
  RoundwoodListState createState() => RoundwoodListState();
}

class RoundwoodListState extends State<RoundwoodList> {
  bool _roundwoodSortAscending = false;

  /// Client-seitiger Filter für is_closed
  /// Firestore kann nicht auf "Feld existiert nicht ODER ist false" filtern
  List<QueryDocumentSnapshot> _applyClosedFilter(List<QueryDocumentSnapshot> docs) {
    // Wenn showClosed == null -> alle anzeigen (kein Filter)
    if (widget.filter.showClosed == null) {
      return docs;
    }

    // Wenn showClosed == true -> nur geschlossene (wird bereits in Firestore gefiltert)
    if (widget.filter.showClosed == true) {
      return docs;
    }

    // Wenn showClosed == false -> nur offene (is_closed != true)
    // Das schließt Dokumente ein, wo is_closed fehlt, null ist, oder false ist
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isClosed = data['is_closed'];
      // Zeige nur wenn NICHT geschlossen (null, fehlt, oder false)
      return isClosed != true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: h * 0.01),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.service.getRoundwoodStream(widget.filter),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // ═══════════════════════════════════════════════════════════
              // WICHTIG: Client-seitiger Filter für is_closed anwenden
              // ═══════════════════════════════════════════════════════════
              final allDocs = snapshot.data!.docs;
              final roundwoods = _applyClosedFilter(allDocs);

              if (roundwoods.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'search',
                        defaultIcon: Icons.search,
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
                      // Zeige Hinweis wenn Filter aktiv
                      if (widget.filter.showClosed == false) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Abgeschlossene Stämme sind ausgeblendet',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (widget.filter.toMap().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => widget.onFilterChanged(RoundwoodFilter()),
                          icon: getAdaptiveIcon(
                            iconName: 'filter_list',
                            defaultIcon: Icons.filter_list,
                          ),
                          label: const Text('Filter zurücksetzen'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              final sortedDocs = roundwoods.toList()
                ..sort((a, b) {
                  final am = a.data() as Map<String, dynamic>;
                  final bm = b.data() as Map<String, dynamic>;

                  final aiRaw = am['internal_number'];
                  final biRaw = bm['internal_number'];
                  final ai = aiRaw is num
                      ? aiRaw.toInt()
                      : int.tryParse(aiRaw?.toString() ?? '') ?? 0;
                  final bi = biRaw is num
                      ? biRaw.toInt()
                      : int.tryParse(biRaw?.toString() ?? '') ?? 0;

                  return _roundwoodSortAscending ? ai.compareTo(bi) : bi.compareTo(ai);
                });

              return Column(
                children: [
                  // Toolbar oberhalb der Liste
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '${sortedDocs.length} Stämme',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        // Zeige Info wenn gefiltert
                        if (widget.filter.showClosed == false && allDocs.length != sortedDocs.length) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Text(
                              '${allDocs.length - sortedDocs.length} ausgeblendet',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          tooltip: _roundwoodSortAscending
                              ? 'Stammnummer aufsteigend'
                              : 'Stammnummer absteigend',
                          icon: _roundwoodSortAscending
                              ? getAdaptiveIcon(
                            iconName: 'arrow_upward',
                            defaultIcon: Icons.arrow_upward,
                          )
                              : getAdaptiveIcon(
                            iconName: 'arrow_downward',
                            defaultIcon: Icons.arrow_downward,
                          ),
                          onPressed: () {
                            setState(() {
                              _roundwoodSortAscending = !_roundwoodSortAscending;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // Die eigentliche Liste
                  Expanded(
                    child: ListView.builder(
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        final item = RoundwoodItem.fromFirestore(sortedDocs[index]);
                        return RoundwoodListItem(
                          item: item,
                          onTap: () {
                            if (widget.onItemSelected != null) {
                              widget.onItemSelected!(
                                sortedDocs[index].id,
                                sortedDocs[index].data() as Map<String, dynamic>,
                              );
                            } else {
                              _showEditDialog(item);
                            }
                          },
                          isDesktopLayout: widget.isDesktopLayout,
                        );
                      },
                    ),
                  ),
                ],
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
              icon: getAdaptiveIcon(
                iconName: 'filter_list',
                defaultIcon: Icons.filter_list,
              ),
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
            icon: getAdaptiveIcon(
              iconName: 'picture_as_pdf',
              defaultIcon: Icons.picture_as_pdf,
            ),
            tooltip: 'Als PDF exportieren',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _exportCsv,
            icon: getAdaptiveIcon(
              iconName: 'table_chart',
              defaultIcon: Icons.table_chart,
            ),
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
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoundwoodEditDialog(
        item: item,
        isDesktopLayout: widget.isDesktopLayout,
      ),
    );

    if (result != null && result['action'] == 'update') {
      await widget.service.updateRoundwood(item.id, result['data']);
    } else if (result != null && result['action'] == 'delete') {
      // Handle delete if needed
    }
  }

  Future<void> _exportPdf() async {
    try {
      final snapshot = await widget.service.getRoundwoodStream(widget.filter).first;
      // Wende auch hier den Client-Filter an
      final filteredDocs = _applyClosedFilter(snapshot.docs);
      final items = filteredDocs.map((doc) => RoundwoodItem.fromFirestore(doc)).toList();

      final fileName = 'Rundholzliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final pdfBytes = await RoundwoodPdfService.generatePdf(items);
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles([XFile(file.path)], subject: fileName);
      Future.delayed(const Duration(minutes: 1), () => file.delete());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Export: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final snapshot = await widget.service.getRoundwoodStream(widget.filter).first;
      // Wende auch hier den Client-Filter an
      final filteredDocs = _applyClosedFilter(snapshot.docs);
      final items = filteredDocs.map((doc) => RoundwoodItem.fromFirestore(doc)).toList();

      final fileName = 'Rundholzliste_${DateFormat('dd.MM.yyyy').format(DateTime.now())}.csv';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final csvBytes = await RoundwoodCsvService.generateCsv(items);
      await file.writeAsBytes(csvBytes);

      await Share.shareXFiles([XFile(file.path)], subject: fileName);
      Future.delayed(const Duration(minutes: 1), () => file.delete());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Export: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}