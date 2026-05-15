import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


import '../../services/price_formatter.dart';
import '../services/icon_helper.dart';
import 'order_model.dart'; // PriceFormatter (für Info-Box)
// <

/// Sheet für die Verwaltung mehrerer Veranlagungsverfügungen (Ausfuhr) pro Auftrag.
///
/// Datenstruktur in Firestore (neu):
///   metadata.veranlagungen: [
///     {
///       'id': String,
///       'nummer': String,
///       'pdfUrl': String?,
///       'pdfFileName': String?,
///       'storagePath': String?,
///       'createdAt': Timestamp,
///       'pdfUploadedAt': Timestamp?,
///     }
///   ]
///
/// Legacy-Felder (werden gelesen, beim ersten Save migriert und gelöscht):
///   metadata.veranlagungsnummer
///   documents.veranlagungsverfuegung_pdf
///   metadata.veranlagungsverfuegung_uploaded_at
///   metadata.veranlagungsnummer_updated_at
class VeranlagungenSheet extends StatefulWidget {
  final OrderX order;
  final Map<String, bool>? roundingSettings;


  const VeranlagungenSheet({
    Key? key,
    required this.order,
    this.roundingSettings,
  }) : super(key: key);

  /// Convenience-Opener für ModalBottomSheet.
  static Future<void> show(
      BuildContext context, {
        required OrderX order,
        Map<String, bool>? roundingSettings,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: VeranlagungenSheet(
          order: order,
          roundingSettings: roundingSettings,
        ),
      ),
    );
  }

  /// Rückwärtskompatibles Lesen — kann von außen genutzt werden
  /// (z.B. für Listen-Icons, Filter, Details-Karte).
  static List<Map<String, dynamic>> extract(OrderX order) {
    final raw = order.metadata['veranlagungen'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // Legacy-Fallback: einen Eintrag aus den alten Feldern bauen.
    final legacyNummer =
        order.metadata['veranlagungsnummer']?.toString() ?? '';
    final legacyPdf = order.documents['veranlagungsverfuegung_pdf'];
    final hasLegacy =
        legacyNummer.isNotEmpty || (legacyPdf != null && legacyPdf.isNotEmpty);
    if (hasLegacy) {
      return [
        {
          'id': 'legacy',
          'nummer': legacyNummer,
          'pdfUrl': legacyPdf,
          'pdfFileName': null,
          'storagePath': null,
          'createdAt': order.metadata['veranlagungsnummer_updated_at'],
          'pdfUploadedAt':
          order.metadata['veranlagungsverfuegung_uploaded_at'],
        }
      ];
    }
    return [];
  }

  /// True, wenn mindestens ein Eintrag mit nicht-leerer Nummer existiert.
  static bool hasAny(OrderX order) {
    return extract(order)
        .any((v) => (v['nummer']?.toString() ?? '').trim().isNotEmpty);
  }

  /// Anzahl der erfassten Veranlagungen (mit Nummer).
  static int count(OrderX order) {
    return extract(order)
        .where((v) => (v['nummer']?.toString() ?? '').trim().isNotEmpty)
        .length;
  }

  /// Anzahl mit hochgeladenem PDF.
  static int countWithPdf(OrderX order) {
    return extract(order)
        .where((v) => (v['pdfUrl']?.toString() ?? '').isNotEmpty)
        .length;
  }

  @override
  State<VeranlagungenSheet> createState() => _VeranlagungenSheetState();
}

