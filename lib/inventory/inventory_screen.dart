import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'inventory_service.dart';
import '../services/icon_helper.dart'; // Passe den Pfad an
import '../constants.dart'; // Passe den Pfad an (für primaryAppColor etc.)

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventur'),
        backgroundColor: const Color(0xFF0F4A29),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: getAdaptiveIcon(
              iconName: 'help_outline',
              defaultIcon: Icons.help_outline,
            ),
            onPressed: _showHelpDialog,
            tooltip: 'Hilfe',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Neue Inventur starten
            _buildNewInventoryCard(),
            const SizedBox(height: 24),
            // Bestehende Inventuren
            _buildExistingInventoriesSection(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NEUE INVENTUR STARTEN
  // ============================================================

  Widget _buildNewInventoryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4A29).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'inventory_2',
                    defaultIcon: Icons.inventory_2,
                    color: const Color(0xFF0F4A29),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Neue Inventur starten',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Erstelle einen Snapshot und exportiere die Zählliste',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Info-Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'info',
                    defaultIcon: Icons.info,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bei Start wird der aktuelle Lagerbestand als Snapshot gespeichert. '
                          'Du erhältst eine CSV-Datei zum Ausfüllen.',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startNewInventory,
                icon: getAdaptiveIcon(
                  iconName: 'play_arrow',
                  defaultIcon: Icons.play_arrow,
                ),
                label: const Text('Inventur starten'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4A29),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNewInventory() async {
    // Bestätigungsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'inventory_2',
              defaultIcon: Icons.inventory_2,
              color: const Color(0xFF0F4A29),
            ),
            const SizedBox(width: 12),
            const Text('Neue Inventur starten?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Folgende Schritte werden ausgeführt:'),
            SizedBox(height: 12),
            Text('1. Aktueller Lagerbestand wird als Snapshot gespeichert'),
            Text('2. CSV-Datei wird erstellt und kann geteilt werden'),
            Text('3. Nach der Zählung kannst du die Datei wieder importieren'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4A29),
              foregroundColor: Colors.white,
            ),
            child: const Text('Starten'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // 1. Snapshot erstellen
      final snapshotId = await _inventoryService.createInventorySnapshot();

      // 2. CSV exportieren
      final file = await _inventoryService.exportInventoryForCounting(snapshotId);

      // 3. Teilen
      await _inventoryService.shareInventoryFile(file);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventur gestartet! CSV wurde erstellt.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // BESTEHENDE INVENTUREN
  // ============================================================

  Widget _buildExistingInventoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            getAdaptiveIcon(
              iconName: 'history',
              defaultIcon: Icons.history,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              'Bestehende Inventuren',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _inventoryService.getSnapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Fehler: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'inbox',
                        defaultIcon: Icons.inbox,
                        color: Colors.grey[400],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Noch keine Inventuren vorhanden',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                return _buildInventoryCard(doc.id, data);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildInventoryCard(String snapshotId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'created';
    final createdAt = data['created_at'] as Timestamp?;
    final totalItems = data['total_items'] ?? 0;
    final totalValue = data['total_value'] ?? 0.0;
    final description = data['description'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showInventoryDetails(snapshotId, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusBadge(status),
                  const Spacer(),
                  if (createdAt != null)
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate()),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.inventory,
                    iconName: 'inventory',
                    label: '$totalItems Artikel',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    icon: Icons.payments,
                    iconName: 'payments',
                    label: NumberFormat.currency(
                      locale: 'de_CH',
                      symbol: 'CHF',
                      decimalDigits: 0,
                    ).format(totalValue),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Aktionsbuttons je nach Status
              _buildActionButtons(snapshotId, status, data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;
    String iconName;

    switch (status) {
      case 'created':
        color = Colors.blue;
        label = 'Erstellt';
        icon = Icons.note_add;
        iconName = 'note_add';
        break;
      case 'counting':
        color = Colors.orange;
        label = 'In Zählung';
        icon = Icons.pending;
        iconName = 'pending';
        break;
      case 'imported':
        color = Colors.purple;
        label = 'Importiert';
        icon = Icons.upload_file;
        iconName = 'upload_file';
        break;
      case 'applied':
        color = Colors.green;
        label = 'Abgeschlossen';
        icon = Icons.check_circle;
        iconName = 'check_circle';
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help;
        iconName = 'help';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String iconName,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            color: Colors.grey[600],
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      String snapshotId,
      String status,
      Map<String, dynamic> data,
      ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // CSV erneut exportieren (außer wenn abgeschlossen)
        if (status != 'applied')
          OutlinedButton.icon(
            onPressed: () => _reExportCsv(snapshotId),
            icon: getAdaptiveIcon(
              iconName: 'download',
              defaultIcon: Icons.download,
              size: 18,
            ),
            label: const Text('CSV Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F4A29),
            ),
          ),

        // CSV importieren (nur bei created oder counting)
        if (status == 'created' || status == 'counting')
          ElevatedButton.icon(
            onPressed: () => _importCsv(snapshotId),
            icon: getAdaptiveIcon(
              iconName: 'upload_file',
              defaultIcon: Icons.upload_file,
              size: 18,
            ),
            label: const Text('CSV Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),

        // Löschen (nur wenn nicht angewendet)
        if (status != 'applied')
          IconButton(
            onPressed: () => _deleteSnapshot(snapshotId),
            icon: getAdaptiveIcon(
              iconName: 'delete',
              defaultIcon: Icons.delete,
              color: Colors.red,
            ),
            tooltip: 'Löschen',
          ),
      ],
    );
  }

  // ============================================================
  // AKTIONEN
  // ============================================================

  Future<void> _reExportCsv(String snapshotId) async {
    setState(() => _isLoading = true);

    try {
      final file = await _inventoryService.exportInventoryForCounting(snapshotId);
      await _inventoryService.shareInventoryFile(file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV wurde exportiert'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importCsv(String snapshotId) async {
    try {
      // Datei auswählen
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isLoading = true);

      // Datei lesen
      final file = File(result.files.first.path!);
      final content = await file.readAsString();

      // Importieren
      final importResult = await _inventoryService.importInventoryCsv(
        content,
        snapshotId,
      );

      if (!mounted) return;

      if (!importResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(importResult.errorMessage ?? 'Import fehlgeschlagen'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Differenz-Dialog anzeigen
      await _showDifferenceDialog(snapshotId, importResult);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Import: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSnapshot(String snapshotId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inventur löschen?'),
        content: const Text(
          'Diese Inventur wird unwiderruflich gelöscht. '
              'Der aktuelle Lagerbestand bleibt unverändert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await _inventoryService.deleteSnapshot(snapshotId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventur gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abgeschlossene Inventuren können nicht gelöscht werden'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // DIFFERENZ-DIALOG
  // ============================================================

  Future<void> _showDifferenceDialog(
      String snapshotId,
      InventoryImportResult result,
      ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => InventoryDifferenceDialog(
        snapshotId: snapshotId,
        result: result,
        inventoryService: _inventoryService,
      ),
    );
  }

  // ============================================================
  // DETAILS DIALOG
  // ============================================================

  void _showInventoryDetails(String snapshotId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => InventoryDetailsSheet(
          snapshotId: snapshotId,
          data: data,
          scrollController: scrollController,
          inventoryService: _inventoryService,
        ),
      ),
    );
  }

  // ============================================================
  // HILFE-DIALOG
  // ============================================================

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'help',
              defaultIcon: Icons.help,
              color: const Color(0xFF0F4A29),
            ),
            const SizedBox(width: 12),
            const Text('Inventur-Hilfe'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'So funktioniert die Inventur:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. Inventur starten'),
              Text(
                '   → Aktueller Bestand wird als Snapshot gespeichert\n'
                    '   → CSV-Datei wird erstellt',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text('2. Zählung durchführen'),
              Text(
                '   → CSV in Excel öffnen\n'
                    '   → Spalte "Gezählt" ausfüllen\n'
                    '   → Optional: Bemerkungen eintragen',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text('3. CSV importieren'),
              Text(
                '   → Ausgefüllte CSV-Datei importieren\n'
                    '   → Differenzen werden automatisch berechnet\n'
                    '   → Abweichungen >10% werden markiert',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text('4. Änderungen übernehmen'),
              Text(
                '   → Differenzen prüfen\n'
                    '   → Änderungen bestätigen\n'
                    '   → Lagerbestand wird aktualisiert',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 16),
              Text(
                'Hinweis: Artikel, die sich im Warenkorb oder in '
                    'Reservierungen befinden, werden normal mitgezählt. '
                    'Fehler werden erst beim Ausbuchen erkannt.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DIFFERENZ-DIALOG WIDGET
// ============================================================

class InventoryDifferenceDialog extends StatefulWidget {
  final String snapshotId;
  final InventoryImportResult result;
  final InventoryService inventoryService;

  const InventoryDifferenceDialog({
    super.key,
    required this.snapshotId,
    required this.result,
    required this.inventoryService,
  });

  @override
  State<InventoryDifferenceDialog> createState() =>
      _InventoryDifferenceDialogState();
}

class _InventoryDifferenceDialogState extends State<InventoryDifferenceDialog> {
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return AlertDialog(
      title: Row(
        children: [
          getAdaptiveIcon(
            iconName: 'compare_arrows',
            defaultIcon: Icons.compare_arrows,
            color: const Color(0xFF0F4A29),
          ),
          const SizedBox(width: 12),
          const Text('Inventur-Differenzen'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zusammenfassung
            _buildSummaryCard(result),
            const SizedBox(height: 16),
            // Differenzen-Liste
            Expanded(
              child: result.differences.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'check_circle',
                      defaultIcon: Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Keine Differenzen gefunden!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Der Bestand stimmt überein.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: result.differences.length,
                itemBuilder: (context, index) {
                  return _buildDifferenceItem(result.differences[index]);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Differenzen exportieren
        if (result.differences.isNotEmpty)
          TextButton.icon(
            onPressed: _exportDifferences,
            icon: getAdaptiveIcon(
              iconName: 'download',
              defaultIcon: Icons.download,
              size: 18,
            ),
            label: const Text('Export'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        if (result.differences.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _isApplying ? null : _applyChanges,
            icon: _isApplying
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : getAdaptiveIcon(
              iconName: 'check',
              defaultIcon: Icons.check,
              size: 18,
            ),
            label: Text(_isApplying ? 'Wird angewendet...' : 'Übernehmen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4A29),
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(InventoryImportResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            label: 'Gesamt',
            value: '${result.totalItems}',
            color: Colors.grey[700]!,
          ),
          _buildSummaryItem(
            label: 'Geändert',
            value: '${result.changedItems}',
            color: Colors.blue,
          ),
          _buildSummaryItem(
            label: 'Warnungen',
            value: '${result.warningItems}',
            color: result.warningItems > 0 ? Colors.orange : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDifferenceItem(InventoryDifference diff) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: diff.hasWarning ? Colors.orange.withOpacity(0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: diff.hasWarning
            ? const BorderSide(color: Colors.orange, width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (diff.hasWarning)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: getAdaptiveIcon(
                      iconName: 'warning',
                      defaultIcon: Icons.warning,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                Expanded(
                  child: Text(
                    diff.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              diff.shortBarcode,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildQuantityBox(
                  label: 'Alt',
                  value: _formatQty(diff.oldQuantity, diff.unit),
                  color: Colors.grey,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: getAdaptiveIcon(
                    iconName: 'arrow_forward',
                    defaultIcon: Icons.arrow_forward,
                    color: Colors.grey,
                    size: 16,
                  ),
                ),
                _buildQuantityBox(
                  label: 'Neu',
                  value: _formatQty(diff.newQuantity, diff.unit),
                  color: const Color(0xFF0F4A29),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: diff.difference > 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${diff.difference > 0 ? '+' : ''}${_formatQty(diff.difference, diff.unit)} (${diff.differencePercent.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: diff.difference > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            if (diff.comment != null && diff.comment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bemerkung: ${diff.comment}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatQty(double qty, String unit) {
    if (unit == 'Stück') {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(3);
  }

  Future<void> _exportDifferences() async {
    try {
      final file = await widget.inventoryService.exportDifferenceReport(
        widget.snapshotId,
        widget.result.differences,
      );
      await widget.inventoryService.shareInventoryFile(file);
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

  Future<void> _applyChanges() async {
    // Bestätigung bei Warnungen
    if (widget.result.warningItems > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'warning',
                defaultIcon: Icons.warning,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              const Text('Warnungen vorhanden'),
            ],
          ),
          content: Text(
            'Es gibt ${widget.result.warningItems} Artikel mit Abweichungen über 10%.\n\n'
                'Möchtest du die Änderungen trotzdem übernehmen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Trotzdem übernehmen'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isApplying = true);

    try {
      final success = await widget.inventoryService.applyInventoryChanges(
        widget.snapshotId,
        widget.result.differences,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.result.changedItems} Artikel wurden aktualisiert',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Übernehmen der Änderungen'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }
}

// ============================================================
// DETAILS SHEET WIDGET
// ============================================================

class InventoryDetailsSheet extends StatelessWidget {
  final String snapshotId;
  final Map<String, dynamic> data;
  final ScrollController scrollController;
  final InventoryService inventoryService;

  const InventoryDetailsSheet({
    super.key,
    required this.snapshotId,
    required this.data,
    required this.scrollController,
    required this.inventoryService,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = data['created_at'] as Timestamp?;
    final appliedAt = data['applied_at'] as Timestamp?;
    final status = data['status'] ?? 'created';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'inventory_2',
                  defaultIcon: Icons.inventory_2,
                  color: const Color(0xFF0F4A29),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['description'] ?? 'Inventur',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildDetailRow(
                  context,
                  'Status',
                  status,
                  Icons.info,
                  'info',
                ),
                _buildDetailRow(
                  context,
                  'Erstellt am',
                  createdAt != null
                      ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate())
                      : '-',
                  Icons.calendar_today,
                  'calendar_today',
                ),
                _buildDetailRow(
                  context,
                  'Erstellt von',
                  data['created_by_email'] ?? '-',
                  Icons.person,
                  'person',
                ),
                _buildDetailRow(
                  context,
                  'Artikel',
                  '${data['total_items'] ?? 0}',
                  Icons.inventory,
                  'inventory',
                ),
                _buildDetailRow(
                  context,
                  'Gesamtwert',
                  NumberFormat.currency(
                    locale: 'de_CH',
                    symbol: 'CHF',
                    decimalDigits: 2,
                  ).format(data['total_value'] ?? 0),
                  Icons.payments,
                  'payments',
                ),
                if (status == 'applied') ...[
                  const Divider(height: 32),
                  _buildDetailRow(
                    context,
                    'Angewendet am',
                    appliedAt != null
                        ? DateFormat('dd.MM.yyyy HH:mm')
                        .format(appliedAt.toDate())
                        : '-',
                    Icons.check_circle,
                    'check_circle',
                  ),
                  _buildDetailRow(
                    context,
                    'Änderungen',
                    '${data['total_changes'] ?? 0} Artikel',
                    Icons.compare_arrows,
                    'compare_arrows',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context,
      String label,
      String value,
      IconData icon,
      String iconName,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}