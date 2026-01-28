// File: lib/services/order_configuration_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/additional_text_manager.dart';
import '../services/icon_helper.dart';
import '../services/pdf_generators/invoice_generator.dart';
import '../services/preview_pdf_viewer_screen.dart';
import '../services/swiss_rounding.dart';

class OrderConfigurationSheet extends StatefulWidget {
  // Flexibel: Entweder Quote-Daten ODER Order-Daten übergeben
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> calculations;
  final Map<String, dynamic> metadata;
  final String documentNumber; // Quote- oder Order-Nummer
  final Map<String, dynamic>? existingInvoiceSettings; // NEU: Für Order-Bearbeitung
  final Map<String, dynamic>? costCenter;
  final Map<String, dynamic>? fair;

  const OrderConfigurationSheet({
    super.key,
    required this.customer,
    required this.items,
    required this.calculations,
    required this.metadata,
    required this.documentNumber,
    this.existingInvoiceSettings,
    this.costCenter,
    this.fair,
  });

  @override
  State<OrderConfigurationSheet> createState() => _OrderConfigurationSheetState();
}

class _OrderConfigurationSheetState extends State<OrderConfigurationSheet> {
  final ValueNotifier<bool> _additionalTextsSelectedNotifier = ValueNotifier<bool>(false);

  Map<String, dynamic> _invoiceSettings = {
    'invoice_date': DateTime.now(),
    'down_payment_amount': 0.0,
    'down_payment_reference': '',
    'down_payment_date': null,
    'show_dimensions': false,
    'is_full_payment': false,
    'payment_method': 'BAR',
    'custom_payment_method': '',
    'payment_term_days': 30,
  };

  Map<String, bool> _roundingSettings = {'CHF': true, 'EUR': false, 'USD': false};

