// File: services/postal_document_service.dart
//
// Dieser Service handhabt die Dokumentenerstellung mit Versandgruppen:
//
// Modus "Gesamt" (shipment_mode = 'total'):
//   → Alle Packstücke = 1 Versandgruppe → 1 HR, 1 Lieferschein (wie bisher)
//
// Modus "Einzelversand" (shipment_mode = 'per_shipment'):
//   → Jedes Packstück hat eine shipment_group (z.B. 1, 2, 3)
//   → Pro Versandgruppe wird 1 HR + 1 Lieferschein erstellt
//   → Mehrere Packstücke können in derselben Gruppe sein
//
// Beispiel:
//   Packstück 1 → Gruppe 1  ┐
//   Packstück 2 → Gruppe 1  ┘ → HR-2026-5000-1, LS-2026-5000-1
//   Packstück 3 → Gruppe 2    → HR-2026-5000-2, LS-2026-5000-2
//   Packstück 4 → Gruppe 3  ┐
//   Packstück 5 → Gruppe 3  ┘ → HR-2026-5000-3, LS-2026-5000-3

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../orders/order_model.dart';
import 'pdf_generators/commercial_invoice_generator.dart';
import 'pdf_generators/delivery_note_generator.dart';

class PostalDocumentService {

  // ═══════════════════════════════════════════════════════════════════════════
  // HAUPT-METHODE: Dokumente pro Versandgruppe erstellen
  // ═══════════════════════════════════════════════════════════════════════════

