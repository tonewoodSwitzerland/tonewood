// File: services/order_document_manager.dart
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
import 'shipping_costs_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _selection = Map.from(widget.documentSelection);
    _settings = Map.from(widget.documentSettings);
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
                ...OrderDocumentManager.availableDocuments.map((docType) {
                  final isDisabled = docType == 'Rechnung'; // Rechnung ist IMMER disabled
                  final isDependentDoc = ['Lieferschein', 'Handelsrechnung', 'Packliste']
                      .contains(docType);
                  final alreadyExists = widget.existingDocs.contains(_getDocumentKey(docType));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDisabled || alreadyExists
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
                        if (isDependentDoc && !alreadyExists)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              onPressed: isDisabled ? null : () => _showDocumentSettings(docType),
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
                                color: isDisabled || alreadyExists
                                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                    : null,
                              ),
                            ),
                            subtitle: _getDocumentSubtitle(docType, alreadyExists),
                            value: _selection[docType] ?? false,
                            onChanged: (isDisabled || alreadyExists) ? null : (value) {
                              setState(() {
                                _selection[docType] = value ?? false;
                              });
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),

                        // NEU: Preview Button
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            onPressed: (isDisabled || alreadyExists) ? null : () async {
                              // Verwende den OrderDocumentPreviewManager für Preview
                              await OrderDocumentPreviewManager.showDocumentPreview(
                                context: context,
                                order: widget.order,
                                documentType: _getDocumentKey(docType),
                              );
                            },
                            icon: const Icon(Icons.visibility),
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
        final hasConfig = settings['origin_declaration'] ||
            settings['cites'] ||
            settings['export_reason'] ||
            settings['incoterms'] ||
            settings['delivery_date'] ||
            settings['carrier'] ||
            settings['signature'];
        if (hasConfig) {
          return Text(
            'Konfiguriert',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          );
        }
        return const Text('Optional', style: TextStyle(fontSize: 12));
      case 'Packliste':
        final packages = _settings['packing_list']['packages'] as List;
        if (packages.isNotEmpty) {
          return Text(
            '${packages.length} Paket(e)',
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
                                onPressed: () {
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

    // Controller für Textfelder
    final numberOfPackagesController = TextEditingController(
      text: settings['number_of_packages'].toString(),
    );
    final packagingWeightController = TextEditingController(
      text: settings['packaging_weight'].toString(),
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
                      Icon(Icons.inventory_2,
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

                        // Anzahl Packungen
                        TextField(
                          controller: numberOfPackagesController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Anzahl Packungen',
                            prefixIcon: const Icon(Icons.inventory),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            helperText: 'Anzahl der Verpackungseinheiten',
                          ),
                          onChanged: (value) {
                            settings['number_of_packages'] = int.tryParse(value) ?? 1;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Verpackungsgewicht
                        TextField(
                          controller: packagingWeightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Verpackungsgewicht (kg)',
                            prefixIcon: const Icon(Icons.scale),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            helperText: 'Gesamtgewicht der Verpackung in kg',
                          ),
                          onChanged: (value) {
                            settings['packaging_weight'] = double.tryParse(value) ?? 0.0;
                          },
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

                        // Checkboxen für Standardsätze
                        CheckboxListTile(
                          title: const Text('Ursprungserklärung'),
                          subtitle: const Text('Erklärung über Schweizer Ursprungswaren'),
                          value: settings['origin_declaration'],
                          onChanged: (value) {
                            setModalState(() {
                              settings['origin_declaration'] = value ?? false;
                            });
                          },
                        ),

                        CheckboxListTile(
                          title: const Text('CITES'),
                          subtitle: const Text('Waren stehen NICHT auf der CITES-Liste'),
                          value: settings['cites'],
                          onChanged: (value) {
                            setModalState(() {
                              settings['cites'] = value ?? false;
                            });
                          },
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
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _settings['commercial_invoice'] = settings;
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

  Future<void> _showPackingListSettings() async {
    // Kopiere bestehende Packages oder erstelle neue
    List<Map<String, dynamic>> packages = List<Map<String, dynamic>>.from(
      _settings['packing_list']['packages'] ?? [],
    );

    // Falls noch keine Pakete existieren, erstelle Paket 1
    if (packages.isEmpty) {
      packages.add({
        'id': 'package_1',
        'name': 'Packung 1',
        'packaging_type': 'Kartonschachtel',
        'length': 0.0,
        'width': 0.0,
        'height': 0.0,
        'tare_weight': 0.0,
        'items': <Map<String, dynamic>>[],
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Produkte aus Auftrag',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...widget.order.items.map((item) {
                                final assignedQuantity = _getAssignedQuantityForOrder(item, packages);
                                final totalQuantity = item['quantity'] as int? ?? 0;
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
                                  final newPackageNumber = packages.length + 1;
                                  packages.add({
                                    'id': 'package_$newPackageNumber',
                                    'name': 'Packung $newPackageNumber',
                                    'packaging_type': 'Kartonschachtel',
                                    'length': 0.0,
                                    'width': 0.0,
                                    'height': 0.0,
                                    'tare_weight': 0.0,
                                    'items': <Map<String, dynamic>>[],
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

                          return _buildOrderPackageCard(
                            context,
                            package,
                            index,
                            widget.order.items,
                            packages,
                            setModalState,
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
                                onPressed: () {
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

    // Versandkosten sind bereits in den Metadaten gespeichert!
    final shippingCosts = metadata['shippingCosts'] ?? {};

    // Bereite alle Daten für die Dokumentengenerierung vor
    return {
      'order': widget.order,
      'items': widget.order.items,
      'customer': widget.order.customer,
      'calculations': widget.order.calculations,
      'settings': _settings,
      'shippingCosts': shippingCosts,  // Verwende die gespeicherten Daten
      'currency': metadata['currency'] ?? 'CHF',
      'exchangeRates': metadata['exchangeRates'] ?? {'CHF': 1.0},
      'costCenterCode': metadata['costCenterCode'] ?? '00000',
      'fair': metadata['fairData'],
      'taxOption': metadata['taxOption'] ?? 0,
      'vatRate': (metadata['vatRate'] as num?)?.toDouble() ?? 8.1,
    };
  }
  Future<bool> _createDocument(String docType, Map<String, dynamic> orderData) async {
    try {
      Uint8List? pdfBytes;
      String? documentUrl;
      String documentKey = _getDocumentKey(docType);

      switch (docType) {
        case 'Rechnung':
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

          // Bereite Tara-Einstellungen vor
          final taraSettings = {
            'number_of_packages': settings['number_of_packages'],
            'packaging_weight': settings['packaging_weight'],
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
          );
          break;

        case 'Packliste':
        // Generiere Packliste mit Settings
          final settings = _settings['packing_list'];

          // Speichere Packages in Firestore für den Generator
          await FirebaseFirestore.instance
              .collection('temporary_packing_list_settings')
              .doc(widget.order.id)
              .set({
            'packages': settings['packages'],
            'order_id': widget.order.id,
            'timestamp': FieldValue.serverTimestamp(),
          });

          pdfBytes = await PackingListGenerator.generatePackingListPdf(
            language: orderData['customer']['language'] ?? 'DE',
            packingListNumber: '${widget.order.orderNumber}-PL',
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenterCode'],
          );

          // Cleanup temporäre Daten
          await FirebaseFirestore.instance
              .collection('temporary_packing_list_settings')
              .doc(widget.order.id)
              .delete();
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
          'user_name': user?.displayName ?? user?.email?.split('@')[0] ?? 'Unknown',
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
  int _getAssignedQuantityForOrder(Map<String, dynamic> item, List<Map<String, dynamic>> packages) {
    int totalAssigned = 0;
    final productId = item['product_id'] ?? '';

    for (final package in packages) {
      final packageItems = package['items'] as List<dynamic>? ?? [];
      for (final assignedItem in packageItems) {
        if (assignedItem['product_id'] == productId) {
          totalAssigned += (assignedItem['quantity'] as int? ?? 0);
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
      ) {
    final packagingTypes = [
      'Kartonschachtel',
      'INKA Palette mit Karton',
      'INKA Palette mit Folie',
      'Holzkiste',
      'Andere',
    ];

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
                        packages.removeAt(index);
                      });
                    },
                    icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                    iconSize: 20,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Verpackungsart
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Verpackungsart',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              value: package['packaging_type'],
              items: packagingTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setModalState(() {
                  package['packaging_type'] = value;
                });
              },
            ),

            const SizedBox(height: 12),

            // Abmessungen
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Länge (cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    initialValue: package['length'].toString(),
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
                    decoration: InputDecoration(
                      labelText: 'Breite (cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    initialValue: package['width'].toString(),
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
                    decoration: InputDecoration(
                      labelText: 'Höhe (cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    initialValue: package['height'].toString(),
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
              decoration: InputDecoration(
                labelText: 'Verpackungsgewicht (kg)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              initialValue: package['tare_weight'].toString(),
              onChanged: (value) {
                package['tare_weight'] = double.tryParse(value) ?? 0.0;
              },
            ),

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
                          '${assignedItem['product_name']} - ${assignedItem['quantity']} Stk.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setModalState(() {
                            package['items'].remove(assignedItem);
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
              final totalQuantity = item['quantity'] as int? ?? 0;
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
      int maxQuantity,
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