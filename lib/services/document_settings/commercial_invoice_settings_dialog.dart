// File: services/document_settings/commercial_invoice_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/icon_helper.dart';
import '../../services/countries.dart';
import '../../quotes/additional_text_manager.dart';
import 'document_settings_provider.dart';

/// Gemeinsamer Handelsrechnung-Einstellungen Dialog.
///
/// Wird sowohl im Auftrags- als auch im Angebotsbereich verwendet.
/// Der [DocumentSettingsProvider] bestimmt, wohin die Daten gespeichert werden.
class CommercialInvoiceSettingsDialog extends StatefulWidget {
  final DocumentSettingsProvider provider;
  final Map<String, dynamic> initialSettings;
  final Map<String, dynamic> customerData;
  final String defaultCurrency;

  /// Anzahl Pakete & Gewicht aus der Packliste (0 = keine Packliste vorhanden)
  final int packingListPackageCount;
  final double packingListTotalWeight;

  /// Für Datumskonflikt-Warnung mit Lieferschein
  final DateTime? existingDeliveryNoteDate;

  /// Zusatztexte-Konfiguration (wird im Dialog bearbeitet und mitgespeichert)
  final Map<String, dynamic>? additionalTextsConfig;

  /// Callback wenn gespeichert wurde
  final void Function(Map<String, dynamic> settings)? onSaved;

  const CommercialInvoiceSettingsDialog({
    super.key,
    required this.provider,
    required this.initialSettings,
    required this.customerData,
    this.defaultCurrency = 'CHF',
    this.packingListPackageCount = 0,
    this.packingListTotalWeight = 0.0,
    this.existingDeliveryNoteDate,
    this.additionalTextsConfig,
    this.onSaved,
  });

