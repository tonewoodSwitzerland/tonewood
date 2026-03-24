// File: services/quote_doc_selection_manager.dart (Erweiterte Version)

/// Info, hier ist der Angeobtsbereich

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tonewood/quotes/quote_doc_selection_manager.dart';
import 'package:tonewood/quotes/quote_settings_dialog.dart';
import 'package:tonewood/services/pdf_generators/commercial_invoice_generator.dart';
import 'package:tonewood/services/pdf_generators/delivery_note_generator.dart';
import 'package:tonewood/services/pdf_generators/packing_list_generator.dart';
import 'package:tonewood/services/product_sorting_manager.dart';
import 'package:tonewood/services/swiss_rounding.dart';
import '../services/document_settings/commercial_invoice_settings_dialog.dart';
import '../services/document_settings/delivery_note_settings_dialog.dart';
import '../services/document_settings/invoice_settings_dialog.dart';
import '../services/document_settings/packing_list_settings_dialog.dart';
import '../services/document_settings/quote_settings_provider.dart';
import '../services/user_basket_service.dart';
import 'additional_text_manager.dart';
import '../services/countries.dart';
import '../services/pdf_generators/invoice_generator.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/services/pdf_services/preview_pdf_viewer_screen.dart';
import 'package:tonewood/quotes/shipping_costs_manager.dart';
import '../services/icon_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pdf_services/download_helper_mobile.dart';
import '../services/pdf_generators/quote_generator.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:intl/intl.dart';
// Am Anfang von quote_doc_selection_manager.dart:
import 'package:http/http.dart' as http;
import 'dart:convert';

class DocumentSelectionManager {
  // Dokumenttypen
  static const List<String> documentTypes = [
    'Offerte',
    'Rechnung',
    'Handelsrechnung',
    'Lieferschein',
    'Packliste',

  ];