class _VeranlagungenSheetState extends State<VeranlagungenSheet> {
  late OrderX _order;
  late List<Map<String, dynamic>> _list;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Timer> _debounce = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _list = VeranlagungenSheet.extract(_order);
    for (final v in _list) {
      _controllers[v['id'] as String] =
          TextEditingController(text: (v['nummer'] ?? '').toString());
    }
  }

  @override
  void dispose() {
    for (final t in _debounce.values) {
      t.cancel();
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Persist: schreibt die komplette Liste in Firestore und entfernt Legacy-Felder.
  // ---------------------------------------------------------------------------
  Future<void> _persist(
      List<Map<String, dynamic>> next, {
        String? historyAction,
        Map<String, dynamic>? historyExtras,
      }) async {
    // Legacy-ID beim ersten echten Save in eine echte ID umwandeln.
    for (final v in next) {
      if (v['id'] == 'legacy') {
        v['id'] =
        'v_${DateTime.now().millisecondsSinceEpoch}_${next.indexOf(v)}';
      }
      v['createdAt'] ??= Timestamp.now();
    }

    final update = <String, dynamic>{
      'metadata.veranlagungen': next,
      // Legacy-Felder ausräumen
      'metadata.veranlagungsnummer': FieldValue.delete(),
      'metadata.veranlagungsnummer_updated_at': FieldValue.delete(),
      'metadata.veranlagungsverfuegung_uploaded_at': FieldValue.delete(),
      'documents.veranlagungsverfuegung_pdf': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(_order.id)
        .update(update);

    if (historyAction != null) {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_order.id)
          .collection('history')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': user?.uid ?? 'unknown',
        'user_email': user?.email ?? 'Unknown User',
        'user_name': user?.email ?? 'Unknown',
        'action': historyAction,
        if (historyExtras != null) ...historyExtras,
      });
    }

    // Lokales Order-Objekt nachziehen (ohne Roundtrip)
    final newMetadata = Map<String, dynamic>.from(_order.metadata)
      ..['veranlagungen'] = next
      ..remove('veranlagungsnummer')
      ..remove('veranlagungsnummer_updated_at')
      ..remove('veranlagungsverfuegung_uploaded_at');
    final newDocuments = Map<String, String>.from(_order.documents)
      ..remove('veranlagungsverfuegung_pdf');

    if (!mounted) return;
    setState(() {
      _order =
          _order.copyWith(metadata: newMetadata, documents: newDocuments);
      _list = next;
      _syncControllers();
    });
  }

  void _syncControllers() {
    final aliveIds = _list.map((e) => e['id'] as String).toSet();
    // Entfernte Einträge bereinigen
    final dead = _controllers.keys
        .where((id) => !aliveIds.contains(id))
        .toList();
    for (final id in dead) {
      _controllers[id]?.dispose();
      _controllers.remove(id);
      _debounce[id]?.cancel();
      _debounce.remove(id);
    }
    // Fehlende Controller anlegen (z.B. nach Migration „legacy" → neue ID)
    for (final v in _list) {
      final id = v['id'] as String;
      _controllers.putIfAbsent(
        id,
            () => TextEditingController(text: (v['nummer'] ?? '').toString()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _addEntry() async {
    final newId = 'v_${DateTime.now().millisecondsSinceEpoch}';
    final entry = <String, dynamic>{
      'id': newId,
      'nummer': '',
      'pdfUrl': null,
      'pdfFileName': null,
      'storagePath': null,
      'createdAt': Timestamp.now(),
      'pdfUploadedAt': null,
    };

    // Lokal sofort einfügen, damit Controller sichtbar wird
    setState(() {
      _list = [..._list, entry];
      _controllers[newId] = TextEditingController();
    });

    try {
      await _persist(_list, historyAction: 'veranlagung_added');
    } catch (e) {
      _showError('Fehler beim Anlegen: $e');
    }
  }

  Future<void> _removeEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Veranlagung entfernen'),
        content: const Text(
            'Diesen Eintrag inkl. evtl. hochgeladenem PDF wirklich entfernen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final idx = _list.indexWhere((e) => e['id'] == id);
    if (idx == -1) return;
    final entry = _list[idx];

    // Storage-Datei wegputzen (best-effort, Legacy hat keinen storagePath)
    final storagePath = entry['storagePath']?.toString();
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (_) {
        // Datei evtl. schon weg — ignorieren
      }
    }

    final next = [..._list]..removeAt(idx);
    try {
      await _persist(
        next,
        historyAction: 'veranlagung_removed',
        historyExtras: {
          'veranlagungsnummer': entry['nummer'],
        },
      );
    } catch (e) {
      _showError('Fehler beim Entfernen: $e');
    }
  }

  void _onNummerChanged(String id, String value) {
    _debounce[id]?.cancel();
    _debounce[id] = Timer(const Duration(milliseconds: 600), () async {
      await _saveNummer(id, value);
    });
  }

  Future<void> _saveNummer(String id, String value) async {
    final idx = _list.indexWhere((e) => e['id'] == id);
    if (idx == -1) return;
    final trimmed = value.trim();
    if ((_list[idx]['nummer'] ?? '').toString() == trimmed) return;

    final old = _list[idx]['nummer'];
    final next = [..._list];
    next[idx] = {...next[idx], 'nummer': trimmed};

    try {
      await _persist(
        next,
        historyAction: 'veranlagung_nummer_updated',
        historyExtras: {
          'veranlagung_id': next[idx]['id'],
          'old_value': old,
          'new_value': trimmed,
        },
      );
    } catch (e) {
      _showError('Fehler beim Speichern: $e');
    }
  }

  Future<void> _uploadPdf(String id) async {
    final idx = _list.indexWhere((e) => e['id'] == id);
    if (idx == -1) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb, // Mobile/Desktop: bytes lazy laden, Web: zwingend bytes
      );
    } catch (e) {
      _showError('Datei-Auswahl fehlgeschlagen: $e');
      return;
    }
    if (result == null) return;

    // Dialog SOFORT zeigen + einen Frame warten, damit er auch wirklich rendert
    // bevor wir den UI-Thread mit File-I/O blockieren.
    setState(() => _busy.add(id));
    _showUploadDialog();
    await Future.delayed(Duration.zero);

    try {
      Uint8List? bytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      if (bytes == null) {
        final path = result.files.first.path;
        if (path != null) {
          bytes = await File(path).readAsBytes();
        }
      }
      if (bytes == null) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError('Datei konnte nicht gelesen werden');
        return;
      }

      // Alte Datei dieses Eintrags vorher löschen, damit kein Orphan bleibt
      final oldPath = _list[idx]['storagePath']?.toString();
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(oldPath).delete();
        } catch (_) {}
      }

      // Neue ID falls noch legacy → wir generieren beim _persist eh um;
      // den Storage-Pfad bauen wir auf Basis der aktuellen ID, das passt für neue Einträge.
      final entryId = _list[idx]['id'] as String;
      final storagePath =
          'orders/${_order.id}/veranlagungsverfuegung/$entryId.pdf';

      final ref = FirebaseStorage.instance.ref(storagePath);
      final task = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'orderNumber': _order.orderNumber,
            'documentType': 'Veranlagungsverfügung',
            'veranlagungId': entryId,
            'veranlagungsnummer':
            (_list[idx]['nummer'] ?? '').toString(),
            'uploadedAt': DateTime.now().toIso8601String(),
            'originalFileName': fileName,
          },
        ),
      );
      final url = await task.ref.getDownloadURL();

      final next = [..._list];
      next[idx] = {
        ...next[idx],
        'pdfUrl': url,
        'pdfFileName': fileName,
        'storagePath': storagePath,
        'pdfUploadedAt': Timestamp.now(),
      };

      await _persist(
        next,
        historyAction: 'veranlagung_pdf_uploaded',
        historyExtras: {
          'veranlagung_id': entryId,
          'veranlagungsnummer': (_list[idx]['nummer'] ?? '').toString(),
          'file_name': fileName,
        },
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Lade-Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF wurde hochgeladen'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showError('Upload fehlgeschlagen: $e');
    } finally {
      if (mounted) {
        setState(() => _busy.remove(id));
      }
    }
  }

  Future<void> _deletePdf(String id) async {
    final idx = _list.indexWhere((e) => e['id'] == id);
    if (idx == -1) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PDF löschen'),
        content: const Text('PDF wirklich löschen? Die Nummer bleibt erhalten.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final entry = _list[idx];
    final storagePath = entry['storagePath']?.toString();
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (_) {}
    }

    final next = [..._list];
    next[idx] = {
      ...next[idx],
      'pdfUrl': null,
      'pdfFileName': null,
      'storagePath': null,
      'pdfUploadedAt': null,
    };

    try {
      await _persist(
        next,
        historyAction: 'veranlagung_pdf_deleted',
        historyExtras: {
          'veranlagung_id': entry['id'],
          'veranlagungsnummer': entry['nummer'],
        },
      );
    } catch (e) {
      _showError('Fehler beim Löschen: $e');
    }
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('PDF konnte nicht geöffnet werden');
    }
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                  getAdaptiveIcon(
                    iconName: 'cloud_upload',
                    defaultIcon: Icons.cloud_upload,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'PDF wird hochgeladen…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  bool get _needsVeranlagungsverfuegung {
    final total = (_order.calculations['total'] as num? ?? 0).toDouble();
    final currency = _order.metadata['currency'] ?? 'CHF';
    if (currency != 'CHF') {
      final rates =
          _order.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
      final rate = (rates['CHF'] as num?)?.toDouble() ?? 1.0;
      return (total / rate) > 1000.0;
    }
    return total > 1000.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAny = _list.any(
            (v) => (v['nummer']?.toString() ?? '').trim().isNotEmpty);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'assignment',
                  defaultIcon: Icons.assignment,
                  color: hasAny ? Colors.green : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Veranlagungsverfügung Ausfuhr',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Auftrag ${_order.orderNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: getAdaptiveIcon(
                      iconName: 'close', defaultIcon: Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info-Box (nur wenn relevant)
                  if (_needsVeranlagungsverfuegung) ...[
                    _buildInfoBox(theme),
                    const SizedBox(height: 20),
                  ],

                  // Liste
                  if (_list.isEmpty)
                    _buildEmptyState(theme)
                  else
                    ..._list.asMap().entries.map((e) =>
                        _buildEntryCard(theme, e.key + 1, e.value)),

                  const SizedBox(height: 12),

                  // + Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addEntry,
                      icon: getAdaptiveIcon(
                          iconName: 'add', defaultIcon: Icons.add),
                      label: const Text('Veranlagung hinzufügen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Footer
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Schließen'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(ThemeData theme) {
    final total = (_order.calculations['total'] as num? ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(
                  iconName: 'info',
                  defaultIcon: Icons.info,
                  color: Colors.blue[700],
                  size: 20),
              const SizedBox(width: 8),
              const Text('Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Warenwert: ${PriceFormatter.fromOrder(
              price: total,
              metadata: _order.metadata,
              roundingSettings: widget.roundingSettings,
            )}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bei Lieferungen mit einem Warenwert über CHF 1\'000.00 muss die Veranlagungsverfügung Ausfuhr gespeichert werden. '
                'Du kannst beliebig viele Veranlagungsnummern erfassen und je Nummer ein PDF hinterlegen.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          getAdaptiveIcon(
            iconName: 'assignment_late',
            defaultIcon: Icons.assignment_late,
            size: 32,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Noch keine Veranlagung erfasst',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
      ThemeData theme, int index, Map<String, dynamic> entry) {
    final id = entry['id'] as String;
    final hasPdf = (entry['pdfUrl']?.toString() ?? '').isNotEmpty;
    final hasNummer =
        (entry['nummer']?.toString() ?? '').trim().isNotEmpty;
    final accent = hasNummer
        ? (hasPdf ? Colors.green : Colors.orange)
        : theme.colorScheme.outline;

    final ctl = _controllers[id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          // Kopfzeile
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: accent.withOpacity(0.25),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Veranlagung $index',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: accent,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'delete_outline',
                    defaultIcon: Icons.delete_outline,
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                    size: 20,
                  ),
                  tooltip: 'Eintrag entfernen',
                  onPressed: () => _removeEntry(id),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nummer
                TextField(
                  controller: ctl,
                  decoration: InputDecoration(
                    labelText: 'Veranlagungsnummer',
                    hintText: 'z.B. 25CH04EXA83JFTR0N8',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: getAdaptiveIcon(
                        iconName: 'pin', defaultIcon: Icons.pin),
                    suffixIcon: hasNummer
                        ? getAdaptiveIcon(
                        iconName: 'check',
                        defaultIcon: Icons.check,
                        color: Colors.green)
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.4),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) => _onNummerChanged(id, v),
                  onSubmitted: (v) => _saveNummer(id, v),
                  onEditingComplete: () => _saveNummer(id, ctl.text),
                ),

                const SizedBox(height: 10),

                // PDF-Status / Aktionen
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: hasPdf
                        ? Colors.green.withOpacity(0.06)
                        : theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasPdf
                          ? Colors.green.withOpacity(0.25)
                          : theme.colorScheme.outline.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'picture_as_pdf',
                        defaultIcon: Icons.picture_as_pdf,
                        size: 20,
                        color: hasPdf
                            ? Colors.green
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasPdf
                                  ? (entry['pdfFileName']?.toString() ??
                                  'PDF hochgeladen')
                                  : 'Kein PDF hinterlegt',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!hasPdf)
                              Text(
                                'PDF hochladen, um die Verfügung zu hinterlegen',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.55),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasPdf) ...[
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: getAdaptiveIcon(
                              iconName: 'visibility',
                              defaultIcon: Icons.visibility,
                              size: 20),
                          tooltip: 'PDF anzeigen',
                          onPressed: () =>
                              _openPdf(entry['pdfUrl'].toString()),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: getAdaptiveIcon(
                              iconName: 'delete',
                              defaultIcon: Icons.delete,
                              size: 20,
                              color: Colors.red),
                          tooltip: 'PDF löschen',
                          onPressed: () => _deletePdf(id),
                        ),
                      ] else
                        TextButton.icon(
                          onPressed:
                          _busy.contains(id) ? null : () => _uploadPdf(id),
                          icon: getAdaptiveIcon(
                              iconName: 'upload_file',
                              defaultIcon: Icons.upload_file,
                              size: 18),
                          label: const Text('Hochladen'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}