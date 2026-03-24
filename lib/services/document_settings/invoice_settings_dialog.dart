// File: services/document_settings/invoice_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/icon_helper.dart';
import '../../services/swiss_rounding.dart';
import 'document_settings_provider.dart';

/// Gemeinsamer Rechnungs-Einstellungen Dialog.
///
/// Wird sowohl im Auftrags- als auch im Angebotsbereich verwendet.
/// Der [DocumentSettingsProvider] bestimmt, wohin die Daten gespeichert werden.
class InvoiceSettingsDialog extends StatefulWidget {
  final DocumentSettingsProvider provider;
  final Map<String, dynamic> initialSettings;

  /// Vorberechneter Bruttobetrag (inkl. MwSt, Versand, Rabatte)
  final double totalAmount;

  /// Währung (CHF, EUR, USD)
  final String currency;

  /// Callback wenn gespeichert wurde
  final void Function(Map<String, dynamic> settings)? onSaved;

  const InvoiceSettingsDialog({
    super.key,
    required this.provider,
    required this.initialSettings,
    required this.totalAmount,
    this.currency = 'CHF',
    this.onSaved,
  });

  /// Convenience-Methode: Lädt Settings und zeigt den Dialog.
  static Future<void> show(
    BuildContext context, {
    required DocumentSettingsProvider provider,
    required double totalAmount,
    String currency = 'CHF',
    Map<String, dynamic>? initialSettings,
    void Function(Map<String, dynamic> settings)? onSaved,
  }) async {
    final settings = initialSettings ?? await provider.loadInvoiceSettings();

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvoiceSettingsDialog(
        provider: provider,
        initialSettings: settings,
        totalAmount: totalAmount,
        currency: currency,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<InvoiceSettingsDialog> createState() => _InvoiceSettingsDialogState();
}

class _InvoiceSettingsDialogState extends State<InvoiceSettingsDialog> {
  // State
  DateTime? invoiceDate;
  double downPaymentAmount = 0.0;
  String downPaymentReference = '';
  DateTime? downPaymentDate;
  DateTime? fullPaymentDate;
  bool showDimensions = false;
  bool isFullPayment = false;
  String paymentMethod = 'BAR';
  String customPaymentMethod = '';
  int paymentTermDays = 30;

  // Controllers
  late TextEditingController downPaymentController;
  late TextEditingController referenceController;
  late TextEditingController customPaymentController;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;

    invoiceDate = s['invoice_date'] ?? DateTime.now();
    downPaymentAmount = (s['down_payment_amount'] as num?)?.toDouble() ?? 0.0;
    downPaymentReference = s['down_payment_reference'] ?? '';
    downPaymentDate = s['down_payment_date'];
    showDimensions = s['show_dimensions'] ?? false;
    isFullPayment = s['is_full_payment'] ?? false;
    paymentMethod = s['payment_method'] ?? 'BAR';
    customPaymentMethod = s['custom_payment_method'] ?? '';
    paymentTermDays = s['payment_term_days'] ?? 30;

    downPaymentController = TextEditingController(
      text: downPaymentAmount > 0 ? downPaymentAmount.toString() : '',
    );
    referenceController = TextEditingController(text: downPaymentReference);
    customPaymentController = TextEditingController(text: customPaymentMethod);
  }

  @override
  void dispose() {
    downPaymentController.dispose();
    referenceController.dispose();
    customPaymentController.dispose();
    super.dispose();
  }

  String _getPaymentMethodLabel(String method, String custom) {
    switch (method) {
      case 'BAR':
        return 'BAR';
      case 'TRANSFER':
        return 'Überweisung';
      case 'CREDIT_CARD':
        return 'Kreditkarte';
      case 'PAYPAL':
        return 'PayPal';
      case 'custom':
        return custom.isNotEmpty ? custom : 'Andere';
      default:
        return method;
    }
  }

  Future<void> _save() async {
    final settings = <String, dynamic>{
      'invoice_date': invoiceDate,
      'down_payment_amount': isFullPayment ? widget.totalAmount : downPaymentAmount,
      'down_payment_reference': downPaymentReference,
      'down_payment_date': isFullPayment ? fullPaymentDate : downPaymentDate,
      'show_dimensions': showDimensions,
      'is_full_payment': isFullPayment,
      'payment_method': paymentMethod,
      'custom_payment_method': customPaymentMethod,
      'payment_term_days': paymentTermDays,
    };

    await widget.provider.saveInvoiceSettings(settings);
    widget.onSaved?.call(settings);

    if (mounted) Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = widget.currency;
    final total = widget.totalAmount;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context),
                  const SizedBox(height: 24),

                  // Rechnungsdatum
                  _buildInvoiceDatePicker(context),
                  const SizedBox(height: 20),

                  // Toggle: Anzahlung vs 100% Vorauskasse
                  _buildPaymentToggle(context, total),
                  const SizedBox(height: 24),

                  // Bruttobetrag
                  _buildTotalDisplay(context, currency, total),
                  const SizedBox(height: 24),

                  // Bedingte Anzeige je nach Zahlungsart
                  if (isFullPayment)
                    _buildFullPaymentSection(context, currency, total)
                  else
                    _buildDownPaymentSection(context, currency, total),

                  // Maße anzeigen
                  const SizedBox(height: 16),
                  _buildShowDimensionsCheckbox(context),

                  const SizedBox(height: 32),

                  // Actions
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // UI-Bausteine
  // ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: getAdaptiveIcon(
            iconName: 'receipt',
            defaultIcon: Icons.receipt,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rechnungseinstellungen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                widget.provider.contextLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
        ),
      ],
    );
  }

  Widget _buildInvoiceDatePicker(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: invoiceDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('de', 'DE'),
        );
        if (picked != null) {
          setState(() => invoiceDate = picked);
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
              iconName: 'calendar_today',
              defaultIcon: Icons.calendar_today,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rechnungsdatum',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    invoiceDate != null
                        ? DateFormat('dd.MM.yyyy').format(invoiceDate!)
                        : DateFormat('dd.MM.yyyy').format(DateTime.now()),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentToggle(BuildContext context, double total) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isFullPayment = false;
                  downPaymentAmount = 0.0;
                  downPaymentController.text = '';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isFullPayment
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Anzahlung',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !isFullPayment
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        !isFullPayment ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isFullPayment = true;
                  downPaymentAmount = double.parse(total.toStringAsFixed(2));
                  downPaymentController.text = downPaymentAmount.toStringAsFixed(2);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isFullPayment
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '100% Vorauskasse',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isFullPayment
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isFullPayment ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalDisplay(BuildContext context, String currency, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Bruttobetrag',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            '$currency ${total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 100% Vorkasse ──

  Widget _buildFullPaymentSection(
      BuildContext context, String currency, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zahlungsmethode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildPaymentMethodChips(context),
        if (paymentMethod == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: customPaymentController,
            decoration: InputDecoration(
              labelText: 'Zahlungsmethode eingeben',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: getAdaptiveIcon(
                    iconName: 'payment', defaultIcon: Icons.payment),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (value) => customPaymentMethod = value,
          ),
        ],
        const SizedBox(height: 16),

        // Zahlungsdatum
        _buildDatePicker(
          label: 'Zahlungsdatum',
          value: fullPaymentDate,
          onChanged: (date) => setState(() => fullPaymentDate = date),
        ),
        const SizedBox(height: 16),

        // Vorschau
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bruttobetrag:'),
                  Text('$currency ${total.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'Bezahlt per ${_getPaymentMethodLabel(paymentMethod, customPaymentMethod)}:'),
                  Text(
                    '- $currency ${total.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Restbetrag:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$currency 0.00',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Anzahlung ──

  Widget _buildDownPaymentSection(
      BuildContext context, String currency, double total) {
    final remaining = total - downPaymentAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Betrag
        TextField(
          controller: downPaymentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Anzahlung BRUTTO ($currency)',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(4.0),
              child: getAdaptiveIcon(
                  iconName: 'payments', defaultIcon: Icons.payments),
            ),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            helperText: 'Betrag der bereits geleisteten Anzahlung',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (value) {
            setState(() {
              final parsed = double.tryParse(value) ?? 0.0;
              downPaymentAmount = double.parse(parsed.toStringAsFixed(2));
            });
          },
        ),
        const SizedBox(height: 16),

        // Belegnummer
        TextField(
          controller: referenceController,
          decoration: InputDecoration(
            labelText: 'Belegnummer / Notiz',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: getAdaptiveIcon(
                  iconName: 'description', defaultIcon: Icons.description),
            ),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            helperText: 'z.B. Anzahlung AR-2025-0004 vom 15.05.2025',
          ),
          onChanged: (value) => downPaymentReference = value,
        ),
        const SizedBox(height: 16),

        // Datum der Anzahlung
        _buildDatePicker(
          label: 'Datum der Anzahlung',
          value: downPaymentDate,
          onChanged: (date) => setState(() => downPaymentDate = date),
        ),
        const SizedBox(height: 24),

        // Zahlungsziel
        Text('Zahlungsziel', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              RadioListTile<int>(
                title: const Text('10 Tage'),
                value: 10,
                groupValue: paymentTermDays,
                onChanged: (v) => setState(() => paymentTermDays = v!),
              ),
              RadioListTile<int>(
                title: const Text('14 Tage'),
                value: 14,
                groupValue: paymentTermDays,
                onChanged: (v) => setState(() => paymentTermDays = v!),
              ),
              RadioListTile<int>(
                title: const Text('30 Tage'),
                value: 30,
                groupValue: paymentTermDays,
                onChanged: (v) => setState(() => paymentTermDays = v!),
              ),
            ],
          ),
        ),

        // Vorschau (nur wenn Anzahlung > 0)
        if (downPaymentAmount > 0) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bruttobetrag:'),
                    Text('$currency ${total.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Anzahlung:'),
                    Text(
                      '- $currency ${downPaymentAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Restbetrag:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '$currency ${remaining.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Shared Widgets ──

  Widget _buildPaymentMethodChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: [
        _chip('BAR', 'BAR'),
        _chip('TRANSFER', 'Überweisung'),
        _chip('CREDIT_CARD', 'Kreditkarte'),
        _chip('PAYPAL', 'PayPal'),
        _chip('custom', 'Andere'),
      ],
    );
  }

  Widget _chip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: paymentMethod == value,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            paymentMethod = value;
            if (value != 'custom') customPaymentMethod = '';
          });
        }
      },
    );
  }

  Widget _buildShowDimensionsCheckbox(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        title: const Text('Maße anzeigen'),
        subtitle: const Text(
          'Zeigt die Spalte "Maße" (Länge×Breite×Dicke) in der Rechnung an',
          style: TextStyle(fontSize: 12),
        ),
        value: showDimensions,
        onChanged: (value) {
          setState(() => showDimensions = value ?? false);
        },
        secondary: getAdaptiveIcon(
          iconName: 'straighten',
          defaultIcon: Icons.straighten,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          locale: const Locale('de', 'DE'),
        );
        if (picked != null) onChanged(picked);
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
              iconName: 'calendar_today',
              defaultIcon: Icons.calendar_today,
            ),
            const SizedBox(width: 12),
            Expanded(
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
                  Text(
                    value != null
                        ? DateFormat('dd.MM.yyyy').format(value)
                        : 'Datum auswählen',
                    style: TextStyle(
                      fontSize: 16,
                      color: value == null
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              IconButton(
                icon: getAdaptiveIcon(
                    iconName: 'clear', defaultIcon: Icons.clear),
                onPressed: () => onChanged(null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
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
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: const Text('Speichern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
