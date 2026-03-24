
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/services/package_card_widget.dart';
import 'package:tonewood/services/package_product_picker.dart';
import 'package:tonewood/services/postal_document_service.dart';
import 'package:tonewood/services/swiss_rounding.dart';
import 'dart:typed_data';
import '../customers/customer.dart';
import '../services/document_settings/additional_texts_settings_dialog.dart';
import '../services/icon_helper.dart';
import 'order_model.dart';
import '../services/countries.dart';
import '../services/document_settings/commercial_invoice_settings_dialog.dart';
import '../services/document_settings/delivery_note_settings_dialog.dart';
import '../services/document_settings/invoice_settings_dialog.dart';
import '../services/document_settings/order_settings_provider.dart';
import '../services/document_settings/packing_list_settings_dialog.dart';
import 'order_configuration_sheet.dart';
import 'order_document_preview_manager.dart';
import '../services/pdf_generators/invoice_generator.dart';
import '../services/pdf_generators/delivery_note_generator.dart';
import '../services/pdf_generators/commercial_invoice_generator.dart';
import '../services/pdf_generators/packing_list_generator.dart';
import







'../quotes/shipping_costs_manager.dart';
import '../quotes/additional_text_manager.dart';
class OrderDocumentManager {
  static const List<String> availableDocuments = [
    'Rechnung',
    'Lieferschein',
    'Handelsrechnung',
    'Packliste',
  ];

  // Zeigt den Dialog zur Dokumentenerstellung für eine Order
  static Future<void> showCreateDocumentsDialog(
      BuildContext context,
      OrderX order,
      ) async {
    // Lade bestehende Dokumente
    final existingDocs = order.documents.keys.toList();

    // Standard-Auswahl: Rechnung ist immer aktiviert
    // Standard-Auswahl: Rechnung ist immer aktiviert
    // 🚀 FIX: .startsWith() nutzen, damit auch Einzelversand-Dokumente (_1, _2) erkannt werden
    Map<String, bool> documentSelection = {
      'Rechnung': !existingDocs.any((doc) => doc.startsWith('invoice_pdf')),
      'Lieferschein': !existingDocs.any((doc) => doc.startsWith('delivery_note_pdf')),
      'Handelsrechnung': !existingDocs.any((doc) => doc.startsWith('commercial_invoice_pdf')),
      'Packliste': !existingDocs.any((doc) => doc.startsWith('packing_list_pdf')),
    };

    // Einstellungen für die verschiedenen Dokumente
    Map<String, dynamic> documentSettings = {
      'delivery_note': <String, dynamic>{
        'delivery_date': null,
        'payment_date': null,
      },
      'commercial_invoice': <String, dynamic>{
        'number_of_packages': 1,
        'packaging_weight': 0.0,
        'commercial_invoice_date': null,
        'use_as_delivery_date': true,
        'origin_declaration': false,
        'cites': false,
        'export_reason': false,
        'export_reason_text': 'Ware',
        'incoterms': false,
        'selected_incoterms': <String>[],
        'incoterms_freetexts': <String, String>{},
        'delivery_date': false,
        'delivery_date_value': null,
        'delivery_date_month_only': false,
        'carrier': false,
        'carrier_text': 'Swiss Post',
        'signature': false,
        'selected_signature': null,
        'currency': null,
      },
      'packing_list': <String, dynamic>{
        'packages': <Map<String, dynamic>>[],
      },
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DocumentCreationDialog(
        order: order,
        documentSelection: documentSelection,
        documentSettings: documentSettings,
        existingDocs: existingDocs,
      ),
    );
  }
}

class _DocumentCreationDialog extends StatefulWidget {
  final OrderX order;
  final Map<String, bool> documentSelection;
  final Map<String, dynamic> documentSettings;
  final List<String> existingDocs;

  const _DocumentCreationDialog({
    required this.order,
    required this.documentSelection,
    required this.documentSettings,
    required this.existingDocs,
  });

  @override
  State<_DocumentCreationDialog> createState() => _DocumentCreationDialogState();
}

class _DocumentCreationDialogState extends State<_DocumentCreationDialog> {
  late Map<String, bool> _selection;
  late Map<String, dynamic> _settings;
  late Map<String, dynamic> _customerData; // NEU: Lokale Kopie der Kundendaten

