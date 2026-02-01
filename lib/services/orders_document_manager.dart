// File: services/order_document_manager.dart

/// Info, hier ist der Auftragsbereich


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/services/swiss_rounding.dart';
import 'dart:typed_data';
import '../customers/customer.dart';
import '../services/icon_helper.dart';
import '../orders/order_model.dart';
import 'countries.dart';
import 'order_configuration_sheet.dart';
import 'order_document_preview_manager.dart';
import 'pdf_generators/invoice_generator.dart';
import 'pdf_generators/delivery_note_generator.dart';
import 'pdf_generators/commercial_invoice_generator.dart';
import 'pdf_generators/packing_list_generator.dart';
import







'shipping_costs_manager.dart';
import '../services/additional_text_manager.dart';
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
    Map<String, bool> documentSelection = {
      'Rechnung': !existingDocs.contains('invoice_pdf'),
      'Lieferschein': !existingDocs.contains('delivery_note_pdf'),
      'Handelsrechnung': !existingDocs.contains('commercial_invoice_pdf'),
      'Packliste': !existingDocs.contains('packing_list_pdf'),
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
  final Map<String, Map<String, TextEditingController>> packageControllers = {};


  @override
  void initState() {
    super.initState();

    _selection = Map.from(widget.documentSelection);
    _selection['Rechnung'] = true;
    _settings = Map.from(widget.documentSettings);
    _customerData = Map<String, dynamic>.from(widget.order.customer ?? {});


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
        setState(() {
          _settings['packing_list'] = packingListDoc.data() ?? {'packages': []};
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
            // packaging_weight wird NICHT mehr geladen!
            'commercial_invoice_date': data['commercial_invoice_date'] != null
                ? (data['commercial_invoice_date'] as Timestamp).toDate()
                : null,
            'use_as_delivery_date': data['use_as_delivery_date'] ?? true, // NEU
            'origin_declaration': data['origin_declaration'] ?? false,
            'cites': data['cites'] ?? false,
            'export_reason': data['export_reason'] ?? false,
            'export_reason_text': data['export_reason_text'] ?? 'Ware',
            'incoterms': data['incoterms'] ?? false,
            'selected_incoterms': List<String>.from(data['selected_incoterms'] ?? []),
            'incoterms_freetexts': Map<String, String>.from(data['incoterms_freetexts'] ?? {}),
            'delivery_date': data['delivery_date'] ?? false,
            'delivery_date_value': data['delivery_date_value'] != null
                ? (data['delivery_date_value'] as Timestamp).toDate()
                : null,
            'delivery_date_month_only': data['delivery_date_month_only'] ?? false,
            'carrier': data['carrier'] ?? false,
            'carrier_text': data['carrier_text'] ?? 'Swiss Post',
            'signature': data['signature'] ?? false,
            'selected_signature': data['selected_signature'],
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
                  final alreadyExists = widget.existingDocs.contains(_getDocumentKey(docType));

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
                          const SizedBox(width: 56),

                        // Checkbox
                        Expanded(
                          child: CheckboxListTile(
                            title: Text(
                              docType,
                              style: TextStyle(
                                color: alreadyExists
                                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                    : null,
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

// NEU: Hilfsmethode für Order mit aktuellen Kundendaten
  OrderX _getOrderWithCurrentCustomerData() {
    return widget.order.copyWith(customer: _customerData);
  }

  Widget? _getDocumentSubtitle(String docType, bool alreadyExists) {
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
          // NEU: Filtere Dienstleistungen heraus
          final filteredItems = widget.order.items
              .where((item) => item['is_service'] != true)
              .toList();

          // Berechne wie viele Produkte zugewiesen sind
          int totalAssigned = 0;
          int totalProducts = filteredItems.length;  // statt widget.order.items.length

          for (final item in filteredItems) {  // statt widget.order.items
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

  Future<void> _showDocumentSettings(String docType) async {
    switch (docType) {
      case 'Rechnung':  // NEU
        await _showInvoiceSettings();
        break;
      case 'Lieferschein':
        await _showDeliveryNoteSettings();
        break;
      case 'Handelsrechnung':
        await _showCommercialInvoiceSettings();
        break;
      case 'Packliste':
        await _showPackingListSettings();
        break;
    }
  }
// Hilfsfunktion zum Zuweisen aller Produkte zu einem Paket
  void _assignAllOrderItemsToPackage(
      Map<String, dynamic> targetPackage,
      List<Map<String, dynamic>> orderItems,
      List<Map<String, dynamic>> packages,
      StateSetter setDialogState,
      ) {
    setDialogState(() {
      // Leere zuerst alle Items aus dem Zielpaket
      targetPackage['items'].clear();

      // Füge alle verfügbaren Items hinzu
      for (final item in orderItems) {
        // KORRIGIERT: num statt double casten
        final totalQuantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;

        // Entferne das Item aus allen anderen Paketen
        for (final package in packages) {
          if (package['id'] != targetPackage['id']) {
            package['items'].removeWhere((assignedItem) =>
            assignedItem['product_id'] == item['product_id']
            );
          }
        }

        // Füge das Item mit voller Menge zum Zielpaket hinzu
        targetPackage['items'].add({
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'product_name_en': item['product_name_en'],
          'quantity': totalQuantity,
          'weight_per_unit': (item['weight'] as num?)?.toDouble() ?? 0.0,
          'volume_per_unit': (item['volume_per_unit'] as num?)?.toDouble() ?? 0.0,
          'density': (item['density'] as num?)?.toDouble() ?? 0.0,
          'custom_density': (item['custom_density'] as num?)?.toDouble(),
          'custom_length': (item['custom_length'] as num?)?.toDouble() ?? 0.0,
          'custom_width': (item['custom_width'] as num?)?.toDouble() ?? 0.0,
          'custom_thickness': (item['custom_thickness'] as num?)?.toDouble() ?? 0.0,
          'wood_code': item['wood_code'] ?? '',
          'wood_name': item['wood_name'] ?? '',
          'unit': item['unit'] ?? 'Stk',
          'instrument_code': item['instrument_code'] ?? '',
          'instrument_name': item['instrument_name'] ?? '',
          'part_code': item['part_code'] ?? '',
          'part_name': item['part_name'] ?? '',
          'quality_code': item['quality_code'] ?? '',
          'quality_name': item['quality_name'] ?? '',
        });
      }
    });
  }
// Nach der _showPackingListSettings Methode hinzufügen:

// _showInvoiceSettings ersetzen:
  Future<void> _showInvoiceSettings() async {
    // Lade bestehende Einstellungen
    Map<String, dynamic>? existingSettings;

    final existingSettingsDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.id)
        .collection('settings')
        .doc('invoice_settings')
        .get();

    if (existingSettingsDoc.exists) {
      final data = existingSettingsDoc.data()!;
      existingSettings = {
        'down_payment_amount': (data['down_payment_amount'] as num?)?.toDouble() ?? 0.0,
        'down_payment_reference': data['down_payment_reference'] ?? '',
        'down_payment_date': data['down_payment_date'] != null
            ? (data['down_payment_date'] as Timestamp).toDate()
            : null,
        'invoice_date': data['invoice_date'] != null
            ? (data['invoice_date'] as Timestamp).toDate()
            : DateTime.now(),
        'is_full_payment': data['is_full_payment'] ?? false,
        'payment_method': data['payment_method'] ?? 'BAR',
        'custom_payment_method': data['custom_payment_method'] ?? '',
        'payment_term_days': data['payment_term_days'] ?? 30,
      };
    }

    final configResult = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderConfigurationSheet(
        customer: _customerData,
        items: widget.order.items,
        calculations: widget.order.calculations,
        metadata: widget.order.metadata,
        documentNumber: 'Auftrag ${widget.order.orderNumber}',
        existingInvoiceSettings: existingSettings,
        costCenter: widget.order.metadata['costCenter'],
        fair: widget.order.metadata['fairData'],
      ),
    );

    if (configResult != null) {
      final invoiceSettings = configResult['invoiceSettings'] as Map<String, dynamic>;

      // Speichere Einstellungen
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('settings')
          .doc('invoice_settings')
          .set({
        ...invoiceSettings,
        'down_payment_date': invoiceSettings['down_payment_date'] != null
            ? Timestamp.fromDate(invoiceSettings['down_payment_date'])
            : null,
        'invoice_date': invoiceSettings['invoice_date'] != null
            ? Timestamp.fromDate(invoiceSettings['invoice_date'])
            : null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _settings['invoice'] = invoiceSettings;
      });
    }
  }

  Future<void> _showDeliveryNoteSettings() async {
    DateTime? deliveryDate = _settings['delivery_note']['delivery_date'];
    DateTime? paymentDate = _settings['delivery_note']['payment_date'];
    // NEU: Wenn kein Lieferdatum gesetzt, lade aus Handelsrechnung-Einstellungen

    bool useAsCommercialInvoiceDate = false; // NEU
    DateTime? existingCommercialInvoiceDate; // NEU: Datum aus Handelsrechnung

    if (deliveryDate == null) {
      final commercialInvoiceSettings = _settings['commercial_invoice'];
      if (commercialInvoiceSettings != null && commercialInvoiceSettings['commercial_invoice_date'] != null) {
        final timestamp = commercialInvoiceSettings['commercial_invoice_date'];
        if (timestamp is DateTime) {
          deliveryDate = timestamp;
        } else if (timestamp is Timestamp) {
          deliveryDate = timestamp.toDate();
        }
      }

      // Falls nicht in _settings, versuche aus Firebase zu laden
      if (deliveryDate == null) {
        try {
          final taraSettingsDoc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.order.id)
              .collection('settings')
              .doc('tara_settings')
              .get();

          if (taraSettingsDoc.exists) {
            final data = taraSettingsDoc.data()!;
            if (data['commercial_invoice_date'] != null) {
              deliveryDate = (data['commercial_invoice_date'] as Timestamp).toDate();
            }
          }
        } catch (e) {
          print('Fehler beim Laden des Handelsrechnungsdatums: $e');
        }
      }
    }

// NEU: Lade Handelsrechnungsdatum für Vergleich
    try {
      final taraSettingsDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('settings')
          .doc('tara_settings')
          .get();

      if (taraSettingsDoc.exists) {
        final data = taraSettingsDoc.data()!;
        if (data['commercial_invoice_date'] != null) {
          existingCommercialInvoiceDate = (data['commercial_invoice_date'] as Timestamp).toDate();
        }
      }
    } catch (e) {
      print('Fehler beim Laden des Handelsrechnungsdatums für Vergleich: $e');
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {  // Renamed to avoid confusion
          // NEU: Hilfsfunktion für Datumskonflikt-Prüfung
          bool hasDateConflict() {
            if (deliveryDate == null || existingCommercialInvoiceDate == null) {
              return false;
            }
            return deliveryDate!.year != existingCommercialInvoiceDate!.year ||
                deliveryDate!.month != existingCommercialInvoiceDate!.month ||
                deliveryDate!.day != existingCommercialInvoiceDate!.day;
          }
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
                       getAdaptiveIcon(iconName: 'local_shipping',defaultIcon:Icons.local_shipping,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Lieferschein Einstellungen',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Content
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
                                // Lieferdatum
                                InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: deliveryDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (date != null) {
                                      setModalState(() {
                                        deliveryDate = date;
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
                                        getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Lieferdatum', style: TextStyle(fontSize: 12)),
                                              Text(
                                                deliveryDate != null
                                                    ? DateFormat('dd.MM.yyyy').format(deliveryDate!)
                                                    : 'Datum auswählen',
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (deliveryDate != null)
                                          IconButton(
                                            icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear),
                                            onPressed: () {
                                              setModalState(() {
                                                deliveryDate = null;
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

// NEU: Checkbox für Übernahme zur Handelsrechnung
                                CheckboxListTile(
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
                                    setModalState(() {
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
                                ),

// NEU: Hinweis wenn Checkbox aktiv und Datum gesetzt
                                if (useAsCommercialInvoiceDate && deliveryDate != null)
                                  Padding(
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
                                  ),

// NEU: Warnung bei Datumskonflikt
                                if (hasDateConflict())
                                  Padding(
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
                                                  'Handelsrechnung: ${DateFormat('dd.MM.yyyy').format(existingCommercialInvoiceDate!)}\n'
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
                                  ),
                                const SizedBox(height: 16),

                                // Adressdaten abgleichen Button
                                InkWell(
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _compareAndUpdateCustomerAddress();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
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
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                                ),

                                const SizedBox(height: 16),

                                // Zahlungsdatum
                                InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: paymentDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (date != null) {
                                      setModalState(() {
                                        paymentDate = date;
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
                                        getAdaptiveIcon(iconName: 'payment', defaultIcon: Icons.payment),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Zahlungsdatum', style: TextStyle(fontSize: 12)),
                                              Text(
                                                paymentDate != null
                                                    ? DateFormat('dd.MM.yyyy').format(paymentDate!)
                                                    : 'Datum auswählen',
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (paymentDate != null)
                                          IconButton(
                                            icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear),
                                            onPressed: () {
                                              setModalState(() {
                                                paymentDate = null;
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Actions - AUSSERHALB des ScrollView, am unteren Rand fixiert
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
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('orders')
                                        .doc(widget.order.id)
                                        .collection('settings')
                                        .doc('delivery_settings')
                                        .set({
                                      'delivery_date': deliveryDate != null
                                          ? Timestamp.fromDate(deliveryDate!)
                                          : null,
                                      'payment_date': paymentDate != null
                                          ? Timestamp.fromDate(paymentDate!)
                                          : null,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
// NEU: Wenn Checkbox aktiv, auch Handelsrechnungsdatum aktualisieren
                                    if (useAsCommercialInvoiceDate && deliveryDate != null) {
                                      await FirebaseFirestore.instance
                                          .collection('orders')
                                          .doc(widget.order.id)
                                          .collection('settings')
                                          .doc('tara_settings')
                                          .set({
                                        'commercial_invoice_date': Timestamp.fromDate(deliveryDate!),
                                      }, SetOptions(merge: true));

                                      // Update auch den lokalen State
                                      if (_settings['commercial_invoice'] != null) {
                                        _settings['commercial_invoice']['commercial_invoice_date'] = deliveryDate;
                                      }
                                    }
                                    Navigator.pop(context);
                                    setState(() {
                                      _settings['delivery_note'] = <String, dynamic>{
                                        'delivery_date': deliveryDate,
                                        'payment_date': paymentDate,
                                      };
                                    });
                                  },
                                  icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save),
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
        },
      ),
    );
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

    // Lieferadresse vergleichen (falls vorhanden)
    if (currentCustomer.hasDifferentShippingAddress) {
      compare('Lieferadresse Firma', orderCustomer['shippingCompany'], currentCustomer.shippingCompany);
      compare('Lieferadresse Vorname', orderCustomer['shippingFirstName'], currentCustomer.shippingFirstName);
      compare('Lieferadresse Nachname', orderCustomer['shippingLastName'], currentCustomer.shippingLastName);
      compare('Lieferadresse Straße', orderCustomer['shippingStreet'], currentCustomer.shippingStreet);
      compare('Lieferadresse PLZ', orderCustomer['shippingZipCode'], currentCustomer.shippingZipCode);
      compare('Lieferadresse Ort', orderCustomer['shippingCity'], currentCustomer.shippingCity);
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
            ? const Text('Die Adressdaten im Auftrag stimmen mit der Datenbank überein.')
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

  Future<void> _showCommercialInvoiceSettings() async {
    final settings = Map<String, dynamic>.from(_settings['commercial_invoice']);

// NEU: Für Konfliktprüfung
    DateTime? existingDeliveryNoteDate;
    // NEU: Berechne Verpackungsgewicht aus Packliste
    double totalPackagingWeight = 0.0;
    int numberOfPackages = 0;
    double manualPackagingWeight = settings['packaging_weight']?.toDouble() ?? 0.0;

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
        numberOfPackages = packages.length;

        // Summiere alle Tara-Gewichte
        for (final package in packages) {
          totalPackagingWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (e) {
      print('Fehler beim Laden der Packlisten-Daten: $e');
    }

    DateTime? commercialInvoiceDate;

    bool useAsDeliveryDate = true; // NEU: Standardmäßig aktiviert
    if (settings['commercial_invoice_date'] != null) {
      commercialInvoiceDate = settings['commercial_invoice_date'] is Timestamp
          ? (settings['commercial_invoice_date'] as Timestamp).toDate()
          : settings['commercial_invoice_date'] as DateTime?;
    }

// NEU: Lade useAsDeliveryDate Einstellung
    useAsDeliveryDate = settings['use_as_delivery_date'] ?? true;

    String selectedCurrency = widget.order.metadata['currency'] ?? 'CHF';
    if (settings['currency'] != null) {
      selectedCurrency = settings['currency'];
    }

    // Controller für Textfelder
    final numberOfPackagesController = TextEditingController(
      text: numberOfPackages > 0 ? numberOfPackages.toString() : (settings['number_of_packages'] ?? 1).toString(),
    );
    final exportReasonController = TextEditingController(
      text: settings['export_reason_text'] ?? 'Ware',
    );
    final carrierController = TextEditingController(
      text: settings['carrier_text'] ?? 'Swiss Post',
    );

    // NEU: Incoterms Variablen
    List<String> selectedIncoterms = List<String>.from(settings['selected_incoterms'] ?? []);
    Map<String, String> incotermsFreeTexts = Map<String, String>.from(settings['incoterms_freetexts'] ?? {});
    final Map<String, TextEditingController> incotermControllers = {};


    // Controller für bestehende Incoterms erstellen
    for (String incotermId in selectedIncoterms) {
      // Hole den Incoterm-Namen
      final incotermDoc = await FirebaseFirestore.instance
          .collection('incoterms')
          .doc(incotermId)
          .get();

      String defaultText = incotermsFreeTexts[incotermId] ?? '';

      // Wenn DAP: Prüfe ob es ein Auto-generierter Text ist und aktualisiere ihn
      if (incotermDoc.exists) {
        final incotermData = incotermDoc.data() as Map<String, dynamic>;
        final incotermName = incotermData['name'] as String;

        if (incotermName == 'DAP') {
          // Prüfe ob der Text dem Standard-Format entspricht
          final isDomicile = defaultText.startsWith('Domicile consignee,') ||
              defaultText.startsWith('Domizil Käufer,');

          // Wenn leer ODER Standard-Format: Neu generieren
          if (defaultText.isEmpty || isDomicile) {
            final countryName = _customerData['country'];
            final country = Countries.getCountryByName(countryName);
            final language = _customerData['language'] ?? 'DE';

            defaultText = language == 'DE'
                ? 'Domizil Käufer, ${country?.name?? countryName}'
                : 'Domicile consignee, ${country?.nameEn ?? countryName}';

            // WICHTIG: Aktualisiere auch die Map, die gespeichert wird!
            incotermsFreeTexts[incotermId] = defaultText;
          }
        }
      }

      incotermControllers[incotermId] = TextEditingController(text: defaultText);
    }

    // NEU: Lieferdatum Variablen
    DateTime? selectedDeliveryDate;
    if (settings['delivery_date_value'] != null) {
      final timestamp = settings['delivery_date_value'];
      if (timestamp is Timestamp) {
        selectedDeliveryDate = timestamp.toDate();
      }
    }
    bool deliveryDateMonthOnly = settings['delivery_date_month_only'] ?? false;

    // NEU: Signatur Variable
    String? selectedSignature = settings['selected_signature'];


    // NEU: Lade Lieferschein-Einstellungen für Vergleich
    try {
      final deliverySettingsDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('settings')
          .doc('delivery_settings')
          .get();

      if (deliverySettingsDoc.exists) {
        final data = deliverySettingsDoc.data()!;
        if (data['delivery_date'] != null) {
          existingDeliveryNoteDate = (data['delivery_date'] as Timestamp).toDate();
        }
      }
    } catch (e) {
      print('Fehler beim Laden des Lieferscheindatums: $e');
    }



    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // NEU: Hilfsfunktion für Datumskonflikt-Prüfung
          bool hasDeliveryDateConflict() {
            if (commercialInvoiceDate == null || existingDeliveryNoteDate == null) {
              return false;
            }
            return commercialInvoiceDate!.year != existingDeliveryNoteDate!.year ||
                commercialInvoiceDate!.month != existingDeliveryNoteDate!.month ||
                commercialInvoiceDate!.day != existingDeliveryNoteDate!.day;
          }
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
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                       getAdaptiveIcon(iconName: 'inventory',defaultIcon:Icons.inventory,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Handelsrechnung Einstellungen',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tara-Einstellungen
                        Text(
                          'Tara-Einstellungen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info wenn aus Packliste
                        if (numberOfPackages > 0) ...[
                          Container(
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
                                getAdaptiveIcon(iconName: 'info', defaultIcon:
                                  Icons.info,
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
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Anzahl Packungen
                        TextField(
                          controller: numberOfPackagesController,
                          keyboardType: TextInputType.number,
                          readOnly: numberOfPackages > 0,
                          decoration: InputDecoration(
                            labelText: 'Anzahl Packungen',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: getAdaptiveIcon(iconName: 'inventory',defaultIcon:Icons.inventory),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            helperText: numberOfPackages > 0
                                ? 'Aus Packliste übernommen'
                                : 'Anzahl der Verpackungseinheiten',
                            filled: numberOfPackages > 0,
                            fillColor: numberOfPackages > 0
                                ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
                                : null,
                          ),
                          onChanged: numberOfPackages > 0 ? null : (value) {
                            settings['number_of_packages'] = int.tryParse(value) ?? 1;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Verpackungsgewicht - editierbar wenn NICHT aus Packliste
                        if (numberOfPackages > 0) ...[
                          // Nur Anzeige wenn aus Packliste
                          Container(
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
                                      const Text(
                                        'Verpackungsgewicht (kg)',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        totalPackagingWeight.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                          ),
                        ] else ...[
                          // Editierbares Feld wenn KEINE Packliste
                          TextField(
                            controller: TextEditingController(
                              text: (settings['packaging_weight'] ?? 0.0).toString(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Verpackungsgewicht (kg)',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(
                                  iconName: 'scale',
                                  defaultIcon: Icons.scale,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              helperText: 'Gesamtgewicht der Verpackung in kg',
                            ),
                            onChanged: (value) {
                              setModalState(() {
                                settings['packaging_weight'] = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Datum der Handelsrechnung
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: commercialInvoiceDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              locale: const Locale('de', 'DE'),
                            );
                            if (picked != null) {
                              setModalState(() {
                                commercialInvoiceDate = picked;
                                settings['commercial_invoice_date'] = picked;
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
                                getAdaptiveIcon(iconName: 'calendar_today',defaultIcon:Icons.calendar_today),
                                const SizedBox(width: 12),
                                Expanded(
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
                                      Text(
                                        commercialInvoiceDate != null
                                            ? DateFormat('dd.MM.yyyy').format(commercialInvoiceDate!)
                                            : 'Aktuelles Datum verwenden',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                if (commercialInvoiceDate != null)
                                  IconButton(
                                    icon:  getAdaptiveIcon(iconName: 'clear', defaultIcon:Icons.clear),
                                    onPressed: () {
                                      setModalState(() {
                                        commercialInvoiceDate = null;
                                        settings['commercial_invoice_date'] = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

// NEU: Checkbox für Übernahme als Lieferdatum
                        // NEU: Checkbox für Übernahme als Lieferdatum
                        CheckboxListTile(
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
                            setModalState(() {
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
                        ),


                        const SizedBox(height: 24),


// Währungsauswahl
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
                                  ButtonSegment(
                                    value: 'CHF',
                                    label: Text('CHF'),
                                  ),
                                  ButtonSegment(
                                    value: 'EUR',
                                    label: Text('EUR'),
                                  ),
                                  ButtonSegment(
                                    value: 'USD',
                                    label: Text('USD'),
                                  ),
                                ],
                                selected: {selectedCurrency},
                                onSelectionChanged: (Set<String> newSelection) {
                                  setModalState(() {
                                    selectedCurrency = newSelection.first;
                                    settings['currency'] = selectedCurrency;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        if (selectedCurrency != (widget.order.metadata['currency'] ?? 'CHF'))
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
                                      'Abweichend von Auftragswährung (${widget.order.metadata['currency'] ?? 'CHF'})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),


                        // Standardsätze
                        Text(
                          'Standardsätze',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),

                        const SizedBox(height: 16),

// NEU: Alle auswählen / Alle abwählen
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  settings['origin_declaration'] = true;
                                  settings['cites'] = true;
                                  settings['export_reason'] = true;
                                  settings['incoterms'] = true;
                                  settings['delivery_date'] = true;
                                  settings['carrier'] = true;
                                  settings['signature'] = true;
                                  // Setze Standard-Signatur wenn aktiviert
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
                                setModalState(() {
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
                        ),
                        const SizedBox(height: 8),


                        // Ursprungserklärung - mit Info-Icon
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Ursprungserklärung'),
                                subtitle: const Text('Erklärung über Schweizer Ursprungswaren'),
                                value: settings['origin_declaration'] ?? false,
                                onChanged: (value) {
                                  setModalState(() {
                                    settings['origin_declaration'] = value ?? false;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: getAdaptiveIcon(iconName: 'info', defaultIcon:
                                Icons.info,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () async {
                                // Lade den Standardtext
                                await AdditionalTextsManager.loadDefaultTextsFromFirebase();
                                final defaultText = AdditionalTextsManager.getTextContent(
                                  {'selected': true, 'type': 'standard'},
                                  'origin_declaration',
                                  language: _customerData['language'] ?? 'DE',
                                );

                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Row(
                                      children: [
                                        getAdaptiveIcon(iconName: 'info', defaultIcon:
                                          Icons.info,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Ursprungserklärung'),
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
                                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              defaultText,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              getAdaptiveIcon(iconName: 'edit', defaultIcon:
                                                Icons.edit,
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
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                            ),
                          ],
                        ),

                        // CITES - mit Info-Icon
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('CITES'),
                                subtitle: const Text('Waren stehen NICHT auf der CITES-Liste'),
                                value: settings['cites'] ?? false,
                                onChanged: (value) {
                                  setModalState(() {
                                    settings['cites'] = value ?? false;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon:  getAdaptiveIcon(iconName: 'info', defaultIcon:
                                Icons.info,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () async {
                                // Lade den Standardtext
                                await AdditionalTextsManager.loadDefaultTextsFromFirebase();
                                final defaultText = AdditionalTextsManager.getTextContent(
                                  {'selected': true, 'type': 'standard'},
                                  'cites',
                                  language: _customerData['language'] ?? 'DE',
                                );

                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Row(
                                      children: [
                                        getAdaptiveIcon(iconName: 'info', defaultIcon:
                                          Icons.info,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('CITES-Erklärung'),
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
                                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              defaultText,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              getAdaptiveIcon(iconName: 'edit', defaultIcon:
                                                Icons.edit,
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
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                            ),
                          ],
                        ),

                        // Export Reason mit Textfeld
                        CheckboxListTile(
                          title: const Text('Grund des Exports'),
                          value: settings['export_reason'] ?? false,
                          onChanged: (value) {
                            setModalState(() {
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                settings['export_reason_text'] = value;
                              },
                            ),
                          ),

                        // Incoterms - NEU: Vollständige Implementierung
                        CheckboxListTile(
                          title: const Text('Incoterms'),
                          value: settings['incoterms'] ?? false,
                          onChanged: (value) {
                            setModalState(() {
                              settings['incoterms'] = value ?? false;
                              if (!(settings['incoterms'] ?? false)) {
                                selectedIncoterms.clear();
                                incotermsFreeTexts.clear();
                              }
                            });
                          },
                        ),
                        if (settings['incoterms'] ?? false) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('incoterms').snapshots(),
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
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: incotermDocs.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final name = data['name'] as String;
                                        final isSelected = selectedIncoterms.contains(doc.id);

                                        return FilterChip(
                                          label: Text(name),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setModalState(() {
                                              if (selected) {
                                                selectedIncoterms.add(doc.id);

                                                // NEU: Für DAP automatisch Default-Text setzen
                                                String initialText = '';
                                                if (name == 'DAP') {
                                                  final countryName = _customerData['country'];
                                                  final country = Countries.getCountryByName(countryName);
                                                  final language = _customerData['language'] ?? 'DE';

                                                  initialText = language == 'DE'
                                                      ? 'Domizil Käufer, ${country?.name ?? countryName}'
                                                      : 'Domicile consignee, ${country?.nameEn ?? countryName}';
                                                }

                                                incotermsFreeTexts[doc.id] = initialText;
                                                incotermControllers[doc.id] = TextEditingController(text: initialText);
                                              } else {
                                                selectedIncoterms.remove(doc.id);
                                                incotermsFreeTexts.remove(doc.id);
                                                incotermControllers[doc.id]?.dispose();
                                                incotermControllers.remove(doc.id);
                                              }
                                              settings['selected_incoterms'] = selectedIncoterms;
                                              settings['incoterms_freetexts'] = incotermsFreeTexts;
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    // Beschreibung der ausgewählten Incoterms
                                    if (selectedIncoterms.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ...selectedIncoterms.map((incotermId) {
                                        final incotermDoc = incotermDocs.firstWhere((doc) => doc.id == incotermId);
                                        final data = incotermDoc.data() as Map<String, dynamic>;
                                        final name = data['name'] as String;
                                        final description = data['de'] as String? ?? data['en'] as String? ?? '';

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.primaryContainer,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    name,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (description.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2, bottom: 4),
                                                child: Text(
                                                  description,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                              ),
                                            TextField(
                                              decoration: InputDecoration(
                                                labelText: 'Zusätzlicher Text für $name',
                                                hintText: 'z.B. Domicile consignee, Sweden',
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                isDense: true,
                                              ),
                                              controller: incotermControllers[incotermId],
                                              onChanged: (value) {
                                                incotermsFreeTexts[incotermId] = value;
                                                settings['incoterms_freetexts'] = incotermsFreeTexts;
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

                        // Lieferdatum - Automatisch von oben übernommen wenn useAsDeliveryDate aktiv
                        CheckboxListTile(
                          title: const Text('Lieferdatum auf Handelsrechnung'),
                          subtitle: Text(
                            settings['delivery_date'] == true
                                ? (useAsDeliveryDate && commercialInvoiceDate != null
                                ? (deliveryDateMonthOnly
                                ? '${['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'][commercialInvoiceDate!.month - 1]} ${commercialInvoiceDate!.year}'
                                : DateFormat('dd.MM.yyyy').format(commercialInvoiceDate!))
                                : (selectedDeliveryDate != null
                                ? (deliveryDateMonthOnly
                                ? '${['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'][selectedDeliveryDate!.month - 1]} ${selectedDeliveryDate!.year}'
                                : DateFormat('dd.MM.yyyy').format(selectedDeliveryDate!))
                                : 'Datum auswählen'))
                                : 'Lieferdatum auf der Handelsrechnung anzeigen',
                            style: TextStyle(
                              fontSize: 12,
                              color: settings['delivery_date'] == true && (useAsDeliveryDate && commercialInvoiceDate != null || selectedDeliveryDate != null)
                                  ? Colors.green[700]
                                  : null,
                            ),
                          ),
                          value: settings['delivery_date'] ?? false,
                          onChanged: (value) {
                            setModalState(() {
                              settings['delivery_date'] = value ?? false;
                              if (!(settings['delivery_date'] ?? false)) {
                                selectedDeliveryDate = null;
                                settings['delivery_date_value'] = null;
                              } else if (useAsDeliveryDate && commercialInvoiceDate != null) {
                                // Übernimm automatisch das Handelsrechnungsdatum
                                selectedDeliveryDate = commercialInvoiceDate;
                                settings['delivery_date_value'] = commercialInvoiceDate;
                              }
                            });
                          },
                        ),
// NEU: Warnung bei Datumskonflikt mit Lieferschein
                        if (hasDeliveryDateConflict())
                          Padding(
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
                                          'Lieferschein: ${DateFormat('dd.MM.yyyy').format(existingDeliveryNoteDate!)}\n'
                                              'Handelsrechnung: ${DateFormat('dd.MM.yyyy').format(commercialInvoiceDate!)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange[700],
                                          ),
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
                          ),
                        if (settings['delivery_date'] ?? false) ...[
                          // Info wenn Datum von oben übernommen wird
                          if (useAsDeliveryDate && commercialInvoiceDate != null)
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
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            // Manueller Datepicker nur wenn NICHT von oben übernommen
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
                                          setModalState(() {
                                            selectedDeliveryDate = date;
                                            settings['delivery_date_value'] = date;
                                          });
                                        }
                                      },
                                      icon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                                      label: Text(selectedDeliveryDate != null
                                          ? DateFormat('dd.MM.yyyy').format(selectedDeliveryDate!)
                                          : 'Datum auswählen'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Format-Toggle immer anzeigen
                          Padding(
                            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  'Format:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ToggleButtons(
                                  isSelected: [!deliveryDateMonthOnly, deliveryDateMonthOnly],
                                  onPressed: (index) {
                                    setModalState(() {
                                      deliveryDateMonthOnly = index == 1;
                                      settings['delivery_date_month_only'] = deliveryDateMonthOnly;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
                                  children: const [
                                    Text('TT.MM.JJJJ', style: TextStyle(fontSize: 11)),
                                    Text('Monat JJJJ', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Carrier mit Textfeld
                        CheckboxListTile(
                          title: const Text('Transporteur'),
                          value: settings['carrier'] ?? false,
                          onChanged: (value) {
                            setModalState(() {
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                settings['carrier_text'] = value;
                              },
                            ),
                          ),

                        // Signatur - NEU: Mit Dropdown
                        // Signatur - NEU: Mit Dropdown und automatischer Vorauswahl
                        CheckboxListTile(
                          title: const Text('Signatur'),
                          value: settings['signature'] ?? false,
                          onChanged: (value) {
                            setModalState(() {
                              settings['signature'] = value ?? false;
                              if (settings['signature'] == true) {
                                // Automatische Vorauswahl wenn aktiviert
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
                                    setModalState(() {
                                      selectedSignature = value;
                                      settings['selected_signature'] = value;
                                    });
                                  },
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Actions
                        Row(
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
                                onPressed: () async {
                                  // Speichere in Firebase
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(widget.order.id)
                                      .collection('settings')
                                      .doc('tara_settings')
                                      .set({
                                    'number_of_packages': numberOfPackages > 0 ? numberOfPackages : settings['number_of_packages'],
                                    'packaging_weight': numberOfPackages > 0 ? totalPackagingWeight : (settings['packaging_weight'] ?? 0.0),
                                    'commercial_invoice_date': commercialInvoiceDate != null
                                        ? Timestamp.fromDate(commercialInvoiceDate!)
                                        : null,
                                    'use_as_delivery_date': useAsDeliveryDate,  // <-- FEHLT!
                                    'commercial_invoice_currency': selectedCurrency,
                                    'commercial_invoice_origin_declaration': settings['origin_declaration'],
                                    'commercial_invoice_cites': settings['cites'],
                                    'commercial_invoice_export_reason': settings['export_reason'],
                                    'commercial_invoice_export_reason_text': settings['export_reason_text'],
                                    'commercial_invoice_incoterms': settings['incoterms'],
                                    'commercial_invoice_selected_incoterms': settings['selected_incoterms'] ?? [],
                                    'commercial_invoice_incoterms_freetexts': settings['incoterms_freetexts'] ?? {},
                                    'commercial_invoice_delivery_date': settings['delivery_date'],
                                    'commercial_invoice_delivery_date_value': selectedDeliveryDate != null
                                        ? Timestamp.fromDate(selectedDeliveryDate!)
                                        : null,
                                    'commercial_invoice_delivery_date_month_only': settings['delivery_date_month_only'] ?? false,
                                    'commercial_invoice_carrier': settings['carrier'],
                                    'commercial_invoice_carrier_text': settings['carrier_text'],
                                    'commercial_invoice_signature': settings['signature'],
                                    'commercial_invoice_selected_signature': settings['selected_signature'],
                                    'timestamp': FieldValue.serverTimestamp(),
                                  }
                                  );

                                  // NEU: Wenn Checkbox aktiv, speichere auch in delivery_settings
                                  if (useAsDeliveryDate && commercialInvoiceDate != null) {
                                    await FirebaseFirestore.instance
                                        .collection('orders')
                                        .doc(widget.order.id)
                                        .collection('settings')
                                        .doc('delivery_settings')
                                        .set({
                                      'delivery_date': Timestamp.fromDate(commercialInvoiceDate!),
                                      'timestamp': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));

                                    // Update auch den lokalen State
                                    _settings['delivery_note']['delivery_date'] = commercialInvoiceDate;
                                  }


                                  setState(() {
                                    _settings['commercial_invoice'] = settings;
                                  });
                                  Navigator.pop(context);
                                },
                                icon: getAdaptiveIcon( iconName: 'save', defaultIcon:Icons.save),
                                label: const Text('Speichern'),
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

  Future<void> _showPackingListSettings() async {
    // Kopiere bestehende Packages oder erstelle neue
    // Kopiere bestehende Packages oder erstelle neue
    List<Map<String, dynamic>> packages = [];

    try {
      final packingListDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('packing_list')
          .doc('settings')
          .get();

      if (packingListDoc.exists) {
        final data = packingListDoc.data()!;
        final rawPackages = data['packages'] as List<dynamic>? ?? [];
        packages = rawPackages.map((p) => Map<String, dynamic>.from(p as Map)).toList();
      }
    } catch (e) {
      print('Fehler beim Laden der Packlisten-Einstellungen: $e');
    }

// NEU: Aktualisiere die Maße in bestehenden Paketen mit aktuellen Werten aus der Order
    for (final package in packages) {
      final packageItems = package['items'] as List<dynamic>? ?? [];
      for (int i = 0; i < packageItems.length; i++) {
        final assignedItem = packageItems[i] as Map<String, dynamic>;
        final productId = assignedItem['product_id'];

        // Finde das aktuelle Item in der Order
        final currentItem = widget.order.items.firstWhere(
              (item) => item['product_id'] == productId,
          orElse: () => <String, dynamic>{},
        );

        if (currentItem.isNotEmpty) {
          // Aktualisiere die Maße mit den aktuellen Werten
          packageItems[i] = {
            ...assignedItem,
            'custom_length': (currentItem['custom_length'] as num?)?.toDouble() ?? 0.0,
            'custom_width': (currentItem['custom_width'] as num?)?.toDouble() ?? 0.0,
            'custom_thickness': (currentItem['custom_thickness'] as num?)?.toDouble() ?? 0.0,
            'density': (currentItem['density'] as num?)?.toDouble() ?? 0.0,
            'custom_density': (currentItem['custom_density'] as num?)?.toDouble(),
            'volume_per_unit': (currentItem['volume_per_unit'] as num?)?.toDouble() ?? 0.0,
            'weight_per_unit': (currentItem['weight'] as num?)?.toDouble() ?? 0.0,
            'product_name': currentItem['product_name'] ?? assignedItem['product_name'],
            'product_name_en': currentItem['product_name_en'] ?? assignedItem['product_name_en'],
            'wood_code': currentItem['wood_code'] ?? assignedItem['wood_code'],
            'wood_name': currentItem['wood_name'] ?? assignedItem['wood_name'],
            'unit': currentItem['unit'] ?? assignedItem['unit'],
            'instrument_code': currentItem['instrument_code'] ?? assignedItem['instrument_code'],
            'instrument_name': currentItem['instrument_name'] ?? assignedItem['instrument_name'],
            'part_code': currentItem['part_code'] ?? assignedItem['part_code'],
            'part_name': currentItem['part_name'] ?? assignedItem['part_name'],
            'quality_code': currentItem['quality_code'] ?? assignedItem['quality_code'],
            'quality_name': currentItem['quality_name'] ?? assignedItem['quality_name'],
          };

          print('Aktualisiert: ${currentItem['product_name']} - ${currentItem['custom_length']}×${currentItem['custom_width']}×${currentItem['custom_thickness']}');
        }
      }
    }
//Filtere Dienstleistungen aus den Order-Items heraus
    final List<Map<String, dynamic>> filteredOrderItems = widget.order.items
        .where((item) => item['is_service'] != true)
        .toList();

// Falls noch keine Pakete existieren, erstelle Paket 1
    if (packages.isEmpty) {
      final firstPackageId = DateTime.now().millisecondsSinceEpoch.toString(); // NEU: Eindeutige ID
      packages.add({
        'id': firstPackageId,
        'name': 'Packung 1',
        'packaging_type': '',
        'length': 0.0,
        'width': 0.0,
        'height': 0.0,
        'tare_weight': 0.0,
        'items': <Map<String, dynamic>>[],
        'standard_package_id': null,
      });

      // Controller für das erste Paket
      packageControllers[firstPackageId] = {
        'length': TextEditingController(text: '0.0'),
        'width': TextEditingController(text: '0.0'),
        'height': TextEditingController(text: '0.0'),
        'weight': TextEditingController(text: '0.0'),
        'custom_name': TextEditingController(text: ''),
      };
    }else {
      // Initialisiere Controller für existierende Pakete
      for (final package in packages) {
        final packageId = package['id'] as String;
        packageControllers[packageId] = {
          'length': TextEditingController(text: package['length'].toString()),
          'width': TextEditingController(text: package['width'].toString()),
          'height': TextEditingController(text: package['height'].toString()),
          'weight': TextEditingController(text: package['tare_weight'].toString()),
          'custom_name': TextEditingController(text: package['packaging_type'] ?? ''),
        };
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.9,
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
                         getAdaptiveIcon(iconName: 'view_list',defaultIcon:Icons.view_list,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        const Text('Packliste Einstellungen',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
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
                          // Übersicht verfügbare Produkte
                          // Übersicht verfügbare Produkte
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Produkte aus Auftrag',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    // NEU: Schnell-Button
                                    if (packages.isNotEmpty)
                                      TextButton.icon(
                                        onPressed: () {
                                          _assignAllOrderItemsToPackage(
                                            packages.first, // Paket 1
                                            filteredOrderItems,
                                            packages,
                                            setModalState,
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Alle Produkte wurden Paket 1 zugewiesen'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        icon:
                                        getAdaptiveIcon(iconName: 'inbox', defaultIcon:
                                          Icons.inbox,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Alle → Paket 1',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...filteredOrderItems.map((item) {
                                  final assignedQuantity = _getAssignedQuantityForOrder(item, packages);
                                  final totalQuantity = (item['quantity'] as num).toDouble();
                                  final remainingQuantity = totalQuantity - assignedQuantity;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['product_name'] ?? '',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: remainingQuantity > 0
                                                ? Colors.orange.withOpacity(0.2)
                                                : Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '$remainingQuantity/$totalQuantity verbleibend',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: remainingQuantity > 0 ? Colors.orange[700] : Colors.green[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Pakete verwalten
                          Row(
                            children: [
                              Text(
                                'Pakete',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    final newPackageId = DateTime.now().millisecondsSinceEpoch.toString(); // NEU: Eindeutige ID

                                    // Erstelle Controller für das neue Paket
                                    packageControllers[newPackageId] = {
                                      'length': TextEditingController(text: '0.0'),
                                      'width': TextEditingController(text: '0.0'),
                                      'height': TextEditingController(text: '0.0'),
                                      'weight': TextEditingController(text: '0.0'),
                                      'custom_name': TextEditingController(text: ''),
                                    };

                                    packages.add({
                                      'id': newPackageId,
                                      'name': '${packages.length + 1}', // Name basiert auf aktueller Anzahl
                                      'packaging_type': '',
                                      'length': 0.0,
                                      'width': 0.0,
                                      'height': 0.0,
                                      'tare_weight': 0.0,
                                      'items': <Map<String, dynamic>>[],
                                      'standard_package_id': null,
                                    });
                                  });
                                },
                                icon:  getAdaptiveIcon(iconName: 'add', defaultIcon:Icons.add, size: 16),
                                label: const Text('Paket hinzufügen'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Pakete anzeigen
                          ...packages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final package = entry.value;

                            package['name'] = '${index + 1}';

                            return _buildOrderPackageCard(
                              context,
                              package,
                              index,
                              filteredOrderItems,
                              packages,
                              setModalState,
                              packageControllers, // NEU: Controller Map übergeben
                            );
                          }).toList(),

                          const SizedBox(height: 24),

                          // Actions
                          Row(
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
                                  onPressed: () async {
                                    // Speichere direkt in Firebase für diesen Auftrag
                                    if (widget.order.id.isNotEmpty) {
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('orders')
                                            .doc(widget.order.id)
                                            .collection('packing_list')
                                            .doc('settings')
                                            .set({
                                          'packages': packages,
                                          'created_at': FieldValue.serverTimestamp(),
                                          'updated_by': FirebaseAuth.instance.currentUser?.uid,
                                        });
                                      } catch (e) {
                                        print('Fehler beim Speichern der Packlisten-Einstellungen: $e');
                                      }
                                    }

                                    // Dispose all controllers
                                    packageControllers.forEach((key, controllers) {
                                      controllers.forEach((_, controller) {
                                        controller.dispose();
                                      });
                                    });

                                    Navigator.pop(context);
                                    setState(() {
                                      _settings['packing_list']['packages'] = packages;
                                    });
                                  },
                                  icon: getAdaptiveIcon( iconName: 'save', defaultIcon:Icons.save),
                                  label: const Text('Speichern'),
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
            ),
          );
        },
      ),
    );
  }


  Future<void> _createDocuments() async {
    setState(() {
      _isCreating = true;
    });

    try {
      if (_selection['Packliste'] == true) {
        final packagesRaw = _settings['packing_list']['packages'] as List<dynamic>? ?? [];
        final packages = packagesRaw.map((p) => Map<String, dynamic>.from(p as Map)).toList();

        // Prüfe ob alle Produkte zugewiesen wurden
        final unassignedProducts = <String>[];

        for (final item in widget.order.items) {
          final productId = item['product_id'] as String? ?? '';
          final productName = item['product_name'] as String? ?? 'Unbekanntes Produkt';
          final totalQuantity = item['quantity'] as double? ?? 0;
          final assignedQuantity = _getAssignedQuantityForOrder(item, packages);

          if (assignedQuantity < totalQuantity) {
            final remaining = totalQuantity - assignedQuantity;
            unassignedProducts.add('$productName: $remaining von $totalQuantity Stück nicht zugewiesen');
          }
        }

        // Wenn nicht alle Produkte zugewiesen wurden, zeige Warnung
        if (unassignedProducts.isNotEmpty) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title:  Row(
                children: [
                   getAdaptiveIcon(iconName: 'warning',defaultIcon:Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Achtung'),
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
                      'Möchten Sie trotzdem fortfahren?',
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

      // Erstelle ausgewählte Dokumente
      for (final entry in _selection.entries) {
        if (entry.value && !widget.existingDocs.contains(_getDocumentKey(entry.key))) {
          final success = await _createDocument(entry.key, orderData);
          if (success) {
            createdDocuments.add(entry.key);
          }
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
            language: orderData['language'],
            invoiceNumber: widget.order.orderNumber,
            shippingCosts: orderData['shippingCosts'],
            calculations: orderData['calculations'],
            paymentTermDays: 30,
            taxOption: orderData['taxOption'],
            vatRate: orderData['vatRate'],
              downPaymentSettings: invoiceSettings,
            roundingSettings: roundingSettings,
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
            language: orderData['language'],
            deliveryNoteNumber: '${widget.order.orderNumber}-LS',
            deliveryDate: settings['delivery_date'],
            paymentDate: settings['payment_date'],
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
            'commercial_invoice_delivery_date': settings['delivery_date'],
            'commercial_invoice_delivery_date_value': settings['delivery_date_value'],
            'commercial_invoice_delivery_date_month_only': settings['delivery_date_month_only'],
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
            language: orderData['language'],
            invoiceNumber: '${widget.order.orderNumber}-CI',
            shippingCosts: orderData['shippingCosts'],
            calculations: orderData['calculations'],
            taxOption: orderData['taxOption'],
            vatRate: orderData['vatRate'],
            taraSettings: taraSettings,
            invoiceDate: invoiceDate,
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
            language: orderData['language'],
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

  // Hilfsmethoden für Packliste
double _getAssignedQuantityForOrder(Map<String, dynamic> item, List<Map<String, dynamic>> packages) {
   double totalAssigned = 0;
    final productId = item['product_id'] ?? '';

    for (final package in packages) {
      final packageItems = package['items'] as List<dynamic>? ?? [];
      for (final assignedItem in packageItems) {
        if (assignedItem['product_id'] == productId) {
          totalAssigned += ((assignedItem['quantity'] as num?)?.toDouble() ?? 0);
        }
      }
    }
    return totalAssigned;
  }



  Widget _buildOrderPackageCard(
      BuildContext context,
      Map<String, dynamic> package,
      int index,
      List<Map<String, dynamic>> orderItems,
      List<Map<String, dynamic>> packages,
      StateSetter setModalState,
      Map<String, Map<String, TextEditingController>> packageControllers,
      ) {
    // State für ausgewähltes Standardpaket
    String? selectedStandardPackageId = package['standard_package_id'];

    // Hole Controller aus der Map
    final controllers = packageControllers[package['id']]!;
    final lengthController = controllers['length']!;
    final widthController = controllers['width']!;
    final heightController = controllers['height']!;
    final weightController = controllers['weight']!;
    final customNameController = controllers['custom_name']!;

    // Controller für Bruttogewicht
    if (!controllers.containsKey('gross_weight')) {
      controllers['gross_weight'] = TextEditingController(
        text: package['gross_weight']?.toString() ?? '',
      );
    }
    final grossWeightController = controllers['gross_weight']!;

    // Berechne Nettogewicht (Summe aller Produkte im Paket)
    double calculateNetWeight() {
      double netWeight = 0.0;
      final packageItems = package['items'] as List<dynamic>? ?? [];

      for (final item in packageItems) {
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final unit = item['unit'] ?? 'Stk';

        if (unit.toLowerCase() == 'kg') {
          netWeight += quantity;
        } else {
          double volumePerPiece = 0.0;
          final volumeField = (item['volume_per_unit'] as num?)?.toDouble() ?? 0.0;

          if (volumeField > 0) {
            volumePerPiece = volumeField;
          } else {
            final length = (item['custom_length'] as num?)?.toDouble() ?? 0.0;
            final width = (item['custom_width'] as num?)?.toDouble() ?? 0.0;
            final thickness = (item['custom_thickness'] as num?)?.toDouble() ?? 0.0;


            if (length > 0 && width > 0 && thickness > 0) {
              volumePerPiece = (length / 1000) * (width / 1000) * (thickness / 1000);
            }


          }

          final density = (item['custom_density'] as num?)?.toDouble()

              ?? (item['density'] as num?)?.toDouble()
              ?? 0.0; final weightPerPiece = volumePerPiece * density;


          netWeight += weightPerPiece * quantity;
        }


      }




      return netWeight;
    }

    // Berechne Bruttogewicht
    double calculateGrossWeight() {
      final netWeight = calculateNetWeight();
      final tareWeight = (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
      return netWeight + tareWeight;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package Header
            Row(
              children: [
                Text(
                  package['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (packages.length > 1)
                  IconButton(
                    onPressed: () {
                      setModalState(() {
                        final packageId = package['id'] as String;
                        packageControllers[packageId]?.forEach((key, controller) {
                          controller.dispose();
                        });
                        packageControllers.remove(packageId);
                        packages.removeAt(index);
                      });
                    },
                    icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete, color: Colors.red[400]),
                    iconSize: 20,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Dropdown für Standardpakete
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('standardized_packages')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final standardPackages = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Verpackungsvorlage',
                        hintText: 'Bitte auswählen',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(iconName: 'inventory', defaultIcon: Icons.inventory),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      value: selectedStandardPackageId,
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'custom',
                          child: Text('Benutzerdefiniert'),
                        ),
                        ...standardPackages.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(data['name'] ?? 'Unbenannt'),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          package['standard_package_id'] = value;
                          package['manual_gross_weight_mode'] = false;
                          package['gross_weight'] = null;
                          grossWeightController.clear();

                          if (value != null && value != 'custom') {
                            final selectedPackage = standardPackages.firstWhere(
                                  (doc) => doc.id == value,
                            );
                            final packageData = selectedPackage.data() as Map<String, dynamic>;

                            package['packaging_type'] = packageData['name'] ?? 'Standardpaket';
                            package['packaging_type_en'] = packageData['nameEn'] ?? packageData['name'] ?? 'Standard package';
                            package['length'] = packageData['length'] ?? 0.0;
                            package['width'] = packageData['width'] ?? 0.0;
                            package['height'] = packageData['height'] ?? 0.0;
                            package['tare_weight'] = packageData['weight'] ?? 0.0;

                            lengthController.text = package['length'].toString();
                            widthController.text = package['width'].toString();
                            heightController.text = package['height'].toString();
                            weightController.text = package['tare_weight'].toString();
                          } else if (value == 'custom') {
                            package['packaging_type'] = '';
                            package['length'] = 0.0;
                            package['width'] = 0.0;
                            package['height'] = 0.0;
                            package['tare_weight'] = 0.0;

                            lengthController.text = '0.0';
                            widthController.text = '0.0';
                            heightController.text = '0.0';
                            weightController.text = '0.0';
                            customNameController.text = '';
                          }
                        });
                      },
                    ),

                    if (selectedStandardPackageId != null && selectedStandardPackageId != 'custom')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
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
                                  'Die Werte wurden aus der Vorlage übernommen und können bei Bedarf angepasst werden.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // Freitextfeld für benutzerdefinierten Namen
            if (selectedStandardPackageId == 'custom') ...[
              TextFormField(
                controller: customNameController,
                decoration: InputDecoration(
                  labelText: 'Verpackungsbezeichnung',
                  hintText: 'z.B. Spezialverpackung',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  package['packaging_type'] = value;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Abmessungen
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: lengthController,
                    decoration: InputDecoration(
                      labelText: 'Länge (cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      package['length'] = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('×', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: widthController,
                    decoration: InputDecoration(
                      labelText: 'Breite (cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      package['width'] = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('×', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: heightController,
                    decoration: InputDecoration(
                      labelText: 'Höhe (cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      package['height'] = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tara-Gewicht
            TextFormField(
              controller: weightController,
              decoration: InputDecoration(
                labelText: 'Verpackungsgewicht / Tara (kg)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return newValue.copyWith(
                    text: newValue.text.replaceAll(',', '.'),
                  );
                }),
              ],
              onChanged: (value) {
                setModalState(() {
                  package['tare_weight'] = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                  // Reset manuelles Bruttogewicht wenn Tara geändert wird (außer im manuellen Modus)
                  if (package['manual_gross_weight_mode'] != true) {
                    package['gross_weight'] = null;
                  }
                });
              },
            ),

            // Integrierte Gewichtsübersicht mit optionalem Bruttogewicht-Input
            if (package['items'].isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nettogewicht
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nettogewicht (Produkte):', style: TextStyle(fontSize: 12)),
                        Text('${calculateNetWeight().toStringAsFixed(2)} kg',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Tara
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('+ Tara (Verpackung):', style: TextStyle(fontSize: 12)),
                        Text('${(package['tare_weight'] as num?)?.toStringAsFixed(2) ?? '0.00'} kg',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),

                    const Divider(height: 12),

                    // Bruttogewicht - entweder berechnet oder mit Eingabefeld
                    if (package['manual_gross_weight_mode'] == true) ...[
                      // Manueller Modus: Eingabefeld
                      Row(
                        children: [
                          const Text('= Bruttogewicht:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('gemessen',
                                style: TextStyle(fontSize: 9, color: Colors.orange[700])),
                          ),
                          const Spacer(),
                          // Zurück zu automatisch
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                package['manual_gross_weight_mode'] = false;
                                package['gross_weight'] = null;
                                grossWeightController.clear();
                                // Tara zurücksetzen wenn Standardpaket
                                if (selectedStandardPackageId != null && selectedStandardPackageId != 'custom') {
                                  FirebaseFirestore.instance
                                      .collection('standardized_packages')
                                      .doc(selectedStandardPackageId)
                                      .get()
                                      .then((doc) {
                                    if (doc.exists) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      setModalState(() {
                                        package['tare_weight'] = data['weight'] ?? 0.0;
                                        weightController.text = package['tare_weight'].toString();
                                      });
                                    }
                                  });
                                }
                              });
                            },
                            icon: getAdaptiveIcon(
                              iconName: 'autorenew',
                              defaultIcon: Icons.autorenew,
                              size: 18,
                            ),
                            tooltip: 'Zurück zu automatischer Berechnung',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: TextFormField(
                          controller: grossWeightController,
                          decoration: InputDecoration(
                            hintText: 'Gewogenes Bruttogewicht eingeben',
                            suffixText: 'kg',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              return newValue.copyWith(
                                text: newValue.text.replaceAll(',', '.'),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            final grossWeight = double.tryParse(value.replaceAll(',', '.'));
                            if (grossWeight != null && grossWeight > 0) {
                              setModalState(() {
                                package['gross_weight'] = grossWeight;
                                // Tara = Brutto - Netto (auf 3 Nachkommastellen begrenzt)
                                final netWeight = calculateNetWeight();
                                final calculatedTara = grossWeight - netWeight;
                                final roundedTara = double.parse((calculatedTara > 0 ? calculatedTara : 0.0).toStringAsFixed(3));
                                package['tare_weight'] = roundedTara;
                                weightController.text = roundedTara.toStringAsFixed(2);
                              });
                            }
                          },    ),
                      ),
                      if (package['gross_weight'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tara wurde auf ${(package['tare_weight'] as num?)?.toStringAsFixed(2) ?? '0.00'} kg angepasst',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ] else ...[
                      // Automatischer Modus: Nur Anzeige + Button zum Wechseln
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('= Bruttogewicht:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('berechnet',
                                    style: TextStyle(fontSize: 9, color: Colors.green[700])),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${calculateGrossWeight().toStringAsFixed(2)} kg',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              // Button zum Wechseln in manuellen Modus
                              IconButton(
                                onPressed: () {
                                  setModalState(() {
                                    package['manual_gross_weight_mode'] = true;
                                    // Setze aktuellen berechneten Wert als Startwert
                                    final currentGross = calculateGrossWeight();
                                    grossWeightController.text = currentGross.toStringAsFixed(2);
                                  });
                                },
                                icon: getAdaptiveIcon(
                                  iconName: 'scale',
                                  defaultIcon: Icons.scale,
                                  size: 18,
                                ),
                                tooltip: 'Gewogenes Bruttogewicht eingeben',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Produkte zuweisen
            Text(
              'Zugewiesene Produkte',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(height: 8),

            // Zugewiesene Produkte anzeigen
            if (package['items'].isNotEmpty) ...[
              ...package['items'].map<Widget>((assignedItem) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${assignedItem['product_name']} - ${assignedItem['quantity']} ${assignedItem['unit'] ?? 'Stk'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setModalState(() {
                            package['items'].remove(assignedItem);
                            // Wenn Bruttogewicht manuell gesetzt war, Tara neu berechnen
                            if (package['manual_gross_weight_mode'] == true && package['gross_weight'] != null) {
                              final netWeight = calculateNetWeight();
                              final grossWeight = package['gross_weight'] as double;
                              package['tare_weight'] = grossWeight - netWeight;
                              weightController.text = package['tare_weight'].toStringAsFixed(2);
                            }
                          });
                        },
                        icon: getAdaptiveIcon(iconName: 'remove', defaultIcon: Icons.remove, color: Colors.red[400]),
                        iconSize: 16,
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],

            // Produkt hinzufügen Button
            OutlinedButton.icon(
              onPressed: () => _showAddOrderProductDialog(
                context,
                package,
                orderItems,
                packages,
                setModalState,
              ),
              icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add, size: 16),
              label: const Text('Produkt hinzufügen'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showAddOrderProductDialog(
      BuildContext context,
      Map<String, dynamic> package,
      List<Map<String, dynamic>> orderItems,
      List<Map<String, dynamic>> packages,
      StateSetter setModalState,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Padding(
          padding: const EdgeInsets.fromLTRB(0, 24,0,0),
          child: const Text('Produkt hinzufügen'),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: orderItems.length,
            itemBuilder: (context, index) {
              final item = orderItems[index];
              final assignedQuantity = _getAssignedQuantityForOrder(item, packages);
              final totalQuantity = (item['quantity'] as num?)?.toDouble() ?? 0;
              final remainingQuantity = totalQuantity - assignedQuantity;

              if (remainingQuantity <= 0) return const SizedBox.shrink();

              return ListTile(
                title: Text(item['product_name'] ?? ''),
                subtitle: Text('Verfügbar: $remainingQuantity Stk.'),
                onTap: () {
                  Navigator.pop(context);
                  _showOrderQuantityDialog(
                    context,
                    item,
                    remainingQuantity,
                    package,
                    setModalState,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  void _showOrderQuantityDialog(
      BuildContext context,
      Map<String, dynamic> item,
    double maxQuantity,
      Map<String, dynamic> package,
      StateSetter setModalState,
      ) {
    int selectedQuantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setQuantityState) => AlertDialog(
          title: Text('Menge für ${item['product_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Verfügbare Menge: $maxQuantity Stk.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: selectedQuantity > 1 ? () {
                      setQuantityState(() {
                        selectedQuantity--;
                      });
                    } : null,
                    icon:

                    getAdaptiveIcon(
                      iconName: 'remove',
                      defaultIcon: Icons.remove,
                    ),


                  ),
                  Expanded(
                    child: Text(
                      '$selectedQuantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: selectedQuantity < maxQuantity ? () {
                      setQuantityState(() {
                        selectedQuantity++;
                      });
                    } : null,
                    icon: getAdaptiveIcon(
                      iconName: 'add',
                      defaultIcon: Icons.add,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                print("dens:${item['density']}");
                setModalState(() {
                  package['items'].add({
                    'product_id': item['product_id'],
                    'product_name': item['product_name'],
                    'product_name_en': item['product_name_en'],
                    'quantity': selectedQuantity.toDouble(), // Konvertiere zu double
                    // Konvertiere ALLE numerischen Werte zu double beim Hinzufügen
                    'weight_per_unit': (item['weight'] as num?)?.toDouble() ?? 0.0,
                    'volume_per_unit': (item['volume_per_unit'] as num?)?.toDouble() ?? 0.0,
                    'density': (item['density'] as num?)?.toDouble() ?? 0.0,
                    'custom_density': (item['custom_density'] as num?)?.toDouble(),
                    'custom_length': (item['custom_length'] as num?)?.toDouble() ?? 0.0,
                    'custom_width': (item['custom_width'] as num?)?.toDouble() ?? 0.0,
                    'custom_thickness': (item['custom_thickness'] as num?)?.toDouble() ?? 0.0,
                    'wood_code': item['wood_code'] ?? '',
                    'wood_name': item['wood_name'] ?? '',
                    'unit': item['unit'] ?? 'Stk',
                    'instrument_code': item['instrument_code'] ?? '',
                    'instrument_name': item['instrument_name'] ?? '',
                    'part_code': item['part_code'] ?? '',
                    'part_name': item['part_name'] ?? '',
                    'quality_code': item['quality_code'] ?? '',
                    'quality_name': item['quality_name'] ?? '',
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}