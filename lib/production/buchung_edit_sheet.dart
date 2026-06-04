// ═══════════════════════════════════════════════════════════════════════════
// lib/production/buchung_edit_sheet.dart
//
// Bearbeiten und Stornieren einer einzelnen Buchung (Charge).
//
// Aufruf:
//   final changed = await showBuchungEdit(context: context, booking: produkt);
//   if (changed == true) { /* Liste neu laden */ }
//
// - Mobile (< 600px): Bottom Sheet
// - Web / Desktop:    zentrierter Dialog
//
// Hintergrund: Eine Buchung verteilt sich auf mehrere Stellen in Firestore
// (production, inventory, production_batches, Subcollection batch, stock_entries).
// Bearbeiten (Menge/Datum) und Stornieren rechnen die Lagerbestände konsistent
// zurück bzw. an – alles in einer atomaren WriteBatch.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../services/icon_helper.dart';

const Color _kAccent = Color(0xFF0F4A29);

/// Öffnet die Bearbeiten/Storno-Ansicht für eine Buchung.
///
/// [booking] ist das `production_batches`-Dokument inkl. `id`.
/// Gibt `true` zurück, wenn die Buchung geändert oder storniert wurde.
Future<bool?> showBuchungEdit({
  required BuildContext context,
  required Map<String, dynamic> booking,
}) {
  final isMobile = MediaQuery.of(context).size.width < 600;

  if (isMobile) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(child: _BuchungEditContent(booking: booking, isMobile: true)),
            ],
          ),
        ),
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 700),
        child: _BuchungEditContent(booking: booking, isMobile: false),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════

class _BuchungEditContent extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool isMobile;

  const _BuchungEditContent({
    required this.booking,
    required this.isMobile,
  });

  @override
  State<_BuchungEditContent> createState() => _BuchungEditContentState();
}

class _BuchungEditContentState extends State<_BuchungEditContent> {
  late final TextEditingController _quantityController;
  late DateTime _selectedDate;
  late final int _originalQuantity;
  bool _isSaving = false;

  String get _productId => widget.booking['product_id'] as String? ?? '';
  String get _shortBarcode {
    final parts = _productId.split('.');
    return parts.length >= 2 ? '${parts[0]}.${parts[1]}' : _productId;
  }

  double get _price => (widget.booking['price_CHF'] as num?)?.toDouble() ?? 0.0;