  final _downPaymentController = TextEditingController();
  final _referenceController = TextEditingController();
  final _customPaymentController = TextEditingController();
  DateTime? _downPaymentDate;
  DateTime? _invoiceDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadExistingSettings();
    _checkAdditionalTexts();
    _loadRoundingSettings();
  }

  void _loadExistingSettings() {
    if (widget.existingInvoiceSettings != null) {
      final existing = widget.existingInvoiceSettings!;

      _invoiceSettings = {
        'invoice_date': existing['invoice_date'] ?? DateTime.now(),
        'down_payment_amount': (existing['down_payment_amount'] as num?)?.toDouble() ?? 0.0,
        'down_payment_reference': existing['down_payment_reference'] ?? '',
        'down_payment_date': existing['down_payment_date'],
        'show_dimensions': existing['show_dimensions'] ?? false,
        'is_full_payment': existing['is_full_payment'] ?? false,
        'payment_method': existing['payment_method'] ?? 'BAR',
        'custom_payment_method': existing['custom_payment_method'] ?? '',
        'payment_term_days': existing['payment_term_days'] ?? 30,
      };

      _downPaymentController.text = _invoiceSettings['down_payment_amount'] > 0
          ? _invoiceSettings['down_payment_amount'].toString()
          : '';
      _referenceController.text = _invoiceSettings['down_payment_reference'] ?? '';
      _customPaymentController.text = _invoiceSettings['custom_payment_method'] ?? '';
      _downPaymentDate = _invoiceSettings['down_payment_date'];
      _invoiceDate = _invoiceSettings['invoice_date'];
    }
  }

  Future<void> _checkAdditionalTexts() async {
    final hasTexts = await AdditionalTextsManager.hasTextsSelected();
    _additionalTextsSelectedNotifier.value = hasTexts;
  }

  Future<void> _loadRoundingSettings() async {
    final settings = await SwissRounding.loadRoundingSettings();
    setState(() {
      _roundingSettings = settings;
    });
  }

  double _convertPrice(num priceInCHF) {
    final price = priceInCHF.toDouble();
    final currency = widget.metadata['currency'] ?? 'CHF';

    double convertedPrice = price;
    if (currency != 'CHF') {
      final exchangeRates = widget.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
      final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;
      convertedPrice = price * rate;
    }

    if (_roundingSettings[currency] == true) {
      convertedPrice = SwissRounding.round(
        convertedPrice,
        currency: currency,
        roundingSettings: _roundingSettings,
      );
    }

    return convertedPrice;
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.metadata['currency'] ?? 'CHF';
    final total = _convertPrice(widget.calculations['total'] ?? 0);

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

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'settings',
                    defaultIcon: Icons.settings,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingInvoiceSettings != null
                            ? 'Rechnungseinstellungen'
                            : 'Auftragseinstellungen',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        widget.documentNumber,
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
            ),
          ),

          const Divider(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info-Box (nur bei Neuanlage, nicht bei Bearbeitung)
                  if (widget.existingInvoiceSettings == null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          getAdaptiveIcon(
                            iconName: 'info',
                            defaultIcon: Icons.info,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Alle weiteren Dokumente werden im Auftragsbereich erstellt',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Zusatztexte Section
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          showAdditionalTextsBottomSheet(
                            context,
                            textsSelectedNotifier: _additionalTextsSelectedNotifier,
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              getAdaptiveIcon(
                                iconName: 'text_fields',
                                defaultIcon: Icons.text_fields,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Zusatztexte konfigurieren',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _additionalTextsSelectedNotifier,
                                      builder: (context, hasTexts, child) {
                                        return Text(
                                          hasTexts
                                              ? 'Zusatztexte ausgewählt'
                                              : 'Keine Zusatztexte ausgewählt',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasTexts
                                                ? Colors.green[700]
                                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              getAdaptiveIcon(
                                iconName: 'arrow_forward',
                                defaultIcon: Icons.arrow_forward,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Rechnungsdatum
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('de', 'DE'),
                      );
                      if (picked != null) {
                        setState(() {
                          _invoiceDate = picked;
                          _invoiceSettings['invoice_date'] = picked;
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
                                  _invoiceDate != null
                                      ? DateFormat('dd.MM.yyyy').format(_invoiceDate!)
                                      : DateFormat('dd.MM.yyyy').format(DateTime.now()),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Toggle: Anzahlung vs 100% Vorauskasse
                  Container(
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
                                _invoiceSettings['is_full_payment'] = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_invoiceSettings['is_full_payment']
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Anzahlung',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_invoiceSettings['is_full_payment']
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: !_invoiceSettings['is_full_payment']
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _invoiceSettings['is_full_payment'] = true;
                                _invoiceSettings['down_payment_amount'] = total;
                                _downPaymentController.text = total.toStringAsFixed(2);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _invoiceSettings['is_full_payment']
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '100% Vorauskasse',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _invoiceSettings['is_full_payment']
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: _invoiceSettings['is_full_payment']
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Gesamtbetrag
                  Container(
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
                  ),

                  const SizedBox(height: 24),

                  // Bedingte Anzeige je nach Zahlungsart
                  if (_invoiceSettings['is_full_payment']) ...[
                    // 100% Vorkasse
                    _buildFullPaymentSection(currency, total),
                  ] else ...[
                    // Anzahlung
                    _buildDownPaymentSection(currency, total),
                  ],
                ],
              ),
            ),
          ),

          // Vorschau-Button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _showInvoicePreview,
                icon: getAdaptiveIcon(iconName: 'visibility', defaultIcon: Icons.visibility),
                label: const Text('Rechnung Vorschau'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Actions
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
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
                  child: ElevatedButton(
                    onPressed: _saveAndClose,
                    child: const Text('Speichern'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPaymentSection(String currency, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zahlungsmethode',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            ChoiceChip(
              label: const Text('BAR'),
              selected: _invoiceSettings['payment_method'] == 'BAR',
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _invoiceSettings['payment_method'] = 'BAR';
                    _invoiceSettings['custom_payment_method'] = '';
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text('Überweisung'),
              selected: _invoiceSettings['payment_method'] == 'TRANSFER',
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _invoiceSettings['payment_method'] = 'TRANSFER';
                    _invoiceSettings['custom_payment_method'] = '';
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text('Kreditkarte'),
              selected: _invoiceSettings['payment_method'] == 'CREDIT_CARD',
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _invoiceSettings['payment_method'] = 'CREDIT_CARD';
                    _invoiceSettings['custom_payment_method'] = '';
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text('PayPal'),
              selected: _invoiceSettings['payment_method'] == 'PAYPAL',
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _invoiceSettings['payment_method'] = 'PAYPAL';
                    _invoiceSettings['custom_payment_method'] = '';
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text('Andere'),
              selected: _invoiceSettings['payment_method'] == 'custom',
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _invoiceSettings['payment_method'] = 'custom';
                  });
                }
              },
            ),
          ],
        ),

        if (_invoiceSettings['payment_method'] == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customPaymentController,
            decoration: InputDecoration(
              labelText: 'Zahlungsmethode eingeben',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: getAdaptiveIcon(
                  iconName: 'payment',
                  defaultIcon: Icons.payment,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              _invoiceSettings['custom_payment_method'] = value;
            },
          ),
        ],

        const SizedBox(height: 16),

        // Zahlungsdatum
        _buildDatePicker(
          label: 'Zahlungsdatum',
          value: _downPaymentDate,
          onChanged: (date) {
            setState(() {
              _downPaymentDate = date;
              _invoiceSettings['down_payment_date'] = date;
              _invoiceSettings['full_payment_date'] = date;
            });
          },
        ),

        const SizedBox(height: 16),

        // Vorschau
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                  Text('Bezahlt per ${_getPaymentMethodLabel()}:'),
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
                  const Text(
                    'Restbetrag:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$currency 0.00',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownPaymentSection(String currency, double total) {
    final downPayment = _invoiceSettings['down_payment_amount'] as double? ?? 0.0;
    final remaining = total - downPayment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Anzahlung Betrag
        TextField(
          controller: _downPaymentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Anzahlung BRUTTO ($currency)',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: getAdaptiveIcon(
                iconName: 'payments',
                defaultIcon: Icons.payments,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            helperText: 'Betrag der bereits geleisteten Anzahlung',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (value) {
            setState(() {
              _invoiceSettings['down_payment_amount'] = double.tryParse(value) ?? 0.0;
            });
          },
        ),

        const SizedBox(height: 16),

        // Belegnummer
        TextField(
          controller: _referenceController,
          decoration: InputDecoration(
            labelText: 'Belegnummer / Notiz',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: getAdaptiveIcon(
                iconName: 'description',
                defaultIcon: Icons.description,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            helperText: 'z.B. Anzahlung AR-2025-0004 vom 15.05.2025',
          ),
          onChanged: (value) {
            _invoiceSettings['down_payment_reference'] = value;
          },
        ),

        const SizedBox(height: 16),

        // Datum der Anzahlung
        _buildDatePicker(
          label: 'Datum der Anzahlung',
          value: _downPaymentDate,
          onChanged: (date) {
            setState(() {
              _downPaymentDate = date;
              _invoiceSettings['down_payment_date'] = date;
            });
          },
        ),

        const SizedBox(height: 24),

        // Zahlungsziel
        Text(
          'Zahlungsziel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
                groupValue: _invoiceSettings['payment_term_days'],
                onChanged: (value) {
                  setState(() {
                    _invoiceSettings['payment_term_days'] = value;
                  });
                },
              ),
              RadioListTile<int>(
                title: const Text('14 Tage'),
                value: 14,
                groupValue: _invoiceSettings['payment_term_days'],
                onChanged: (value) {
                  setState(() {
                    _invoiceSettings['payment_term_days'] = value;
                  });
                },
              ),
              RadioListTile<int>(
                title: const Text('30 Tage'),
                value: 30,
                groupValue: _invoiceSettings['payment_term_days'],
                onChanged: (value) {
                  setState(() {
                    _invoiceSettings['payment_term_days'] = value;
                  });
                },
              ),
            ],
          ),
        ),

        // Vorschau (nur wenn Anzahlung > 0)
        if (downPayment > 0) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                      '- $currency ${downPayment.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Restbetrag:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required Function(DateTime?) onChanged,
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
        if (picked != null) {
          onChanged(picked);
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
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              IconButton(
                icon: getAdaptiveIcon(
                  iconName: 'clear',
                  defaultIcon: Icons.clear,
                ),
                onPressed: () => onChanged(null),
              ),
          ],
        ),
      ),
    );
  }

  String _getPaymentMethodLabel() {
    switch (_invoiceSettings['payment_method']) {
      case 'BAR':
        return 'BAR';
      case 'TRANSFER':
        return 'Überweisung';
      case 'CREDIT_CARD':
        return 'Kreditkarte';
      case 'PAYPAL':
        return 'PayPal';
      case 'custom':
        return _customPaymentController.text.isNotEmpty
            ? _customPaymentController.text
            : 'Andere';
      default:
        return 'BAR';
    }
  }

  Future<void> _showInvoicePreview() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();

      final previewInvoiceSettings = {
        'invoice_date': _invoiceDate,
        'down_payment_amount': double.tryParse(_downPaymentController.text) ?? 0.0,
        'down_payment_reference': _referenceController.text,
        'down_payment_date': _downPaymentDate,
        'show_dimensions': _invoiceSettings['show_dimensions'] ?? false,
        'is_full_payment': _invoiceSettings['is_full_payment'] ?? false,
        'payment_method': _invoiceSettings['payment_method'] ?? 'BAR',
        'custom_payment_method': _invoiceSettings['custom_payment_method'] ?? '',
        'payment_term_days': _invoiceSettings['payment_term_days'] ?? 30,
      };

      final rawExchangeRates = widget.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
      final exchangeRates = <String, double>{'CHF': 1.0};
      rawExchangeRates.forEach((key, value) {
        if (value != null) {
          exchangeRates[key] = (value as num).toDouble();
        }
      });

      final safeCalculations = <String, dynamic>{};
      widget.calculations.forEach((key, value) {
        if (value is num) {
          safeCalculations[key] = value.toDouble();
        } else {
          safeCalculations[key] = value;
        }
      });

      final roundingSettings = await SwissRounding.loadRoundingSettings();

      final pdfBytes = await InvoiceGenerator.generateInvoicePdf(
        items: widget.items,
        customerData: widget.customer,
        fairData: widget.fair,
        costCenterCode: widget.costCenter?['code'] ?? '00000',
        currency: widget.metadata['currency'] ?? 'CHF',
        exchangeRates: exchangeRates,
        language: widget.customer['language'] ?? 'DE',
        invoiceNumber: 'PREVIEW',
        shippingCosts: widget.metadata['shippingCosts'] as Map<String, dynamic>?,
        calculations: safeCalculations,
        paymentTermDays: _invoiceSettings['payment_term_days'] ?? 30,
        taxOption: widget.metadata['taxOption'] ?? 0,
        vatRate: (widget.metadata['vatRate'] as num?)?.toDouble() ?? 8.1,
        downPaymentSettings: previewInvoiceSettings,
        additionalTexts: additionalTexts,
        roundingSettings: roundingSettings,
      );

      if (mounted) {
        Navigator.pop(context); // Loading schließen

        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (bottomSheetContext) => Container(
            height: MediaQuery.of(context).size.height * 0.95,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'picture_as_pdf',
                        defaultIcon: Icons.picture_as_pdf,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rechnung Vorschau',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: PreviewPDFViewerScreen(
                    pdfBytes: pdfBytes,
                    title: 'Rechnung Vorschau',
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Fehler bei der Vorschau: $e');
      print('StackTrace:\n$stackTrace');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveAndClose() async {
    _invoiceSettings['invoice_date'] = _invoiceDate;
    _invoiceSettings['down_payment_date'] = _downPaymentDate;
    _invoiceSettings['down_payment_amount'] = double.tryParse(_downPaymentController.text) ?? 0.0;
    _invoiceSettings['down_payment_reference'] = _referenceController.text;
    _invoiceSettings['custom_payment_method'] = _customPaymentController.text;

    final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();

    Navigator.pop(context, {
      'additionalTexts': additionalTexts,
      'invoiceSettings': _invoiceSettings,
    });
  }

  @override
  void dispose() {
    _downPaymentController.dispose();
    _referenceController.dispose();
    _customPaymentController.dispose();
    _additionalTextsSelectedNotifier.dispose();
    super.dispose();
  }
}