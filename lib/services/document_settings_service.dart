// File: services/document_settings_service.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../components/order_model.dart';
import '../services/icon_helper.dart';
import '../services/additional_text_manager.dart';

class DocumentSettingsService {

  // Für Einzelaufträge
  static Future<Map<String, dynamic>?> showOrderDocumentSettings({
    required BuildContext context,
    required String documentType,
    required Map<String, dynamic> initialSettings,
    required String orderId,
    OrderX? order,
  }) async {
    switch (documentType) {
      case 'delivery_note':
        return await _showDeliveryNoteSettings(
          context: context,
          initialSettings: initialSettings,
          entityId: orderId,
          entityType: 'order',
        );
      case 'commercial_invoice':
        return await _showCommercialInvoiceSettings(
          context: context,
          initialSettings: initialSettings,
          entityId: orderId,
          entityType: 'order',
        );
      case 'packing_list':
        if (order == null) throw ArgumentError('Order required for packing list');
        return await _showPackingListSettings(
          context: context,
          initialSettings: initialSettings,
          entityId: orderId,
          entityType: 'order',
          items: order.items,
        );
      case 'invoice':
        return await _showInvoiceSettings(
          context: context,
          initialSettings: initialSettings,
          orderId: orderId,
        );
      default:
        return null;
    }
  }

  // Für Sammellieferungen
  static Future<Map<String, dynamic>?> showCombinedShipmentSettings({
    required BuildContext context,
    required String documentType,
    required Map<String, dynamic> initialSettings,
    required String shipmentId,
    required List<OrderX> orders,
  }) async {
    // Kombiniere alle Items aus allen Orders
    final List<Map<String, dynamic>> allItems = [];
    for (final order in orders) {
      for (final item in order.items) {
        // Erweitere Items mit Order-Referenz
        final Map<String, dynamic> extendedItem = Map<String, dynamic>.from(item);
        extendedItem['_order_id'] = order.id;
        extendedItem['_order_number'] = order.orderNumber;
        allItems.add(extendedItem);
      }
    }

    switch (documentType) {
      case 'delivery_note':
        return await _showDeliveryNoteSettings(
          context: context,
          initialSettings: initialSettings,
          entityId: shipmentId,
          entityType: 'combined_shipment',
        );
      case 'commercial_invoice':
        return await _showCommercialInvoiceSettings(
          context: context,
          initialSettings: initialSettings,
          entityId: shipmentId,
          entityType: 'combined_shipment',
        );
      case 'packing_list':
        return await _showPackingListSettings(
          context: context,
          initialSettings: initialSettings,
          entityId: shipmentId,
          entityType: 'combined_shipment',
          items: allItems,
        );
      default:
        return null;
    }
  }

  // Lieferschein Settings
  static Future<Map<String, dynamic>?> _showDeliveryNoteSettings({
    required BuildContext context,
    required Map<String, dynamic> initialSettings,
    required String entityId,
    required String entityType,
  }) async {
    DateTime? deliveryDate = initialSettings['delivery_date'];
    DateTime? paymentDate = initialSettings['payment_date'];

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeliveryNoteSettingsDialog(
        initialDeliveryDate: deliveryDate,
        initialPaymentDate: paymentDate,
        onSave: (settings) async {
          // Speichere in Firebase
          final path = entityType == 'order'
              ? 'orders/$entityId/settings/delivery_settings'
              : 'combined_shipments/$entityId/settings/delivery_settings';

          await FirebaseFirestore.instance.doc(path).set({
            'delivery_date': settings['delivery_date'] != null
                ? Timestamp.fromDate(settings['delivery_date'])
                : null,
            'payment_date': settings['payment_date'] != null
                ? Timestamp.fromDate(settings['payment_date'])
                : null,
            'timestamp': FieldValue.serverTimestamp(),
          });
        },
      ),
    );

