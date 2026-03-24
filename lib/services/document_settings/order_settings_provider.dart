// File: services/document_settings/order_settings_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'document_settings_provider.dart';
import '../../orders/order_model.dart';

/// Konkrete Implementierung für den Auftragsbereich.
/// 
/// Liest/Speichert Settings in: orders/{orderId}/settings/...
/// und orders/{orderId}/packing_list/...
class OrderSettingsProvider extends DocumentSettingsProvider {
  final OrderX order;
  
  /// Lokale Kopie der Kundendaten, die im Dialog verändert werden kann
  /// (z.B. nach Adressabgleich).
  Map<String, dynamic> customerData;
  
  OrderSettingsProvider({
    required this.order,
    Map<String, dynamic>? customerDataOverride,
  }) : customerData = customerDataOverride 
           ?? Map<String, dynamic>.from(order.customer ?? {});
  
  /// Firestore-Referenz auf das Order-Dokument
  DocumentReference get _orderRef => 
      FirebaseFirestore.instance.collection('orders').doc(order.id);
  
  /// Referenz auf die Settings-Subcollection
  CollectionReference get _settingsRef => _orderRef.collection('settings');
  
  // ═══════════════════════════════════════════════════════════════════
  // Kontext
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  String get contextLabel => 'Auftrag ${order.orderNumber}';
  
  @override
  String get contextType => 'order';
  
  // ═══════════════════════════════════════════════════════════════════
  // Lieferschein
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  Future<Map<String, dynamic>> loadDeliveryNoteSettings() async {
    try {
      final doc = await _settingsRef.doc('delivery_settings').get();
      if (!doc.exists) return {};
      
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return {
        'delivery_date': data['delivery_date'] != null
            ? (data['delivery_date'] as Timestamp).toDate()
            : null,
        'payment_date': data['payment_date'] != null
            ? (data['payment_date'] as Timestamp).toDate()
            : null,
      };
    } catch (e) {
      print('Fehler beim Laden der Lieferschein-Einstellungen: $e');
      return {};
    }
  }
  
  @override
  Future<void> saveDeliveryNoteSettings(Map<String, dynamic> settings) async {
    await _settingsRef.doc('delivery_settings').set({
      'delivery_date': settings['delivery_date'] != null
          ? Timestamp.fromDate(settings['delivery_date'] as DateTime)
          : null,
      'payment_date': settings['payment_date'] != null
          ? Timestamp.fromDate(settings['payment_date'] as DateTime)
          : null,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  @override
  Future<bool> hasExistingDeliveryNoteSettings() async {
    try {
      final doc = await _settingsRef.doc('delivery_settings').get();
      return doc.exists;
    } catch (e) {
      print('Fehler beim Prüfen der Liefereinstellungen: $e');
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // Handelsrechnung / Tara
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  Future<Map<String, dynamic>> loadCommercialInvoiceSettings() async {
    try {
      final doc = await _settingsRef.doc('tara_settings').get();
      if (!doc.exists) return _defaultCommercialInvoiceSettings();
      
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return {
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
    } catch (e) {
      print('Fehler beim Laden der Handelsrechnung-Einstellungen: $e');
      return _defaultCommercialInvoiceSettings();
    }
  }
  
  Map<String, dynamic> _defaultCommercialInvoiceSettings() => {
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
  };
  
  @override
  Future<void> saveCommercialInvoiceSettings(Map<String, dynamic> settings) async {
    final data = <String, dynamic>{
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    // Alle Felder mit dem commercial_invoice_ Prefix speichern
    settings.forEach((key, value) {
      if (value is DateTime) {
        data[key] = Timestamp.fromDate(value);
      } else {
        data[key] = value;
      }
    });
    
    await _settingsRef.doc('tara_settings').set(data, SetOptions(merge: true));
  }
  
  @override
  Future<DateTime?> loadCommercialInvoiceDate() async {
    try {
      final doc = await _settingsRef.doc('tara_settings').get();
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>? ?? {};
      if (data['commercial_invoice_date'] != null) {
        return (data['commercial_invoice_date'] as Timestamp).toDate();
      }
      return null;
    } catch (e) {
      print('Fehler beim Laden des Handelsrechnungsdatums: $e');
      return null;
    }
  }
  
  /// Speichert nur das HR-Datum (für die "Als HR-Datum übernehmen" Funktion)
  Future<void> saveCommercialInvoiceDate(DateTime date) async {
    await _settingsRef.doc('tara_settings').set({
      'commercial_invoice_date': Timestamp.fromDate(date),
    }, SetOptions(merge: true));
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // Packliste
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  Future<Map<String, dynamic>> loadPackingListSettings() async {
    try {
      final doc = await _orderRef
          .collection('packing_list')
          .doc('settings')
          .get();
      
      if (!doc.exists) return {'packages': []};
      return doc.data() as Map<String, dynamic>? ?? {'packages': []};
    } catch (e) {
      print('Fehler beim Laden der Packlisten-Einstellungen: $e');
      return {'packages': []};
    }
  }
  
  @override
  Future<void> savePackingListSettings(Map<String, dynamic> settings) async {
    await _orderRef
        .collection('packing_list')
        .doc('settings')
        .set({
      ...settings,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // Rechnung
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  Future<Map<String, dynamic>> loadInvoiceSettings() async {
    try {
      final doc = await _settingsRef.doc('invoice_settings').get();
      if (!doc.exists) return _defaultInvoiceSettings();
      
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return {
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
    } catch (e) {
      print('Fehler beim Laden der Rechnungs-Einstellungen: $e');
      return _defaultInvoiceSettings();
    }
  }
  
  Map<String, dynamic> _defaultInvoiceSettings() => {
    'down_payment_amount': 0.0,
    'down_payment_reference': '',
    'down_payment_date': null,
    'invoice_date': DateTime.now(),
    'is_full_payment': false,
    'payment_method': 'BAR',
    'custom_payment_method': '',
    'payment_term_days': 30,
  };
  
  @override
  Future<void> saveInvoiceSettings(Map<String, dynamic> settings) async {
    final data = <String, dynamic>{
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    settings.forEach((key, value) {
      if (value is DateTime) {
        data[key] = Timestamp.fromDate(value);
      } else {
        data[key] = value;
      }
    });
    
    await _settingsRef.doc('invoice_settings').set(data);
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // Zusatztexte
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  Future<Map<String, dynamic>> loadAdditionalTexts() async {
    try {
      final orderDoc = await _orderRef.get();
      if (!orderDoc.exists) return {};
      
      final data = orderDoc.data() as Map<String, dynamic>? ?? {};
      final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
      return Map<String, dynamic>.from(metadata['additionalTexts'] ?? {});
    } catch (e) {
      print('Fehler beim Laden der Zusatztexte: $e');
      return {};
    }
  }
  
  @override
  Future<void> saveAdditionalTexts(Map<String, dynamic> config) async {
    await _orderRef.update({
      'metadata.additionalTexts': config,
    });
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // Feature-Flags
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  bool get supportsCustomerAddressCompare => true;
}
