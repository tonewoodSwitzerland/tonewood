// File: lib/services/incoterms_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'icon_helper.dart';

/// Verwaltung der Incoterms (Anlegen, Bearbeiten, Löschen) – zweisprachig DE/EN
class IncotermsSettingsScreen extends StatefulWidget {
  const IncotermsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<IncotermsSettingsScreen> createState() => _IncotermsSettingsScreenState();
}

class _IncotermsSettingsScreenState extends State<IncotermsSettingsScreen> {
  final _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _incoterms = [];
  bool _isLoading = true;

  // Für die Detailansicht im Wide-Layout
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _loadIncoterms();
  }

  Future<void> _loadIncoterms() async {
    try {
      final snapshot = await _db.collection('incoterms').orderBy('name').get();
      setState(() {
        _incoterms = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fehler beim Laden der Incoterms: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addIncoterm() async {
    final result = await _showEditDialog(context);
    if (result == null) return;

    try {
      final docRef = await _db.collection('incoterms').add({
        'name': result['name'],
        'de': result['de'],
        'en': result['en'],
        'created_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _incoterms.add({
          'id': docRef.id,
          'name': result['name'],
          'de': result['de'],
          'en': result['en'],
        });
        _incoterms.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        _selectedId = docRef.id;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('„${result['name']}" hinzugefügt'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _editIncoterm(Map<String, dynamic> incoterm) async {
    final result = await _showEditDialog(context, existing: incoterm);
    if (result == null) return;

    try {
      await _db.collection('incoterms').doc(incoterm['id']).update({
        'name': result['name'],
        'de': result['de'],
        'en': result['en'],
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        final idx = _incoterms.indexWhere((i) => i['id'] == incoterm['id']);
        if (idx >= 0) {
          _incoterms[idx] = {'id': incoterm['id'], ...result};
        }
        _incoterms.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('„${result['name']}" aktualisiert'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteIncoterm(Map<String, dynamic> incoterm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 32),
        title: const Text('Incoterm löschen?'),
        content: Text(
          '„${incoterm['name']}" wird dauerhaft gelöscht.\n\n'
              'Achtung: Falls dieser Incoterm bereits in Aufträgen verwendet wird, '
              'kann er dort nicht mehr angezeigt werden.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.collection('incoterms').doc(incoterm['id']).delete();
      setState(() {
        _incoterms.removeWhere((i) => i['id'] == incoterm['id']);
        if (_selectedId == incoterm['id']) _selectedId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('„${incoterm['name']}" gelöscht'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDIT DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, String>?> _showEditDialog(BuildContext context, {Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final deCtrl = TextEditingController(text: existing?['de'] ?? '');
    final enCtrl = TextEditingController(text: existing?['en'] ?? '');
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Incoterm bearbeiten' : 'Neuer Incoterm'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kürzel
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kürzel *',
                      hintText: 'z.B. CIF, EXW, FOB',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
                    autofocus: true,
                  ),

                  const SizedBox(height: 20),

                  // DE Sektion
                  _buildDialogSectionLabel('Deutsch'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: deCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bezeichnung (DE)',
                      hintText: 'z.B. Kosten, Versicherung, Fracht',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 20),

                  // EN Sektion
                  _buildDialogSectionLabel('English'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: enCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (EN)',
                      hintText: 'e.g. cost, insurance, freight',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, {
                  'name': nameCtrl.text.trim(),
                  'de': deCtrl.text.trim(),
                  'en': enCtrl.text.trim(),
                });
              }
            },
            icon: Icon(isEdit ? Icons.check : Icons.add, size: 18),
            label: Text(isEdit ? 'Speichern' : 'Hinzufügen'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogSectionLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: text == 'Deutsch' ? Colors.black.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text == 'Deutsch' ? '🇩🇪' : '🇬🇧',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: text == 'Deutsch' ? Colors.grey.shade800 : Colors.blue.shade800,
          )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Incoterms')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoterms verwalten'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _addIncoterm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Neu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
      // FAB nur auf Mobile (auf Wide ist der Button in der AppBar genug)
      floatingActionButton: isWide
          ? null
          : FloatingActionButton(
        onPressed: _addIncoterm,
        child: const Icon(Icons.add),
      ),
      body: isWide ? _buildWideLayout(context) : _buildNarrowLayout(context),
    );
  }

  /// Desktop/Web: Master-Detail Split
  Widget _buildWideLayout(BuildContext context) {
    final selected = _selectedId != null
        ? _incoterms.firstWhere((i) => i['id'] == _selectedId, orElse: () => {})
        : null;

    return Row(
      children: [
        // LISTE (links)
        SizedBox(
          width: 380,
          child: Column(
            children: [
              _buildListHeader(context),
              Expanded(child: _buildIncotermsList(context, isWide: true)),
            ],
          ),
        ),
        Container(width: 1, color: Colors.grey.shade300),
        // DETAIL (rechts)
        Expanded(
          child: selected != null && selected.isNotEmpty
              ? _buildDetailPanel(context, selected)
              : _buildEmptyDetail(context),
        ),
      ],
    );
  }

  /// Mobile: Einfache Liste
  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        _buildListHeader(context),
        Expanded(child: _buildIncotermsList(context, isWide: false)),
      ],
    );
  }

  Widget _buildListHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(iconName: 'local_shipping', defaultIcon: Icons.local_shipping, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Text('${_incoterms.length} Incoterm${_incoterms.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
          const Spacer(),
          Text('Incoterms® 2020', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildIncotermsList(BuildContext context, {required bool isWide}) {
    if (_incoterms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Keine Incoterms vorhanden', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Erstelle deinen ersten Incoterm mit dem + Button', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _incoterms.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _incoterms[index];
        final isSelected = isWide && _selectedId == item['id'];
        final name = item['name'] as String? ?? '';
        final de = item['de'] as String? ?? '';
        final en = item['en'] as String? ?? '';

        return ListTile(
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.blueGrey.shade100,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.blueGrey.shade700,
              ),
            ),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: de.isNotEmpty
              ? Text(de, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)
              : (en.isNotEmpty
              ? Text(en, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)
              : null),
          trailing: isWide
              ? null
              : PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'edit') _editIncoterm(item);
              if (action == 'delete') _deleteIncoterm(item);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Bearbeiten'), dense: true)),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Löschen', style: TextStyle(color: Colors.red)), dense: true)),
            ],
          ),
          onTap: () {
            if (isWide) {
              setState(() => _selectedId = item['id']);
            } else {
              _editIncoterm(item);
            }
          },
        );
      },
    );
  }

  /// Detail-Panel rechts im Wide-Layout
  Widget _buildDetailPanel(BuildContext context, Map<String, dynamic> incoterm) {
    final name = incoterm['name'] as String? ?? '';
    final de = incoterm['de'] as String? ?? '';
    final en = incoterm['en'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (de.isNotEmpty)
                      Text(de, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              // Aktionen
              OutlinedButton.icon(
                onPressed: () => _editIncoterm(incoterm),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Bearbeiten'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _deleteIncoterm(incoterm),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Löschen', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Deutsch
          if (de.isNotEmpty)
            ...[
              _buildDetailLanguageCard(
                flag: '🇩🇪',
                language: 'Deutsch',
                label: 'Bezeichnung',
                value: de,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
            ],

          // English
          if (en.isNotEmpty)
            _buildDetailLanguageCard(
              flag: '🇬🇧',
              language: 'English',
              label: 'Description',
              value: en,
              color: Colors.blue,
            ),

          if (de.isEmpty && en.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text(
                  'Noch keine Bezeichnungen hinterlegt. Klicke auf "Bearbeiten" um Details hinzuzufügen.',
                  style: TextStyle(fontSize: 13),
                )),
              ]),
            ),

          const SizedBox(height: 32),

          // Verwendung
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info_outline, color: Colors.grey, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'Dieser Incoterm kann in Handelsrechnungen ausgewählt werden. '
                    'Die Bezeichnung wird auf dem PDF-Dokument angezeigt.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLanguageCard({
    required String flag,
    required String language,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(language, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
            ]),
            const Divider(height: 20),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDetail(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Wähle einen Incoterm aus der Liste', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('oder erstelle einen neuen mit dem "Neu"-Button', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}