  @override
  void initState() {
    super.initState();
    _originalQuantity = (widget.booking['quantity'] as num?)?.toInt() ?? 0;
    _quantityController =
        TextEditingController(text: _originalQuantity.toString());

    final rawDate = widget.booking['stock_entry_date'];
    DateTime initial = DateTime.now();
    if (rawDate != null) {
      try {
        initial = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    _selectedDate = initial;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // ─── Speichern (Mengen-/Datumsänderung) ─────────────────────────────────
  Future<void> _save() async {
    final newQuantity = int.tryParse(_quantityController.text.trim());
    if (newQuantity == null || newQuantity <= 0) {
      AppToast.show(message: 'Bitte eine gültige Menge eingeben', height: h);
      return;
    }

    final delta = newQuantity - _originalQuantity;
    final originalDate = _bookingDate();
    final dateChanged = !_isSameDay(_selectedDate, originalDate);

    if (delta == 0 && !dateChanged) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final docId = widget.booking['id'] as String;
      final batchNumber = widget.booking['batch_number'];
      final newValue = newQuantity * _price;

      // 1. Flacher Eintrag in production_batches
      final flatRef = firestore.collection('production_batches').doc(docId);
      batch.update(flatRef, {
        'quantity': newQuantity,
        'value': newValue,
        'stock_entry_date': Timestamp.fromDate(_selectedDate),
      });

      // 2. Charge in der Subcollection production/{id}/batch/{nr}
      if (batchNumber != null) {
        final subRef = firestore
            .collection('production')
            .doc(_productId)
            .collection('batch')
            .doc(batchNumber.toString().padLeft(4, '0'));
        batch.set(
          subRef,
          {
            'quantity': newQuantity,
            'stock_entry_date': Timestamp.fromDate(_selectedDate),
          },
          SetOptions(merge: true),
        );
      }

      // 3. Bestände nur anpassen, wenn sich die Menge geändert hat
      if (delta != 0) {
        batch.update(
          firestore.collection('production').doc(_productId),
          {
            'quantity': FieldValue.increment(delta),
            'last_stock_change': delta,
            'last_stock_entry': FieldValue.serverTimestamp(),
          },
        );
        batch.set(
          firestore.collection('inventory').doc(_shortBarcode),
          {
            'quantity': FieldValue.increment(delta),
            'last_stock_change': delta,
            'last_stock_entry': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // 4. Korrektur in der History
        batch.set(
          firestore.collection('stock_entries').doc(),
          {
            ..._historyBase(),
            'quantity_change': delta,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'adjustment',
            'entry_type': 'edit',
          },
        );
      }

      await batch.commit();

      if (!mounted) return;
      AppToast.show(message: 'Buchung aktualisiert', height: h);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.show(message: 'Fehler beim Speichern: $e', height: h);
    }
  }

  // ─── Stornieren ─────────────────────────────────────────────────────────
  Future<void> _confirmAndCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'warning_amber',
              defaultIcon: Icons.warning_amber,
              color: Colors.red[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Buchung stornieren?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• Der Lagerbestand wird um $_originalQuantity '
                        '${widget.booking['unit'] ?? 'Stk'} reduziert.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Die Buchung wird vollständig entfernt.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Diese Aktion kann nicht rückgängig gemacht werden.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stornieren'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _cancelBooking();
  }

  Future<void> _cancelBooking() async {
    setState(() => _isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final docId = widget.booking['id'] as String;
      final batchNumber = widget.booking['batch_number'];
      final qty = _originalQuantity;

      // 1. Bestände zurückrechnen
      batch.update(
        firestore.collection('production').doc(_productId),
        {
          'quantity': FieldValue.increment(-qty),
          'last_stock_change': -qty,
          'last_stock_entry': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        firestore.collection('inventory').doc(_shortBarcode),
        {
          'quantity': FieldValue.increment(-qty),
          'last_stock_change': -qty,
          'last_stock_entry': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2. Flachen Eintrag löschen
      batch.delete(firestore.collection('production_batches').doc(docId));

      // 3. Charge in der Subcollection löschen
      if (batchNumber != null) {
        batch.delete(
          firestore
              .collection('production')
              .doc(_productId)
              .collection('batch')
              .doc(batchNumber.toString().padLeft(4, '0')),
        );
      }

      // 4. Storno in der History dokumentieren
      batch.set(
        firestore.collection('stock_entries').doc(),
        {
          ..._historyBase(),
          'quantity_change': -qty,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'storno',
          'entry_type': 'storno',
        },
      );

      await batch.commit();

      if (!mounted) return;
      AppToast.show(message: 'Buchung storniert', height: h);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.show(message: 'Fehler beim Stornieren: $e', height: h);
    }
  }

  // ─── Helfer ───────────────────────────────────────────────────────────
  Map<String, dynamic> _historyBase() => {
    'product_id': _productId,
    'batch_number': widget.booking['batch_number'],
    'product_name':
    '${widget.booking['instrument_name'] ?? ''} ${widget.booking['part_name'] ?? ''}'
        .trim(),
    'instrument_name': widget.booking['instrument_name'],
    'part_name': widget.booking['part_name'],
    'wood_name': widget.booking['wood_name'],
    'quality_name': widget.booking['quality_name'],
    'roundwood_id': widget.booking['roundwood_id'],
    'roundwood_internal_number':
    widget.booking['roundwood_internal_number'],
  };

  DateTime _bookingDate() {
    final rawDate = widget.booking['stock_entry_date'];
    if (rawDate != null) {
      try {
        return (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    return _selectedDate;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ─── UI ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}.'
        '${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: getAdaptiveIcon(
                  iconName: 'edit_note',
                  defaultIcon: Icons.edit_note,
                  color: _kAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Buchung bearbeiten',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _kAccent,
                      ),
                    ),
                    Text(
                      '${widget.booking['instrument_name'] ?? ''} ${widget.booking['part_name'] ?? ''}'
                          .trim(),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Schließen',
                icon: getAdaptiveIcon(
                  iconName: 'close',
                  defaultIcon: Icons.close,
                  color: Colors.grey[600],
                ),
                onPressed:
                _isSaving ? null : () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Menge
                Text(
                  'Menge',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    suffixText: widget.booking['unit'] ?? 'Stk',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // Datum
                Text(
                  'Buchungsdatum',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isSaving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'calendar_today',
                          defaultIcon: Icons.calendar_today,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(dateStr, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Hinweis
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kAccent.withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'info_outline',
                        defaultIcon: Icons.info_outline,
                        color: _kAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Eine Mengenänderung passt den Lagerbestand '
                              'automatisch an.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Speichern
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : getAdaptiveIcon(
                      iconName: 'save',
                      defaultIcon: Icons.save,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text('Speichern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Stornieren
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _confirmAndCancel,
                    icon: getAdaptiveIcon(
                      iconName: 'delete_outline',
                      defaultIcon: Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    label: const Text('Buchung stornieren'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}