  /// Convenience-Methode: Lädt alle nötigen Daten und zeigt den Dialog.
  static Future<void> show(
    BuildContext context, {
    required DocumentSettingsProvider provider,
    required Map<String, dynamic> customerData,
    Map<String, dynamic>? initialSettings,
    String defaultCurrency = 'CHF',
    Map<String, dynamic>? additionalTextsConfig,
    void Function(Map<String, dynamic> settings)? onSaved,
  }) async {
    // Lade Settings und Packlisten-Daten parallel
    final settings = initialSettings ?? await provider.loadCommercialInvoiceSettings();

    // Lade Packlisten-Infos für Tara-Berechnung
    int packageCount = 0;
    double totalWeight = 0.0;
    final packingListSettings = await provider.loadPackingListSettings();
    final packages = packingListSettings['packages'] as List<dynamic>? ?? [];
    if (packages.isNotEmpty) {
      packageCount = packages.length;
      for (final package in packages) {
        totalWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // Lade Lieferschein-Datum für Datumskonflikt
    final deliverySettings = await provider.loadDeliveryNoteSettings();
    final existingDeliveryDate = deliverySettings['delivery_date'] as DateTime?;

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommercialInvoiceSettingsDialog(
        provider: provider,
        initialSettings: settings,
        customerData: customerData,
        defaultCurrency: defaultCurrency,
        packingListPackageCount: packageCount,
        packingListTotalWeight: totalWeight,
        existingDeliveryNoteDate: existingDeliveryDate,
        additionalTextsConfig: additionalTextsConfig,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<CommercialInvoiceSettingsDialog> createState() =>
      _CommercialInvoiceSettingsDialogState();
}

class _CommercialInvoiceSettingsDialogState
    extends State<CommercialInvoiceSettingsDialog> {
  late Map<String, dynamic> settings;

  // Tara
  late int numberOfPackages;
  late double totalPackagingWeight;

  // Datum
  DateTime? commercialInvoiceDate;
  bool useAsDeliveryDate = false;

  // Währung
  late String selectedCurrency;

  // Standardsätze
  late List<String> selectedIncoterms;
  late Map<String, String> incotermsFreeTexts;
  final Map<String, TextEditingController> incotermControllers = {};

  DateTime? selectedDeliveryDate;
  bool deliveryDateMonthOnly = false;
  String? selectedSignature;

  // Controllers
  late TextEditingController numberOfPackagesController;
  late TextEditingController exportReasonController;
  late TextEditingController carrierController;

  @override
  void initState() {
    super.initState();
    settings = Map<String, dynamic>.from(widget.initialSettings);

    // Tara
    numberOfPackages = widget.packingListPackageCount;
    totalPackagingWeight = widget.packingListTotalWeight;

    // Datum
    final rawDate = settings['commercial_invoice_date'];
    if (rawDate is DateTime) {
      commercialInvoiceDate = rawDate;
    } else if (rawDate is Timestamp) {
      commercialInvoiceDate = rawDate.toDate();
    }

    useAsDeliveryDate = settings['use_as_delivery_date'] ?? true;

    // Währung
    selectedCurrency = settings['currency'] ?? widget.defaultCurrency;

    // Incoterms
    selectedIncoterms = List<String>.from(settings['selected_incoterms'] ?? []);
    incotermsFreeTexts =
        Map<String, String>.from(settings['incoterms_freetexts'] ?? {});

    // Lieferdatum
    final rawDeliveryDate = settings['delivery_date_value'];
    if (rawDeliveryDate is DateTime) {
      selectedDeliveryDate = rawDeliveryDate;
    } else if (rawDeliveryDate is Timestamp) {
      selectedDeliveryDate = rawDeliveryDate.toDate();
    }
    deliveryDateMonthOnly = settings['delivery_date_month_only'] ?? false;

    // Signatur
    selectedSignature = settings['selected_signature'];

    // Controllers
    numberOfPackagesController = TextEditingController(
      text: numberOfPackages > 0
          ? numberOfPackages.toString()
          : (settings['number_of_packages'] ?? 1).toString(),
    );
    exportReasonController =
        TextEditingController(text: settings['export_reason_text'] ?? 'Ware');
    carrierController =
        TextEditingController(text: settings['carrier_text'] ?? 'Swiss Post');

    // Incoterm-Controller initialisieren (inkl. DAP Auto-Text)
    _initIncotermControllers();
  }

  Future<void> _initIncotermControllers() async {
    for (String incotermId in selectedIncoterms) {
      String defaultText = incotermsFreeTexts[incotermId] ?? '';

      // Für DAP: Auto-generierten Text aktualisieren
      try {
        final incotermDoc = await FirebaseFirestore.instance
            .collection('incoterms')
            .doc(incotermId)
            .get();

        if (incotermDoc.exists) {
          final incotermData = incotermDoc.data() as Map<String, dynamic>;
          final incotermName = incotermData['name'] as String;

          if (incotermName == 'DAP') {
            final isDomicile = defaultText.startsWith('Domicile consignee,') ||
                defaultText.startsWith('Domizil Käufer,');

            if (defaultText.isEmpty || isDomicile) {
              final countryName = widget.customerData['country'];
              final country = Countries.getCountryByName(countryName);
              final language = widget.customerData['language'] ?? 'DE';

              defaultText = language == 'DE'
                  ? 'Domizil Käufer, ${country?.name ?? countryName}'
                  : 'Domicile consignee, ${country?.nameEn ?? countryName}';

              incotermsFreeTexts[incotermId] = defaultText;
            }
          }
        }
      } catch (e) {
        print('Fehler beim Laden des Incoterms $incotermId: $e');
      }

      incotermControllers[incotermId] = TextEditingController(text: defaultText);
    }
  }

  @override
  void dispose() {
    numberOfPackagesController.dispose();
    exportReasonController.dispose();
    carrierController.dispose();
    for (final controller in incotermControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Hilfsfunktionen
  // ─────────────────────────────────────────────────────────────────

  bool _hasDeliveryDateConflict() {
    if (commercialInvoiceDate == null ||
        widget.existingDeliveryNoteDate == null) {
      return false;
    }
    return commercialInvoiceDate!.year !=
            widget.existingDeliveryNoteDate!.year ||
        commercialInvoiceDate!.month !=
            widget.existingDeliveryNoteDate!.month ||
        commercialInvoiceDate!.day != widget.existingDeliveryNoteDate!.day;
  }

  Future<void> _save() async {
    // Settings zusammenbauen
    settings['commercial_invoice_date'] = commercialInvoiceDate;
    settings['use_as_delivery_date'] = useAsDeliveryDate;
    settings['currency'] = selectedCurrency;
    settings['selected_incoterms'] = selectedIncoterms;
    settings['incoterms_freetexts'] = incotermsFreeTexts;
    settings['selected_signature'] = selectedSignature;
    settings['delivery_date_value'] = selectedDeliveryDate;
    settings['delivery_date_month_only'] = deliveryDateMonthOnly;

    // Über Provider speichern
    await widget.provider.saveCommercialInvoiceSettings({
      'number_of_packages': numberOfPackages > 0
          ? numberOfPackages
          : settings['number_of_packages'],
      'packaging_weight': numberOfPackages > 0
          ? totalPackagingWeight
          : (settings['packaging_weight'] ?? 0.0),
      'commercial_invoice_date': commercialInvoiceDate,
      'use_as_delivery_date': useAsDeliveryDate,
      'commercial_invoice_currency': selectedCurrency,
      'commercial_invoice_origin_declaration': settings['origin_declaration'],
      'commercial_invoice_cites': settings['cites'],
      'commercial_invoice_export_reason': settings['export_reason'],
      'commercial_invoice_export_reason_text': settings['export_reason_text'],
      'commercial_invoice_incoterms': settings['incoterms'],
      'commercial_invoice_selected_incoterms':
          settings['selected_incoterms'] ?? [],
      'commercial_invoice_incoterms_freetexts':
          settings['incoterms_freetexts'] ?? {},
      'commercial_invoice_delivery_date': settings['delivery_date'],
      'commercial_invoice_delivery_date_value': useAsDeliveryDate
          ? commercialInvoiceDate
          : selectedDeliveryDate,
      'commercial_invoice_delivery_date_month_only':
          settings['delivery_date_month_only'] ?? false,
      'commercial_invoice_carrier': settings['carrier'],
      'commercial_invoice_carrier_text': settings['carrier_text'],
      'commercial_invoice_signature': settings['signature'],
      'commercial_invoice_selected_signature': settings['selected_signature'],
    });

    // Wenn "als Lieferdatum übernehmen" aktiv → Lieferschein-Settings updaten
    if (useAsDeliveryDate && commercialInvoiceDate != null) {
      final deliverySettings = await widget.provider.loadDeliveryNoteSettings();
      deliverySettings['delivery_date'] = commercialInvoiceDate;
      await widget.provider.saveDeliveryNoteSettings(deliverySettings);
    }

    // Zusatztexte speichern falls vorhanden
    if (widget.additionalTextsConfig != null) {
      await widget.provider.saveAdditionalTexts(widget.additionalTextsConfig!);
    }

    // Callback
    widget.onSaved?.call(settings);

    if (mounted) Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          _buildDragHandle(context),

          // Header
          _buildHeader(context),

          const Divider(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tara-Einstellungen ──
                  _buildSectionTitle('Tara-Einstellungen'),
                  const SizedBox(height: 16),
                  if (numberOfPackages > 0) _buildPackingListInfo(context),
                  if (numberOfPackages > 0) const SizedBox(height: 16),
                  _buildNumberOfPackages(context),
                  const SizedBox(height: 16),
                  _buildPackagingWeight(context),
                  const SizedBox(height: 24),

                  // ── Datum der Handelsrechnung ──
                  _buildCommercialInvoiceDatePicker(context),
                  const SizedBox(height: 8),
                  _buildUseAsDeliveryDateCheckbox(),
                  const SizedBox(height: 24),

                  // ── Währung ──
                  _buildCurrencySelector(context),
                  const SizedBox(height: 16),

                  // ── Standardsätze ──
                  _buildSectionTitle('Standardsätze'),
                  const SizedBox(height: 16),
                  _buildSelectAllButtons(),
                  const SizedBox(height: 8),
                  _buildOriginDeclaration(),
                  _buildCites(),
                  _buildExportReason(),
                  _buildIncoterms(context),
                  _buildDeliveryDateOnInvoice(context),
                  if (_hasDeliveryDateConflict())
                    _buildDeliveryDateConflictWarning(),
                  _buildDeliveryDateSubSettings(context),
                  _buildCarrier(),
                  _buildSignature(context),

                  const SizedBox(height: 24),

                  // ── Actions ──
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

  Widget _buildDragHandle(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          getAdaptiveIcon(
            iconName: 'inventory',
            defaultIcon: Icons.inventory,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Text(
            'Handelsrechnung Einstellungen',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // ── Tara ──

  Widget _buildPackingListInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(
            iconName: 'info',
            defaultIcon: Icons.info,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Daten aus Packliste übernommen',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberOfPackages(BuildContext context) {
    return TextField(
      controller: numberOfPackagesController,
      keyboardType: TextInputType.number,
      readOnly: numberOfPackages > 0,
      decoration: InputDecoration(
        labelText: 'Anzahl Packungen',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(8.0),
          child: getAdaptiveIcon(
              iconName: 'inventory', defaultIcon: Icons.inventory),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        helperText: numberOfPackages > 0
            ? 'Aus Packliste übernommen'
            : 'Anzahl der Verpackungseinheiten',
        filled: numberOfPackages > 0,
        fillColor: numberOfPackages > 0
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
            : null,
      ),
      onChanged: numberOfPackages > 0
          ? null
          : (value) {
              settings['number_of_packages'] = int.tryParse(value) ?? 1;
            },
    );
  }

  Widget _buildPackagingWeight(BuildContext context) {
    if (numberOfPackages > 0) {
      // Read-only Anzeige wenn aus Packliste
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        child: Row(
          children: [
            getAdaptiveIcon(iconName: 'scale', defaultIcon: Icons.scale),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Verpackungsgewicht (kg)',
                      style: TextStyle(fontSize: 12)),
                  Text(
                    totalPackagingWeight.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Summe aller Pakete aus Packliste',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Editierbares Feld
      return TextField(
        controller: TextEditingController(
          text: (settings['packaging_weight'] ?? 0.0).toString(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Verpackungsgewicht (kg)',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(8.0),
            child: getAdaptiveIcon(iconName: 'scale', defaultIcon: Icons.scale),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          helperText: 'Gesamtgewicht der Verpackung in kg',
        ),
        onChanged: (value) {
          setState(() {
            settings['packaging_weight'] = double.tryParse(value) ?? 0.0;
          });
        },
      );
    }
  }

  // ── Datum ──

  Widget _buildCommercialInvoiceDatePicker(BuildContext context) {
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
            'Datum der Handelsrechnung',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: commercialInvoiceDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      locale: const Locale('de', 'DE'),
                    );
                    if (picked != null) {
                      setState(() {
                        commercialInvoiceDate = picked;
                        settings['commercial_invoice_date'] = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: commercialInvoiceDate != null
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
                          iconName: 'calendar_today',
                          defaultIcon: Icons.calendar_today,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          commercialInvoiceDate != null
                              ? DateFormat('dd.MM.yyyy')
                                  .format(commercialInvoiceDate!)
                              : 'Datum auswählen',
                          style: TextStyle(
                            fontSize: 15,
                            color: commercialInvoiceDate != null
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
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    commercialInvoiceDate = DateTime.now();
                    settings['commercial_invoice_date'] = commercialInvoiceDate;
                  });
                },
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
              if (commercialInvoiceDate != null)
                IconButton(
                  icon: getAdaptiveIcon(
                      iconName: 'clear', defaultIcon: Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      commercialInvoiceDate = null;
                      settings['commercial_invoice_date'] = null;
                    });
                  },
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUseAsDeliveryDateCheckbox() {
    return CheckboxListTile(
      title: const Text('Als Lieferdatum übernehmen'),
      subtitle: Text(
        useAsDeliveryDate && commercialInvoiceDate != null
            ? 'Lieferdatum: ${DateFormat('dd.MM.yyyy').format(commercialInvoiceDate!)}'
            : 'wird im Lieferschein als Lieferdatum verwendet',
        style: TextStyle(
          fontSize: 11,
          color: useAsDeliveryDate && commercialInvoiceDate != null
              ? Colors.green[700]
              : null,
          fontWeight: useAsDeliveryDate && commercialInvoiceDate != null
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      value: useAsDeliveryDate,
      onChanged: (value) {
        setState(() {
          useAsDeliveryDate = value ?? true;
        });
      },
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: getAdaptiveIcon(
        iconName: 'local_shipping',
        defaultIcon: Icons.local_shipping,
        size: 20,
        color: useAsDeliveryDate && commercialInvoiceDate != null
            ? Colors.green[700]
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // ── Währung ──

  Widget _buildCurrencySelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Währung',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'CHF', label: Text('CHF')),
                  ButtonSegment(value: 'EUR', label: Text('EUR')),
                  ButtonSegment(value: 'USD', label: Text('USD')),
                ],
                selected: {selectedCurrency},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    selectedCurrency = newSelection.first;
                    settings['currency'] = selectedCurrency;
                  });
                },
              ),
            ),
          ],
        ),
        if (selectedCurrency != widget.defaultCurrency)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'info',
                    defaultIcon: Icons.info,
                    size: 16,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Abweichend von Auftragswährung (${widget.defaultCurrency})',
                      style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Standardsätze ──

  Widget _buildSelectAllButtons() {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              settings['origin_declaration'] = true;
              settings['cites'] = true;
              settings['export_reason'] = true;
              settings['incoterms'] = true;
              settings['delivery_date'] = true;
              settings['carrier'] = true;
              settings['signature'] = true;
              selectedSignature ??= 'x4i6s1FMleIE0bdg0Ujv';
              settings['selected_signature'] = selectedSignature;
            });
          },
          icon: getAdaptiveIcon(
            iconName: 'select_all',
            defaultIcon: Icons.select_all,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          label: const Text('Alle auswählen'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () {
            setState(() {
              settings['origin_declaration'] = false;
              settings['cites'] = false;
              settings['export_reason'] = false;
              settings['incoterms'] = false;
              settings['delivery_date'] = false;
              settings['carrier'] = false;
              settings['signature'] = false;
              selectedIncoterms.clear();
              incotermsFreeTexts.clear();
              selectedDeliveryDate = null;
              settings['delivery_date_value'] = null;
              selectedSignature = null;
              settings['selected_signature'] = null;
            });
          },
          icon: getAdaptiveIcon(
            iconName: 'deselect',
            defaultIcon: Icons.deselect,
            size: 20,
            color: Theme.of(context).colorScheme.outline,
          ),
          label: const Text('Alle abwählen'),
        ),
      ],
    );
  }

  Widget _buildOriginDeclaration() {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            title: const Text('Ursprungserklärung'),
            subtitle:
                const Text('Erklärung über Schweizer Ursprungswaren'),
            value: settings['origin_declaration'] ?? false,
            onChanged: (value) {
              setState(() {
                settings['origin_declaration'] = value ?? false;
              });
            },
          ),
        ),
        _buildInfoButton(
          title: 'Ursprungserklärung',
          textKey: 'origin_declaration',
        ),
      ],
    );
  }

  Widget _buildCites() {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            title: const Text('CITES'),
            subtitle:
                const Text('Waren stehen NICHT auf der CITES-Liste'),
            value: settings['cites'] ?? false,
            onChanged: (value) {
              setState(() {
                settings['cites'] = value ?? false;
              });
            },
          ),
        ),
        _buildInfoButton(
          title: 'CITES-Erklärung',
          textKey: 'cites',
        ),
      ],
    );
  }

  Widget _buildExportReason() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Grund des Exports'),
          value: settings['export_reason'] ?? false,
          onChanged: (value) {
            setState(() {
              settings['export_reason'] = value ?? false;
            });
          },
        ),
        if (settings['export_reason'] ?? false)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: TextField(
              controller: exportReasonController,
              decoration: InputDecoration(
                labelText: 'Grund des Exports',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (value) {
                settings['export_reason_text'] = value;
              },
            ),
          ),
      ],
    );
  }

  Widget _buildIncoterms(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Incoterms'),
          value: settings['incoterms'] ?? false,
          onChanged: (value) {
            setState(() {
              settings['incoterms'] = value ?? false;
              if (!(settings['incoterms'] ?? false)) {
                selectedIncoterms.clear();
                incotermsFreeTexts.clear();
              }
            });
          },
        ),
        if (settings['incoterms'] ?? false)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incoterms')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();

                final incotermDocs = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoterms auswählen:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: incotermDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] as String;
                        final isSelected =
                            selectedIncoterms.contains(doc.id);

                        return FilterChip(
                          label: Text(name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedIncoterms.add(doc.id);

                                String initialText = '';
                                if (name == 'DAP') {
                                  final countryName =
                                      widget.customerData['country'];
                                  final country =
                                      Countries.getCountryByName(countryName);
                                  final language =
                                      widget.customerData['language'] ?? 'DE';

                                  initialText = language == 'DE'
                                      ? 'Domizil Käufer, ${country?.name ?? countryName}'
                                      : 'Domicile consignee, ${country?.nameEn ?? countryName}';
                                }

                                incotermsFreeTexts[doc.id] = initialText;
                                incotermControllers[doc.id] =
                                    TextEditingController(text: initialText);
                              } else {
                                selectedIncoterms.remove(doc.id);
                                incotermsFreeTexts.remove(doc.id);
                                incotermControllers[doc.id]?.dispose();
                                incotermControllers.remove(doc.id);
                              }
                              settings['selected_incoterms'] =
                                  selectedIncoterms;
                              settings['incoterms_freetexts'] =
                                  incotermsFreeTexts;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    // Beschreibung & Freitext der ausgewählten Incoterms
                    if (selectedIncoterms.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...selectedIncoterms.map((incotermId) {
                        final incotermDoc = incotermDocs
                            .firstWhere((doc) => doc.id == incotermId);
                        final data =
                            incotermDoc.data() as Map<String, dynamic>;
                        final name = data['name'] as String;
                        final description = data['de'] as String? ??
                            data['en'] as String? ??
                            '';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (description.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 2, bottom: 4),
                                child: Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ),
                            TextField(
                              decoration: InputDecoration(
                                labelText: 'Zusätzlicher Text für $name',
                                hintText:
                                    'z.B. Domicile consignee, Sweden',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              controller: incotermControllers[incotermId],
                              onChanged: (value) {
                                incotermsFreeTexts[incotermId] = value;
                                settings['incoterms_freetexts'] =
                                    incotermsFreeTexts;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }).toList(),
                    ],
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDeliveryDateOnInvoice(BuildContext context) {
    return CheckboxListTile(
      title: const Text('Lieferdatum auf Handelsrechnung'),
      subtitle: Text(
        settings['delivery_date'] == true
            ? (useAsDeliveryDate
                ? (deliveryDateMonthOnly
                    ? '${_monthName((commercialInvoiceDate ?? DateTime.now()).month)} ${(commercialInvoiceDate ?? DateTime.now()).year}'
                    : DateFormat('dd.MM.yyyy')
                        .format(commercialInvoiceDate ?? DateTime.now()))
                : (selectedDeliveryDate != null
                    ? (deliveryDateMonthOnly
                        ? '${_monthName(selectedDeliveryDate!.month)} ${selectedDeliveryDate!.year}'
                        : DateFormat('dd.MM.yyyy')
                            .format(selectedDeliveryDate!))
                    : 'Datum auswählen'))
            : 'Lieferdatum auf der Handelsrechnung anzeigen',
        style: TextStyle(
          fontSize: 12,
          color: settings['delivery_date'] == true &&
                  (useAsDeliveryDate || selectedDeliveryDate != null)
              ? Colors.green[700]
              : null,
        ),
      ),
      value: settings['delivery_date'] ?? false,
      onChanged: (value) {
        setState(() {
          settings['delivery_date'] = value ?? false;
          if (!(settings['delivery_date'] ?? false)) {
            selectedDeliveryDate = null;
            settings['delivery_date_value'] = null;
          } else if (useAsDeliveryDate) {
            final effectiveDate = commercialInvoiceDate ?? DateTime.now();
            selectedDeliveryDate = effectiveDate;
            settings['delivery_date_value'] = effectiveDate;
          }
        });
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return months[month - 1];
  }

  Widget _buildDeliveryDateConflictWarning() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
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
                    'Abweichendes Datum im Lieferschein',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lieferschein: ${DateFormat('dd.MM.yyyy').format(widget.existingDeliveryNoteDate!)}\n'
                    'Handelsrechnung: ${DateFormat('dd.MM.yyyy').format(commercialInvoiceDate!)}',
                    style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                  ),
                  if (useAsDeliveryDate)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '→ Lieferscheindatum wird überschrieben',
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

  Widget _buildDeliveryDateSubSettings(BuildContext context) {
    if (!(settings['delivery_date'] ?? false)) return const SizedBox.shrink();

    return Column(
      children: [
        // Info wenn automatisch übernommen
        if (useAsDeliveryDate)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
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
                    iconName: 'link',
                    defaultIcon: Icons.link,
                    size: 16,
                    color: Colors.green[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wird automatisch vom Handelsrechnungsdatum übernommen',
                      style: TextStyle(fontSize: 11, color: Colors.green[700]),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Manueller Datepicker
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDeliveryDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          selectedDeliveryDate = date;
                          settings['delivery_date_value'] = date;
                        });
                      }
                    },
                    icon: getAdaptiveIcon(
                        iconName: 'calendar_today',
                        defaultIcon: Icons.calendar_today),
                    label: Text(selectedDeliveryDate != null
                        ? DateFormat('dd.MM.yyyy').format(selectedDeliveryDate!)
                        : 'Datum auswählen'),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Format-Toggle
        Padding(
          padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
          child: Row(
            children: [
              Text(
                'Format:',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              ToggleButtons(
                isSelected: [!deliveryDateMonthOnly, deliveryDateMonthOnly],
                onPressed: (index) {
                  setState(() {
                    deliveryDateMonthOnly = index == 1;
                    settings['delivery_date_month_only'] = deliveryDateMonthOnly;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                constraints:
                    const BoxConstraints(minHeight: 32, minWidth: 80),
                children: const [
                  Text('TT.MM.JJJJ', style: TextStyle(fontSize: 11)),
                  Text('Monat JJJJ', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarrier() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Transporteur'),
          value: settings['carrier'] ?? false,
          onChanged: (value) {
            setState(() {
              settings['carrier'] = value ?? false;
            });
          },
        ),
        if (settings['carrier'] ?? false)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: TextField(
              controller: carrierController,
              decoration: InputDecoration(
                labelText: 'Transporteur',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (value) {
                settings['carrier_text'] = value;
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSignature(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Signatur'),
          value: settings['signature'] ?? false,
          onChanged: (value) {
            setState(() {
              settings['signature'] = value ?? false;
              if (settings['signature'] == true) {
                selectedSignature ??= 'x4i6s1FMleIE0bdg0Ujv';
                settings['selected_signature'] = selectedSignature;
              } else {
                selectedSignature = null;
                settings['selected_signature'] = null;
              }
            });
          },
        ),
        if (settings['signature'] ?? false)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('general_data')
                  .doc('signatures')
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();

                final userDocs = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Signatur auswählen',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  value: selectedSignature,
                  items: userDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] as String;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSignature = value;
                      settings['selected_signature'] = value;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Helpers ──

  Widget _buildInfoButton({
    required String title,
    required String textKey,
  }) {
    return IconButton(
      icon: getAdaptiveIcon(
        iconName: 'info',
        defaultIcon: Icons.info,
        color: Theme.of(context).colorScheme.primary,
      ),
      onPressed: () async {
        await AdditionalTextsManager.loadDefaultTextsFromFirebase();
        final defaultText = AdditionalTextsManager.getTextContent(
          {'selected': true, 'type': 'standard'},
          textKey,
          language: widget.customerData['language'] ?? 'DE',
        );

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'info',
                  defaultIcon: Icons.info,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(defaultText, style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'edit',
                        defaultIcon: Icons.edit,
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dieser Text kann in der Admin-Ansicht unter "Zusatztexte" bearbeitet werden.',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Actions ──

  Widget _buildActions(BuildContext context) {
    return Row(
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
            icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save),
            label: const Text('Speichern'),
          ),
        ),
      ],
    );
  }
}
