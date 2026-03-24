// File: services/document_settings/delivery_note_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/services/document_settings/quote_settings_provider.dart';
import '../../services/icon_helper.dart';
import 'document_settings_provider.dart';
import 'order_settings_provider.dart';

/// Gemeinsamer Lieferschein-Einstellungen Dialog.
/// 
/// Wird sowohl im Auftrags- als auch im Angebotsbereich verwendet.
/// Der [DocumentSettingsProvider] bestimmt, wohin die Daten gespeichert werden.
/// 
/// Verwendung:
/// ```dart
/// await DeliveryNoteSettingsDialog.show(
///   context,
///   provider: myProvider,
///   onSaved: (settings) {
///     setState(() {
///       _settings['delivery_note'] = settings;
///     });
///   },
/// );
/// ```
class DeliveryNoteSettingsDialog extends StatefulWidget {
  final DocumentSettingsProvider provider;
  final Map<String, dynamic> initialDeliveryNoteSettings;
  final Map<String, dynamic>? commercialInvoiceSettings;
  final DateTime? existingCommercialInvoiceDate;
  final bool deliveryDateExplicitlyManaged;

  /// Callback wenn gespeichert wurde. Gibt die neuen Settings zurück.
  final void Function(Map<String, dynamic> settings)? onSaved;

  const DeliveryNoteSettingsDialog({
    super.key,
    required this.provider,
    required this.initialDeliveryNoteSettings,
    this.commercialInvoiceSettings,
    this.existingCommercialInvoiceDate,
    this.deliveryDateExplicitlyManaged = false,
    this.onSaved,
  });

