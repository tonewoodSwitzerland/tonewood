// lib/home/quotes/extend_quote_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Dialog zum Verlängern eines abgelaufenen Angebots.
/// Gibt `true` zurück wenn erfolgreich verlängert wurde, sonst `null`.
class ExtendQuoteDialog extends StatefulWidget {
  final String quoteId;
  final DateTime currentValidUntil;

  const ExtendQuoteDialog({
    Key? key,
    required this.quoteId,
    required this.currentValidUntil,
  }) : super(key: key);

  /// Zeigt den Dialog an und gibt `true` zurück wenn verlängert wurde.
  static Future<bool?> show(
      BuildContext context, {
        required String quoteId,
        required DateTime currentValidUntil,
      }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ExtendQuoteDialog(
        quoteId: quoteId,
        currentValidUntil: currentValidUntil,
      ),
    );
  }

  @override
  State<ExtendQuoteDialog> createState() => _ExtendQuoteDialogState();
}

class _ExtendQuoteDialogState extends State<ExtendQuoteDialog> {
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default: 14 Tage ab heute
    _selectedDate = DateTime.now().add(const Duration(days: 14));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('de', 'DE'),
    );
    if (picked != null) {
      setState(() {
        // Setze auf Ende des Tages (23:59:59)
        _selectedDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quoteId)
          .update({
        'validUntil': Timestamp.fromDate(_selectedDate),
      });

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Verlängern: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);
    final daysFromNow = _selectedDate.difference(DateTime.now()).inDays;

    return AlertDialog(
      title: const Text('Angebot verlängern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bisherige Frist: ${DateFormat('dd.MM.yyyy').format(widget.currentValidUntil)}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Neue Angebotsfrist:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _isSaving ? null : _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    '(in $daysFromNow Tagen)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Schnellauswahl-Chips
          Wrap(
            spacing: 8,
            children: [14, 30, 60].map((days) {
              final isSelected = _selectedDate.difference(DateTime.now()).inDays == days;
              return ActionChip(
                label: Text('$days Tage'),
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                onPressed: _isSaving
                    ? null
                    : () {
                  setState(() {
                    final d = DateTime.now().add(Duration(days: days));
                    _selectedDate = DateTime(d.year, d.month, d.day, 23, 59, 59);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.update, size: 18),
          label: Text(_isSaving ? 'Speichern...' : 'Verlängern'),
        ),
      ],
    );
  }
}