    return result;
  }

  // Handelsrechnung Settings
  static Future<Map<String, dynamic>?> _showCommercialInvoiceSettings({
    required BuildContext context,
    required Map<String, dynamic> initialSettings,
    required String entityId,
    required String entityType,
  }) async {
    // Lade Verpackungsdaten aus Packliste falls vorhanden
    double totalPackagingWeight = 0.0;
    int numberOfPackages = 0;

    try {
      final packingListPath = entityType == 'order'
          ? 'orders/$entityId/packing_list/settings'
          : 'combined_shipments/$entityId/packing_list/settings';

      final packingListDoc = await FirebaseFirestore.instance
          .doc(packingListPath)
          .get();

      if (packingListDoc.exists) {
        final data = packingListDoc.data()!;
        final packages = data['packages'] as List<dynamic>? ?? [];
        numberOfPackages = packages.length;

        for (final package in packages) {
          totalPackagingWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (e) {
      print('Fehler beim Laden der Packlisten-Daten: $e');
    }

    // Setze initiale Werte
    if (numberOfPackages > 0) {
      initialSettings['number_of_packages'] = numberOfPackages;
      initialSettings['packaging_weight'] = totalPackagingWeight;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommercialInvoiceSettingsDialog(
        initialSettings: initialSettings,
        packagingDataFromPackingList: {
          'numberOfPackages': numberOfPackages,
          'totalPackagingWeight': totalPackagingWeight,
        },
        onSave: (settings) async {
          // Speichere in Firebase
          final path = entityType == 'order'
              ? 'orders/$entityId/settings/tara_settings'
              : 'combined_shipments/$entityId/settings/tara_settings';

          await FirebaseFirestore.instance.doc(path).set({
            'number_of_packages': settings['number_of_packages'],
            'commercial_invoice_date': settings['commercial_invoice_date'] != null
                ? Timestamp.fromDate(settings['commercial_invoice_date'])
                : null,
            'origin_declaration': settings['origin_declaration'],
            'cites': settings['cites'],
            'export_reason': settings['export_reason'],
            'export_reason_text': settings['export_reason_text'],
            'incoterms': settings['incoterms'],
            'selected_incoterms': settings['selected_incoterms'] ?? [],
            'incoterms_freetexts': settings['incoterms_freetexts'] ?? {},
            'delivery_date': settings['delivery_date'],
            'delivery_date_value': settings['delivery_date_value'] != null
                ? Timestamp.fromDate(settings['delivery_date_value'])
                : null,
            'delivery_date_month_only': settings['delivery_date_month_only'] ?? false,
            'carrier': settings['carrier'],
            'carrier_text': settings['carrier_text'],
            'signature': settings['signature'],
            'selected_signature': settings['selected_signature'],
            'timestamp': FieldValue.serverTimestamp(),
          });
        },
      ),
    );

    return result;
  }

  // Packliste Settings
  static Future<Map<String, dynamic>?> _showPackingListSettings({
    required BuildContext context,
    required Map<String, dynamic> initialSettings,
    required String entityId,
    required String entityType,
    required List<Map<String, dynamic>> items,
  }) async {
    // Lade bestehende Packages
    List<Map<String, dynamic>> packages = [];
    try {
      final packingListPath = entityType == 'order'
          ? 'orders/$entityId/packing_list/settings'
          : 'combined_shipments/$entityId/packing_list/settings';

      final packingListDoc = await FirebaseFirestore.instance
          .doc(packingListPath)
          .get();

      if (packingListDoc.exists) {
        final data = packingListDoc.data()!;
        final rawPackages = data['packages'] as List<dynamic>? ?? [];
        packages = rawPackages.map((p) => Map<String, dynamic>.from(p as Map)).toList();
      }
    } catch (e) {
      print('Fehler beim Laden der Packlisten-Einstellungen: $e');
    }

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) => _PackingListSettingsDialog(
        initialPackages: packages,
        availableItems: items,
        entityId: entityId,
        entityType: entityType,
        onSave: (packages) async {
          // Speichere in Firebase
          final path = entityType == 'order'
              ? 'orders/$entityId/packing_list/settings'
              : 'combined_shipments/$entityId/packing_list/settings';

          await FirebaseFirestore.instance.doc(path).set({
            'packages': packages,
            'created_at': FieldValue.serverTimestamp(),
            'updated_by': FirebaseAuth.instance.currentUser?.uid,
          });
        },
      ),
    );

    return result;
  }

  // Rechnung Settings (nur für Einzelaufträge)
  static Future<Map<String, dynamic>?> _showInvoiceSettings({
    required BuildContext context,
    required Map<String, dynamic> initialSettings,
    required String orderId,
  }) async {
    // Implementierung des Invoice Settings Dialogs
    // ... (Code aus OrderDocumentManager)
    return null; // Placeholder
  }
}

// Dialog Widgets als separate Klassen

class _DeliveryNoteSettingsDialog extends StatefulWidget {
  final DateTime? initialDeliveryDate;
  final DateTime? initialPaymentDate;
  final Function(Map<String, dynamic>) onSave;

  const _DeliveryNoteSettingsDialog({
    this.initialDeliveryDate,
    this.initialPaymentDate,
    required this.onSave,
  });

  @override
  State<_DeliveryNoteSettingsDialog> createState() => _DeliveryNoteSettingsDialogState();
}

class _DeliveryNoteSettingsDialogState extends State<_DeliveryNoteSettingsDialog> {
  DateTime? deliveryDate;
  DateTime? paymentDate;

  @override
  void initState() {
    super.initState();
    deliveryDate = widget.initialDeliveryDate;
    paymentDate = widget.initialPaymentDate;
  }