  /// Convenience-Methode: Lädt alle nötigen Daten und zeigt den Dialog.
  static Future<void> show(
    BuildContext context, {
    required DocumentSettingsProvider provider,
    Map<String, dynamic>? initialDeliveryNoteSettings,
    Map<String, dynamic>? commercialInvoiceSettings,
    void Function(Map<String, dynamic> settings)? onSaved,
  }) async {
    // Lade Settings parallel
    final futures = await Future.wait([
      initialDeliveryNoteSettings != null
          ? Future.value(initialDeliveryNoteSettings)
          : provider.loadDeliveryNoteSettings(),
      provider.hasExistingDeliveryNoteSettings(),
      provider.loadCommercialInvoiceDate(),
    ]);

    final deliverySettings = futures[0] as Map<String, dynamic>;
    final explicitlyManaged = futures[1] as bool;
    final existingCIDate = futures[2] as DateTime?;

    // Wenn Lieferdatum noch nie gesetzt wurde, aus HR vorbelegen
    Map<String, dynamic> effectiveSettings = Map.from(deliverySettings);
    if (effectiveSettings['delivery_date'] == null && !explicitlyManaged) {
      // Versuche HR-Datum als Vorbelegung
      if (commercialInvoiceSettings != null &&
          commercialInvoiceSettings['commercial_invoice_date'] != null) {
        effectiveSettings['delivery_date'] =
            commercialInvoiceSettings['commercial_invoice_date'];
      } else if (existingCIDate != null) {
        effectiveSettings['delivery_date'] = existingCIDate;
      }
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeliveryNoteSettingsDialog(
        provider: provider,
        initialDeliveryNoteSettings: effectiveSettings,
        commercialInvoiceSettings: commercialInvoiceSettings,
        existingCommercialInvoiceDate: existingCIDate,
        deliveryDateExplicitlyManaged: explicitlyManaged,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<DeliveryNoteSettingsDialog> createState() =>
      _DeliveryNoteSettingsDialogState();
}

class _DeliveryNoteSettingsDialogState
    extends State<DeliveryNoteSettingsDialog> {
  DateTime? deliveryDate;
  DateTime? paymentDate;
  bool useAsCommercialInvoiceDate = false;

  @override
  void initState() {
    super.initState();
    deliveryDate = widget.initialDeliveryNoteSettings['delivery_date'];
    paymentDate = widget.initialDeliveryNoteSettings['payment_date'];
  }

  // ─────────────────────────────────────────────────────────────────
  // Hilfsfunktionen
  // ─────────────────────────────────────────────────────────────────

  bool _hasDateConflict() {
    if (deliveryDate == null || widget.existingCommercialInvoiceDate == null) {
      return false;
    }
    return deliveryDate!.year != widget.existingCommercialInvoiceDate!.year ||
        deliveryDate!.month != widget.existingCommercialInvoiceDate!.month ||
        deliveryDate!.day != widget.existingCommercialInvoiceDate!.day;
  }

  Future<void> _save() async {
    // 1. Lieferschein-Settings speichern
    await widget.provider.saveDeliveryNoteSettings({
      'delivery_date': deliveryDate,
      'payment_date': paymentDate,
    });

    // 2. Wenn Checkbox aktiv, auch Handelsrechnungsdatum aktualisieren
    if (useAsCommercialInvoiceDate && deliveryDate != null) {
      if (widget.provider is OrderSettingsProvider) {
        await (widget.provider as dynamic).saveCommercialInvoiceDate(deliveryDate!);
      } else if (widget.provider is QuoteSettingsProvider) {
        await (widget.provider as dynamic).saveCommercialInvoiceDate(deliveryDate!);
      } else {
        // Fallback: Über die allgemeine Methode
        final currentSettings =
            await widget.provider.loadCommercialInvoiceSettings();
        currentSettings['commercial_invoice_date'] = deliveryDate;
        await widget.provider.saveCommercialInvoiceSettings(currentSettings);
      }
    }

    // 3. Callback
    final savedSettings = <String, dynamic>{
      'delivery_date': deliveryDate,
      'payment_date': paymentDate,
    };
    widget.onSaved?.call(savedSettings);

    if (mounted) Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'local_shipping',
                  defaultIcon: Icons.local_shipping,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Lieferschein Einstellungen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: getAdaptiveIcon(
                    iconName: 'close',
                    defaultIcon: Icons.close,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Scrollbarer Bereich
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // ── Lieferdatum ──
                          _buildDatePickerSection(
                            label: 'Lieferdatum',
                            iconName: 'calendar_today',
                            defaultIcon: Icons.calendar_today,
                            date: deliveryDate,
                            onDateChanged: (date) =>
                                setState(() => deliveryDate = date),
                          ),

                          const SizedBox(height: 8),

                          // ── Checkbox: Als HR-Datum übernehmen ──
                          _buildCommercialInvoiceDateCheckbox(),

                          // ── Grüner Hinweis wenn aktiv ──
                          if (useAsCommercialInvoiceDate &&
                              deliveryDate != null)
                            _buildConfirmationBanner(),

                          // ── Warnung bei Datumskonflikt ──
                          if (_hasDateConflict())
                            _buildDateConflictWarning(),

                          const SizedBox(height: 16),

                          // ── Adressdaten abgleichen (nur Orders) ──
                          if (widget.provider.supportsCustomerAddressCompare)
                            _buildCustomerAddressCompareButton(),

                          if (widget.provider.supportsCustomerAddressCompare)
                            const SizedBox(height: 16),

                          // ── Zahlungsdatum ──
                          _buildDatePickerSection(
                            label: 'Zahlungsdatum',
                            iconName: 'payment',
                            defaultIcon: Icons.payment,
                            date: paymentDate,
                            onDateChanged: (date) =>
                                setState(() => paymentDate = date),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions – fixiert am unteren Rand
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _save,
                            icon: getAdaptiveIcon(
                              iconName: 'save',
                              defaultIcon: Icons.save,
                            ),
                            label: const Text('Speichern'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Wiederverwendbare UI-Bausteine
  // ─────────────────────────────────────────────────────────────────

  /// Datums-Auswahl Section (Lieferdatum / Zahlungsdatum)
  Widget _buildDatePickerSection({
    required String label,
    required String iconName,
    required IconData defaultIcon,
    required DateTime? date,
    required ValueChanged<DateTime?> onDateChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Datepicker Button
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      locale: const Locale('de', 'DE'),
                    );
                    if (picked != null) {
                      onDateChanged(picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: date != null
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5)
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: iconName,
                          defaultIcon: defaultIcon,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date != null
                              ? DateFormat('dd.MM.yyyy').format(date!)
                              : 'Datum auswählen',
                          style: TextStyle(
                            fontSize: 15,
                            color: date != null
                                ? null
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // "Heute" Schnellbutton
              OutlinedButton(
                onPressed: () => onDateChanged(DateTime.now()),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  side: BorderSide(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  'Heute',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              // Löschen Button (nur wenn Datum gesetzt)
              if (date != null)
                IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'clear',
                    defaultIcon: Icons.clear,
                    size: 18,
                  ),
                  onPressed: () => onDateChanged(null),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Checkbox: "Als Handelsrechnungsdatum übernehmen"
  Widget _buildCommercialInvoiceDateCheckbox() {
    return CheckboxListTile(
      title: const Text('Als Handelsrechnungsdatum übernehmen'),
      subtitle: Text(
        useAsCommercialInvoiceDate && deliveryDate != null
            ? 'Handelsrechnung: ${DateFormat('dd.MM.yyyy').format(deliveryDate!)}'
            : 'Datum wird in der Handelsrechnung verwendet',
        style: TextStyle(
          fontSize: 11,
          color: useAsCommercialInvoiceDate && deliveryDate != null
              ? Colors.green[700]
              : null,
          fontWeight: useAsCommercialInvoiceDate && deliveryDate != null
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      value: useAsCommercialInvoiceDate,
      onChanged: (value) {
        setState(() {
          useAsCommercialInvoiceDate = value ?? false;
        });
      },
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: getAdaptiveIcon(
        iconName: 'receipt_long',
        defaultIcon: Icons.receipt_long,
        size: 20,
        color: useAsCommercialInvoiceDate && deliveryDate != null
            ? Colors.green[700]
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// Grüner Bestätigungs-Banner
  Widget _buildConfirmationBanner() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'check_circle',
              defaultIcon: Icons.check_circle,
              size: 16,
              color: Colors.green[700],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Das Handelsrechnungsdatum wird auf ${DateFormat('dd.MM.yyyy').format(deliveryDate!)} gesetzt',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Orange Warnung bei Datumskonflikt
  Widget _buildDateConflictWarning() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'warning',
              defaultIcon: Icons.warning_amber_rounded,
              size: 20,
              color: Colors.orange[700],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abweichendes Datum in Handelsrechnung',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Handelsrechnung: ${DateFormat('dd.MM.yyyy').format(widget.existingCommercialInvoiceDate!)}\n'
                    'Lieferschein: ${DateFormat('dd.MM.yyyy').format(deliveryDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                    ),
                  ),
                  if (useAsCommercialInvoiceDate)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '→ Handelsrechnungsdatum wird überschrieben',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Button für Adressdaten-Abgleich (nur bei Orders)
  Widget _buildCustomerAddressCompareButton() {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        await widget.provider.onCompareCustomerAddress?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withOpacity(0.1),
        ),
        child: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'sync',
              defaultIcon: Icons.sync,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adressdaten abgleichen',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Mit aktuellen Kundendaten vergleichen',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            getAdaptiveIcon(
              iconName: 'chevron_right',
              defaultIcon: Icons.chevron_right,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
