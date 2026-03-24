// File: services/document_settings/quote_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/icon_helper.dart';
import '../../quotes/quote_doc_selection_manager.dart';

/// Offerte-Einstellungen Dialog (nur im Angebotsbereich).
///
/// Einstellungen: Gültigkeitsdatum, Maße anzeigen, Zahlungshinweis.
class QuoteSettingsDialog {
  /// Zeigt den Offerte-Einstellungen Dialog.
  static Future<void> show(BuildContext context) async {
    // Lade bestehende Einstellungen
    final existingSettings = await DocumentSelectionManager.loadQuoteSettings();
    DateTime? validityDate = existingSettings['validity_date'];
    bool showDimensions = existingSettings['show_dimensions'] ?? false;
    bool showValidityAddition = existingSettings['show_validity_addition'] ?? true;

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: getAdaptiveIcon(
                                iconName: 'request_quote',
                                defaultIcon: Icons.request_quote,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Offerte - Einstellungen',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: getAdaptiveIcon(
                                iconName: 'close',
                                defaultIcon: Icons.close,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Gültigkeitsdatum
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: validityDate ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                              locale: const Locale('de', 'DE'),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                validityDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                getAdaptiveIcon(
                                  iconName: 'event',
                                  defaultIcon: Icons.event,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gültig bis',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        validityDate != null
                                            ? DateFormat('dd.MM.yyyy').format(validityDate!)
                                            : 'Datum auswählen',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                if (validityDate != null)
                                  IconButton(
                                    icon: getAdaptiveIcon(
                                      iconName: 'clear',
                                      defaultIcon: Icons.clear,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        validityDate = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Maße anzeigen
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CheckboxListTile(
                            title: const Text('Maße anzeigen'),
                            subtitle: const Text(
                              'Zeigt die Spalte "Maße" (Länge×Breite×Dicke) in der Offerte an',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: showDimensions,
                            onChanged: (value) {
                              setDialogState(() {
                                showDimensions = value ?? false;
                              });
                            },
                            secondary: getAdaptiveIcon(
                              iconName: 'straighten',
                              defaultIcon: Icons.straighten,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Info-Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              getAdaptiveIcon(
                                iconName: 'info',
                                defaultIcon: Icons.info,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Die Offerte ist standardmäßig 14 Tage gültig. Die Maße-Spalte ist standardmäßig ausgeblendet.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Zahlungshinweis
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CheckboxListTile(
                            title: const Text('Zahlungshinweis anzeigen'),
                            subtitle: const Text(
                              'Zeigt den Hinweis zur Vorauszahlung an (Standard: an für Nicht-CH Kunden)',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: showValidityAddition,
                            onChanged: (value) {
                              setDialogState(() {
                                showValidityAddition = value ?? true;
                              });
                            },
                            secondary: getAdaptiveIcon(
                              iconName: 'payment',
                              defaultIcon: Icons.payment,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Abbrechen'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await DocumentSelectionManager.saveQuoteSettings({
                                    'validity_date': validityDate != null
                                        ? Timestamp.fromDate(validityDate!)
                                        : null,
                                    'show_dimensions': showDimensions,
                                    'show_validity_addition': showValidityAddition,
                                  });

                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Offerten-Einstellungen gespeichert'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: getAdaptiveIcon(
                                  iconName: 'save',
                                  defaultIcon: Icons.save,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                                label: const Text('Speichern'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}