  /// Erstellt Handelsrechnungen und Lieferscheine pro Versandgruppe.
  ///
  /// Gibt eine Liste der erfolgreich erstellten Dokumentnamen zurück.
  static Future<List<String>> createShipmentDocuments({
    required OrderX order,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> settings,
    required Map<String, dynamic> additionalTextsConfig,
    required bool createCommercialInvoices,
    required bool createDeliveryNotes,
  }) async {
    final List<String> createdDocuments = [];

    // 1. Packages aus Packliste laden
    final packages = await _loadPackages(order.id);
    if (packages.isEmpty) {
      throw Exception('Keine Packstücke in der Packliste konfiguriert. '
          'Bitte zuerst die Packliste mit Packstücken einrichten.');
    }

    // 2. Packages nach Versandgruppe gruppieren
    final shipmentGroups = _groupPackagesByShipment(packages);

    // 3. Exchange Rates vorbereiten
    final exchangeRates = _prepareExchangeRates(orderData);

    // 4. Gesamt-Subtotal berechnen (für proportionale Rabattverteilung)
    final allItems = orderData['items'] as List<Map<String, dynamic>>;
    final totalSubtotal = _calculateSubtotal(allItems);

    // 5. Pro Versandgruppe iterieren
    final sortedGroupNumbers = shipmentGroups.keys.toList()..sort();
    final totalGroups = sortedGroupNumbers.length;

    for (int i = 0; i < sortedGroupNumbers.length; i++) {
      final groupNumber = sortedGroupNumbers[i];
      final groupPackages = shipmentGroups[groupNumber]!;
      final displayNumber = i + 1; // Fortlaufende Nummer 1, 2, 3...

      // Alle Items aus allen Packstücken dieser Versandgruppe sammeln
      final groupItems = _getItemsForShipmentGroup(groupPackages, allItems);

      if (groupItems.isEmpty) continue;

      // Anteilige Calculations berechnen
      final groupCalculations = _calculateProportionalDiscounts(
        packageItems: groupItems,
        totalSubtotal: totalSubtotal,
        originalCalculations: orderData['calculations'] as Map<String, dynamic>?,
      );

      // Tara-Daten für die gesamte Versandgruppe summieren
      final groupTaraData = _calculateGroupTaraData(groupPackages);

      // 6. Handelsrechnung pro Versandgruppe
      if (createCommercialInvoices) {
        final success = await _createGroupCommercialInvoice(
          order: order,
          orderData: orderData,
          settings: settings,
          exchangeRates: exchangeRates,
          groupItems: groupItems,
          groupCalculations: groupCalculations,
          groupTaraData: groupTaraData,
          displayNumber: displayNumber,
          totalGroups: totalGroups,
          additionalTextsConfig: additionalTextsConfig,
        );
        if (success) {
          createdDocuments.add('Handelsrechnung $displayNumber/$totalGroups');
        }
      }

      // 7. Lieferschein pro Versandgruppe
      if (createDeliveryNotes) {
        final success = await _createGroupDeliveryNote(
          order: order,
          orderData: orderData,
          settings: settings,
          exchangeRates: exchangeRates,
          groupItems: groupItems,
          displayNumber: displayNumber,
          totalGroups: totalGroups,
          additionalTextsConfig: additionalTextsConfig,
        );
        if (success) {
          createdDocuments.add('Lieferschein $displayNumber/$totalGroups');
        }
      }
    }

    return createdDocuments;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PACKAGES LADEN & GRUPPIEREN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lädt die Packstücke aus der Packliste-Subcollection
  static Future<List<Map<String, dynamic>>> _loadPackages(String orderId) async {
    try {
      final packingListDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('packing_list')
          .doc('settings')
          .get();

      if (!packingListDoc.exists) return [];

      final data = packingListDoc.data()!;
      final packages = data['packages'] as List<dynamic>? ?? [];
      return packages.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    } catch (e) {
      print('PostalDocumentService: Fehler beim Laden der Packages: $e');
      return [];
    }
  }

  /// Gruppiert Packstücke nach ihrer shipment_group.
  ///
  /// Jedes Packstück hat ein Feld 'shipment_group' (int).
  /// Packstücke mit gleicher Gruppe werden zusammengefasst.
  static Map<int, List<Map<String, dynamic>>> _groupPackagesByShipment(
      List<Map<String, dynamic>> packages,
      ) {
    final Map<int, List<Map<String, dynamic>>> groups = {};

    for (final package in packages) {
      final group = (package['shipment_group'] as num?)?.toInt() ?? 1;
      groups.putIfAbsent(group, () => []);
      groups[group]!.add(package);
    }

    return groups;
  }
  // In PostalDocumentService, neue statische Helper-Methode:
  static String _getItemKey(Map<String, dynamic> item) {
    return item['basket_doc_id']?.toString() ?? '';
  }
  // ═══════════════════════════════════════════════════════════════════════════
  // ITEMS PRO VERSANDGRUPPE EXTRAHIEREN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sammelt alle Items aus allen Packstücken einer Versandgruppe.
  ///
  /// Wenn dasselbe Produkt in mehreren Packstücken der gleichen Gruppe vorkommt,
  /// werden die Mengen zusammengefasst.
  static List<Map<String, dynamic>> _getItemsForShipmentGroup(
      List<Map<String, dynamic>> groupPackages,
      List<Map<String, dynamic>> allOrderItems,
      ) {
    final Map<String, Map<String, dynamic>> mergedItems = {};

    for (final package in groupPackages) {
      final packageItemsList = package['items'] as List<dynamic>? ?? [];

      for (final pkgItem in packageItemsList) {
        final pkgItemMap = Map<String, dynamic>.from(pkgItem as Map);
        final pkgItemKey = _getItemKey(pkgItemMap);
        final packageQuantity = (pkgItemMap['quantity'] as num?)?.toDouble() ?? 0.0;

        if (packageQuantity <= 0) continue;

        // Finde das entsprechende Order-Item per itemKey
        final orderItem = allOrderItems.firstWhere(
              (item) => _getItemKey(item) == pkgItemKey,
          orElse: () => <String, dynamic>{},
        );

        if (orderItem.isEmpty) continue;

        if (mergedItems.containsKey(pkgItemKey)) {
          // Gleicher Key: Menge addieren
          final existing = mergedItems[pkgItemKey]!;
          final existingQty = (existing['quantity'] as num?)?.toDouble() ?? 0.0;
          existing['quantity'] = existingQty + packageQuantity;

          // Einzelrabatt auch addieren
          final originalQuantity = (orderItem['quantity'] as num?)?.toDouble() ?? 1.0;
          final originalDiscountAmount = (orderItem['discount_amount'] as num?)?.toDouble() ?? 0.0;
          if (originalDiscountAmount > 0 && originalQuantity > 0) {
            final discountPerUnit = originalDiscountAmount / originalQuantity;
            final existingDiscount = (existing['discount_amount'] as num?)?.toDouble() ?? 0.0;
            existing['discount_amount'] = existingDiscount + (discountPerUnit * packageQuantity);
          }
        } else {
          // Neues Produkt
          final itemCopy = Map<String, dynamic>.from(orderItem);
          itemCopy['quantity'] = packageQuantity;

          // Einzelrabatt proportional anpassen
          final originalQuantity = (orderItem['quantity'] as num?)?.toDouble() ?? 1.0;
          final originalDiscountAmount = (orderItem['discount_amount'] as num?)?.toDouble() ?? 0.0;
          if (originalDiscountAmount > 0 && originalQuantity > 0) {
            final discountPerUnit = originalDiscountAmount / originalQuantity;
            itemCopy['discount_amount'] = discountPerUnit * packageQuantity;
          }

          mergedItems[pkgItemKey] = itemCopy;
        }
      }
    }

    return mergedItems.values.toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TARA-DATEN PRO VERSANDGRUPPE BERECHNEN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Berechnet die summierten Tara-Daten für eine Versandgruppe
  static Map<String, dynamic> _calculateGroupTaraData(
      List<Map<String, dynamic>> groupPackages,
      ) {
    double totalTareWeight = 0.0;
    double totalVolume = 0.0;

    for (final package in groupPackages) {
      totalTareWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;

      final width = (package['width'] as num?)?.toDouble() ?? 0.0;
      final height = (package['height'] as num?)?.toDouble() ?? 0.0;
      final length = (package['length'] as num?)?.toDouble() ?? 0.0;
      totalVolume += (width * height * length) / 1000000; // cm³ → m³
    }

    return {
      'number_of_packages': groupPackages.length,
      'packaging_weight': totalTareWeight,
      'packaging_volume': totalVolume,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANTEILIGE RABATTE BERECHNEN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Berechnet den Subtotal einer Items-Liste (ohne Rabatte, ohne Services)
  static double _calculateSubtotal(List<Map<String, dynamic>> items) {
    double subtotal = 0.0;
    for (final item in items) {
      if (item['is_service'] == true) continue;
      if (item['is_gratisartikel'] == true) continue;

      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = (item['custom_price_per_unit'] as num?) != null
          ? (item['custom_price_per_unit'] as num).toDouble()
          : (item['price_per_unit'] as num? ?? 0).toDouble();

      subtotal += quantity * pricePerUnit;
    }
    return subtotal;
  }

  /// Berechnet anteilige Calculations für eine Versandgruppe.
  /// Absolute Gesamtrabatte werden proportional zum Wertanteil aufgeteilt.
  static Map<String, dynamic> _calculateProportionalDiscounts({
    required List<Map<String, dynamic>> packageItems,
    required double totalSubtotal,
    required Map<String, dynamic>? originalCalculations,
  }) {
    if (originalCalculations == null) return {};

    final calculations = Map<String, dynamic>.from(originalCalculations);
    final packageSubtotal = _calculateSubtotal(packageItems);
    final proportion = totalSubtotal > 0 ? packageSubtotal / totalSubtotal : 0.0;

    final totalDiscountAmount = (calculations['total_discount_amount'] as num?)?.toDouble() ?? 0.0;
    if (totalDiscountAmount > 0) {
      calculations['total_discount_amount'] = totalDiscountAmount * proportion;
    }

    return calculations;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCHANGE RATES
  // ═══════════════════════════════════════════════════════════════════════════

  static Map<String, double> _prepareExchangeRates(Map<String, dynamic> orderData) {
    final rawExchangeRates = orderData['exchangeRates'] as Map<dynamic, dynamic>? ?? {};
    final exchangeRates = <String, double>{'CHF': 1.0};
    rawExchangeRates.forEach((key, value) {
      if (value != null) {
        exchangeRates[key.toString()] = (value as num).toDouble();
      }
    });
    return exchangeRates;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HANDELSRECHNUNG PRO VERSANDGRUPPE
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> _createGroupCommercialInvoice({
    required OrderX order,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> settings,
    required Map<String, double> exchangeRates,
    required List<Map<String, dynamic>> groupItems,
    required Map<String, dynamic> groupCalculations,
    required Map<String, dynamic> groupTaraData,
    required int displayNumber,
    required int totalGroups,
    required Map<String, dynamic> additionalTextsConfig,
  }) async {
    try {
      final ciSettings = settings['commercial_invoice'] as Map<String, dynamic>? ?? {};
      final commercialInvoiceCurrency = ciSettings['currency'] ?? orderData['currency'];

      final taraSettings = {
        'number_of_packages': groupTaraData['number_of_packages'],
        'packaging_weight': groupTaraData['packaging_weight'],
        'packaging_volume': groupTaraData['packaging_volume'],
        'commercial_invoice_date': ciSettings['commercial_invoice_date'],
        'commercial_invoice_origin_declaration': ciSettings['origin_declaration'],
        'commercial_invoice_cites': ciSettings['cites'],
        'commercial_invoice_export_reason': ciSettings['export_reason'],
        'commercial_invoice_export_reason_text': ciSettings['export_reason_text'],
        'commercial_invoice_incoterms': ciSettings['incoterms'],
        'commercial_invoice_selected_incoterms': ciSettings['selected_incoterms'],
        'commercial_invoice_incoterms_freetexts': ciSettings['incoterms_freetexts'],
        'commercial_invoice_delivery_date':
        ciSettings['delivery_date'] == true || ciSettings['use_as_delivery_date'] == true,
        'commercial_invoice_delivery_date_value': ciSettings['use_as_delivery_date'] == true
            ? ciSettings['commercial_invoice_date']
            : ciSettings['delivery_date_value'],
        'commercial_invoice_delivery_date_month_only': ciSettings['use_as_delivery_date'] == true
            ? false
            : (ciSettings['delivery_date_month_only'] ?? false),
        'commercial_invoice_carrier': ciSettings['carrier'],
        'commercial_invoice_carrier_text': ciSettings['carrier_text'],
        'commercial_invoice_signature': ciSettings['signature'],
        'commercial_invoice_selected_signature': ciSettings['selected_signature'],
      };

      DateTime? invoiceDate;
      if (ciSettings['commercial_invoice_date'] != null) {
        invoiceDate = ciSettings['commercial_invoice_date'] is DateTime
            ? ciSettings['commercial_invoice_date'] as DateTime
            : (ciSettings['commercial_invoice_date'] as Timestamp).toDate();
      }

      final invoiceNum = '${order.orderNumber}-CI-$displayNumber';

      final pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
        items: groupItems,
        customerData: orderData['customer'],
        fairData: orderData['fair'],
        costCenterCode: orderData['costCenterCode'],
        currency: commercialInvoiceCurrency,
        exchangeRates: exchangeRates,
        language: orderData['language'],
        invoiceNumber: invoiceNum,
        shippingCosts: null, // Keine Versandkosten auf Einzel-HR
        calculations: groupCalculations,
        taxOption: orderData['taxOption'],
        vatRate: orderData['vatRate'],
        taraSettings: taraSettings,
        invoiceDate: invoiceDate,
        additionalTexts: additionalTextsConfig,
      );

      final documentKey = 'commercial_invoice_pdf_$displayNumber';
      await _uploadAndSaveDocument(
        orderId: order.id,
        orderNumber: order.orderNumber,
        pdfBytes: pdfBytes,
        documentKey: documentKey,
        documentType: 'Handelsrechnung $displayNumber/$totalGroups',
      );

      return true;
    } catch (e) {
      print('PostalDocumentService: Fehler bei HR $displayNumber: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIEFERSCHEIN PRO VERSANDGRUPPE
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> _createGroupDeliveryNote({
    required OrderX order,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> settings,
    required Map<String, double> exchangeRates,
    required List<Map<String, dynamic>> groupItems,
    required int displayNumber,
    required int totalGroups,
    required Map<String, dynamic> additionalTextsConfig,
  }) async {
    try {
      final dnSettings = settings['delivery_note'] as Map<String, dynamic>? ?? {};
      final deliveryNum = '${order.orderNumber}-LS-$displayNumber';

      final pdfBytes = await DeliveryNoteGenerator.generateDeliveryNotePdf(
        items: groupItems,
        customerData: orderData['customer'],
        fairData: orderData['fair'],
        costCenterCode: orderData['costCenterCode'],
        currency: orderData['currency'],
        exchangeRates: exchangeRates,
        language: orderData['language'],
        deliveryNoteNumber: deliveryNum,
        deliveryDate: dnSettings['delivery_date'],
        paymentDate: dnSettings['payment_date'],
        additionalTexts: additionalTextsConfig,
      );

      final documentKey = 'delivery_note_pdf_$displayNumber';
      await _uploadAndSaveDocument(
        orderId: order.id,
        orderNumber: order.orderNumber,
        pdfBytes: pdfBytes,
        documentKey: documentKey,
        documentType: 'Lieferschein $displayNumber/$totalGroups',
      );

      return true;
    } catch (e) {
      print('PostalDocumentService: Fehler bei LS $displayNumber: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UPLOAD & SPEICHERN
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> _uploadAndSaveDocument({
    required String orderId,
    required String orderNumber,
    required Uint8List pdfBytes,
    required String documentKey,
    required String documentType,
  }) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('orders')
        .child(orderId)
        .child('$documentKey.pdf');

    final uploadTask = await storageRef.putData(
      pdfBytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'orderNumber': orderNumber,
          'documentType': documentType,
          'createdAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    final documentUrl = await uploadTask.ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'documents.$documentKey': documentUrl,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('history')
        .add({
      'timestamp': FieldValue.serverTimestamp(),
      'user_id': user?.uid ?? 'unknown',
      'user_email': user?.email ?? 'Unknown User',
      'user_name': user?.email ?? 'Unknown',
      'action': 'document_created',
      'document_type': documentType,
      'document_url': documentUrl,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDIERUNG
  // ═══════════════════════════════════════════════════════════════════════════

  /// Prüft ob der Einzelversand-Modus verwendet werden kann.
  /// Gibt null zurück wenn alles OK, sonst eine Fehlermeldung.
  static Future<String?> validateShipmentMode(String orderId) async {
    final packages = await _loadPackages(orderId);

    if (packages.isEmpty) {
      return 'Für den Einzelversand müssen Packstücke in der Packliste konfiguriert sein.\n\n'
          'Bitte zuerst unter Packliste → Einstellungen die Packstücke anlegen und '
          'Produkte zuweisen.';
    }

    // Prüfe ob Versandgruppen zugewiesen sind
    final hasShipmentGroups = packages.any(
          (p) => (p['shipment_group'] as num?)?.toInt() != null && (p['shipment_group'] as num).toInt() > 0,
    );

    if (!hasShipmentGroups) {
      return 'Bitte weise den Packstücken zuerst Versandgruppen zu.\n\n'
          'Gehe zu Packliste → Einstellungen und wähle für jedes Packstück '
          'die Versandgruppe (Sendung 1, Sendung 2, etc.).';
    }

    // Prüfe ob alle Packstücke Items haben
    final emptyPackages = <int>[];
    for (int i = 0; i < packages.length; i++) {
      final items = packages[i]['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) {
        emptyPackages.add(i + 1);
      }
    }

    if (emptyPackages.isNotEmpty) {
      return 'Die folgenden Packstücke haben keine Produkte zugewiesen:\n'
          '${emptyPackages.map((n) => '• Packstück $n').join('\n')}\n\n'
          'Bitte weise allen Packstücken Produkte zu.';
    }

    return null; // Alles OK
  }

  /// Gibt die Anzahl der Versandgruppen zurück (für Vorschau-Anzeige)
  static Future<int> getShipmentGroupCount(String orderId) async {
    final packages = await _loadPackages(orderId);
    if (packages.isEmpty) return 0;
    final groups = _groupPackagesByShipment(packages);
    return groups.length;
  }

  /// Prüft ob bereits Einzelversand-Dokumente existieren
  static bool hasExistingShipmentDocuments(Map<String, String> documents) {
    return documents.keys.any((key) =>
    RegExp(r'commercial_invoice_pdf_\d+').hasMatch(key) ||
        RegExp(r'delivery_note_pdf_\d+').hasMatch(key));
  }
}