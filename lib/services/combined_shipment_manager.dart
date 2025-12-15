import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tonewood/services/pdf_generators/combined_commercial_invoice_generator.dart';
import 'package:tonewood/services/pdf_generators/combined_delivery_note_generator.dart';
import 'package:tonewood/services/pdf_generators/combined_packing_list_generator.dart';
import '../orders/order_model.dart';
import 'orders_document_manager.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class CombinedShipmentManager {
  static const String collection = 'combined_shipments';

  // Generiere neue Sammellieferungsnummer
  static Future<String> _generateShipmentNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('combined_shipment_counters');

      return await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        Map<String, dynamic> counters = {};
        if (counterDoc.exists) {
          counters = counterDoc.data() ?? {};
        }

        int currentNumber = counters[year.toString()] ?? 0;
        currentNumber++;

        transaction.set(counterRef, {
          year.toString(): currentNumber,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Format: SL-2025-0001
        return 'SL-$year-${currentNumber.toString().padLeft(4, '0')}';
      });
    } catch (e) {
      print('Fehler beim Erstellen der Sammellieferungsnummer: $e');
      // Fallback
      return 'SL-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Erstelle neue Sammellieferung
  static Future<String> createCombinedShipment({
    required List<String> orderIds,
    required Map<String, dynamic> shippingAddress,
  }) async {
    if (orderIds.isEmpty) {
      throw Exception('Keine Aufträge ausgewählt');
    }

    final user = FirebaseAuth.instance.currentUser;
    final shipmentNumber = await _generateShipmentNumber();

    // Erstelle Sammellieferung
    final shipmentData = {
      'shipment_number': shipmentNumber,
      'order_ids': orderIds,
      'shipping_address': shippingAddress,
      'status': 'draft',
      'created_at': FieldValue.serverTimestamp(),
      'created_by': user?.uid,
      'created_by_email': user?.email,
      'documents': {},
    };

    final shipmentRef = await FirebaseFirestore.instance
        .collection(collection)
        .add(shipmentData);

    // Update Status der beteiligten Aufträge
    final batch = FirebaseFirestore.instance.batch();
    for (final orderId in orderIds) {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);

      batch.update(orderRef, {
        'combined_shipment_id': shipmentRef.id,
        'combined_shipment_number': shipmentNumber,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    return shipmentNumber;
  }

  // Lade Sammellieferung mit allen verknüpften Aufträgen
  static Future<Map<String, dynamic>> loadCombinedShipmentWithOrders(String shipmentId) async {
    final shipmentDoc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(shipmentId)
        .get();

    if (!shipmentDoc.exists) {
      throw Exception('Sammellieferung nicht gefunden');
    }

    // WICHTIG: Sichere Konvertierung
    final rawData = shipmentDoc.data()!;
    final Map<String, dynamic> shipmentData = {};

    rawData.forEach((key, value) {
      if (value is Map) {
        // Rekursive Konvertierung für verschachtelte Maps
        final nestedMap = <String, dynamic>{};
        value.forEach((nestedKey, nestedValue) {
          nestedMap[nestedKey.toString()] = nestedValue;
        });
        shipmentData[key.toString()] = nestedMap;
      } else if (value is List) {
        // Listen direkt übernehmen
        shipmentData[key.toString()] = value;
      } else {
        shipmentData[key.toString()] = value;
      }
    });

    final orderIds = List<String>.from(shipmentData['order_ids'] ?? []);

    // Lade alle verknüpften Aufträge
    final List<OrderX> orders = [];
    for (final orderId in orderIds) {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (orderDoc.exists) {
        orders.add(OrderX.fromFirestore(orderDoc));
      }
    }

    return {
      'id': shipmentDoc.id,
      'data': shipmentData,
      'orders': orders,
    };
  }

  // Zeige Dialog zur Dokumentenerstellung
  static Future<void> showCreateDocumentsDialog(
      BuildContext context,
      String shipmentId,
      ) async {
    final shipmentData = await loadCombinedShipmentWithOrders(shipmentId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CombinedDocumentCreationDialog(
        shipmentData: shipmentData,
      ),
    );
  }

  // Erstelle Dokumente für Sammellieferung
  static Future<Map<String, String>> createDocuments({
    required String shipmentId,
    required Map<String, dynamic> shipmentData,
    required List<OrderX> orders,
    required List<String> documentTypes,
    required Map<String, dynamic> settings,
  }) async {
    final Map<String, String> createdDocuments = {};

    // Sammle alle Items und Kundendaten
    List<Map<String, dynamic>> allItems = [];
    Map<String, String> orderReferences = {}; // orderId -> invoiceNumber

    for (final order in orders) {
      // Debug
      print('Processing order: ${order.orderNumber}');
      print('Order items type: ${order.items.runtimeType}');
      print('First item type: ${order.items.isNotEmpty ? order.items.first.runtimeType : 'no items'}');

      // Erweitere Items mit Auftragsnummer
      for (final item in order.items) {
        // Erstelle eine komplett neue Map mit String-Keys
        final Map<String, dynamic> extendedItem = {};

        // Kopiere alle Werte mit sicherer Konvertierung
        if (item is Map) {
          item.forEach((key, value) {
            final stringKey = key.toString();

            // Konvertiere auch verschachtelte Maps
            if (value is Map) {
              final Map<String, dynamic> nestedMap = {};
              value.forEach((nestedKey, nestedValue) {
                nestedMap[nestedKey.toString()] = nestedValue;
              });
              extendedItem[stringKey] = nestedMap;
            } else {
              extendedItem[stringKey] = value;
            }
          });
        }

        extendedItem['_order_id'] = order.id;
        extendedItem['_order_number'] = order.orderNumber;
        extendedItem['_invoice_number'] = order.orderNumber;

        print('Extended item keys: ${extendedItem.keys.toList()}');

        allItems.add(extendedItem);
      }

      orderReferences[order.id] = order.orderNumber;
    }

    // DEBUG: Nach Item-Sammlung
    print('=== AFTER COLLECTING ITEMS ===');
    print('allItems count: ${allItems.length}');
    print('allItems type: ${allItems.runtimeType}');
    if (allItems.isNotEmpty) {
      print('First allItem type: ${allItems.first.runtimeType}');
      print('First allItem keys: ${allItems.first.keys.toList()}');
    }

    // WICHTIG: Sichere Konvertierung der shipping_address
    final rawShippingAddress = shipmentData['data']['shipping_address'];
    print('=== SHIPPING ADDRESS DEBUG ===');
    print('rawShippingAddress type: ${rawShippingAddress.runtimeType}');

    final Map<String, dynamic> shippingAddress = {};
    if (rawShippingAddress is Map) {
      rawShippingAddress.forEach((key, value) {
        shippingAddress[key.toString()] = value;
      });
    }
    print('shippingAddress converted type: ${shippingAddress.runtimeType}');

    // Basis-Kundendaten aus der ersten Order, aber mit Lieferadresse überschreiben
    final baseCustomer = <String, dynamic>{};

    // DEBUG: Customer data
    print('=== CUSTOMER DATA DEBUG ===');
    print('orders.first.customer type: ${orders.first.customer.runtimeType}');

    // Sichere Kopie der Customer-Daten
    orders.first.customer.forEach((key, value) {
      baseCustomer[key.toString()] = value;
    });

    // Überschreibe mit Lieferadresse
    baseCustomer.addAll({
      'street': shippingAddress['street'],
      'houseNumber': shippingAddress['houseNumber'],
      'zipCode': shippingAddress['zipCode'],
      'city': shippingAddress['city'],
      'country': shippingAddress['country'],
      'contactPerson': shippingAddress['contactPerson'],
      'phone': shippingAddress['phone'],
      'email': shippingAddress['email'],
    });

    print('baseCustomer type after merge: ${baseCustomer.runtimeType}');
    print('baseCustomer keys: ${baseCustomer.keys.toList()}');

    // DEBUG: Settings
    print('=== SETTINGS DEBUG ===');
    print('settings type: ${settings.runtimeType}');
    print('settings keys: ${settings.keys.toList()}');

    // Erstelle Dokumente
    for (final docType in documentTypes) {
      try {
        Uint8List? pdfBytes;
        String documentKey = '';

        switch (docType) {
          case 'Lieferschein':
            documentKey = 'delivery_note_pdf';

            print('=== BEFORE CALLING DeliveryNoteGenerator ===');
            print('allItems type: ${allItems.runtimeType}');
            print('baseCustomer type: ${baseCustomer.runtimeType}');
            print('orderReferences type: ${orderReferences.runtimeType}');
            print('settings[delivery_note] type: ${settings['delivery_note'].runtimeType}');
// Sichere Konvertierung der settings
            final Map<String, dynamic> deliveryNoteSettings = {};
            final rawDeliverySettings = settings['delivery_note'];
            if (rawDeliverySettings is Map) {
              rawDeliverySettings.forEach((key, value) {
                deliveryNoteSettings[key.toString()] = value;
              });
            }

            pdfBytes = await CombinedDeliveryNoteGenerator.generatePdf(
              shipmentNumber: shipmentData['data']['shipment_number'],
              items: allItems,
              customerData: baseCustomer,
              orderReferences: orderReferences,
              orders: orders,
              settings: deliveryNoteSettings,
            );
            break;

          case 'Handelsrechnung':
            documentKey = 'commercial_invoice_pdf';

            // Sichere Konvertierung der settings
            final Map<String, dynamic> invoiceSettings = {};
            final rawInvoiceSettings = settings['commercial_invoice'];
            if (rawInvoiceSettings is Map) {
              rawInvoiceSettings.forEach((key, value) {
                invoiceSettings[key.toString()] = value;
              });
            }

            pdfBytes = await CombinedCommercialInvoiceGenerator.generatePdf(
              shipmentNumber: shipmentData['data']['shipment_number'],
              items: allItems,
              customerData: baseCustomer,
              orderReferences: orderReferences,
              orders: orders,
              settings: invoiceSettings,
            );
            break;

          case 'Packliste':
            documentKey = 'packing_list_pdf';

            // Sichere Konvertierung der settings
            final Map<String, dynamic> packingListSettings = {};
            final rawPackingSettings = settings['packing_list'];
            if (rawPackingSettings is Map) {
              rawPackingSettings.forEach((key, value) {
                packingListSettings[key.toString()] = value;
              });
            }

            pdfBytes = await CombinedPackingListGenerator.generatePdf(
              shipmentNumber: shipmentData['data']['shipment_number'],
              items: allItems,
              customerData: baseCustomer,
              orderReferences: orderReferences,
              orders: orders,
              shipmentId: shipmentId,
              settings: packingListSettings,
            );
            break;
        }

        if (pdfBytes != null) {
          // Upload zu Firebase Storage
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('combined_shipments')
              .child(shipmentId)
              .child('$documentKey.pdf');

          final uploadTask = await storageRef.putData(
            pdfBytes,
            SettableMetadata(
              contentType: 'application/pdf',
              customMetadata: {
                'shipmentNumber': shipmentData['data']['shipment_number'],
                'documentType': docType,
                'createdAt': DateTime.now().toIso8601String(),
              },
            ),
          );

          final downloadUrl = await uploadTask.ref.getDownloadURL();
          createdDocuments[documentKey] = downloadUrl;
        }
      } catch (e, stackTrace) {
        print('Fehler beim Erstellen von $docType: $e');
        print('StackTrace: $stackTrace');
      }
    }

    // Update Sammellieferung mit Dokument-URLs
    if (createdDocuments.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(shipmentId)
          .update({
        'documents': createdDocuments,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    return createdDocuments;
  }
}

// Dialog Widget für Dokumentenerstellung
class _CombinedDocumentCreationDialog extends StatefulWidget {
  final Map<String, dynamic> shipmentData;

  const _CombinedDocumentCreationDialog({
    required this.shipmentData,
  });

  @override
  State<_CombinedDocumentCreationDialog> createState() => _CombinedDocumentCreationDialogState();
}

class _CombinedDocumentCreationDialogState extends State<_CombinedDocumentCreationDialog> {
  final Map<String, bool> _selection = {
    'Lieferschein': true,
    'Handelsrechnung': true,
    'Packliste': true,
  };

  final Map<String, dynamic> _settings = {
    'delivery_note': {},
    'commercial_invoice': {},
    'packing_list': {},
  };

  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final orders = widget.shipmentData['orders'] as List<OrderX>;

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
                      const Text(
                        'Dokumente erstellen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Sammellieferung ${widget.shipmentData['data']['shipment_number']}',
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

          // Auftragsübersicht
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enthaltene Aufträge:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                ...orders.map((order) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '• Rechnung ${order.orderNumber} - ${order.customer['company'] ?? order.customer['fullName']}',
                    style: const TextStyle(fontSize: 11),
                  ),
                )).toList(),
              ],
            ),
          ),

          // Dokumentauswahl
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ..._selection.keys.map((docType) {
                  return CheckboxListTile(
                    title: Text(docType),
                    value: _selection[docType],
                    onChanged: (value) {
                      setState(() {
                        _selection[docType] = value ?? false;
                      });
                    },
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
                    onPressed: _isCreating ? null : _createDocuments,
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

  Future<void> _createDocuments() async {
    setState(() {
      _isCreating = true;
    });

    try {
      final selectedDocs = _selection.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final createdDocs = await CombinedShipmentManager.createDocuments(
        shipmentId: widget.shipmentData['id'],
        shipmentData: widget.shipmentData,
        orders: widget.shipmentData['orders'],
        documentTypes: selectedDocs,
        settings: _settings,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${createdDocs.length} Dokumente wurden erstellt'),
            backgroundColor: Colors.green,
          ),
        );
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
}