  // Speichert die Auswahl in Firestore
  static Future<void> saveDocumentSelection(Map<String, bool> selection) async {
    try {
      await
          UserBasketService.temporaryDocumentSelection
          .doc('current_selection')
          .set({
        'selection': selection,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Dokumentenauswahl: $e');
    }
  }

  // Lädt die aktuelle Auswahl aus Firestore
  static Future<Map<String, bool>> loadDocumentSelection() async {
    try {
      final doc = await
          UserBasketService.temporaryDocumentSelection
          .doc('current_selection')
          .get();

      if (doc.exists && doc.data() != null && doc.data()!.containsKey('selection')) {
        return Map<String, bool>.from(doc.data()!['selection']);
      }
    } catch (e) {
      print('Fehler beim Laden der Dokumentenauswahl: $e');
    }

    // Standard-Werte, wenn nichts gefunden wurde
    return {
      'Offerte': false,
      'Rechnung': false,
      'Handelsrechnung': false,
      'Lieferschein': false,
      'Packliste': false,
    };
  }

  // Prüft, ob bereits eine Auswahl getroffen wurde
  static Future<bool> hasSelection() async {
    try {
      final doc =
         await UserBasketService.temporaryDocumentSelection
          .doc('current_selection')
          .get();

      return doc.exists;
    } catch (e) {
      print('Fehler beim Prüfen der Dokumentenauswahl: $e');
      return false;
    }
  }
// In DocumentSelectionManager hinzufügen:

  static Future<void> savePackingListSettings(List<Map<String, dynamic>> packages) async {
    try {
      // Erweitere die gespeicherten Daten um die standard_package_id
      final packagesWithStandardInfo = packages.map((package) {
        return {
          ...package,
          'standard_package_id': package['standard_package_id'],
        };
      }).toList();

      await
          UserBasketService.temporaryDocumentSettings
          .doc('packing_list_settings')
          .set({
        'packages': packagesWithStandardInfo,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Packliste-Einstellungen: $e');
    }
  }

  static Future<Map<String, dynamic>> loadPackingListSettings() async {
    try {
      final doc =
      await   UserBasketService.temporaryDocumentSettings
          .doc('packing_list_settings')
          .get();

      if (doc.exists) {
        return doc.data() ?? {};
      }

      return {};
    } catch (e) {
      print('Fehler beim Laden der Packliste-Einstellungen: $e');
      return {};
    }
  }


  static Future<void> saveTaraSettings(int numberOfPackages, double packagingWeight) async {
    try {
      await UserBasketService.temporaryDocumentSettings
          .doc('tara_settings')
          .set({
        'number_of_packages': numberOfPackages,
        'packaging_weight': packagingWeight,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Tara-Einstellungen: $e');
    }
  }

  static Future<Map<String, dynamic>> loadTaraSettings() async {
    try {
      // 1. Lade zuerst die gespeicherten Tara-Einstellungen
      final doc = await UserBasketService.temporaryDocumentSettings
          .doc('tara_settings')
          .get();

      Map<String, dynamic> taraSettings = {};
      bool shouldLoadFromPackingList = true;

      if (doc.exists && doc.data() != null) {
        taraSettings = doc.data()!;

        // Prüfe ob GÜLTIGE explizite Tara-Werte existieren (nicht 0)
        final hasValidPackages = taraSettings.containsKey('number_of_packages') &&
            (taraSettings['number_of_packages'] as num? ?? 0) > 0;
        final hasValidWeight = taraSettings.containsKey('packaging_weight') &&
            (taraSettings['packaging_weight'] as num? ?? 0) > 0;
        final hasValidVolume = taraSettings.containsKey('packaging_volume') &&
            (taraSettings['packaging_volume'] as num? ?? 0) > 0;

        // Nur wenn ALLE Werte gültig sind (> 0), nicht aus Packliste laden
        shouldLoadFromPackingList = !hasValidPackages || !hasValidWeight || !hasValidVolume;
      }

      // 2. Wenn keine gültigen Tara-Einstellungen existieren oder Werte 0 sind,
      //    nutze die Packlisten-Daten
      if (shouldLoadFromPackingList) {
        final packingListSettings = await loadPackingListSettings();
        final packages = packingListSettings['packages'] as List<dynamic>?;

        if (packages != null && packages.isNotEmpty) {
          double totalPackagingWeight = 0.0;
          double totalPackagingVolume = 0.0;

          // Berechne das Gesamtgewicht aller Verpackungen
          for (final package in packages) {
            final tareWeight = package['tare_weight'];
            if (tareWeight != null) {
              totalPackagingWeight += (tareWeight is num) ? tareWeight.toDouble() : 0.0;

              final width = (package['width'] as num?)?.toDouble() ?? 0.0;
              final height = (package['height'] as num?)?.toDouble() ?? 0.0;
              final length = (package['length'] as num?)?.toDouble() ?? 0.0;

              // cm³ zu m³: dividiere durch 1.000.000 (10^6)

              final volumeM3 = (width * height * length) / 1000000; // in m³
              totalPackagingVolume += volumeM3;




            }
          }

          // Überschreibe nur number_of_packages und packaging_weight
          taraSettings['number_of_packages'] = packages.length;
          taraSettings['packaging_weight'] = totalPackagingWeight;
          taraSettings['packaging_volume'] = totalPackagingVolume;
          print('Verwende Packlisten-Daten: ${packages.length} Pakete, ${totalPackagingWeight.toStringAsFixed(2)} kg');
        } else {
          // Fallback wenn weder Tara-Settings noch Packliste existieren
          taraSettings['number_of_packages'] = taraSettings['number_of_packages'] ?? 1;
          taraSettings['packaging_weight'] = taraSettings['packaging_weight'] ?? 0.0;
          taraSettings['packaging_volume'] = taraSettings['packaging_volume'] ?? 0.0;

        }
      }

      // 3. Stelle sicher, dass alle Werte als richtige Typen vorliegen
      return {
        'number_of_packages': (taraSettings['number_of_packages'] ?? 1) as int,
        'packaging_weight': ((taraSettings['packaging_weight'] ?? 0.0) as num).toDouble(),
        'packaging_volume': ((taraSettings['packaging_volume'] ?? 0.0) as num).toDouble(),


        // Alle anderen Einstellungen beibehalten
        'commercial_invoice_origin_declaration': taraSettings['commercial_invoice_origin_declaration'] ?? false,
        'commercial_invoice_cites': taraSettings['commercial_invoice_cites'] ?? false,
        'commercial_invoice_export_reason': taraSettings['commercial_invoice_export_reason'] ?? false,
        'commercial_invoice_export_reason_text': taraSettings['commercial_invoice_export_reason_text'] ?? 'Ware',
        'commercial_invoice_incoterms': taraSettings['commercial_invoice_incoterms'] ?? false,
        'commercial_invoice_selected_incoterms': List<String>.from(taraSettings['commercial_invoice_selected_incoterms'] ?? []),
        'commercial_invoice_incoterms_freetexts': Map<String, String>.from(taraSettings['commercial_invoice_incoterms_freetexts'] ?? {}),
        'commercial_invoice_delivery_date': taraSettings['commercial_invoice_delivery_date'] ?? false,
        'commercial_invoice_delivery_date_value': taraSettings['commercial_invoice_delivery_date_value'],
        'commercial_invoice_delivery_date_month_only': taraSettings['commercial_invoice_delivery_date_month_only'] ?? false,
        'commercial_invoice_carrier': taraSettings['commercial_invoice_carrier'] ?? false,
        'commercial_invoice_carrier_text': taraSettings['commercial_invoice_carrier_text'] ?? 'Swiss Post',
        'commercial_invoice_signature': taraSettings['commercial_invoice_signature'] ?? false,
        'commercial_invoice_selected_signature': taraSettings['commercial_invoice_selected_signature'],
        'commercial_invoice_date': taraSettings['commercial_invoice_date'],
        'commercial_invoice_currency': taraSettings['commercial_invoice_currency'],
        'use_commercial_date_as_delivery_date': taraSettings['use_commercial_date_as_delivery_date'] ?? true, // NEU

      };

    } catch (e) {
      print('Fehler beim Laden der Tara-Einstellungen: $e');
      return {
        'number_of_packages': 1,
        'packaging_weight': 0.0,
        'packaging_volume': 0.0,
      };
    }
  }



  // Löscht die aktuelle Auswahl
// Löscht die aktuelle Auswahl
  static Future<void> clearSelection() async {
    try {
      // 1. Lösche die Dokumentauswahl
      await UserBasketService.temporaryDocumentSelection
          .doc('current_selection')
          .delete();

      // 2. Lösche ALLE Dokument-Einstellungen
      final settingsCollection = UserBasketService.temporaryDocumentSettings;

      // Hole alle Dokumente in der Collection
      final snapshot = await settingsCollection.get();

      // Lösche jedes Dokument einzeln
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        print('Gelöscht: ${doc.id}'); // Debug-Ausgabe
      }

      print('Dokumentauswahl und alle Einstellungen zurückgesetzt');
    } catch (e) {
      print('Fehler beim Löschen der Dokumentenauswahl: $e');
    }
  }

  // Neue Methode in DocumentSelectionManager hinzufügen
  static Future<Map<String, dynamic>> _calculateDiscountsForPreview(List<Map<String, dynamic>> basketItems) async {
    try {
      double itemDiscounts = 0.0;
      double totalDiscountAmount = 0.0;

      // Berechne Item-Rabatte direkt aus den basketItems
      for (final item in basketItems) {
        final isGratisartikel = item['is_gratisartikel'] == true;

        // Überspringe Gratisartikel bei der Rabattberechnung
        if (isGratisartikel) continue;

        final customPriceValue = item['custom_price_per_unit'];
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue as num).toDouble()
            : (item['price_per_unit'] as num).toDouble();

        final quantity = item['quantity'];
        final quantityDouble = quantity is int ? quantity.toDouble() : quantity as double;
        final itemSubtotal = quantityDouble * pricePerUnit;

        // Rabatt ist direkt im Item gespeichert
        final discount = item['discount'] as Map<String, dynamic>?;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();
          final discountAmount = (itemSubtotal * (percentage / 100)) + absolute;
          itemDiscounts += discountAmount;
        }
      }

      // Lade Gesamtrabatt aus temporary_discounts/total_discount
      final totalDiscountDoc = await  UserBasketService.temporaryDiscounts
          .doc('total_discount')
          .get();

      if (totalDiscountDoc.exists) {
        final totalDiscountData = totalDiscountDoc.data()!;
        final totalPercentage = (totalDiscountData['percentage'] as num? ?? 0).toDouble();
        final totalAbsolute = (totalDiscountData['absolute'] as num? ?? 0).toDouble();

        // Berechne Subtotal nach Item-Rabatten (ohne Gratisartikel)
        final subtotal = basketItems.fold<double>(0.0, (sum, item) {
          final isGratisartikel = item['is_gratisartikel'] == true;
          if (isGratisartikel) return sum; // Überspringe Gratisartikel

          final customPriceValue = item['custom_price_per_unit'];
          final pricePerUnit = customPriceValue != null
              ? (customPriceValue as num).toDouble()
              : (item['price_per_unit'] as num).toDouble();
          final qty = item['quantity'];
          final qtyDouble = qty is int ? qty.toDouble() : qty as double;
          return sum + (qtyDouble * pricePerUnit);
        });

        final subtotalAfterItemDiscounts = subtotal - itemDiscounts;
        totalDiscountAmount = (subtotalAfterItemDiscounts * (totalPercentage / 100)) + totalAbsolute;
      }

      return {
        'item_discounts': itemDiscounts,
        'total_discount_amount': totalDiscountAmount,
      };
    } catch (e) {
      print('Fehler beim Berechnen der Rabatte: $e');
      return {
        'item_discounts': 0.0,
        'total_discount_amount': 0.0,
      };
    }
  }

  // ===== DOCUMENT_SELECTION_MANAGER ANPASSUNGEN =====

// Erweitere die saveDeliveryNoteSettings Methode:
  static Future<void> saveDeliveryNoteSettings(
      DateTime? deliveryDate,
      DateTime? paymentDate, {
        bool useAsCommercialInvoiceDate = false,
        bool preservePaymentDate = false, // NEU
      }) async {
    final Map<String, dynamic> data = {
      'timestamp': FieldValue.serverTimestamp(),
      'use_as_commercial_invoice_date': useAsCommercialInvoiceDate,
    };

    if (deliveryDate != null) {
      data['delivery_date'] = Timestamp.fromDate(deliveryDate);
    } else if (!preservePaymentDate) {
      data['delivery_date'] = null;
    }

    if (!preservePaymentDate) {
      if (paymentDate != null) {
        data['payment_date'] = Timestamp.fromDate(paymentDate);
      } else {
        data['payment_date'] = null;
      }
    }

    if (preservePaymentDate) {
      // Nur delivery_date updaten, payment_date beibehalten
      await UserBasketService.temporaryDocumentSettings
          .doc('delivery_note_settings')
          .update({'delivery_date': data['delivery_date']});
    } else {
      await UserBasketService.temporaryDocumentSettings
          .doc('delivery_note_settings')
          .set(data);
    }
  }

// Erweitere loadDeliveryNoteSettings:
  static Future<Map<String, dynamic>> loadDeliveryNoteSettings() async {
    final doc = await UserBasketService.temporaryDocumentSettings
        .doc('delivery_note_settings')
        .get();

    if (!doc.exists) return {};

    final data = doc.data()!;
    return {
      'delivery_date': data['delivery_date'] != null
          ? (data['delivery_date'] as Timestamp).toDate()
          : null,
      'payment_date': data['payment_date'] != null
          ? (data['payment_date'] as Timestamp).toDate()
          : null,
      'use_as_commercial_invoice_date': data['use_as_commercial_invoice_date'] ?? false,
    };
  }

  // In quote_doc_selection_manager.dart, nach den anderen save-Methoden hinzufügen:
  static Future<void> saveInvoiceSettings(Map<String, dynamic> settings) async {
    try {
      await UserBasketService.temporaryDocumentSettings
          .doc('invoice_settings')
          .set({
        'invoice_date': settings['invoice_date'], // <-- NEU!
        'down_payment_amount': settings['down_payment_amount'] ?? 0.0,
        'down_payment_reference': settings['down_payment_reference'] ?? '',
        'down_payment_date': settings['down_payment_date'],
        'show_dimensions': settings['show_dimensions'] ?? false,
        'is_full_payment': settings['is_full_payment'] ?? false,
        'payment_method': settings['payment_method'] ?? 'BAR',
        'custom_payment_method': settings['custom_payment_method'] ?? '',
        'payment_term_days': settings['payment_term_days'] ?? 30,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Rechnungs-Einstellungen: $e');
    }
  }

  static Future<Map<String, dynamic>> loadInvoiceSettings() async {
    try {
      final doc = await  UserBasketService.temporaryDocumentSettings
          .doc('invoice_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'invoice_date': data['invoice_date'] != null  // <-- NEU!
              ? (data['invoice_date'] as Timestamp).toDate()
              : null,
          'down_payment_amount': data['down_payment_amount'] ?? 0.0,
          'down_payment_reference': data['down_payment_reference'] ?? '',
          'down_payment_date': data['down_payment_date'] != null
              ? (data['down_payment_date'] as Timestamp).toDate()
              : null,
          'show_dimensions': data['show_dimensions'] ?? false,
          'is_full_payment': data['is_full_payment'] ?? false,
          'payment_method': data['payment_method'] ?? 'BAR',
          'custom_payment_method': data['custom_payment_method'] ?? '',
          'payment_term_days': data['payment_term_days'] ?? 30,
        };
      }
    } catch (e) {
      print('Fehler beim Laden der Rechnungs-Einstellungen: $e');
    }

    return {
      'invoice_date': null, // <-- NEU!
      'down_payment_amount': 0.0,
      'down_payment_reference': '',
      'down_payment_date': null,
      'show_dimensions': false,
      'is_full_payment': false,
      'payment_method': 'BAR',
      'custom_payment_method': '',
      'payment_term_days': 30,
    };
  }
// Nach saveInvoiceSettings() hinzufügen:

  static Future<void> saveQuoteSettings(Map<String, dynamic> settings) async {
    try {
      await UserBasketService.temporaryDocumentSettings
          .doc('quote_settings')
          .set({
        'validity_date': settings['validity_date'],
        'show_dimensions': settings['show_dimensions'],
        'show_validity_addition': settings['show_validity_addition'],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Offerten-Einstellungen: $e');
    }
  }

  static Future<Map<String, dynamic>> loadQuoteSettings() async {
    try {
      final doc = await
          UserBasketService.temporaryDocumentSettings
          .doc('quote_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'validity_date': data['validity_date'] != null
              ? (data['validity_date'] as Timestamp).toDate()
              : null,
          'show_dimensions': data['show_dimensions'] ?? false,
          'show_validity_addition': data['show_validity_addition'] ?? false,
        };
      }
    } catch (e) {
      print('Fehler beim Laden der Offerten-Einstellungen: $e');
    }

    return {
      'validity_date': null,
    };
  }




  static Future<void> _showCommercialInvoicePreview(BuildContext context, Map<String, dynamic> data, {String? language, Map<String, dynamic>? taraSettingsOverride, String suffix = 'PREVIEW'}) async {
    try {
      String currency;
      final customerData = data['customer'] as Map<String, dynamic>;
      final documentLanguage = language ?? customerData['language'] ?? 'DE';
      final shippingCosts = await ShippingCostsManager.loadShippingCosts();

      // NEU: Verwende den Override (bei Einzelversand) oder lade regulär
      final taraSettings = taraSettingsOverride ?? await loadTaraSettings();

      if (taraSettings['packaging_weight'] != null) {
        taraSettings['packaging_weight'] = (taraSettings['packaging_weight'] as num).toDouble();
      }

      DateTime? invoiceDate;
      if (taraSettings['commercial_invoice_date'] != null) {
        final timestamp = taraSettings['commercial_invoice_date'];
        if (timestamp is Timestamp) {
          invoiceDate = timestamp.toDate();
        }
      }

      final basketItems = data['basketItems'] as List<Map<String, dynamic>>;
      final calculations = await _calculateDiscountsForPreview(basketItems);
      final taxOption = data['taxOption'] ?? 0;
      final vatRate = data['vatRate'] ?? 8.1;

      final items = basketItems.map((basketItem) {
        final customPriceValue = basketItem['custom_price_per_unit'];
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue is int ? customPriceValue.toDouble() : (customPriceValue as num).toDouble())
            : (basketItem['price_per_unit'] is int
            ? (basketItem['price_per_unit'] as int).toDouble()
            : (basketItem['price_per_unit'] as num).toDouble());

        final quantity = (basketItem['quantity'] as num).toDouble();
        final itemSubtotal = quantity * pricePerUnit;
        final discount = basketItem['discount'] as Map<String, dynamic>? ?? {'percentage': 0.0, 'absolute': 0.0};

        double discountAmount = 0.0;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();
          discountAmount = (itemSubtotal * (percentage / 100)) + absolute;
        }

        final Map<String, dynamic> newItem = Map<String, dynamic>.from(basketItem);
        newItem['price_per_unit'] = pricePerUnit;
        newItem['quantity'] = quantity;
        newItem['discount'] = discount;
        newItem['discount_amount'] = discountAmount;
        newItem['total'] = itemSubtotal - discountAmount;

        if (newItem['weight'] != null) newItem['weight'] = (newItem['weight'] as num).toDouble();
        if (newItem['volume'] != null) newItem['volume'] = (newItem['volume'] as num).toDouble();
        if (newItem['custom_length'] != null) newItem['custom_length'] = (newItem['custom_length'] as num).toDouble();
        if (newItem['custom_width'] != null) newItem['custom_width'] = (newItem['custom_width'] as num).toDouble();
        if (newItem['custom_thickness'] != null) newItem['custom_thickness'] = (newItem['custom_thickness'] as num).toDouble();

        return newItem;
      }).toList();

      if (taraSettings['commercial_invoice_currency'] != null){
        currency = taraSettings['commercial_invoice_currency'] as String;
      } else {
        final currencySettings = await loadCurrencySettings();
        currency = currencySettings['currency'] as String;
      }

      final exchangeRates = await _fetchCurrentExchangeRates();
      final costCenter = data['costCenter'];
      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';

      final pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
        invoiceDate: invoiceDate,
        items: items,
        customerData: data['customer'],
        fairData: data['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: documentLanguage,
        invoiceNumber: suffix == 'PREVIEW' ? 'PREVIEW' : 'PREVIEW $suffix',
        shippingCosts: shippingCosts,
        calculations: calculations,
        taxOption: taxOption,
        vatRate: vatRate,
        taraSettings: taraSettings,
      );

      if (context.mounted) {
        Navigator.pop(context);
        final fileName = suffix == 'PREVIEW' ? 'Handelsrechnung_Preview.pdf' : 'Handelsrechnung_Preview_$suffix.pdf';
        _openPdfViewer(context, pdfBytes, fileName);
      }
    } catch (e) {
      print('Fehler bei Handelsrechnung-Preview: $e');
      rethrow;
    }
  }

  static Future<void> _showDeliveryNotePreview(BuildContext context, Map<String, dynamic> data, {String? language, String suffix = 'PREVIEW'}) async {
    try {
      final customerData = data['customer'] as Map<String, dynamic>;
      final documentLanguage = language ?? customerData['language'] ?? 'DE';

      final deliveryNoteSettings = await loadDeliveryNoteSettings();
      final taraSettings = await loadTaraSettings();

      DateTime? effectiveDeliveryDate = deliveryNoteSettings['delivery_date'];
      if (taraSettings['use_commercial_date_as_delivery_date'] == true &&
          taraSettings['commercial_invoice_date'] != null) {
        final timestamp = taraSettings['commercial_invoice_date'];
        if (timestamp is Timestamp) {
          effectiveDeliveryDate = timestamp.toDate();
        }
      }

      final basketItems = data['basketItems'] as List<Map<String, dynamic>>;
      final items = basketItems.map((basketItem) {
        final customPriceValue = basketItem['custom_price_per_unit'];
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue as num).toDouble()
            : (basketItem['price_per_unit'] as num).toDouble();

        return {
          ...basketItem,
          'price_per_unit': pricePerUnit,
        };
      }).toList();

      final currencySettings = await loadCurrencySettings();
      final currency = currencySettings['currency'] as String;
      final exchangeRates = await _fetchCurrentExchangeRates();
      final costCenter = data['costCenter'];
      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';

      final pdfBytes = await DeliveryNoteGenerator.generateDeliveryNotePdf(
        items: items,
        customerData: data['customer'],
        fairData: data['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: documentLanguage,
        deliveryNoteNumber: suffix == 'PREVIEW' ? 'PREVIEW' : 'PREVIEW $suffix',
        deliveryDate: effectiveDeliveryDate,
        paymentDate: deliveryNoteSettings['payment_date'],
      );

      if (context.mounted) {
        Navigator.pop(context);
        final fileName = suffix == 'PREVIEW' ? 'Lieferschein_Preview.pdf' : 'Lieferschein_Preview_$suffix.pdf';
        _openPdfViewer(context, pdfBytes, fileName);
      }
    } catch (e) {
      print('Fehler bei Lieferschein-Preview: $e');
      rethrow;
    }
  }

  static Future<void> showDocumentPreview(BuildContext context, String documentType, {String? language}) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final previewData = await _loadPreviewData(context);

      if (context.mounted) {
        Navigator.pop(context);
      }

      if (previewData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nicht genügend Daten für Preview verfügbar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 🚀 NEU: DIE EINZELVERSAND-WEICHE FÜR ANGEBOTE
      if (documentType == 'Handelsrechnung' || documentType == 'Lieferschein') {
        final packingListSettings = await loadPackingListSettings();
        final shipmentMode = packingListSettings['shipment_mode'] as String? ?? 'total';

        if (shipmentMode == 'per_shipment') {
          await _showShipmentGroupPreviewSelector(
            context: context,
            documentType: documentType,
            previewData: previewData,
            packingListSettings: packingListSettings,
            language: language,
          );
          return;
        }
      }

      switch (documentType) {
        case 'Offerte':
          await _showQuotePreview(context, previewData, language: language);
          break;
        case 'Rechnung':
          await _showInvoicePreview(context, previewData, language: language);
          break;
        case 'Handelsrechnung':
          await _showCommercialInvoicePreview(context, previewData, language: language);
          break;
        case 'Lieferschein':
          await _showDeliveryNotePreview(context, previewData, language: language);
          break;
        case 'Packliste':
          await _showPackingListPreview(context, previewData, language: language);
          break;
        default:
          _showNotImplementedMessage(context, documentType);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei der Preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
// =========================================================================
  // EINZELVERSAND PREVIEW MANAGER LOGIK FÜR ANGEBOTE
  // =========================================================================

  static Future<void> _showShipmentGroupPreviewSelector({
    required BuildContext context,
    required String documentType,
    required Map<String, dynamic> previewData,
    required Map<String, dynamic> packingListSettings,
    String? language,
  }) async {
    final rawPackages = packingListSettings['packages'] as List<dynamic>? ?? [];
    if (rawPackages.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Packstücke konfiguriert'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final packages = rawPackages.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    final Map<int, List<Map<String, dynamic>>> shipmentGroups = {};
    for (int i = 0; i < packages.length; i++) {
      final group = (packages[i]['shipment_group'] as num?)?.toInt() ?? (i + 1);
      shipmentGroups.putIfAbsent(group, () => []);
      shipmentGroups[group]!.add(packages[i]);
    }

    final sortedGroupNumbers = shipmentGroups.keys.toList()..sort();
    final isCommercialInvoice = documentType == 'Handelsrechnung';
    final docLabel = isCommercialInvoice ? 'Handelsrechnung' : 'Lieferschein';
    final outerContext = context;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'mail', defaultIcon: Icons.mail, color: Theme.of(sheetContext).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$docLabel Preview', style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Einzelversand: ${sortedGroupNumbers.length} Sendungen', style: TextStyle(fontSize: 12, color: Theme.of(sheetContext).colorScheme.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(sheetContext), icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              itemCount: sortedGroupNumbers.length,
              itemBuilder: (context, index) {
                final groupNumber = sortedGroupNumbers[index];
                final groupPackages = shipmentGroups[groupNumber]!;
                final displayNumber = index + 1;

                int itemCount = 0;
                for (final pkg in groupPackages) {
                  final items = pkg['items'] as List<dynamic>? ?? [];
                  itemCount += items.length;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.15), shape: BoxShape.circle),
                      child: Center(child: Text('$displayNumber', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))),
                    ),
                    title: Text('$docLabel Sendung $displayNumber'),
                    subtitle: Text('${groupPackages.length} Paket${groupPackages.length > 1 ? 'e' : ''} • $itemCount Produkt${itemCount > 1 ? 'e' : ''}', style: const TextStyle(fontSize: 12)),
                    trailing: getAdaptiveIcon(iconName: 'chevron_right', defaultIcon: Icons.chevron_right),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _showShipmentGroupPreview(
                        context: outerContext,
                        documentType: documentType,
                        previewData: previewData,
                        groupPackages: groupPackages,
                        displayNumber: displayNumber,
                        language: language,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showShipmentGroupPreview({
    required BuildContext context,
    required String documentType,
    required Map<String, dynamic> previewData,
    required List<Map<String, dynamic>> groupPackages,
    required int displayNumber,
    String? language,
  }) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    final allBasketItems = previewData['basketItems'] as List<Map<String, dynamic>>;
    final Map<String, Map<String, dynamic>> mergedItems = {};

    for (final package in groupPackages) {
      final packageItemsList = package['items'] as List<dynamic>? ?? [];
      for (final pkgItem in packageItemsList) {
        final pkgItemMap = Map<String, dynamic>.from(pkgItem as Map);
        final pkgItemKey = pkgItemMap['basket_doc_id']?.toString() ?? '';
        final packageQuantity = (pkgItemMap['quantity'] as num?)?.toDouble() ?? 0.0;

        if (packageQuantity <= 0) continue;

        final originalItem = allBasketItems.firstWhere(
              (item) => (item['doc_id']?.toString() ?? '') == pkgItemKey,
          orElse: () => <String, dynamic>{},
        );

        if (originalItem.isEmpty) continue;

        if (mergedItems.containsKey(pkgItemKey)) {
          mergedItems[pkgItemKey]!['quantity'] += packageQuantity;
        } else {
          final itemCopy = Map<String, dynamic>.from(originalItem);
          itemCopy['quantity'] = packageQuantity;
          mergedItems[pkgItemKey] = itemCopy;
        }
      }
    }

    final groupData = Map<String, dynamic>.from(previewData);
    groupData['basketItems'] = mergedItems.values.toList(); // Die gefilterten Items!

    if (context.mounted) Navigator.pop(context); // Lader schließen

    if (documentType == 'Handelsrechnung') {
      double totalTareWeight = 0.0;
      double totalVolume = 0.0;
      for (final package in groupPackages) {
        totalTareWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
        final width = (package['width'] as num?)?.toDouble() ?? 0.0;
        final height = (package['height'] as num?)?.toDouble() ?? 0.0;
        final length = (package['length'] as num?)?.toDouble() ?? 0.0;
        totalVolume += (width * height * length) / 1000000;
      }

      final baseTara = await loadTaraSettings();
      baseTara['number_of_packages'] = groupPackages.length;
      baseTara['packaging_weight'] = totalTareWeight;
      baseTara['packaging_volume'] = totalVolume;

      await _showCommercialInvoicePreview(context, groupData, language: language, taraSettingsOverride: baseTara, suffix: 'Sendung_$displayNumber');
    } else {
      await _showDeliveryNotePreview(context, groupData, language: language, suffix: 'Sendung_$displayNumber');
    }
  }

  // Ersetze die _showPackingListPreview Methode mit dieser Version:

  static Future<void> _showPackingListPreview(BuildContext context, Map<String, dynamic> data, {String? language}) async {
    try {
      print('=== START PACKLISTE PREVIEW DEBUG ===');
      print('Received data: ${data.keys}');

      // Customer Data Debug
      final customerData = data['customer'] as Map<String, dynamic>;
      print('Customer data keys: ${customerData.keys}');
      print('Customer language: ${customerData['language']}');

      final documentLanguage = language ?? customerData['language'] ?? 'DE';
      print('Document language: $documentLanguage');

      // Cost Center Debug
      final costCenter = data['costCenter'];
      print('Cost center data: $costCenter');

      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';
      print('Cost center code: $costCenterCode');

      // Fair Data Debug
      final fairData = data['fair'];
      print('Fair data: $fairData');

      // Lade Packlisten-Einstellungen für Debug
      final packingListSettings = await DocumentSelectionManager.loadPackingListSettings();
      print('Packing list settings: ${packingListSettings.keys}');
      print('Packages: ${packingListSettings['packages']}');

      // Generiere PDF mit detailliertem Error Handling
      print('Calling PackingListGenerator.generatePackingListPdf...');

      final pdfBytes = await PackingListGenerator.generatePackingListPdf(
        language: documentLanguage,
        packingListNumber: 'PREVIEW',
        customerData: customerData,
        fairData: fairData,
        costCenterCode: costCenterCode,
      );

      print('PDF bytes generated successfully: ${pdfBytes.length} bytes');

      if (context.mounted) {
        Navigator.pop(context);
        _openPdfViewer(context, pdfBytes, 'Packliste_Preview.pdf');
      }
    } catch (e, stackTrace) {
      print('=== FEHLER BEI PACKLISTE-PREVIEW ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('=== END ERROR ===');
      rethrow;
    }
  }
  // Lade Preview-Daten
  static Future<Map<String, dynamic>?> _loadPreviewData(BuildContext context) async {
    try {
      // Kunde laden
      final customerSnapshot = await
          UserBasketService.temporaryCustomer
          .limit(1)
          .get();

      if (customerSnapshot.docs.isEmpty) {
        return null;
      }

      // Kostenstelle laden
      final costCenterSnapshot = await
      UserBasketService.temporaryCostCenter
          .limit(1)
          .get();

      // Warenkorb laden
      final basketSnapshot = await
          UserBasketService.temporaryBasket
          .get();

      if (basketSnapshot.docs.isEmpty) {
        return null;
      }

      // Messe laden (optional)
      final fairSnapshot = await
      UserBasketService.temporaryFair
          .limit(1)
          .get();

      // NEU: Lade Steuereinstellungen
      final taxDoc = await
      UserBasketService.temporaryTax
          .doc('current_tax')
          .get();

      int taxOption = 1; // Standard als Fallback
      double vatRate = 8.1; // Standard MwSt-Satz

      if (taxDoc.exists) {
        final taxData = taxDoc.data()!;
        taxOption = taxData['tax_option'] ?? 1;
        vatRate = (taxData['vat_rate'] as num?)?.toDouble() ?? 8.1;
      }

      return {
        'customer': customerSnapshot.docs.first.data(),
        'costCenter': costCenterSnapshot.docs.isNotEmpty
            ? costCenterSnapshot.docs.first.data()
            : null,
        'basketItems': basketSnapshot.docs.map((doc) => {
          ...doc.data(),
          'doc_id': doc.id,
        }).toList(),
        'fair': fairSnapshot.docs.isNotEmpty
            ? fairSnapshot.docs.first.data()
            : null,
        // NEU: Steuereinstellungen hinzufügen
        'taxOption': taxOption,
        'vatRate': vatRate,
      };









    } catch (e) {
      print('Fehler beim Laden der Preview-Daten: $e');
      return null;
    }
  }

  // Zeige Offerte-Preview
// Zeige Offerte-Preview


// NEUE VERSION - Ersetze mit:
  static Future<Map<String, double>> _fetchCurrentExchangeRates() async {
    try {
      // Lade die gespeicherten Wechselkurse aus Firebase
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('currency_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        if (data.containsKey('exchange_rates')) {
          final rates = data['exchange_rates'] as Map<String, dynamic>;

          print('Wechselkurse aus Firebase geladen');
          print('EUR: ${rates['EUR']}, USD: ${rates['USD']}');

          return {
            'CHF': 1.0,
            'EUR': (rates['EUR'] as num).toDouble(),
            'USD': (rates['USD'] as num).toDouble(),
          };
        }
      }

      // Fallback zu Standard-Werten wenn nichts in Firebase
      print('Keine Wechselkurse in Firebase gefunden, verwende Standard-Werte');
      return {'CHF': 1.0, 'EUR': 0.96, 'USD': 1.08};

    } catch (e) {
      print('Fehler beim Laden der Wechselkurse aus Firebase: $e');
      // Fallback zu Standard-Werten
      return {'CHF': 1.0, 'EUR': 0.96, 'USD': 1.08};
    }
  }

  static Future<void> _showQuotePreview(BuildContext context, Map<String, dynamic> data, {String? language}) async {
    try {
      print('=== START _showQuotePreview DEBUG ===');
      print('Received data keys: ${data.keys}');
      print('Language parameter: $language');

      // Customer Data Debug
      final customerData = data['customer'] as Map<String, dynamic>;
      print('Customer data type: ${customerData.runtimeType}');
      print('Customer data keys: ${customerData.keys}');
      print('Customer language field: ${customerData['language']}');
      print('Customer language type: ${customerData['language']?.runtimeType}');

      final documentLanguage = language ?? customerData['language'] ?? 'DE';
      print('Final document language: $documentLanguage');

      // Shipping Costs Debug
      print('Loading shipping costs...');
      final shippingCosts = await ShippingCostsManager.loadShippingCosts();
      print('Shipping costs loaded: ${shippingCosts.keys}');

      // Tax Settings Debug
      final taxOption = data['taxOption'] ?? 1;
      final vatRate = data['vatRate'] ?? 8.1;
      print('Tax option: $taxOption, VAT rate: $vatRate');

      // Basket Items Debug
      final basketItems = data['basketItems'] as List<Map<String, dynamic>>;
      print('Number of basket items: ${basketItems.length}');

      // Quote Settings Debug
      print('Loading quote settings...');
      final quoteSettings = await DocumentSelectionManager.loadQuoteSettings();
      print('Quote settings: $quoteSettings');

      // Calculations Debug
      print('Calculating discounts...');
      final calculations = await _calculateDiscountsForPreview(basketItems);
      print('Calculations result: $calculations');

      // Items Processing Debug
      print('Processing items...');
      final items = basketItems.map((basketItem) {
        print('  Processing item: ${basketItem['product_name']}');

        final customPriceValue = basketItem['custom_price_per_unit'];
        print('    Custom price value: $customPriceValue');

        final pricePerUnit = customPriceValue != null
            ? (customPriceValue as num).toDouble()
            : (basketItem['price_per_unit'] as num).toDouble();
        print('    Price per unit: $pricePerUnit');

        final quantity = (basketItem['quantity'] as num).toDouble();
        print('    Quantity: $quantity');

        final itemSubtotal = quantity * pricePerUnit;
        print('    Item subtotal: $itemSubtotal');

        final discount = basketItem['discount'] as Map<String, dynamic>? ?? {'percentage': 0.0, 'absolute': 0.0};
        print('    Discount: $discount');

        double discountAmount = 0.0;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();
          discountAmount = (itemSubtotal * (percentage / 100)) + absolute;
        }
        print('    Discount amount: $discountAmount');

        return {
          ...basketItem,
          'price_per_unit': pricePerUnit,
          'discount': discount,
          'discount_amount': discountAmount,
          'total': itemSubtotal - discountAmount,
        };
      }).toList();
      print('Items processed successfully');

      // Currency Settings Debug
      print('Loading currency settings...');
      final currencySettings = await loadCurrencySettings();
      print('Currency settings: $currencySettings');

      final currency = currencySettings['currency'] as String;
      print('Currency: $currency');

      // Exchange Rates Debug
      print('Fetching exchange rates...');
      final exchangeRates = await _fetchCurrentExchangeRates();
      print('Exchange rates: $exchangeRates');
// NEU: Lade Rundungseinstellungen
      print('Loading rounding settings...');
      final roundingSettings = await SwissRounding.loadRoundingSettings();
      print('Rounding settings: $roundingSettings');
      // Cost Center Debug
      final costCenter = data['costCenter'];
      print('Cost center data: $costCenter');
      print('Cost center type: ${costCenter?.runtimeType}');

      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';
      print('Cost center code: $costCenterCode');
      print('Cost center code type: ${costCenterCode.runtimeType}');

      // Fair Data Debug
      print('Fair data: ${data['fair']}');
      print('Fair data type: ${data['fair']?.runtimeType}');

      // Final Debug before PDF generation
      print('=== CALLING QuoteGenerator.generateQuotePdf ===');
      print('items: ${items.length} items');
      print('customerData: ${customerData.keys}');
      print('fairData: ${data['fair']}');
      print('costCenterCode: $costCenterCode (type: ${costCenterCode.runtimeType})');
      print('currency: $currency');
      print('exchangeRates: $exchangeRates');
      print('language: $documentLanguage');
      print('quoteNumber: PREVIEW');
      print('shippingCosts: ${shippingCosts.keys}');
      print('calculations: $calculations');
      print('taxOption: $taxOption');
      print('vatRate: $vatRate');
      print('validityDate: ${quoteSettings['validity_date']}');

      final pdfBytes = await QuoteGenerator.generateQuotePdf(
        roundingSettings: roundingSettings,
        items: items,
        customerData: data['customer'],
        fairData: data['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: documentLanguage,
        quoteNumber: 'PREVIEW',
        shippingCosts: shippingCosts,
        calculations: calculations,
        taxOption: taxOption,
        vatRate: vatRate,
        validityDate: quoteSettings['validity_date'],
      );

      print('PDF generated successfully');

      if (context.mounted) {
        Navigator.pop(context);
        _openPdfViewer(context, pdfBytes, 'Offerte_Preview.pdf');
      }

      print('=== END _showQuotePreview DEBUG ===');
    } catch (e, stackTrace) {
      print('=== ERROR in _showQuotePreview ===');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('=== END ERROR ===');
      rethrow;
    }
  }
// Neue Methode hinzufügen
  static Future<void> _showInvoicePreview(BuildContext context, Map<String, dynamic> data, {String? language}) async {
    try {
      final customerData = data['customer'] as Map<String, dynamic>;
      final documentLanguage = language ?? customerData['language'] ?? 'DE';
      final shippingCosts = await ShippingCostsManager.loadShippingCosts();
      final taxOption = data['taxOption'] ?? 0;
      final vatRate = data['vatRate'] ?? 8.1;
      final basketItems = data['basketItems'] as List<Map<String, dynamic>>;
      final invoiceSettings = await loadInvoiceSettings();
      final roundingSettings = await SwissRounding.loadRoundingSettings();

      // Berechne Rabatte für Preview
      final calculations = await _calculateDiscountsForPreview(basketItems);

      final items = basketItems.map((basketItem) {
        final customPriceValue = basketItem['custom_price_per_unit'];
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue as num).toDouble()
            : (basketItem['price_per_unit'] as num).toDouble();

        return {
          ...basketItem,
          'price_per_unit': pricePerUnit,
        };
      }).toList();
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();

      // NEU: Hole paymentTermDays aus den Invoice Settings
      final paymentTermDays = invoiceSettings['payment_term_days'] ?? 30;

      final currencySettings = await loadCurrencySettings();
      final currency = currencySettings['currency'] as String;
      // Konvertiere die exchange rates korrekt
      final exchangeRatesRaw = currencySettings['exchangeRates'] as Map<String, dynamic>;
      final exchangeRates = <String, double>{};

      exchangeRatesRaw.forEach((key, value) {
        exchangeRates[key] = (value as num).toDouble();
      });



      final costCenter = data['costCenter'];
      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';

      final pdfBytes = await InvoiceGenerator.generateInvoicePdf(
        downPaymentSettings: invoiceSettings,
        items: items,
        customerData: data['customer'],
        fairData: data['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: documentLanguage,
        invoiceNumber: 'PREVIEW',
        shippingCosts: shippingCosts,
        calculations: calculations, // <-- Jetzt mit echten Rabatten
        paymentTermDays: paymentTermDays,
        taxOption: taxOption,  // NEU (falls InvoiceGenerator das unterstützt)
        vatRate: vatRate,
        additionalTexts: additionalTexts,
        roundingSettings: roundingSettings
      );

      if (context.mounted) {
        Navigator.pop(context);
        _openPdfViewer(context, pdfBytes, 'Rechnung_Preview.pdf');
      }
    } catch (e) {
      print('Fehler bei Rechnung-Preview: $e');
      rethrow;
    }
  }

  static void _openPdfViewer(BuildContext context, Uint8List pdfBytes, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewPDFViewerScreen(
          pdfBytes: pdfBytes,
          title: fileName,
        ),
      ),
    );
  }

  // PDF teilen
  static Future<void> _sharePdf(BuildContext context, Uint8List pdfBytes, String fileName) async {
    try {
      if (kIsWeb) {
        // Für Web: Download
        await DownloadHelper.downloadFile(pdfBytes, fileName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Für Mobile: Share
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(pdfBytes);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          subject: 'Dokument: $fileName',
        );

        // Cleanup nach kurzer Zeit
        Future.delayed(const Duration(minutes: 5), () async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });
      }
    } catch (e) {
      print('Fehler beim Teilen: $e');
      rethrow;
    }
  }

  // PDF herunterladen
  static Future<void> _downloadPdf(BuildContext context, Uint8List pdfBytes, String fileName) async {
    try {
      if (kIsWeb) {
        await DownloadHelper.downloadFile(pdfBytes, fileName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final downloadPath = await DownloadHelper.downloadFile(pdfBytes, fileName);
        if (context.mounted && downloadPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gespeichert unter: $downloadPath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Fehler beim Download: $e');
      rethrow;
    }
  }

  // Zeige "Nicht implementiert" Nachricht
  static void _showNotImplementedMessage(BuildContext context, String documentType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$documentType Preview'),
        content: Text('Die Preview für $documentType ist noch nicht implementiert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>> _calculateDiscountsForPreview(List<Map<String, dynamic>> basketItems) async {
try {
double itemDiscounts = 0.0;
double totalDiscountAmount = 0.0;

// Berechne Item-Rabatte direkt aus den basketItems
for (final item in basketItems) {
final customPriceValue = item['custom_price_per_unit'];
final pricePerUnit = customPriceValue != null
? (customPriceValue as num).toDouble()
    : (item['price_per_unit'] as num).toDouble();

final quantity = item['quantity'];
final quantityDouble = quantity is int ? quantity.toDouble() : quantity as double;
final itemSubtotal = quantityDouble * pricePerUnit;

// Rabatt ist direkt im Item gespeichert
final discount = item['discount'] as Map<String, dynamic>?;
if (discount != null) {
final percentage = (discount['percentage'] as num? ?? 0).toDouble();
final absolute = (discount['absolute'] as num? ?? 0).toDouble();
final discountAmount = (itemSubtotal * (percentage / 100)) + absolute;
itemDiscounts += discountAmount;
}
}

// Lade Gesamtrabatt aus temporary_discounts/total_discount
final totalDiscountDoc = await
    UserBasketService.temporaryDiscounts
    .doc('total_discount')
    .get();

if (totalDiscountDoc.exists) {
final totalDiscountData = totalDiscountDoc.data()!;
final totalPercentage = (totalDiscountData['percentage'] as num? ?? 0).toDouble();
final totalAbsolute = (totalDiscountData['absolute'] as num? ?? 0).toDouble();

// Berechne Subtotal nach Item-Rabatten
final subtotal = basketItems.fold<double>(0.0, (sum, item) {
final customPriceValue = item['custom_price_per_unit'];
final pricePerUnit = customPriceValue != null
? (customPriceValue as num).toDouble()
    : (item['price_per_unit'] as num).toDouble();
final qty = item['quantity'];
final qtyDouble = qty is int ? qty.toDouble() : qty as double;
return sum + (qtyDouble * pricePerUnit);
});

final subtotalAfterItemDiscounts = subtotal - itemDiscounts;
totalDiscountAmount = (subtotalAfterItemDiscounts * (totalPercentage / 100)) + totalAbsolute;
}

return {
'item_discounts': itemDiscounts,
'total_discount_amount': totalDiscountAmount,
};
} catch (e) {
print('Fehler beim Berechnen der Rabatte: $e');
return {
'item_discounts': 0.0,
'total_discount_amount': 0.0,
};
}
}

// Neue Methode zum Laden der aktuellen Währungseinstellungen
 Future<Map<String, dynamic>> loadCurrencySettings() async {
try {
final doc = await FirebaseFirestore.instance
    .collection('general_data')
    .doc('currency_settings')
    .get();

if (doc.exists) {
final data = doc.data()!;
return {
'currency': data['selected_currency'] ?? 'CHF',
'exchangeRates': {
'CHF': 1.0,
'EUR': (data['exchange_rates']?['EUR'] ?? 0.96).toDouble(),
'USD': (data['exchange_rates']?['USD'] ?? 1.08).toDouble(),
}
};
}
} catch (e) {
print('Fehler beim Laden der Währungseinstellungen: $e');
}

// Fallback-Werte
return {
'currency': 'CHF',
'exchangeRates': {'CHF': 1.0, 'EUR': 0.96, 'USD': 1.08}
};
}

Future<void> showDocumentSelectionBottomSheet(BuildContext context, {
  required ValueNotifier<bool> selectionCompleteNotifier,
  ValueNotifier<String>? documentLanguageNotifier,
}) async {
  Map<String, bool> documentSelection = await DocumentSelectionManager.loadDocumentSelection();

  // Lade die Währungseinstellungen hier
  final currencyDoc = await FirebaseFirestore.instance
      .collection('general_data')
      .doc('currency_settings')
      .get();

  String currency = 'CHF'; // Default
  Map<String, double> exchangeRates = {'CHF': 1.0, 'EUR': 0.96, 'USD': 1.08};

  if (currencyDoc.exists) {
    final data = currencyDoc.data()!;
    currency = data['selected_currency'] ?? 'CHF';
    if (data.containsKey('exchange_rates')) {
      final rates = data['exchange_rates'] as Map<String, dynamic>;
      exchangeRates = {
        'CHF': 1.0,
        'EUR': rates['EUR'] as double? ?? 0.96,
        'USD': rates['USD'] as double? ?? 1.08,
      };
    }
  }

  // NEU: Lade Packlisten-Settings für den Subtitle (Einzelversand)
  Map<String, dynamic> packingListSettings = await DocumentSelectionManager.loadPackingListSettings();
  String shipmentMode = packingListSettings['shipment_mode'] as String? ?? 'total';
  List<dynamic> packages = packingListSettings['packages'] as List<dynamic>? ?? [];

  final hasSelection = documentSelection.values.any((selected) => selected == true);
  selectionCompleteNotifier.value = hasSelection;
  // Verwende den übergebenen documentLanguageNotifier direkt
  final languageNotifier = documentLanguageNotifier ?? ValueNotifier<String>('DE');
  final dependentDocuments = ['Lieferschein', 'Handelsrechnung', 'Packliste'];

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {

        // NEU: Hilfsmethode für den Subtitle (zeigt Einzelversand an)
        Widget? buildDocumentSubtitle(String docType) {
          if (shipmentMode == 'per_shipment' &&
              (docType == 'Handelsrechnung' || docType == 'Lieferschein')) {
            final Set<int> groups = {};
            for (int i = 0; i < packages.length; i++) {
              final pkg = packages[i] as Map<String, dynamic>;
              groups.add((pkg['shipment_group'] as num?)?.toInt() ?? (i + 1));
            }
            final groupCount = groups.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, // Wichtig für mehrzeiligen Text
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: getAdaptiveIcon(
                          iconName: 'mail',
                          defaultIcon: Icons.mail,
                          size: 11,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded( // <-- Das Expanded verhindert den Overflow
                        child: Text(
                          groupCount > 0
                              ? 'Einzelversand: $groupCount Sendung${groupCount > 1 ? 'en' : ''} '
                              '→ $groupCount $docType${groupCount > 1 ? 'en' : ''}'
                              : 'Einzelversand (Sendungen in Packliste konfigurieren)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return null;
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
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

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: getAdaptiveIcon(
                              iconName: 'description',
                              defaultIcon: Icons.description,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Dokumente',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: getAdaptiveIcon(
                              iconName: 'close',
                              defaultIcon: Icons.close,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Informationstext
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            getAdaptiveIcon(
                              iconName: 'info',
                              defaultIcon: Icons.info,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Wähle aus, welche Dokumente erstellt werden sollen.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => ProductSortingManager.showSortingDialog(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: getAdaptiveIcon(
                                  iconName: 'sort',
                                  defaultIcon: Icons.sort,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sortierreihenfolge',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Produkte nach Instrument, Holzart, etc. sortieren',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              getAdaptiveIcon(
                                iconName: 'chevron_right',
                                defaultIcon: Icons.chevron_right,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Hinweis zu Abhängigkeiten
                      if (documentSelection['Rechnung'] != true &&
                          dependentDocuments.any((doc) => documentSelection[doc] == true))
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              getAdaptiveIcon(iconName: 'warning', defaultIcon:
                              Icons.warning,
                                color: Colors.orange[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lieferschein, Handelsrechnung und Packliste können nur zusammen mit einer Rechnung erstellt werden.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Dokumenten-Liste
                      Expanded(
                        child: ListView.separated(
                          itemCount: DocumentSelectionManager.documentTypes.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final docType = DocumentSelectionManager.documentTypes[index];
                            final isDependent = dependentDocuments.contains(docType);
                            final isDisabled = isDependent && documentSelection['Rechnung'] != true;

                            return Container(
                              decoration: BoxDecoration(
                                color: isDisabled
                                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: documentSelection[docType] == true
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Zahnrad für alle Dokumenttypen
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: IconButton(
                                      onPressed: isDisabled ? null : () async {
                                        // Je nach Dokumenttyp die richtige Funktion aufrufen
                                        switch (docType) {
                                          case 'Lieferschein':
                                            final quoteProvider = QuoteSettingsProvider();
                                            await DeliveryNoteSettingsDialog.show(
                                              context,
                                              provider: quoteProvider,
                                            );
                                            break;
                                          case 'Handelsrechnung':
                                            final quoteProvider = QuoteSettingsProvider();
                                            final customerSnapshot = await UserBasketService.temporaryCustomer.limit(1).get();
                                            final customerData = customerSnapshot.docs.isNotEmpty
                                                ? customerSnapshot.docs.first.data() as Map<String, dynamic>
                                                : <String, dynamic>{};
                                            final currencySettings = await loadCurrencySettings();

                                            await CommercialInvoiceSettingsDialog.show(
                                              context,
                                              provider: quoteProvider,
                                              customerData: customerData,
                                              defaultCurrency: currencySettings['currency'] as String? ?? 'CHF',
                                            );
                                            break;
                                          case 'Packliste':
                                            final quoteProvider = QuoteSettingsProvider();

                                            final basketSnapshot = await UserBasketService.temporaryBasket.get();
                                            final items = basketSnapshot.docs.map((doc) => {
                                              ...doc.data(),
                                              'doc_id': doc.id,
                                              'basket_doc_id': doc.id,
                                            }).where((item) => item['is_service'] != true).toList().cast<Map<String, dynamic>>();

                                            await PackingListSettingsDialog.show(
                                              context,
                                              provider: quoteProvider,
                                              items: items,
                                              showShipmentModeToggle: true,
                                            );

                                            // NEU: Nach dem Bearbeiten der Packliste die UI aktualisieren
                                            final updatedSettings = await DocumentSelectionManager.loadPackingListSettings();
                                            setState(() {
                                              packingListSettings = updatedSettings;
                                              shipmentMode = updatedSettings['shipment_mode'] as String? ?? 'total';
                                              packages = updatedSettings['packages'] as List<dynamic>? ?? [];
                                            });
                                            break;
                                          case 'Rechnung':
                                          // Berechne Gesamtbetrag
                                            double totalAmount = 0.0;
                                            try {
                                              final basketSnapshot = await UserBasketService.temporaryBasket.get();
                                              final calculations = await _calculateDiscountsForPreview(
                                                basketSnapshot.docs.map((doc) => doc.data()).toList(),
                                              );
                                              double subtotal = 0.0;
                                              for (final doc in basketSnapshot.docs) {
                                                final data = doc.data();
                                                final customPriceValue = data['custom_price_per_unit'];
                                                final pricePerUnit = customPriceValue != null
                                                    ? (customPriceValue as num).toDouble()
                                                    : (data['price_per_unit'] as num).toDouble();
                                                final quantity = (data['quantity'] as num).toDouble();
                                                subtotal += quantity * pricePerUnit;
                                              }
                                              final netAmount = subtotal - (calculations['item_discounts'] as double) - (calculations['total_discount_amount'] as double);
                                              final shippingCosts = await ShippingCostsManager.loadShippingCosts();
                                              double netWithShipping = netAmount;
                                              if (shippingCosts.isNotEmpty) {
                                                netWithShipping += (shippingCosts['amount'] ?? 0.0) + (shippingCosts['phytosanitaryCertificate'] ?? 0.0);
                                                netWithShipping += (shippingCosts['totalSurcharges'] ?? 0.0) - (shippingCosts['totalDeductions'] ?? 0.0);
                                              }
                                              final taxDoc = await UserBasketService.temporaryTax.doc('current_tax').get();
                                              final vatRate = taxDoc.exists ? (taxDoc.data()?['vat_rate'] ?? 8.1).toDouble() : 8.1;
                                              final taxOption = taxDoc.exists ? (taxDoc.data()?['tax_option'] ?? 0) : 0;
                                              totalAmount = taxOption == 0 ? netWithShipping * (1 + vatRate / 100) : netWithShipping;
                                              if (currency != 'CHF' && exchangeRates.containsKey(currency)) {
                                                totalAmount = totalAmount * exchangeRates[currency]!;
                                              }
                                              final roundingSettings = await SwissRounding.loadRoundingSettings();
                                              totalAmount = SwissRounding.round(totalAmount, currency: currency, roundingSettings: roundingSettings);
                                            } catch (e) {
                                              print('Fehler beim Berechnen des Gesamtbetrags: $e');
                                            }

                                            final quoteProvider = QuoteSettingsProvider();
                                            await InvoiceSettingsDialog.show(
                                              context,
                                              provider: quoteProvider,
                                              totalAmount: totalAmount,
                                              currency: currency,
                                            );
                                            break;
                                          case 'Offerte':
                                            await QuoteSettingsDialog.show(context);
                                            break;
                                          default:
                                            showDialog(
                                              context: context,
                                              builder: (dialogContext) => AlertDialog(
                                                title: Row(
                                                  children: [
                                                    getAdaptiveIcon(
                                                      iconName: 'info',
                                                      defaultIcon: Icons.info,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text('$docType'),
                                                  ],
                                                ),
                                                content: Text(
                                                  'Für $docType sind keine zusätzlichen Einstellungen verfügbar.',
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dialogContext),
                                                    child: const Text('OK'),
                                                  ),
                                                ],
                                              ),
                                            );
                                        }
                                      },
                                      icon: getAdaptiveIcon(
                                        iconName: 'settings',
                                        defaultIcon: Icons.settings,
                                      ),
                                      tooltip: '$docType',
                                    ),
                                  ),

                                  // Checkbox
                                  Expanded(
                                    child: CheckboxListTile(
                                      title: Row(
                                        children: [
                                          Text(
                                            docType,
                                            style: TextStyle(
                                              color: isDisabled
                                                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // NEU: Subtitle Methode hier einfügen
                                      subtitle: buildDocumentSubtitle(docType),
                                      value: documentSelection[docType] ?? false,
                                      onChanged: isDisabled ? null : (value) async {
                                        // Validierungslogik
                                        if (isDependent && value == true && documentSelection['Rechnung'] != true) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('$docType kann nur zusammen mit einer Rechnung erstellt werden'),
                                              backgroundColor: Colors.orange,
                                              action: SnackBarAction(
                                                label: 'Rechnung aktivieren',
                                                onPressed: () {
                                                  setState(() {
                                                    documentSelection['Rechnung'] = true;
                                                    documentSelection[docType] = true;
                                                  });
                                                  DocumentSelectionManager.saveDocumentSelection(documentSelection);
                                                },
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        if (docType == 'Rechnung' && value == false) {
                                          bool hasActiveDependents = dependentDocuments.any(
                                                  (doc) => documentSelection[doc] == true
                                          );

                                          if (hasActiveDependents) {
                                            final shouldProceed = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogContext) => AlertDialog(
                                                title: const Text('Warnung'),
                                                content: const Text(
                                                    'Wenn du die Rechnung deaktivierst, werden auch Lieferschein, '
                                                        'Handelsrechnung und Packliste deaktiviert. Fortfahren?'
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dialogContext, false),
                                                    child: const Text('Abbrechen'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(dialogContext, true),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                    ),
                                                    child: const Text('Deaktivieren'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (shouldProceed != true) return;

                                            setState(() {
                                              for (final doc in dependentDocuments) {
                                                documentSelection[doc] = false;
                                              }
                                            });
                                          }
                                        }

                                        setState(() {
                                          documentSelection[docType] = value ?? false;
                                        });

                                        await DocumentSelectionManager.saveDocumentSelection(documentSelection);

                                        final hasSelection = documentSelection.values.any((selected) => selected == true);
                                        selectionCompleteNotifier.value = hasSelection;
                                      },
                                      activeColor: Theme.of(context).colorScheme.primary,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),

                                  // Preview Button
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: IconButton(
                                      onPressed: isDisabled ? null : () async {
                                        await DocumentSelectionManager.showDocumentPreview(
                                          context,
                                          docType,
                                          language: languageNotifier.value,
                                        );
                                      },
                                      icon: getAdaptiveIcon(
                                        iconName: 'visibility',
                                        defaultIcon: Icons.visibility,
                                      ),
                                      tooltip: 'Vorschau',
                                    ),
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
              ),
            ],
          ),
        );
      },
    ),
  );
}