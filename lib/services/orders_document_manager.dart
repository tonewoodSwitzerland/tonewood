// File: services/order_document_manager.dart

/// Info, hier ist der Auftragsbereich


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../services/icon_helper.dart';
import '../components/order_model.dart';
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
  bool _isCreating = false;
  bool _isLoadingSettings = true; // NEU
  final Map<String, Map<String, TextEditingController>> packageControllers = {};


  @override
  void initState() {
    super.initState();

    _selection = Map.from(widget.documentSelection);
    _selection['Rechnung'] = true;
    _settings = Map.from(widget.documentSettings);
    _loadExistingSettings();
  }
  @override
  void dispose() {
    // Dispose all package controllers
    packageControllers.forEach((key, controllers) {
      controllers.forEach((_, controller) {
        controller.dispose();
      });
    });
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
                  child: Icon(
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
                  icon: const Icon(Icons.close),
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
                              icon: const Icon(Icons.settings),
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
                                order: widget.order,
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
          // Berechne wie viele Produkte zugewiesen sind
          int totalAssigned = 0;
          int totalProducts = widget.order.items.length;

          for (final item in widget.order.items) {
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
        final totalQuantity = item['quantity'] as double? ?? 0;

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
          'quantity': totalQuantity,
          'weight_per_unit': item['weight'] ?? 0.0,
          'volume_per_unit': item['volume'] ?? 0.0,
          'custom_length': item['custom_length'] ?? 0.0,
          'custom_width': item['custom_width'] ?? 0.0,
          'custom_thickness': item['custom_thickness'] ?? 0.0,
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

  Future<void> _showInvoiceSettings() async {
    double downPaymentAmount = 0.0;
    String downPaymentReference = '';
    DateTime? downPaymentDate;

    // Lade bestehende Einstellungen
    final existingSettingsDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.id)
        .collection('settings')
        .doc('invoice_settings')
        .get();

    if (existingSettingsDoc.exists) {
      final data = existingSettingsDoc.data()!;
      downPaymentAmount = (data['down_payment_amount'] ?? 0.0).toDouble();
      downPaymentReference = data['down_payment_reference'] ?? '';
      if (data['down_payment_date'] != null) {
        downPaymentDate = (data['down_payment_date'] as Timestamp).toDate();
      }
    }

    final downPaymentController = TextEditingController(
        text: downPaymentAmount > 0 ? downPaymentAmount.toString() : ''
    );
    final referenceController = TextEditingController(text: downPaymentReference);

    // Hole den Gesamtbetrag aus der Order
    final totalAmount = (widget.order.calculations['total'] as num? ?? 0).toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
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
                      Icon(Icons.receipt,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Rechnung - Anzahlung',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
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
                        // Gesamtbetrag anzeigen
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
                                'CHF ${totalAmount.toStringAsFixed(2)}',
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

                        // Anzahlung Betrag
                        TextField(
                          controller: downPaymentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Anzahlung (CHF)',
                            prefixIcon: const Icon(Icons.payments),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            helperText: 'Betrag der bereits geleisteten Anzahlung',
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              downPaymentAmount = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // Belegnummer/Notiz
                        TextField(
                          controller: referenceController,
                          decoration: InputDecoration(
                            labelText: 'Belegnummer / Notiz',
                            prefixIcon: const Icon(Icons.description),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            helperText: 'z.B. Anzahlung AR-2025-0004 vom 15.05.2025',
                          ),
                          onChanged: (value) {
                            downPaymentReference = value;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Datum der Anzahlung
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: downPaymentDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              locale: const Locale('de', 'DE'),
                            );
                            if (picked != null) {
                              setModalState(() {
                                downPaymentDate = picked;
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
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Datum der Anzahlung',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        downPaymentDate != null
                                            ? DateFormat('dd.MM.yyyy').format(downPaymentDate!)
                                            : 'Datum auswählen',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                if (downPaymentDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setModalState(() {
                                        downPaymentDate = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Vorschau der Berechnung
                        if (downPaymentAmount > 0)
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
                                    Text('CHF ${totalAmount.toStringAsFixed(2)}'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Anzahlung:'),
                                    Text(
                                      '- CHF ${downPaymentAmount.toStringAsFixed(2)}',
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
                                      'CHF ${(totalAmount - downPaymentAmount).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
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
                                  // Speichere Einstellungen
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(widget.order.id)
                                      .collection('settings')
                                      .doc('invoice_settings')
                                      .set({
                                    'down_payment_amount': downPaymentAmount,
                                    'down_payment_reference': downPaymentReference,
                                    'down_payment_date': downPaymentDate != null
                                        ? Timestamp.fromDate(downPaymentDate!)
                                        : null,
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });

                                  Navigator.pop(context);
                                  setState(() {
                                    _settings['invoice'] = {
                                      'down_payment_amount': downPaymentAmount,
                                      'down_payment_reference': downPaymentReference,
                                      'down_payment_date': downPaymentDate,
                                    };
                                  });
                                },
                                icon: const Icon(Icons.save),
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

  Future<void> _showDeliveryNoteSettings() async {
    DateTime? deliveryDate = _settings['delivery_note']['delivery_date'];
    DateTime? paymentDate = _settings['delivery_note']['payment_date'];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {  // Renamed to avoid confusion
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
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
                      Icon(Icons.local_shipping,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Lieferschein Einstellungen',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
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
                              setModalState(() {  // Use modal setState
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
                                const Icon(Icons.calendar_today),
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
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setModalState(() {  // Use modal setState
                                        deliveryDate = null;
                                      });
                                    },
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
                              setModalState(() {  // Use modal setState
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
                                const Icon(Icons.payment),
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
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setModalState(() {  // Use modal setState
                                        paymentDate = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Actions
                        Padding(
                          padding: const EdgeInsets.all(24.0),
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
                                  // Am Ende der _showDeliveryNoteSettings Methode, vor Navigator.pop:
                                  onPressed: () async {
                                    // Speichere in Firebase
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

                                    // Update parent state after closing modal
                                    Navigator.pop(context);
                                    setState(() {  // Use parent setState
                                      _settings['delivery_note'] = <String, dynamic>{
                                        'delivery_date': deliveryDate,
                                        'payment_date': paymentDate,
                                      };
                                    });
                                  },
                                  icon: const Icon(Icons.save),
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


  Future<void> _showCommercialInvoiceSettings() async {
    final settings = Map<String, dynamic>.from(_settings['commercial_invoice']);

    // NEU: Berechne Verpackungsgewicht aus Packliste
    double totalPackagingWeight = 0.0;
    int numberOfPackages = 0;

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
    if (settings['commercial_invoice_date'] != null) {
      commercialInvoiceDate = settings['commercial_invoice_date'] is Timestamp
          ? (settings['commercial_invoice_date'] as Timestamp).toDate()
          : settings['commercial_invoice_date'] as DateTime?;
    }

    // Controller für Textfelder (ohne packagingWeightController!)
    final numberOfPackagesController = TextEditingController(
      text: numberOfPackages > 0 ? numberOfPackages.toString() : (settings['number_of_packages'] ?? 1).toString(),
    );
    final exportReasonController = TextEditingController(
      text: settings['export_reason_text'],
    );
    final carrierController = TextEditingController(
      text: settings['carrier_text'],
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
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
                      Icon(Icons.inventory,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Handelsrechnung Einstellungen',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
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
                                Icon(
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
                            prefixIcon: const Icon(Icons.inventory),
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

                        // Verpackungsgewicht (nur Anzeige!)
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
                              const Icon(Icons.scale),
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
                                    if (numberOfPackages > 0)
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
                                const Icon(Icons.calendar_today),
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
                                    icon: const Icon(Icons.clear),
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

                        const SizedBox(height: 24),

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

                        // In der _showCommercialInvoiceSettings Methode, ersetze die Checkboxen für Ursprungserklärung und CITES:

// Ursprungserklärung - mit Info-Icon
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Ursprungserklärung'),
                                subtitle: const Text('Erklärung über Schweizer Ursprungswaren'),
                                value: settings['origin_declaration'],
                                onChanged: (value) {
                                  setModalState(() {
                                    settings['origin_declaration'] = value ?? false;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () async {
                                // Lade den Standardtext
                                await AdditionalTextsManager.loadDefaultTextsFromFirebase();
                                final defaultText = AdditionalTextsManager.getTextContent(
                                  {'selected': true, 'type': 'standard'},
                                  'origin_declaration',
                                  language: widget.order.customer['language'] ?? 'DE',
                                );

                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Row(
                                      children: [
                                        Icon(
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
                                              Icon(
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
                                value: settings['cites'],
                                onChanged: (value) {
                                  setModalState(() {
                                    settings['cites'] = value ?? false;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () async {
                                // Lade den Standardtext
                                await AdditionalTextsManager.loadDefaultTextsFromFirebase();
                                final defaultText = AdditionalTextsManager.getTextContent(
                                  {'selected': true, 'type': 'standard'},
                                  'cites',
                                  language: widget.order.customer['language'] ?? 'DE',
                                );

                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Row(
                                      children: [
                                        Icon(
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
                                              Icon(
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
                          value: settings['export_reason'],
                          onChanged: (value) {
                            setModalState(() {
                              settings['export_reason'] = value ?? false;
                            });
                          },
                        ),
                        if (settings['export_reason'])
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

                        // Incoterms
                        CheckboxListTile(
                          title: const Text('Incoterms'),
                          value: settings['incoterms'],
                          onChanged: (value) {
                            setModalState(() {
                              settings['incoterms'] = value ?? false;
                            });
                          },
                        ),

                        // Lieferdatum
                        CheckboxListTile(
                          title: const Text('Lieferdatum'),
                          subtitle: settings['delivery_date_value'] != null
                              ? Text(DateFormat('dd.MM.yyyy').format(settings['delivery_date_value']))
                              : null,
                          value: settings['delivery_date'],
                          onChanged: (value) {
                            setModalState(() {
                              settings['delivery_date'] = value ?? false;
                            });
                          },
                        ),

                        // Carrier mit Textfeld
                        CheckboxListTile(
                          title: const Text('Transporteur'),
                          value: settings['carrier'],
                          onChanged: (value) {
                            setModalState(() {
                              settings['carrier'] = value ?? false;
                            });
                          },
                        ),
                        if (settings['carrier'])
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

                        // Signatur
                        CheckboxListTile(
                          title: const Text('Signatur'),
                          value: settings['signature'],
                          onChanged: (value) {
                            setModalState(() {
                              settings['signature'] = value ?? false;
                            });
                          },
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
                                  // Speichere in Firebase (OHNE packaging_weight!)
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(widget.order.id)
                                      .collection('settings')
                                      .doc('tara_settings')
                                      .set({
                                    'number_of_packages': numberOfPackages > 0 ? numberOfPackages : settings['number_of_packages'],
                                    // packaging_weight wird NICHT mehr gespeichert!
                                    'commercial_invoice_date': settings['commercial_invoice_date'] != null
                                        ? Timestamp.fromDate(settings['commercial_invoice_date'])
                                        : null,
                                    'origin_declaration': settings['origin_declaration'],
                                    'cites': settings['cites'],
                                    'export_reason': settings['export_reason'],
                                    'export_reason_text': settings['export_reason_text'],
                                    'incoterms': settings['incoterms'],
                                    'selected_incoterms': settings['selected_incoterms'],
                                    'incoterms_freetexts': settings['incoterms_freetexts'],
                                    'delivery_date': settings['delivery_date'],
                                    'delivery_date_value': settings['delivery_date_value'],
                                    'delivery_date_month_only': settings['delivery_date_month_only'],
                                    'carrier': settings['carrier'],
                                    'carrier_text': settings['carrier_text'],
                                    'signature': settings['signature'],
                                    'selected_signature': settings['selected_signature'],
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });
                                  setState(() {
                                    _settings['commercial_invoice'] = settings;
                                  });
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.save),
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
                        Icon(Icons.view_list,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        const Text('Packliste Einstellungen',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
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
                                            widget.order.items,
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
                                        icon: const Icon(
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
                                ...widget.order.items.map((item) {
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
                                icon: const Icon(Icons.add, size: 16),
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
                              widget.order.items,
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
                                  icon: const Icon(Icons.save),
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
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
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

    // Bereite alle Daten für die Dokumentengenerierung vor
    return {
      'order': widget.order,
      'items': widget.order.items,
      'customer': widget.order.customer,
      'calculations': widget.order.calculations,
      'settings': _settings,
      'shippingCosts': shippingCosts,  // Jetzt mit sicheren double-Werten
      'currency': metadata['currency'] ?? 'CHF',
      'exchangeRates': exchangeRates,
      'costCenterCode': metadata['costCenterCode'] ?? '00000',
      'fair': metadata['fairData'],
      'taxOption': metadata['taxOption'] ?? 0,
      'vatRate': (metadata['vatRate'] as num?)?.toDouble() ?? 8.1,
    };
  }
  Future<bool> _createDocument(String docType, Map<String, dynamic> orderData) async {

    print("yoooooo!");
    try {
      Uint8List? pdfBytes;
      String? documentUrl;
      String documentKey = _getDocumentKey(docType);

      switch (docType) {
        case 'Rechnung':
          final invoiceSettings = _settings['invoice'] ?? {};

          // Generiere Rechnung
          pdfBytes = await InvoiceGenerator.generateInvoicePdf(
            items: orderData['items'],
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenterCode'],
            currency: orderData['currency'],
            exchangeRates: orderData['exchangeRates'],
            language: orderData['customer']['language'] ?? 'DE',
            invoiceNumber: widget.order.orderNumber,
            shippingCosts: orderData['shippingCosts'],
            calculations: orderData['calculations'],
            paymentTermDays: 30,
            taxOption: orderData['taxOption'],
            vatRate: orderData['vatRate'],
              downPaymentSettings: invoiceSettings,
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
            exchangeRates: orderData['exchangeRates'],
            language: orderData['customer']['language'] ?? 'DE',
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
          int numberOfPackages = settings['number_of_packages'] ?? 1;

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


          print("invoiceDate:$invoiceDate");
          pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
            items: orderData['items'],
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenterCode'],
            currency: orderData['currency'],
            exchangeRates: orderData['exchangeRates'],
            language: orderData['customer']['language'] ?? 'DE',
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
            language: orderData['customer']['language'] ?? 'DE',
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

    // NEU: Controller für Bruttogewicht
    if (!controllers.containsKey('gross_weight')) {
      controllers['gross_weight'] = TextEditingController(
        text: package['gross_weight']?.toString() ?? '',
      );
    }
    final grossWeightController = controllers['gross_weight']!;

    // NEU: Berechne Nettogewicht (Summe aller Produkte im Paket)
    double calculateNetWeight() {
      double netWeight = 0.0;
      final packageItems = package['items'] as List<dynamic>? ?? [];

      for (final item in packageItems) {
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final unit = item['unit'] ?? 'Stk';

        if (unit.toLowerCase() == 'kg') {
          // Bei kg-Einheit ist quantity bereits das Gewicht
          netWeight += quantity;
        } else {
          // Volumen berechnen (gleiche Logik wie in packing_list_generator)
          double volumePerPiece = 0.0;

          // Priorisierung für Volumenberechnung
          if (item['volume_per_unit'] != null && (item['volume_per_unit'] as num) > 0) {
            volumePerPiece = (item['volume_per_unit'] as num).toDouble();
          } else {
            final length = (item['custom_length'] as num?)?.toDouble() ?? 0.0;
            final width = (item['custom_width'] as num?)?.toDouble() ?? 0.0;
            final thickness = (item['custom_thickness'] as num?)?.toDouble() ?? 0.0;

            if (length > 0 && width > 0 && thickness > 0) {
              volumePerPiece = (length / 1000) * (width / 1000) * (thickness / 1000);
            }
          }

          // Gewicht aus Volumen und Dichte
          final woodCode = item['wood_code'] as String? ?? '';
          final density = 450.0; // Default-Dichte, sollte aus woodTypeCache kommen
          final weightPerPiece = volumePerPiece * density;
          netWeight += weightPerPiece * quantity;
        }
      }

      return netWeight;
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
                    icon: Icon(Icons.delete_outline, color: Colors.red[400]),
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
                        prefixIcon: Icon(Icons.inventory),
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
                              Icon(
                                Icons.info,
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
                  prefixIcon: Icon(Icons.edit),
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
              onChanged: (value) {
                package['tare_weight'] = double.tryParse(value) ?? 0.0;
              },
            ),

            const SizedBox(height: 12),

            // NEU: Bruttogewicht mit automatischer Tara-Berechnung
            TextFormField(
              controller: grossWeightController,
              decoration: InputDecoration(
                labelText: 'Bruttogewicht (gemessen) (kg)',
                helperText: 'Leer lassen für automatische Berechnung',
                prefixIcon: Icon(Icons.scale),
                suffixIcon: grossWeightController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setModalState(() {
                      grossWeightController.clear();
                      package['gross_weight'] = null;
                      // Setze Tara auf Standardwert zurück
                      if (selectedStandardPackageId != null && selectedStandardPackageId != 'custom') {
                        final selectedPackage = FirebaseFirestore.instance
                            .collection('standardized_packages')
                            .doc(selectedStandardPackageId);
                        selectedPackage.get().then((doc) {
                          if (doc.exists) {
                            final data = doc.data() as Map<String, dynamic>;
                            package['tare_weight'] = data['weight'] ?? 0.0;
                            weightController.text = package['tare_weight'].toString();
                          }
                        });
                      }
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                setModalState(() {
                  final grossWeight = double.tryParse(value);

                  if (value.isEmpty || grossWeight == null) {
                    // Feld wurde geleert - zurück zum Standardgewicht
                    package['gross_weight'] = null;

                    // Setze Tara auf Standardwert zurück
                    if (selectedStandardPackageId != null && selectedStandardPackageId != 'custom') {
                      // Lade Standardgewicht aus der Datenbank
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
                    } else {
                      // Bei custom bleibt das manuell eingegebene Tara-Gewicht
                      // Keine Änderung nötig
                    }
                  } else if (grossWeight > 0) {
                    // Bruttogewicht eingegeben, berechne Tara neu
                    package['gross_weight'] = grossWeight;
                    final netWeight = calculateNetWeight();
                    final calculatedTara = grossWeight - netWeight;
                    package['tare_weight'] = calculatedTara > 0 ? calculatedTara : 0.0;
                    weightController.text = package['tare_weight'].toStringAsFixed(2);
                  }
                });
              },
            ),

            // NEU: Info-Box mit Gewichtsübersicht
            if (package['items'].isNotEmpty) ...[
              const SizedBox(height: 8),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Nettogewicht (Produkte):', style: TextStyle(fontSize: 12)),
                        Text('${calculateNetWeight().toStringAsFixed(2)} kg',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tara (Verpackung):', style: TextStyle(fontSize: 12)),
                        Text('${package['tare_weight'].toStringAsFixed(2)} kg',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bruttogewicht:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${(calculateNetWeight() + (package['tare_weight'] ?? 0.0)).toStringAsFixed(2)} kg',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
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
                            if (package['gross_weight'] != null) {
                              final netWeight = calculateNetWeight();
                              final grossWeight = package['gross_weight'] as double;
                              package['tare_weight'] = grossWeight - netWeight;
                              weightController.text = package['tare_weight'].toStringAsFixed(2);
                            }
                          });
                        },
                        icon: Icon(Icons.remove_circle_outline, color: Colors.red[400]),
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
              icon: const Icon(Icons.add, size: 16),
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
        title: const Text('Produkt hinzufügen'),
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
                    icon: const Icon(Icons.remove),
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
                    icon: const Icon(Icons.add),
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
                setModalState(() {
                  package['items'].add({
                    'product_id': item['product_id'],
                    'product_name': item['product_name'],
                    'quantity': selectedQuantity,
                    'weight_per_unit': item['weight'] ?? 0.0,
                    'volume_per_unit': item['volume'] ?? 0.0,
                    'custom_length': item['custom_length'] ?? 0.0,
                    'custom_width': item['custom_width'] ?? 0.0,
                    'custom_thickness': item['custom_thickness'] ?? 0.0,
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