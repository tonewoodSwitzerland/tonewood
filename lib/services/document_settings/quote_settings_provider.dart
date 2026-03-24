// File: services/document_settings/quote_settings_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'document_settings_provider.dart';
import '../../services/user_basket_service.dart';
import '../../quotes/additional_text_manager.dart';

/// Konkrete Implementierung für den Angebotsbereich.
/// 
/// Liest/Speichert Settings in: UserBasketService.temporaryDocumentSettings/...
class QuoteSettingsProvider extends DocumentSettingsProvider {
  
  /// Referenz auf die temporären Dokument-Einstellungen
  CollectionReference get _settingsRef => 
      UserBasketService.temporaryDocumentSettings;
  
  // ═══════════════════════════════════════════════════════════════════
  // Kontext
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  String get contextLabel => 'Angebot';
  
  @override
  String get contextType => 'quote';
  
  // ═══════════════════════════════════════════════════════════════════
  // Lieferschein
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  Future<Map<String, dynamic>> loadDeliveryNoteSettings() async {
    try {
      final doc = await _settingsRef.doc('delivery_note_settings').get();
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
    await _settingsRef.doc('delivery_note_settings').set({
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
      final doc = await _settingsRef.doc('delivery_note_settings').get();
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
      
      // Quote-Bereich: Lade auch Packlisten-Daten für Gewicht/Volumen
      Map<String, dynamic> result = Map.from(data);
      
      // Prüfe ob Tara-Werte aus Packliste übernommen werden sollen
      final hasValidPackages = (data['number_of_packages'] as num? ?? 0) > 0;
      final hasValidWeight = (data['packaging_weight'] as num? ?? 0) > 0;
      
      if (!hasValidPackages || !hasValidWeight) {
        final packingListSettings = await loadPackingListSettings();
        final packages = packingListSettings['packages'] as List<dynamic>?;
        
        if (packages != null && packages.isNotEmpty) {
          double totalPackagingWeight = 0.0;
          double totalPackagingVolume = 0.0;
          
          for (final package in packages) {
            final tareWeight = package['tare_weight'];
            if (tareWeight != null) {
              totalPackagingWeight += (tareWeight is num) ? tareWeight.toDouble() : 0.0;
            }
            final width = (package['width'] as num?)?.toDouble() ?? 0.0;
            final height = (package['height'] as num?)?.toDouble() ?? 0.0;
            final length = (package['length'] as num?)?.toDouble() ?? 0.0;
            totalPackagingVolume += (width * height * length) / 1000000;
          }
          
          result['number_of_packages'] = packages.length;
          result['packaging_weight'] = totalPackagingWeight;
          result['packaging_volume'] = totalPackagingVolume;
        }
      }
      
      return {
        'number_of_packages': (result['number_of_packages'] as num?)?.toInt() ?? 1,
        'packaging_weight': (result['packaging_weight'] as num?)?.toDouble() ?? 0.0,
        'packaging_volume': (result['packaging_volume'] as num?)?.toDouble() ?? 0.0,
        'commercial_invoice_date': result['commercial_invoice_date'] != null
            ? (result['commercial_invoice_date'] is Timestamp 
                ? (result['commercial_invoice_date'] as Timestamp).toDate()
                : result['commercial_invoice_date'])
            : null,
        'origin_declaration': result['commercial_invoice_origin_declaration'] ?? result['origin_declaration'] ?? false,
        'cites': result['commercial_invoice_cites'] ?? result['cites'] ?? false,
        'export_reason': result['commercial_invoice_export_reason'] ?? result['export_reason'] ?? false,
        'export_reason_text': result['commercial_invoice_export_reason_text'] ?? result['export_reason_text'] ?? 'Ware',
        'incoterms': result['commercial_invoice_incoterms'] ?? result['incoterms'] ?? false,
        'selected_incoterms': List<String>.from(result['commercial_invoice_selected_incoterms'] ?? result['selected_incoterms'] ?? []),
        'incoterms_freetexts': Map<String, String>.from(result['commercial_invoice_incoterms_freetexts'] ?? result['incoterms_freetexts'] ?? {}),
        'delivery_date': result['commercial_invoice_delivery_date'] ?? result['delivery_date'] ?? false,
        'delivery_date_value': _parseDateTime(result['commercial_invoice_delivery_date_value'] ?? result['delivery_date_value']),
        'delivery_date_month_only': result['commercial_invoice_delivery_date_month_only'] ?? result['delivery_date_month_only'] ?? false,
        'carrier': result['commercial_invoice_carrier'] ?? result['carrier'] ?? false,
        'carrier_text': result['commercial_invoice_carrier_text'] ?? result['carrier_text'] ?? 'Swiss Post',
        'signature': result['commercial_invoice_signature'] ?? result['signature'] ?? false,
        'selected_signature': result['commercial_invoice_selected_signature'] ?? result['selected_signature'],
        'currency': result['commercial_invoice_currency'],
      };
    } catch (e) {
      print('Fehler beim Laden der Handelsrechnung-Einstellungen: $e');
      return _defaultCommercialInvoiceSettings();
    }
  }
  
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }
  
  Map<String, dynamic> _defaultCommercialInvoiceSettings() => {
    'number_of_packages': 1,
    'packaging_weight': 0.0,
    'packaging_volume': 0.0,
    'commercial_invoice_date': null,
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
      return _parseDateTime(data['commercial_invoice_date']);
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
      final doc = await _settingsRef.doc('packing_list_settings').get();
      if (!doc.exists) return {'packages': []};
      return doc.data() as Map<String, dynamic>? ?? {'packages': []};
    } catch (e) {
      print('Fehler beim Laden der Packlisten-Einstellungen: $e');
      return {'packages': []};
    }
  }
  
  @override
  Future<void> savePackingListSettings(Map<String, dynamic> settings) async {
    await _settingsRef.doc('packing_list_settings').set({
      ...settings,
      'timestamp': FieldValue.serverTimestamp(),
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
        'invoice_date': data['invoice_date'] != null
            ? (data['invoice_date'] as Timestamp).toDate()
            : null,
        'down_payment_amount': (data['down_payment_amount'] as num?)?.toDouble() ?? 0.0,
        'down_payment_reference': data['down_payment_reference'] ?? '',
        'down_payment_date': data['down_payment_date'] != null
            ? (data['down_payment_date'] as Timestamp).toDate()
            : null,
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
    'invoice_date': null,
    'down_payment_amount': 0.0,
    'down_payment_reference': '',
    'down_payment_date': null,
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
      return await AdditionalTextsManager.loadAdditionalTexts();
    } catch (e) {
      print('Fehler beim Laden der Zusatztexte: $e');
      return {};
    }
  }
  
  @override
  Future<void> saveAdditionalTexts(Map<String, dynamic> config) async {
    await AdditionalTextsManager.saveAdditionalTexts(config);
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // Feature-Flags
  // ═══════════════════════════════════════════════════════════════════
  
  @override
  bool get supportsCustomerAddressCompare => false;
}