  @override
  Widget build(BuildContext context) {
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
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
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
                  _buildDateSelector(
                    title: 'Lieferdatum',
                    icon: 'calendar_today',
                    selectedDate: deliveryDate,
                    onDateSelected: (date) => setState(() => deliveryDate = date),
                    onDateCleared: () => setState(() => deliveryDate = null),
                  ),

                  const SizedBox(height: 16),

                  // Zahlungsdatum
                  _buildDateSelector(
                    title: 'Zahlungsdatum',
                    icon: 'payment',
                    selectedDate: paymentDate,
                    onDateSelected: (date) => setState(() => paymentDate = date),
                    onDateCleared: () => setState(() => paymentDate = null),
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
                          onPressed: () async {
                            final settings = {
                              'delivery_date': deliveryDate,
                              'payment_date': paymentDate,
                            };
                            await widget.onSave(settings);
                            if (context.mounted) {
                              Navigator.pop(context, settings);
                            }
                          },
                          icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save),
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
  }

  Widget _buildDateSelector({
    required String title,
    required String icon,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
    required VoidCallback onDateCleared,
  }) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          onDateSelected(date);
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
            getAdaptiveIcon(iconName: icon, defaultIcon: Icons.calendar_today),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12)),
                  Text(
                    selectedDate != null
                        ? DateFormat('dd.MM.yyyy').format(selectedDate)
                        : 'Datum auswählen',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            if (selectedDate != null)
              IconButton(
                icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear),
                onPressed: onDateCleared,
              ),
          ],
        ),
      ),
    );
  }
}

// Weitere Dialog-Klassen folgen dem gleichen Muster...
class _CommercialInvoiceSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> initialSettings;
  final Map<String, dynamic> packagingDataFromPackingList;
  final Function(Map<String, dynamic>) onSave;

  const _CommercialInvoiceSettingsDialog({
    required this.initialSettings,
    required this.packagingDataFromPackingList,
    required this.onSave,
  });

  @override
  State<_CommercialInvoiceSettingsDialog> createState() => _CommercialInvoiceSettingsDialogState();
}

class _CommercialInvoiceSettingsDialogState extends State<_CommercialInvoiceSettingsDialog> {
  late Map<String, dynamic> settings;
  late TextEditingController numberOfPackagesController;
  late TextEditingController exportReasonController;
  late TextEditingController carrierController;

  @override
  void initState() {
    super.initState();
    settings = Map<String, dynamic>.from(widget.initialSettings);

    // Initialisiere Controller
    final numberOfPackages = widget.packagingDataFromPackingList['numberOfPackages'] > 0
        ? widget.packagingDataFromPackingList['numberOfPackages']
        : (settings['number_of_packages'] ?? 1);

    numberOfPackagesController = TextEditingController(text: numberOfPackages.toString());
    exportReasonController = TextEditingController(text: settings['export_reason_text'] ?? 'Ware');
    carrierController = TextEditingController(text: settings['carrier_text'] ?? 'Swiss Post');
  }

  @override
  void dispose() {
    numberOfPackagesController.dispose();
    exportReasonController.dispose();
    carrierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Implementation des Commercial Invoice Settings Dialogs
    // ... (Code aus OrderDocumentManager anpassen)
    return Container(); // Placeholder
  }
}

class _PackingListSettingsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialPackages;
  final List<Map<String, dynamic>> availableItems;
  final String entityId;
  final String entityType;
  final Function(List<Map<String, dynamic>>) onSave;

  const _PackingListSettingsDialog({
    required this.initialPackages,
    required this.availableItems,
    required this.entityId,
    required this.entityType,
    required this.onSave,
  });

  @override
  State<_PackingListSettingsDialog> createState() => _PackingListSettingsDialogState();
}

class _PackingListSettingsDialogState extends State<_PackingListSettingsDialog> {
  late List<Map<String, dynamic>> packages;
  final Map<String, Map<String, TextEditingController>> packageControllers = {};

  @override
  void initState() {
    super.initState();
    packages = widget.initialPackages.isNotEmpty
        ? List<Map<String, dynamic>>.from(widget.initialPackages)
        : [_createNewPackage(1)];

    // Initialisiere Controller für existierende Pakete
    _initializeControllers();
  }

  void _initializeControllers() {
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

  Map<String, dynamic> _createNewPackage(int index) {
    final packageId = DateTime.now().millisecondsSinceEpoch.toString();
    return {
      'id': packageId,
      'name': 'Paket $index',
      'packaging_type': '',
      'length': 0.0,
      'width': 0.0,
      'height': 0.0,
      'tare_weight': 0.0,
      'items': <Map<String, dynamic>>[],
      'standard_package_id': null,
    };
  }

  @override
  void dispose() {
    packageControllers.forEach((key, controllers) {
      controllers.forEach((_, controller) {
        controller.dispose();
      });
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Implementation des Packing List Settings Dialogs
    // ... (Code aus OrderDocumentManager anpassen)
    return Container(); // Placeholder
  }
}