  bool _isCreating = false;
  bool _isLoadingSettings = true; // NEU
  String _shipmentMode = 'total'; // 'total' = Gesamtversand, 'per_shipment' = Einzelversand
// Sprache pro Dokument
  late Map<String, String> _documentLanguages;
  final Map<String, Map<String, TextEditingController>> packageControllers = {};
  late Map<String, dynamic> _additionalTextsConfig;
  late final OrderSettingsProvider _provider;
  @override
  void initState() {
    super.initState();

    _selection = Map.from(widget.documentSelection);
    _selection['Rechnung'] = true;
    _settings = Map.from(widget.documentSettings);
    // Standard-Sprache aus Order-Metadata oder Kunden-Sprache
    final defaultLang = widget.order.metadata['language']
        ?? widget.order.customer['language']
        ?? 'DE';
    _documentLanguages = {
      'Rechnung': defaultLang,
      'Lieferschein': defaultLang,
      'Handelsrechnung': defaultLang,
      'Packliste': defaultLang,
    };
    _customerData = Map<String, dynamic>.from(widget.order.customer ?? {});
    _provider = OrderSettingsProvider(
      order: widget.order,
      customerDataOverride: _customerData,
    );
    _provider.onCompareCustomerAddress = _compareAndUpdateCustomerAddress;


// Zusatztexte aus Order laden
    final orderAdditionalTexts = widget.order.metadata['additionalTexts'] as Map<String, dynamic>?;
    if (orderAdditionalTexts != null) {
      _additionalTextsConfig = Map<String, dynamic>.from(orderAdditionalTexts);
      // Migration: altes 'legend' Feld
      if (_additionalTextsConfig.containsKey('legend') && !_additionalTextsConfig.containsKey('legend_origin')) {
        final legendSelected = _additionalTextsConfig['legend']?['selected'] ?? false;
        final legendType = _additionalTextsConfig['legend']?['type'] ?? 'standard';
        final legendCustom = _additionalTextsConfig['legend']?['custom_text'] ?? '';
        _additionalTextsConfig['legend_origin'] = {
          'type': legendType,
          'custom_text': legendCustom,
          'selected': legendSelected,
        };
        _additionalTextsConfig['legend_temperature'] = {
          'type': legendType,
          'custom_text': '',
          'selected': legendSelected,
        };
        _additionalTextsConfig.remove('legend');
      }
    } else {
      final defaults = AdditionalTextsManager.getCachedDefaultSelections();
      _additionalTextsConfig = {
        'legend_origin': {'type': 'standard', 'custom_text': '', 'selected': defaults['legend_origin'] ?? true},
        'legend_temperature': {'type': 'standard', 'custom_text': '', 'selected': defaults['legend_temperature'] ?? true},
        'fsc': {'type': 'standard', 'custom_text': '', 'selected': defaults['fsc'] ?? false},
        'natural_product': {'type': 'standard', 'custom_text': '', 'selected': defaults['natural_product'] ?? true},
        'bank_info': {'type': 'standard', 'custom_text': '', 'selected': defaults['bank_info'] ?? false},
        'free_text': {'type': 'custom', 'custom_text': '', 'selected': defaults['free_text'] ?? false},
      };
    }
    // Custom Blocks sicherstellen
    AdditionalTextsManager.ensureCustomBlocks(_additionalTextsConfig);

    _loadExistingSettings();
  }
  @override
  @override
  void dispose() {
    // Dispose all package controllers mit Try-Catch
    packageControllers.forEach((key, controllers) {
      controllers.forEach((_, controller) {
        try {
          controller.dispose();
        } catch (e) {
          // Controller war bereits disposed - ignorieren
        }
      });
    });
    packageControllers.clear();
    super.dispose();
  }
  Future<void> _loadExistingSettings() async {
    try {
      // Lade Packlisten-Einstellungen
      final packingListDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('packing_list')
          .doc('settings')
          .get();

      if (packingListDoc.exists) {
        final data = packingListDoc.data() ?? {'packages': []};
        setState(() {
          _settings['packing_list'] = data;
          // NEU: Lade Versandmodus
          _shipmentMode = data['shipment_mode'] as String? ?? 'total';
        });
      }

      // Lade Lieferschein-Einstellungen
      final deliverySettingsDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('settings')
          .doc('delivery_settings')
          .get();

      if (deliverySettingsDoc.exists) {
        final data = deliverySettingsDoc.data()!;
        setState(() {
          _settings['delivery_note'] = {
            'delivery_date': data['delivery_date'] != null
                ? (data['delivery_date'] as Timestamp).toDate()
                : null,
            'payment_date': data['payment_date'] != null
                ? (data['payment_date'] as Timestamp).toDate()
                : null,
          };
        });
      }

      final taraSettingsDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('settings')
          .doc('tara_settings')
          .get();

      if (taraSettingsDoc.exists) {
        final data = taraSettingsDoc.data()!;
        setState(() {
          _settings['commercial_invoice'] = {
            'number_of_packages': data['number_of_packages'] ?? 1,
            'commercial_invoice_date': data['commercial_invoice_date'] != null
                ? (data['commercial_invoice_date'] as Timestamp).toDate()
                : null,
            'use_as_delivery_date': data['use_as_delivery_date'] ?? true,
            'origin_declaration': data['commercial_invoice_origin_declaration'] ?? data['origin_declaration'] ?? false,
            'cites': data['commercial_invoice_cites'] ?? data['cites'] ?? false,
            'export_reason': data['commercial_invoice_export_reason'] ?? data['export_reason'] ?? false,
            'export_reason_text': data['commercial_invoice_export_reason_text'] ?? data['export_reason_text'] ?? 'Ware',
            'incoterms': data['commercial_invoice_incoterms'] ?? data['incoterms'] ?? false,
            'selected_incoterms': List<String>.from(data['commercial_invoice_selected_incoterms'] ?? data['selected_incoterms'] ?? []),
            'incoterms_freetexts': Map<String, String>.from(data['commercial_invoice_incoterms_freetexts'] ?? data['incoterms_freetexts'] ?? {}),
            'delivery_date': data['commercial_invoice_delivery_date'] ?? data['delivery_date'] ?? false,
            'delivery_date_value': (data['commercial_invoice_delivery_date_value'] ?? data['delivery_date_value']) != null
                ? ((data['commercial_invoice_delivery_date_value'] ?? data['delivery_date_value']) as Timestamp).toDate()
                : null,
            'delivery_date_month_only': data['commercial_invoice_delivery_date_month_only'] ?? data['delivery_date_month_only'] ?? false,
            'carrier': data['commercial_invoice_carrier'] ?? data['carrier'] ?? false,
            'carrier_text': data['commercial_invoice_carrier_text'] ?? data['carrier_text'] ?? 'Swiss Post',
            'signature': data['commercial_invoice_signature'] ?? data['signature'] ?? false,
            'selected_signature': data['commercial_invoice_selected_signature'] ?? data['selected_signature'],
            'currency': data['commercial_invoice_currency'],
          };
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Einstellungen: $e');
    } finally {
      setState(() {
        _isLoadingSettings = false;
      });
    }
  }
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
                  child:   getAdaptiveIcon(
                    iconName: 'description',
                    defaultIcon:
                    Icons.description,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dokumente',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Auftrag ${widget.order.orderNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => AdditionalTextsSettingsDialog.show(
                    context,
                    provider: _provider,
                    config: _additionalTextsConfig,
                    onSaved: () => setState(() {}),
                  ),
                  icon: getAdaptiveIcon(iconName: 'text_fields', defaultIcon: Icons.text_fields),
                  tooltip: 'Zusatztexte',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon:  getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [


                // Dokumentauswahl
                // Dokumentauswahl
                ...OrderDocumentManager.availableDocuments.map((docType) {
                  final isDisabled = docType == 'Rechnung'; // Rechnung ist wieder disabled (damit immer gecheckt)
                  final isDependentDoc = ['Lieferschein', 'Handelsrechnung', 'Packliste']
                      .contains(docType);

                  // 🚀 FIX: Auch hier auf .startsWith() prüfen, um das UI korrekt zu blockieren
                  final baseKey = _getDocumentKey(docType);
                  final alreadyExists = baseKey.isNotEmpty && widget.existingDocs.any((doc) => doc.startsWith(baseKey));
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: alreadyExists
                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selection[docType] == true && !alreadyExists
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                            : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Settings Button
                        if ((isDependentDoc || docType == 'Rechnung') && !alreadyExists)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              onPressed: () => _showDocumentSettings(docType),  // Kein isDisabled check mehr
                              icon:    getAdaptiveIcon(
                                  iconName: 'settings',
                                  defaultIcon:Icons.settings),
                              tooltip: '$docType Einstellungen',
                            ),
                          )
                        else
                          const SizedBox(width: 10),
// Sprach-Auswahl
                        if (!alreadyExists)
                          _buildLanguageSelector(docType)
                        else
                          const SizedBox(width: 10),
                        // Checkbox
                        Expanded(
                          child: CheckboxListTile(
                            title: Text(
                              docType,
                              style: TextStyle(
                                  color: alreadyExists
                                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                      : null,
                                  fontSize: 14
                              ),
                            ),
                            subtitle: _getDocumentSubtitle(docType, alreadyExists),
                            value: _selection[docType] ?? false,
                            onChanged: (isDisabled || alreadyExists) ? null : (value) {  // Disabled = nicht änderbar
                              setState(() {
                                _selection[docType] = value ?? false;
                              });
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),

                        // Preview Button
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            onPressed: alreadyExists ? null : () async {  // Kein isDisabled check mehr

                              await OrderDocumentPreviewManager.showDocumentPreview(
                                context: context,
                                order: _getOrderWithCurrentCustomerData(),
                                documentType: _getDocumentKey(docType),
                                language: _documentLanguages[docType],
                              );
                            },
                            icon:
                            getAdaptiveIcon(
                              iconName: 'visibility',
                              defaultIcon: Icons.visibility,

                            ),

                            tooltip: 'Vorschau',
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

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
                    onPressed: _isCreating ? null : () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCreating || !_hasSelection() ? null : _createDocuments,
                    child: _isCreating
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Dokumente erstellen'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  OrderX _getOrderWithCurrentCustomerData() {
    return widget.order.copyWith(customer: _customerData);
  }

  Widget? _getDocumentSubtitle(String docType, bool alreadyExists) {
    // ── Einzelversand-Hinweis für HR und Lieferschein ──
    if (_shipmentMode == 'per_shipment' &&
        (docType == 'Handelsrechnung' || docType == 'Lieferschein')) {
      final packingListSettings = _settings['packing_list'];
      final packages = packingListSettings?['packages'] as List? ?? [];

      // Berechne Anzahl Versandgruppen
      final Set<int> groups = {};
      for (int i = 0; i < packages.length; i++) {
        final pkg = packages[i] as Map<String, dynamic>;
        groups.add((pkg['shipment_group'] as num?)?.toInt() ?? (i + 1));
      }
      final groupCount = groups.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alreadyExists)
            Text(
              'Bereits erstellt',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(
                  iconName: 'mail',
                  defaultIcon: Icons.mail,
                  size: 11,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),

              ],
            ),
          ),
          Text(
            groupCount > 0
                ? 'Einzelversand: $groupCount Sendung${groupCount > 1 ? 'en' : ''} '
                '→ $groupCount ${docType}${groupCount > 1 ? 'en' : ''}'
                : 'Einzelversand (Sendungen in Packliste konfigurieren)',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // ── Bestehende Logik ──
    if (alreadyExists) {
      return const Text('Bereits erstellt', style: TextStyle(fontSize: 12));
    }

    switch (docType) {
      case 'Rechnung':
        final settings = _settings['invoice'] ?? {};
        if (settings['down_payment_amount'] != null && settings['down_payment_amount'] > 0) {
          return Text(
            'Anzahlung: CHF ${settings['down_payment_amount'].toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          );
        }
        return widget.existingDocs.contains('invoice_pdf')
            ? const Text('Bereits erstellt', style: TextStyle(fontSize: 12))
            : const Text('Wird mit dem Auftrag erstellt', style: TextStyle(fontSize: 12));
      case 'Lieferschein':
        final settings = _settings['delivery_note'];
        if (settings['delivery_date'] != null || settings['payment_date'] != null) {
          return Text(
            'Konfiguriert',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          );
        }
        return const Text('Optional', style: TextStyle(fontSize: 12));
      case 'Handelsrechnung':
        final settings = _settings['commercial_invoice'];
        final hasConfig = settings['origin_declaration'] == true ||
            settings['cites'] == true ||
            settings['export_reason'] == true ||
            settings['incoterms'] == true ||
            settings['delivery_date'] == true ||
            settings['carrier'] == true ||
            settings['signature'] == true;
        if (hasConfig) {
          return Text(
            'Konfiguriert',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          );
        }
        return const Text('Optional', style: TextStyle(fontSize: 12));
      case 'Packliste':
        final packages = _settings['packing_list']['packages'] as List? ?? [];
        if (packages.isNotEmpty) {
          final filteredItems = widget.order.items
              .where((item) => item['is_service'] != true)
              .toList();

          int totalAssigned = 0;
          int totalProducts = filteredItems.length;

          for (final item in filteredItems) {
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
            final assigned = _getAssignedQuantityForOrder(item, packages.cast<Map<String, dynamic>>());
            if (assigned >= quantity) totalAssigned++;
          }

          return Text(
            '${packages.length} Paket(e) • $totalAssigned/$totalProducts Produkte zugewiesen',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          );
        }
        return const Text('Optional', style: TextStyle(fontSize: 12));
      default:
        return null;
    }
  }

  bool _hasSelection() {
    return _selection.values.any((selected) => selected == true);
  }

  Widget _buildLanguageSelector(String docType) {
    final lang = _documentLanguages[docType] ?? 'DE';
    final languages = ['DE', 'EN'];

    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          _documentLanguages[docType] = value;
        });
      },
      itemBuilder: (context) => languages.map((l) => PopupMenuItem(
        value: l,
        child: Text(l, style: TextStyle(
          fontWeight: l == lang ? FontWeight.bold : FontWeight.normal,
        )),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 16,
                color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _showDocumentSettings(String docType) async {
    switch (docType) {
      case 'Rechnung':
        final currency = widget.order.metadata['currency'] ?? 'CHF';
        final total = (widget.order.calculations['total'] as num?)?.toDouble() ?? 0.0;

        await InvoiceSettingsDialog.show(
          context,
          provider: _provider,
          totalAmount: total,
          currency: currency,
          initialSettings: _settings['invoice'],
          onSaved: (settings) {
            setState(() {
              _settings['invoice'] = settings;
            });
          },
        );
        break;
      case 'Lieferschein':
        await DeliveryNoteSettingsDialog.show(
          context,
          provider: _provider,
          initialDeliveryNoteSettings: _settings['delivery_note'],
          commercialInvoiceSettings: _settings['commercial_invoice'],
          onSaved: (settings) {
            setState(() {
              _settings['delivery_note'] = settings;
            });
          },
        );
        break;
        break;
      case 'Handelsrechnung':
        await CommercialInvoiceSettingsDialog.show(
          context,
          provider: _provider,
          customerData: _customerData,
          initialSettings: _settings['commercial_invoice'],
          defaultCurrency: widget.order.metadata['currency'] ?? 'CHF',
          additionalTextsConfig: _additionalTextsConfig,
          onSaved: (settings) {
            setState(() {
              _settings['commercial_invoice'] = settings;
              // Falls Lieferdatum aktualisiert wurde
              if (settings['use_as_delivery_date'] == true &&
                  settings['commercial_invoice_date'] != null) {
                _settings['delivery_note']['delivery_date'] =
                settings['commercial_invoice_date'];
              }
            });
          },
        );
        break;
      case 'Packliste':
        final filteredItems = widget.order.items
            .where((item) => item['is_service'] != true)
            .toList();

        await PackingListSettingsDialog.show(
          context,
          provider: _provider,
          items: filteredItems,
          initialShipmentMode: _shipmentMode,
          showShipmentModeToggle: true,
          onSaved: (packages, shipmentMode) {
            setState(() {
              _settings['packing_list']['packages'] = packages;
              _shipmentMode = shipmentMode;
            });
          },
        );
        break;
    }
  }

  Future<void> _compareAndUpdateCustomerAddress() async {
    // 1. Hole Kunden-ID aus dem Auftrag
    final orderCustomer = _customerData;
    if (orderCustomer == null || orderCustomer['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kein Kunde im Auftrag gefunden'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final customerId = orderCustomer['id'] as String;

    // 2. Lade aktuelle Kundendaten aus Firestore
    final customerDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .get();

    if (!customerDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde nicht mehr in der Datenbank gefunden'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final currentCustomer = Customer.fromMap(customerDoc.data()!, customerDoc.id);

    // 3. Vergleiche die Daten
    final List<Map<String, dynamic>> differences = [];

    void compare(String fieldName, String? oldValue, String? newValue) {
      final oldVal = (oldValue ?? '').trim();
      final newVal = (newValue ?? '').trim();
      if (oldVal != newVal) {
        differences.add({
          'field': fieldName,
          'old': oldVal.isEmpty ? '(leer)' : oldVal,
          'new': newVal.isEmpty ? '(leer)' : newVal,
        });
      }
    }

    void compareBool(String fieldName, bool? oldValue, bool? newValue) {
      final oldVal = oldValue ?? false;
      final newVal = newValue ?? false;
      if (oldVal != newVal) {
        differences.add({
          'field': fieldName,
          'old': oldVal ? 'Ja' : 'Nein',
          'new': newVal ? 'Ja' : 'Nein',
        });
      }
    }

    // Rechnungsadresse vergleichen
    compare('Firma', orderCustomer['company'], currentCustomer.company);
    compare('Vorname', orderCustomer['firstName'], currentCustomer.firstName);
    compare('Nachname', orderCustomer['lastName'], currentCustomer.lastName);
    compare('Straße', orderCustomer['street'], currentCustomer.street);
    compare('Hausnummer', orderCustomer['houseNumber'], currentCustomer.houseNumber);
    compare('PLZ', orderCustomer['zipCode'], currentCustomer.zipCode);
    compare('Ort', orderCustomer['city'], currentCustomer.city);
    compare('Provinz', orderCustomer['province'], currentCustomer.province);
    compare('Land', orderCustomer['country'], currentCustomer.country);
    compare('E-Mail', orderCustomer['email'], currentCustomer.email);
    compare('Telefon 1', orderCustomer['phone1'], currentCustomer.phone1);
    compare('Telefon 2', orderCustomer['phone2'], currentCustomer.phone2);

    // Dokumentenoptionen vergleichen
    // DEBUG: Typen und Werte prüfen
    print('=== DEBUG KUNDENABGLEICH ===');
    print('orderCustomer showEoriOnDocuments: ${orderCustomer['showEoriOnDocuments']} (${orderCustomer['showEoriOnDocuments'].runtimeType})');
    print('currentCustomer showEoriOnDocuments: ${currentCustomer.showEoriOnDocuments} (${currentCustomer.showEoriOnDocuments.runtimeType})');
    print('orderCustomer eoriNumber: ${orderCustomer['eoriNumber']} (${orderCustomer['eoriNumber'].runtimeType})');
    print('currentCustomer eoriNumber: ${currentCustomer.eoriNumber} (${currentCustomer.eoriNumber.runtimeType})');
    print('orderCustomer showVatOnDocuments: ${orderCustomer['showVatOnDocuments']} (${orderCustomer['showVatOnDocuments'].runtimeType})');
    print('currentCustomer showVatOnDocuments: ${currentCustomer.showVatOnDocuments} (${currentCustomer.showVatOnDocuments.runtimeType})');
    print('orderCustomer vatNumber: ${orderCustomer['vatNumber']} (${orderCustomer['vatNumber'].runtimeType})');
    print('currentCustomer vatNumber: ${currentCustomer.vatNumber} (${currentCustomer.vatNumber.runtimeType})');
    print('=== ALLE ORDER CUSTOMER KEYS ===');
    print(orderCustomer.keys.toList());
    print('============================');

    compare('EORI-Nummer', orderCustomer['eoriNumber'], currentCustomer.eoriNumber);
    compareBool('EORI auf Dokumenten anzeigen', orderCustomer['showEoriOnDocuments'], currentCustomer.showEoriOnDocuments);
    compare('MwSt-Nummer', orderCustomer['vatNumber'], currentCustomer.vatNumber);
    compareBool('MwSt auf Dokumenten anzeigen', orderCustomer['showVatOnDocuments'], currentCustomer.showVatOnDocuments);
    compareBool('Eigenes Feld auf Dokumenten anzeigen', orderCustomer['showCustomFieldOnDocuments'], currentCustomer.showCustomFieldOnDocuments);
    compare('Eigenes Feld Titel', orderCustomer['customFieldTitle'], currentCustomer.customFieldTitle);
    compare('Eigenes Feld Wert', orderCustomer['customFieldValue'], currentCustomer.customFieldValue);

    // Sprache vergleichen
    compare('Sprache', orderCustomer['language'], currentCustomer.language);

    // Lieferadresse vergleichen (falls vorhanden)
    if (currentCustomer.hasDifferentShippingAddress) {
      compare('Lieferadresse Firma', orderCustomer['shippingCompany'], currentCustomer.shippingCompany);
      compare('Lieferadresse Vorname', orderCustomer['shippingFirstName'], currentCustomer.shippingFirstName);
      compare('Lieferadresse Nachname', orderCustomer['shippingLastName'], currentCustomer.shippingLastName);
      compare('Lieferadresse Straße', orderCustomer['shippingStreet'], currentCustomer.shippingStreet);
      compare('Lieferadresse PLZ', orderCustomer['shippingZipCode'], currentCustomer.shippingZipCode);
      compare('Lieferadresse Ort', orderCustomer['shippingCity'], currentCustomer.shippingCity);
      compare('Lieferadresse Provinz', orderCustomer['shippingProvince'], currentCustomer.shippingProvince);
      compare('Lieferadresse Land', orderCustomer['shippingCountry'], currentCustomer.shippingCountry);
    }

    // 4. Zeige Dialog mit Unterschieden
    if (!mounted) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: differences.isEmpty ? 'check_circle' : 'compare_arrows',
              defaultIcon: differences.isEmpty ? Icons.check_circle : Icons.compare_arrows,
              color: differences.isEmpty ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                differences.isEmpty
                    ? 'Keine Änderungen'
                    : '${differences.length} Änderung${differences.length > 1 ? 'en' : ''} gefunden',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: differences.isEmpty
            ? const Text('Die Kundendaten im Auftrag stimmen mit der Datenbank überein.')
            : SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Folgende Felder haben sich geändert:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: differences.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final diff = differences[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diff['field'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Alt:',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                      Text(
                                        diff['old'],
                                        style: TextStyle(
                                          color: Colors.red.shade900,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Neu:',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      Text(
                                        diff['new'],
                                        style: TextStyle(
                                          color: Colors.green.shade900,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(differences.isEmpty ? 'OK' : 'Abbrechen'),
          ),
          if (differences.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: getAdaptiveIcon(iconName: 'update', defaultIcon: Icons.update),
              label: const Text('Auftrag aktualisieren'),
            ),
        ],
      ),
    );

    // 5. Auftrag aktualisieren wenn gewünscht
    // 5. Auftrag aktualisieren wenn gewünscht
    if (shouldUpdate == true) {
      try {
        final updatedCustomerMap = currentCustomer.toMap();

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.order.id)
            .update({
          'customer': updatedCustomerMap,
          'customerUpdatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          // NEU: Aktualisiere lokale Kundendaten sofort
          setState(() {
            _customerData = Map<String, dynamic>.from(updatedCustomerMap);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kundendaten im Auftrag wurden aktualisiert'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Aktualisieren: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _createDocuments() async {
    setState(() {
      _isCreating = true;
    });

    print('=== DEBUG _createDocuments START ===');
    print('Shipment Mode: $_shipmentMode');
    print('Selections: $_selection');
    print('Existing Docs: ${widget.existingDocs}');

    try {
      // 1. Packlisten-Zuweisung prüfen (Warnung bei unzugewiesenen Produkten)
      if (_selection['Packliste'] == true) {
        final packagesRaw = _settings['packing_list']['packages'] as List<dynamic>? ?? [];
        final packages = packagesRaw.map((p) => Map<String, dynamic>.from(p as Map)).toList();
        final filteredItems = widget.order.items
            .where((item) => item['is_service'] != true)
            .toList();

        final unassignedProducts = <String>[];

        for (final item in filteredItems) {
          final productId = item['product_id'] as String? ?? '';
          final productName = item['product_name'] as String? ?? 'Unbekanntes Produkt';
          final totalQuantity = item['quantity'] as double? ?? 0;
          final assignedQuantity = _getAssignedQuantityForOrder(item, packages);

          if (assignedQuantity < totalQuantity) {
            final remaining = totalQuantity - assignedQuantity;
            unassignedProducts.add('$productName: $remaining von $totalQuantity Stück nicht zugewiesen');
          }
        }

        if (unassignedProducts.isNotEmpty) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  getAdaptiveIcon(iconName: 'warning', defaultIcon: Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Achtung'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Die folgenden Produkte wurden noch nicht vollständig Paketen zugewiesen:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: unassignedProducts.map((product) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  product,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Möchtest du trotzdem fortfahren?',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Die nicht zugewiesenen Produkte erscheinen nicht auf der Packliste.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Zurück zur Konfiguration'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Trotzdem erstellen'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) {
            setState(() {
              _isCreating = false;
            });
            return;
          }
        }
      }

      final List<String> createdDocuments = [];

      // Lade Order-Daten für Dokumentengenerierung
      final orderData = await _prepareOrderData();

      // ══════════════════════════════════════════
      // EINZELVERSAND: HR und Lieferschein pro Sendung
      // ══════════════════════════════════════════
      if (_shipmentMode == 'per_shipment') {
        print('=== DEBUG: EINZELVERSAND WIRD GESTARTET ===');

        // 🚀 BUGFIX START: Sicherstellen, dass jedes Paket eine 'shipment_group' hat.
        final packagesRaw = _settings['packing_list']['packages'] as List<dynamic>? ?? [];
        final packages = packagesRaw.map((p) => Map<String, dynamic>.from(p as Map)).toList();
        bool needsUpdate = false;

        for (int i = 0; i < packages.length; i++) {
          if (packages[i]['shipment_group'] == null) {
            packages[i]['shipment_group'] = i + 1; // Fallback: Index + 1
            needsUpdate = true;
          }
        }

        // Aktualisiere das lokale Settings-Objekt, falls der Service darauf zugreift
        _settings['packing_list']['packages'] = packages;

        // Speichere die korrigierten Pakete in Firestore ab, da der
        // PostalDocumentService sie oft frisch von dort lädt.
        if (needsUpdate) {
          print('DEBUG: Schreibe fehlende shipment_group in Firestore...');
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.order.id)
              .collection('packing_list')
              .doc('settings')
              .set({
            'packages': packages,
            'shipment_mode': _shipmentMode,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        // 🚀 BUGFIX END

        // Validierung
        final validationError = await PostalDocumentService.validateShipmentMode(widget.order.id);
        if (validationError != null) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'warning',
                      defaultIcon: Icons.warning,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    const Text('Konfiguration prüfen'),
                  ],
                ),
                content: Text(validationError),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          setState(() => _isCreating = false);
          return;
        }

        // 🚀 FIX: .startsWith() statt .contains() nutzen, da die Dateien _1, _2 am Ende haben!
        final shouldCreateHR = _selection['Handelsrechnung'] == true &&
            !widget.existingDocs.any((doc) => doc.startsWith('commercial_invoice_pdf'));
        final shouldCreateLS = _selection['Lieferschein'] == true &&
            !widget.existingDocs.any((doc) => doc.startsWith('delivery_note_pdf'));
        print('DEBUG: Erstelle ShipmentDocuments (HR: $shouldCreateHR, LS: $shouldCreateLS)');

        // Erstelle Dokumente pro Versandgruppe
        final shipmentDocs = await PostalDocumentService.createShipmentDocuments(
          order: widget.order,
          orderData: orderData,
          settings: _settings,
          additionalTextsConfig: _additionalTextsConfig,
          createCommercialInvoices: shouldCreateHR,
          createDeliveryNotes: shouldCreateLS,
        );

        print('DEBUG: Erstellte Sendungsdokumente: $shipmentDocs');
        createdDocuments.addAll(shipmentDocs);
      }

      // ══════════════════════════════════════════
      // GESAMTVERSAND (oder Rechnung/Packliste)
      // ══════════════════════════════════════════
      for (final entry in _selection.entries) {
        if (!entry.value) continue;
        // 🚀 FIX: Auch hier auf .startsWith() prüfen, um Namens-Konflikte zu vermeiden
        final baseKey = _getDocumentKey(entry.key);
        if (widget.existingDocs.any((doc) => doc.startsWith(baseKey))) continue;
        // Im Einzelversand: HR und Lieferschein überspringen (wurden oben bereits pro Sendung erstellt)
        if (_shipmentMode == 'per_shipment' &&
            (entry.key == 'Handelsrechnung' || entry.key == 'Lieferschein')) {
          continue;
        }

        print('DEBUG: Erstelle Standard-Dokument für ${entry.key}...');
        final success = await _createDocument(entry.key, orderData);
        if (success) {
          createdDocuments.add(entry.key);
        }
      }

      if (mounted) {
        Navigator.pop(context);

        if (createdDocuments.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erstellt: ${createdDocuments.join(', ')}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('=== DEBUG: EXCEPTION in _createDocuments ===');
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _prepareOrderData() async {
    // Extrahiere Daten aus der Order
    final metadata = widget.order.metadata;

    // Versandkosten sicher konvertieren
    final rawShippingCosts = metadata['shippingCosts'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> shippingCosts = {};

    // Sichere Konvertierung aller numerischen Werte in shippingCosts
    rawShippingCosts.forEach((key, value) {
      if (value is num) {
        shippingCosts[key] = value.toDouble();
      } else {
        shippingCosts[key] = value;
      }
    });

    // Konvertiere exchangeRates sicher zu Map<String, double>
    final rawExchangeRates = metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
    final Map<String, double> exchangeRates = {
      'CHF': 1.0,
    };

    rawExchangeRates.forEach((key, value) {
      if (value != null) {
        exchangeRates[key] = (value as num).toDouble();
      }
    });
    final costCenterCode = widget.order.costCenter?['code'] ?? '00000';
    // print('DEBUG: Final costCenterCode = $costCenterCode');


    // Bereite alle Daten für die Dokumentengenerierung vor
    return {
      'order': widget.order,
      'items': widget.order.items,
      'customer': _customerData, // NEU: Verwende lokale Kundendaten statt widget.order.customer
      'calculations': widget.order.calculations,
      'settings': _settings,
      'shippingCosts': shippingCosts,
      'currency': metadata['currency'] ?? 'CHF',
      'exchangeRates': exchangeRates,
      'costCenterCode': widget.order.costCenter?['code'] ?? '00000',
      'fair': metadata['fairData'],
      'taxOption': metadata['taxOption'] ?? 0,
      'vatRate': (metadata['vatRate'] as num?)?.toDouble() ?? 8.1,
      'language': metadata['language'] ?? _customerData['language'] ?? 'DE',
      'documentLanguages': _documentLanguages, // NEU
    };
  }

  Future<bool> _createDocument(String docType, Map<String, dynamic> orderData) async {

    // print("yoooooo!");
    try {
      Uint8List? pdfBytes;
      String? documentUrl;
      String documentKey = _getDocumentKey(docType);
      final rawExchangeRates = orderData['exchangeRates'] as Map<dynamic, dynamic>? ?? {};
      final exchangeRates = <String, double>{'CHF': 1.0};
      rawExchangeRates.forEach((key, value) {
        if (value != null) {
          exchangeRates[key.toString()] = (value as num).toDouble();
        }
      });


      switch (docType) {

        case 'Rechnung':
        /* print('=== DEBUG Rechnung erstellen ===');
          print('orderData costCenterCode: ${orderData['costCenterCode']}');
          print('orderData fair: ${orderData['fair']}');
          print('orderData currency: ${orderData['currency']}');
          print('================================');*/

          final rawInvoiceSettings = _settings['invoice'] as Map<dynamic, dynamic>? ?? {};
          final invoiceSettings = <String, dynamic>{};
          rawInvoiceSettings.forEach((key, value) {
            invoiceSettings[key.toString()] = value;
          });
          final roundingSettings = await SwissRounding.loadRoundingSettings();




          // Generiere Rechnung
          pdfBytes = await InvoiceGenerator.generateInvoicePdf(
            items: orderData['items'],
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenterCode'],
            currency: orderData['currency'],
            exchangeRates: exchangeRates,
            language: _documentLanguages[docType] ?? orderData['language'],
            invoiceNumber: widget.order.orderNumber,
            shippingCosts: orderData['shippingCosts'],
            calculations: orderData['calculations'],
            paymentTermDays: 30,
            taxOption: orderData['taxOption'],
            vatRate: orderData['vatRate'],
            downPaymentSettings: invoiceSettings,
            roundingSettings: roundingSettings,
            additionalTexts: _additionalTextsConfig,
          );
          break;

        case 'Lieferschein':

        // Generiere Lieferschein mit Settings
          final settings = _settings['delivery_note'];
          pdfBytes = await DeliveryNoteGenerator.generateDeliveryNotePdf(
            items: orderData['items'],
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenterCode'],
            currency: orderData['currency'],
            exchangeRates: exchangeRates,
            language: _documentLanguages[docType] ?? orderData['language'],
            deliveryNoteNumber: '${widget.order.orderNumber}-LS',
            deliveryDate: settings['delivery_date'],
            paymentDate: settings['payment_date'],
            additionalTexts: _additionalTextsConfig,
          );
          break;

        case 'Handelsrechnung':
        // Generiere Handelsrechnung mit Settings
          final settings = _settings['commercial_invoice'];
          // NEU: Lade Verpackungsgewicht aus Packliste
          double packagingWeight = 0.0;
          double packagingVolume = 0.0;
          int numberOfPackages = settings['number_of_packages'] ?? 1;

          final commercialInvoiceCurrency = settings['currency'] ?? orderData['currency'];
          try {
            final packingListDoc = await FirebaseFirestore.instance
                .collection('orders')
                .doc(widget.order.id)
                .collection('packing_list')
                .doc('settings')
                .get();

            if (packingListDoc.exists) {
              final data = packingListDoc.data()!;
              final packages = data['packages'] as List<dynamic>? ?? [];
              if (packages.isNotEmpty) {
                numberOfPackages = packages.length;
                for (final package in packages) {
                  packagingWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
                  // Volumen berechnen: width * height * length (mm³ → m³)
                  final width = (package['width'] as num?)?.toDouble() ?? 0.0;
                  final height = (package['height'] as num?)?.toDouble() ?? 0.0;
                  final length = (package['length'] as num?)?.toDouble() ?? 0.0;

                  // cm³ zu m³: dividiere durch 1.000.000 (10^6)

                  final volumeM3 = (width * height * length) / 1000000; // in m³
                  packagingVolume += volumeM3;

                }
              }
            }
          } catch (e) {
            print('Fehler beim Laden des Verpackungsgewichts: $e');
          }
          // Bereite Tara-Einstellungen vor
          final taraSettings = {
            'number_of_packages': settings['number_of_packages'],
            'packaging_weight': packagingWeight,
            'packaging_volume': packagingVolume,
            'commercial_invoice_date': settings['commercial_invoice_date'],
            'commercial_invoice_origin_declaration': settings['origin_declaration'],
            'commercial_invoice_cites': settings['cites'],
            'commercial_invoice_export_reason': settings['export_reason'],
            'commercial_invoice_export_reason_text': settings['export_reason_text'],
            'commercial_invoice_incoterms': settings['incoterms'],
            'commercial_invoice_selected_incoterms': settings['selected_incoterms'],
            'commercial_invoice_incoterms_freetexts': settings['incoterms_freetexts'],
            // Wenn use_as_delivery_date aktiv, dann commercial_invoice_date als Lieferdatum verwenden
            'commercial_invoice_delivery_date': settings['delivery_date'] == true || settings['use_as_delivery_date'] == true,
            'commercial_invoice_delivery_date_value': settings['use_as_delivery_date'] == true
                ? (settings['commercial_invoice_date'] ?? DateTime.now())
                : settings['delivery_date_value'],
            'commercial_invoice_delivery_date_month_only': settings['use_as_delivery_date'] == true
                ? false  // Bei "als Lieferdatum übernehmen" volles Datum anzeigen
                : (settings['delivery_date_month_only'] ?? false),
            'commercial_invoice_carrier': settings['carrier'],
            'commercial_invoice_carrier_text': settings['carrier_text'],
            'commercial_invoice_signature': settings['signature'],
            'commercial_invoice_selected_signature': settings['selected_signature'],
          };
          // Konvertiere DateTime zu Timestamp falls nötig
          DateTime? invoiceDate;
          if (settings['commercial_invoice_date'] != null) {
            invoiceDate = settings['commercial_invoice_date'] is DateTime
                ? settings['commercial_invoice_date'] as DateTime
                : (settings['commercial_invoice_date'] as Timestamp).toDate();
          }

          print("pV:$packagingVolume");
          print("invoiceDate:$invoiceDate");

          pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
            items: orderData['items'],
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenterCode'],
            currency: commercialInvoiceCurrency,
            exchangeRates: exchangeRates,
            language: _documentLanguages[docType] ?? orderData['language'],
            invoiceNumber: '${widget.order.orderNumber}-CI',
            shippingCosts: orderData['shippingCosts'],
            calculations: orderData['calculations'],
            taxOption: orderData['taxOption'],
            vatRate: orderData['vatRate'],
            taraSettings: taraSettings,
            invoiceDate: invoiceDate,
            additionalTexts: _additionalTextsConfig,
          );
          break;

        case 'Packliste':
        // Generiere Packliste mit Settings
          final settings = _settings['packing_list'];

          // Speichere Packages als Subcollection des Auftrags
          final packingListRef = FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.order.id)
              .collection('packing_list')
              .doc('settings');

          await packingListRef.set({
            'packages': settings['packages'],
            'created_at': FieldValue.serverTimestamp(),
            'created_by': FirebaseAuth.instance.currentUser?.uid,
          });

          pdfBytes = await PackingListGenerator.generatePackingListPdf(
            language: _documentLanguages[docType] ?? orderData['language'],
            packingListNumber: '${widget.order.orderNumber}-PL',
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenterCode'],
            orderId: widget.order.id,  // NEU: Übergebe die Order ID
          );

          // Kein Cleanup nötig - die Daten bleiben in der Order!
          break;

        default:
          return false;
      }

      if (pdfBytes != null) {
        // Speichere PDF in Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('orders')
            .child(widget.order.id)
            .child('$documentKey.pdf');

        final uploadTask = await storageRef.putData(
          pdfBytes,
          SettableMetadata(
            contentType: 'application/pdf',
            customMetadata: {
              'orderNumber': widget.order.orderNumber,
              'documentType': docType,
              'createdAt': DateTime.now().toIso8601String(),
            },
          ),
        );

        documentUrl = await uploadTask.ref.getDownloadURL();

        // Update Order mit Dokument-URL
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.order.id)
            .update({
          'documents.$documentKey': documentUrl,
          'metadata.document_languages.$documentKey': _documentLanguages[docType] ?? 'DE', // NEU
          'updated_at': FieldValue.serverTimestamp(),
        });

        // History-Eintrag erstellen
        final user = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.order.id)
            .collection('history')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'user_id': user?.uid ?? 'unknown',
          'user_email': user?.email ?? 'Unknown User',
          'user_name': user?.email ?? 'Unknown',
          'action': 'document_created',
          'document_type': docType,
          'document_url': documentUrl,
        });

        return true;
      }

      return false;
    } catch (e) {

      print('Fehler beim Erstellen von $docType: $e');
      return false;
    }
  }

  String _getDocumentKey(String docType) {
    switch (docType) {
      case 'Rechnung':
        return 'invoice_pdf';
      case 'Lieferschein':
        return 'delivery_note_pdf';
      case 'Handelsrechnung':
        return 'commercial_invoice_pdf';
      case 'Packliste':
        return 'packing_list_pdf';
      default:
        return '';
    }
  }

  String _getItemKey(Map<String, dynamic> item) {
    return item['basket_doc_id']?.toString() ?? '';
  }

  double _getAssignedQuantityForOrder(Map<String, dynamic> item, List<Map<String, dynamic>> packages) {
    double totalAssigned = 0;
    final itemKey = _getItemKey(item);

    for (final package in packages) {
      final packageItems = package['items'] as List<dynamic>? ?? [];
      for (final assignedItem in packageItems) {
        if (_getItemKey(Map<String, dynamic>.from(assignedItem as Map)) == itemKey) {
          totalAssigned += ((assignedItem['quantity'] as num?)?.toDouble() ?? 0);
        }
      }
    }
    return totalAssigned;
  }

}