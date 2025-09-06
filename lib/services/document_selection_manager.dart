// File: services/document_selection_manager.dart (Erweiterte Version)

/// Info, hier ist der Angeobtsbereich




import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tonewood/services/pdf_generators/commercial_invoice_generator.dart';
import 'package:tonewood/services/pdf_generators/delivery_note_generator.dart';
import 'package:tonewood/services/pdf_generators/packing_list_generator.dart';
import 'additional_text_manager.dart';
import 'pdf_generators/invoice_generator.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/services/preview_pdf_viewer_screen.dart';
import 'package:tonewood/services/shipping_costs_manager.dart';
import '../services/icon_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'download_helper_mobile.dart';
import 'pdf_generators/quote_generator.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:intl/intl.dart';
// Am Anfang von document_selection_manager.dart:
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
      await FirebaseFirestore.instance
          .collection('temporary_document_selection')
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
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_selection')
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
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_selection')
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

      await FirebaseFirestore.instance
          .collection('temporary_document_settings')
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
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_settings')
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

  static Future<void> _showCommercialInvoicePreview(BuildContext context, Map<String, dynamic> data, {String? language}) async {
    try {
      final customerData = data['customer'] as Map<String, dynamic>;
      final documentLanguage = language ?? customerData['language'] ?? 'DE';
      final shippingCosts = await ShippingCostsManager.loadShippingCosts();

      // NEU: Lade Tara-Einstellungen
      final taraSettings = await loadTaraSettings();
      print(taraSettings);

      if (taraSettings['packaging_weight'] != null) {
        taraSettings['packaging_weight'] = (taraSettings['packaging_weight'] as num).toDouble();
      }

      print("rtest:${taraSettings['packaging_weight']}");

      // Nach dem Laden der taraSettings
      DateTime? invoiceDate;
      if (taraSettings['commercial_invoice_date'] != null) {
        final timestamp = taraSettings['commercial_invoice_date'];
        if (timestamp is Timestamp) {
          invoiceDate = timestamp.toDate();
        }
      }

      final basketItems = data['basketItems'] as List<Map<String, dynamic>>;

      // Berechne Rabatte für Preview
      final calculations = await _calculateDiscountsForPreview(basketItems);

      // Lade Steuereinstellungen
      final taxOption = data['taxOption'] ?? 0;
      final vatRate = data['vatRate'] ?? 8.1;

      // Konvertiere Basket-Items zu Items für PDF
      final items = basketItems.map((basketItem) {
        final customPriceValue = basketItem['custom_price_per_unit'];

        // WICHTIG: Stelle sicher, dass price_per_unit immer ein double ist
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue is int ? customPriceValue.toDouble() : (customPriceValue as num).toDouble())
            : (basketItem['price_per_unit'] is int
            ? (basketItem['price_per_unit'] as int).toDouble()
            : (basketItem['price_per_unit'] as num).toDouble());

        // Sichere Konvertierung für quantity
        final quantity = (basketItem['quantity'] as num).toDouble();

        final itemSubtotal = quantity * pricePerUnit;

        final discount = basketItem['discount'] as Map<String, dynamic>? ?? {'percentage': 0.0, 'absolute': 0.0};

        double discountAmount = 0.0;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();
          discountAmount = (itemSubtotal * (percentage / 100)) + absolute;
        }

        // WICHTIG: Erstelle eine neue Map mit allen konvertierten Werten
        final Map<String, dynamic> newItem = Map<String, dynamic>.from(basketItem);

        // Überschreibe die numerischen Werte mit double-Versionen
        newItem['price_per_unit'] = pricePerUnit;
        newItem['quantity'] = quantity;
        newItem['discount'] = discount;
        newItem['discount_amount'] = discountAmount;
        newItem['total'] = itemSubtotal - discountAmount;

        // Stelle sicher, dass andere numerische Felder auch als double vorliegen
        if (newItem['weight'] != null) {
          newItem['weight'] = newItem['weight'] is int
              ? (newItem['weight'] as int).toDouble()
              : (newItem['weight'] as num).toDouble();
        }

        if (newItem['volume'] != null) {
          newItem['volume'] = newItem['volume'] is int
              ? (newItem['volume'] as int).toDouble()
              : (newItem['volume'] as num).toDouble();
        }

        // Custom dimensions
        if (newItem['custom_length'] != null) {
          newItem['custom_length'] = newItem['custom_length'] is int
              ? (newItem['custom_length'] as int).toDouble()
              : (newItem['custom_length'] as num).toDouble();
        }

        if (newItem['custom_width'] != null) {
          newItem['custom_width'] = newItem['custom_width'] is int
              ? (newItem['custom_width'] as int).toDouble()
              : (newItem['custom_width'] as num).toDouble();
        }

        if (newItem['custom_thickness'] != null) {
          newItem['custom_thickness'] = newItem['custom_thickness'] is int
              ? (newItem['custom_thickness'] as int).toDouble()
              : (newItem['custom_thickness'] as num).toDouble();
        }

        return newItem;
      }).toList();

      final currencySettings = await _loadCurrencySettings();
      final currency = currencySettings['currency'] as String;
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
        invoiceNumber: 'PREVIEW',
        shippingCosts: shippingCosts,
        calculations: calculations,
        taxOption: taxOption,
        vatRate: vatRate,
        taraSettings: taraSettings,
      );

      if (context.mounted) {
        Navigator.pop(context);
        _openPdfViewer(context, pdfBytes, 'Handelsrechnung_Preview.pdf');
      }
    } catch (e) {
      print('YYFehler bei Handelsrechnung-Preview: $e');
      rethrow;
    }
  }
  static Future<void> saveTaraSettings(int numberOfPackages, double packagingWeight) async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_document_settings')
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
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('tara_settings')
          .get();

      Map<String, dynamic> taraSettings = {};
      bool hasExplicitTaraSettings = false;

      if (doc.exists && doc.data() != null) {
        taraSettings = doc.data()!;
        // Prüfe ob explizit Tara-Werte gespeichert wurden
        hasExplicitTaraSettings = taraSettings.containsKey('number_of_packages') ||
            taraSettings.containsKey('packaging_weight');
      }

      // 2. Wenn KEINE expliziten Tara-Einstellungen für Gewicht/Anzahl existieren,
      //    nutze die Packlisten-Daten
      if (!hasExplicitTaraSettings) {
        final packingListSettings = await loadPackingListSettings();
        final packages = packingListSettings['packages'] as List<dynamic>?;

        if (packages != null && packages.isNotEmpty) {
          double totalPackagingWeight = 0.0;

          // Berechne das Gesamtgewicht aller Verpackungen
          for (final package in packages) {
            final tareWeight = package['tare_weight'];
            if (tareWeight != null) {
              totalPackagingWeight += (tareWeight is num) ? tareWeight.toDouble() : 0.0;
            }
          }

          // Überschreibe nur number_of_packages und packaging_weight
          taraSettings['number_of_packages'] = packages.length;
          taraSettings['packaging_weight'] = totalPackagingWeight;

          print('Verwende Packlisten-Daten: ${packages.length} Pakete, ${totalPackagingWeight.toStringAsFixed(2)} kg');
        } else {
          // Fallback wenn weder Tara-Settings noch Packliste existieren
          taraSettings['number_of_packages'] = taraSettings['number_of_packages'] ?? 1;
          taraSettings['packaging_weight'] = taraSettings['packaging_weight'] ?? 0.0;
        }
      }

      // 3. Stelle sicher, dass alle Werte als richtige Typen vorliegen
      return {
        'number_of_packages': (taraSettings['number_of_packages'] ?? 1) as int,
        'packaging_weight': ((taraSettings['packaging_weight'] ?? 0.0) as num).toDouble(),
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
      };

    } catch (e) {
      print('Fehler beim Laden der Tara-Einstellungen: $e');
      return {
        'number_of_packages': 1,
        'packaging_weight': 0.0,
      };
    }
  }



  // Löscht die aktuelle Auswahl
// Löscht die aktuelle Auswahl
  static Future<void> clearSelection() async {
    try {
      // 1. Lösche die Dokumentauswahl
      await FirebaseFirestore.instance
          .collection('temporary_document_selection')
          .doc('current_selection')
          .delete();

      // 2. Lösche ALLE Dokument-Einstellungen
      final settingsCollection = FirebaseFirestore.instance
          .collection('temporary_document_settings');

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
      final totalDiscountDoc = await FirebaseFirestore.instance
          .collection('temporary_discounts')
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

  static Future<void> saveDeliveryNoteSettings(DateTime? deliveryDate, DateTime? paymentDate) async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('delivery_note_settings')
          .set({
        'delivery_date': deliveryDate?.toIso8601String(),
        'payment_date': paymentDate?.toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Lieferschein-Einstellungen: $e');
    }
  }


  // In document_selection_manager.dart, nach den anderen save-Methoden hinzufügen:

  static Future<void> saveInvoiceSettings(Map<String, dynamic> settings) async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('invoice_settings')
          .set({
        'down_payment_amount': settings['down_payment_amount'] ?? 0.0,
        'down_payment_reference': settings['down_payment_reference'] ?? '',
        'down_payment_date': settings['down_payment_date'],
        'show_dimensions': settings['show_dimensions'] ?? false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Rechnungs-Einstellungen: $e');
    }
  }

  static Future<Map<String, dynamic>> loadInvoiceSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('invoice_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'down_payment_amount': data['down_payment_amount'] ?? 0.0,
          'down_payment_reference': data['down_payment_reference'] ?? '',
          'down_payment_date': data['down_payment_date'] != null
              ? (data['down_payment_date'] as Timestamp).toDate()
              : null,
          'show_dimensions': data['show_dimensions'] ?? false,
        };
      }
    } catch (e) {
      print('Fehler beim Laden der Rechnungs-Einstellungen: $e');
    }

    return {
      'down_payment_amount': 0.0,
      'down_payment_reference': '',
      'down_payment_date': null,
      'show_dimensions': false,
    };
  }
// Nach saveInvoiceSettings() hinzufügen:

  static Future<void> saveQuoteSettings(Map<String, dynamic> settings) async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('quote_settings')
          .set({
        'validity_date': settings['validity_date'],
        'show_dimensions': settings['show_dimensions'],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Offerten-Einstellungen: $e');
    }
  }

  static Future<Map<String, dynamic>> loadQuoteSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('quote_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'validity_date': data['validity_date'] != null
              ? (data['validity_date'] as Timestamp).toDate()
              : null,
          'show_dimensions': data['show_dimensions'] ?? false,
        };
      }
    } catch (e) {
      print('Fehler beim Laden der Offerten-Einstellungen: $e');
    }

    return {
      'validity_date': null,
    };
  }


// Lade Lieferschein-Einstellungen
  static Future<Map<String, DateTime?>> loadDeliveryNoteSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('delivery_note_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'delivery_date': data['delivery_date'] != null
              ? DateTime.parse(data['delivery_date'])
              : null,
          'payment_date': data['payment_date'] != null
              ? DateTime.parse(data['payment_date'])
              : null,
        };
      }
    } catch (e) {
      print('Fehler beim Laden der Lieferschein-Einstellungen: $e');
    }

    return {'delivery_date': null, 'payment_date': null};
  }







// Neue Methode zum Laden der aktuellen Währungseinstellungen
  static Future<Map<String, dynamic>> _loadCurrencySettings() async {
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

// Zeige Lieferschein-Preview
  static Future<void> _showDeliveryNotePreview(BuildContext context, Map<String, dynamic> data, {String? language}) async {
    try {
      final customerData = data['customer'] as Map<String, dynamic>;
      final documentLanguage = language ?? customerData['language'] ?? 'DE';

      // Lade Lieferschein-Einstellungen
      final deliveryNoteSettings = await loadDeliveryNoteSettings();

      final basketItems = data['basketItems'] as List<Map<String, dynamic>>;

      // Konvertiere Basket-Items für PDF
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

      final currencySettings = await _loadCurrencySettings();
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
        deliveryNoteNumber: 'PREVIEW',
        deliveryDate: deliveryNoteSettings['delivery_date'],
        paymentDate: deliveryNoteSettings['payment_date'],
      );

      if (context.mounted) {
        Navigator.pop(context);
        _openPdfViewer(context, pdfBytes, 'Lieferschein_Preview.pdf');
      }
    } catch (e) {
      print('Fehler bei Lieferschein-Preview: $e');
      rethrow;
    }
  }
  // Preview-Funktionen für verschiedene Dokumente
  static Future<void> showDocumentPreview(BuildContext context, String documentType, {String? language}) async {
    try {


      print("language:$language");
      // Zeige Loading-Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Lade benötigte Daten für Preview
      final previewData = await _loadPreviewData(context);

      if (context.mounted) {
        Navigator.pop(context); // Schließe Loading-Dialog
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

      // Generiere entsprechendes PDF
      switch (documentType) {
        case 'Offerte':
          await _showQuotePreview(context, previewData,language: language);
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
        Navigator.pop(context); // Schließe Loading-Dialog falls noch offen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei der Preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      final customerSnapshot = await FirebaseFirestore.instance
          .collection('temporary_customer')
          .limit(1)
          .get();

      if (customerSnapshot.docs.isEmpty) {
        return null;
      }

      // Kostenstelle laden
      final costCenterSnapshot = await FirebaseFirestore.instance
          .collection('temporary_cost_center')
          .limit(1)
          .get();

      // Warenkorb laden
      final basketSnapshot = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .get();

      if (basketSnapshot.docs.isEmpty) {
        return null;
      }

      // Messe laden (optional)
      final fairSnapshot = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .limit(1)
          .get();

      // NEU: Lade Steuereinstellungen
      final taxDoc = await FirebaseFirestore.instance
          .collection('temporary_tax')
          .doc('current_tax')
          .get();

      int taxOption = 0; // Standard als Fallback
      double vatRate = 8.1; // Standard MwSt-Satz

      if (taxDoc.exists) {
        final taxData = taxDoc.data()!;
        taxOption = taxData['tax_option'] ?? 0;
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



  static Future<Map<String, bool>> _loadRoundingSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('currency_settings')
          .get();

      if (doc.exists && doc.data()!.containsKey('rounding_settings')) {
        final settings = doc.data()!['rounding_settings'] as Map<String, dynamic>;
        return {
          'CHF': settings['CHF'] ?? true,
          'EUR': settings['EUR'] ?? false,
          'USD': settings['USD'] ?? false,
        };
      }

      // Fallback zu Standard-Einstellungen
      print('Keine Rundungseinstellungen in Firebase gefunden, verwende Standard-Werte');
      return {
        'CHF': true,  // Standard: CHF wird gerundet
        'EUR': false,
        'USD': false,
      };
    } catch (e) {
      print('Fehler beim Laden der Rundungseinstellungen: $e');
      // Fallback zu Standard-Einstellungen
      return {
        'CHF': true,
        'EUR': false,
        'USD': false,
      };
    }
  }
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
      final taxOption = data['taxOption'] ?? 0;
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
      final currencySettings = await _loadCurrencySettings();
      print('Currency settings: $currencySettings');

      final currency = currencySettings['currency'] as String;
      print('Currency: $currency');

      // Exchange Rates Debug
      print('Fetching exchange rates...');
      final exchangeRates = await _fetchCurrentExchangeRates();
      print('Exchange rates: $exchangeRates');
// NEU: Lade Rundungseinstellungen
      print('Loading rounding settings...');
      final roundingSettings = await _loadRoundingSettings();
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

      final currencySettings = await _loadCurrencySettings();
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
        paymentTermDays: 30,
        taxOption: taxOption,  // NEU (falls InvoiceGenerator das unterstützt)
        vatRate: vatRate,
        additionalTexts: additionalTexts,
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
// Am Ende der document_selection_manager.dart Datei:


// In der showDocumentSelectionBottomSheet Funktion, fügen Sie diese neue Funktion hinzu:




Future<void> _showDeliveryNoteSettingsDialog(BuildContext context) async {
  DateTime? selectedDeliveryDate;
  DateTime? selectedPaymentDate;

  // Lade bestehende Einstellungen
  final existingSettings = await DocumentSelectionManager.loadDeliveryNoteSettings();
  selectedDeliveryDate = existingSettings['delivery_date'];
  selectedPaymentDate = existingSettings['payment_date'];

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
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
                              iconName: 'local_shipping',
                              defaultIcon: Icons.local_shipping,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Lieferschein',
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
                      const SizedBox(height: 24),

                      // Lieferdatum
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDeliveryDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),

                            locale: const Locale('de', 'DE'),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDeliveryDate = picked;
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
                              getAdaptiveIcon(
                                iconName: 'calendar_today',
                                defaultIcon: Icons.calendar_today,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lieferdatum',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      selectedDeliveryDate != null
                                          ? DateFormat('dd.MM.yyyy').format(selectedDeliveryDate!)
                                          : 'Datum auswählen',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedDeliveryDate != null)
                                IconButton(
                                  icon: getAdaptiveIcon(
                                    iconName: 'clear',
                                    defaultIcon: Icons.clear,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      selectedDeliveryDate = null;
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
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedPaymentDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            locale: const Locale('de', 'DE'),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedPaymentDate = picked;
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
                              getAdaptiveIcon(
                                iconName: 'payment',
                                defaultIcon: Icons.payment,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Zahlungsdatum',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      selectedPaymentDate != null
                                          ? DateFormat('dd.MM.yyyy').format(selectedPaymentDate!)
                                          : 'Datum auswählen',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedPaymentDate != null)
                                IconButton(
                                  icon: getAdaptiveIcon(
                                    iconName: 'clear',
                                    defaultIcon: Icons.clear,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      selectedPaymentDate = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Abbrechen'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await DocumentSelectionManager.saveDeliveryNoteSettings(
                                  selectedDeliveryDate,
                                  selectedPaymentDate,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Einstellungen gespeichert'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              icon: getAdaptiveIcon(
                                iconName: 'save',
                                defaultIcon: Icons.save,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              label: const Text('Speichern'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
double _getAssignedQuantity(Map<String, dynamic> item, List<Map<String, dynamic>> packages) {
  double totalAssigned = 0;
  for (final package in packages) {
    final packageItems = package['items'] as List<dynamic>;
    for (final assignedItem in packageItems) {
      if (assignedItem['product_id'] == item['product_id']) {
        totalAssigned += (assignedItem['quantity'] as num).toDouble();
      }
    }
  }
  return totalAssigned;
}

Widget _buildPackageCard(
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

  // Sichere Controller-Referenz
  final packageId = package['id'] as String;
  if (!packageControllers.containsKey(packageId)) {
    // Falls Controller fehlen, erstelle sie
    packageControllers[packageId] = {
      'length': TextEditingController(text: package['length']?.toString() ?? '0.0'),
      'width': TextEditingController(text: package['width']?.toString() ?? '0.0'),
      'height': TextEditingController(text: package['height']?.toString() ?? '0.0'),
      'weight': TextEditingController(text: package['tare_weight']?.toString() ?? '0.0'),
      'custom_name': TextEditingController(text: package['packaging_type'] ?? ''),
      'gross_weight': TextEditingController(text: package['gross_weight']?.toString() ?? ''),
    };
  }

  final controllers = packageControllers[packageId]!;

  // NEU: Berechne Nettogewicht (gleiche Funktion wie vorher)
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
        final volumePerUnit = item['volume_per_unit'];
        final density = (item['density'] as num?)?.toDouble() ?? 0.0;

        if (volumePerUnit != null && (volumePerUnit as num) > 0) {
          volumePerPiece = (volumePerUnit as num).toDouble();
        } else {
          final length = (item['custom_length'] as num?)?.toDouble() ?? 0.0;
          final width = (item['custom_width'] as num?)?.toDouble() ?? 0.0;
          final thickness = (item['custom_thickness'] as num?)?.toDouble() ?? 0.0;

          if (length > 0 && width > 0 && thickness > 0) {
            volumePerPiece = (length / 1000) * (width / 1000) * (thickness / 1000);
          }
        }

        final weightPerPiece = volumePerPiece * density;
        netWeight += weightPerPiece * quantity;
      }
    }

    return netWeight;
  }

  return Card(
    key: ValueKey(packageId), // Wichtig: Eindeutiger Key
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
                'Paket ${index + 1}', // Verwende index statt package['name']
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
                      // Controller werden beim Dialog-Schließen disposed
                    });
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'delete',
                    defaultIcon: Icons.delete,
                    color: Colors.red[400],
                  ),
                  iconSize: 20,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Dropdown für Standardpakete (gleich wie vorher)
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
                      prefixIcon: getAdaptiveIcon(
                        iconName: 'inventory',
                        defaultIcon: Icons.inventory,
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

                          controllers['length']!.text = package['length'].toString();
                          controllers['width']!.text = package['width'].toString();
                          controllers['height']!.text = package['height'].toString();
                          controllers['weight']!.text = package['tare_weight'].toString();
                        } else if (value == 'custom') {
                          package['packaging_type'] = '';
                          package['length'] = 0.0;
                          package['width'] = 0.0;
                          package['height'] = 0.0;
                          package['tare_weight'] = 0.0;

                          controllers['length']!.text = '0.0';
                          controllers['width']!.text = '0.0';
                          controllers['height']!.text = '0.0';
                          controllers['weight']!.text = '0.0';
                          controllers['custom_name']!.text = '';
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
              controller: controllers['custom_name']!,
              decoration: InputDecoration(
                labelText: 'Verpackungsbezeichnung',
                hintText: 'z.B. Spezialverpackung',
                prefixIcon: getAdaptiveIcon(
                  iconName: 'edit',
                  defaultIcon: Icons.edit,
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
                  controller: controllers['length']!,
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
                  controller: controllers['width']!,
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
                  controller: controllers['height']!,
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
            controller: controllers['weight']!,
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

          // Bruttogewicht
          TextFormField(
            controller: controllers['gross_weight']!,
            decoration: InputDecoration(
              labelText: 'Bruttogewicht (gemessen) (kg)',
              helperText: 'Leer lassen für automatische Berechnung',
              prefixIcon: getAdaptiveIcon(
                iconName: 'scale',
                defaultIcon: Icons.scale,
              ),
              suffixIcon: controllers['gross_weight']!.text.isNotEmpty
                  ? IconButton(
                icon: getAdaptiveIcon(
                  iconName: 'clear',
                  defaultIcon: Icons.clear,
                ),
                onPressed: () {
                  setModalState(() {
                    controllers['gross_weight']!.clear();
                    package['gross_weight'] = null;

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
                            controllers['weight']!.text = package['tare_weight'].toString();
                          });
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
                  package['gross_weight'] = null;

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
                          controllers['weight']!.text = package['tare_weight'].toString();
                        });
                      }
                    });
                  }
                } else if (grossWeight > 0) {
                  package['gross_weight'] = grossWeight;
                  final netWeight = calculateNetWeight();
                  final calculatedTara = grossWeight - netWeight;
                  package['tare_weight'] = calculatedTara > 0 ? calculatedTara : 0.0;
                  controllers['weight']!.text = package['tare_weight'].toStringAsFixed(2);
                }
              });
            },
          ),

          // Gewichtsübersicht (gleich wie vorher)
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
                      const Text('Nettogewicht (Produkte):', style: TextStyle(fontSize: 12)),
                      Text('${calculateNetWeight().toStringAsFixed(2)} kg',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tara (Verpackung):', style: TextStyle(fontSize: 12)),
                      Text('${package['tare_weight'].toStringAsFixed(2)} kg',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bruttogewicht:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${(calculateNetWeight() + (package['tare_weight'] ?? 0.0)).toStringAsFixed(2)} kg',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Zugewiesene Produkte
          Text(
            'Zugewiesene Produkte',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          const SizedBox(height: 8),

          // Produkte anzeigen
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
                          if (package['gross_weight'] != null) {
                            final netWeight = calculateNetWeight();
                            final grossWeight = package['gross_weight'] as double;
                            package['tare_weight'] = grossWeight - netWeight;
                            controllers['weight']!.text = package['tare_weight'].toStringAsFixed(2);
                          }
                        });
                      },
                      icon: getAdaptiveIcon(
                        iconName: 'remove',
                        defaultIcon: Icons.remove,
                        color: Colors.red[400],
                      ),
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
            onPressed: () => _showAddProductDialog(
              context,
              package,
              orderItems,
              packages,
              setModalState,
            ),
            icon: getAdaptiveIcon(
              iconName: 'add',
              defaultIcon: Icons.add,
              size: 16,
            ),
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

void _showAddProductDialog(
    BuildContext dialogContext,
    Map<String, dynamic> package,
    List<dynamic> availableItems,
    List<Map<String, dynamic>> packages,
    StateSetter setDialogState,
    ) {
  showDialog(
    context: dialogContext,
    builder: (context) => AlertDialog(
      title: const Text('Produkt hinzufügen'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: availableItems.length,
          itemBuilder: (context, index) {
            final item = availableItems[index];
            final assignedQuantity = _getAssignedQuantity(item, packages);
            final remainingQuantity = (item['quantity'] as num? ?? 0).toDouble() - assignedQuantity;

            if (remainingQuantity <= 0) return const SizedBox.shrink();

            return ListTile(
              title: Text(item['product_name'] ?? ''),
              subtitle: Text('Verfügbar: $remainingQuantity Stk.'),
              onTap: () {
                Navigator.pop(context);
                _showQuantityDialog(
                  dialogContext,
                  item,
                  remainingQuantity,
                  package,
                  setDialogState,
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

void _showQuantityDialog(
    BuildContext dialogContext,
    Map<String, dynamic> item,
    double maxQuantity,
    Map<String, dynamic> package,
    StateSetter setDialogState,
    ) {
  int selectedQuantity = 1;

  // Debug-Ausgabe
  print('=== _showQuantityDialog Debug ===');
  print('Item: ${item['product_name']}');
  print('custom_length: ${item['custom_length']}');
  print('custom_width: ${item['custom_width']}');
  print('custom_thickness: ${item['custom_thickness']}');
  print('densityX: ${item['density']}');
  showDialog(
    context: dialogContext,
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
                  icon: getAdaptiveIcon(
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
              // Debug vor dem Hinzufügen
              print('=== Füge zu Package hinzu ===');
              print('custom_length: ${item['custom_length']}');
              print('custom_width: ${item['custom_width']}');
              print('custom_thickness: ${item['custom_thickness']}');

              setDialogState(() {
                package['items'].add({
                  'product_id': item['product_id'],
                  'product_name': item['product_name'],
                  'product_name_en': item['product_name_en'] ?? '',
                  'quantity': selectedQuantity,
                  // Maße korrekt übernehmen
                  'custom_length': item['custom_length'] ?? 0.0,
                  'custom_width': item['custom_width'] ?? 0.0,
                  'custom_thickness': item['custom_thickness'] ?? 0.0,
                  'density': item['density'] ?? 0.0,
                  'volume_per_unit': item['volume_per_unit'] ?? 0.0,


                  // Weitere wichtige Felder
                  'wood_code': item['wood_code'] ?? '',
                  'wood_name': item['wood_name'] ?? '',
                  'unit': item['unit'] ?? 'Stk',
                  'instrument_code': item['instrument_code'] ?? '',
                  'instrument_name': item['instrument_name'] ?? '',
                  'instrument_name_en': item['instrument_name_en'] ?? '' ,
                  'part_code': item['part_code'] ?? '',
                  'part_name': item['part_name'] ?? '',
                  'part_name_en': item['part_name_en'] ?? '',
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

// Hilfsfunktion zum Laden der Standardtexte
Future<String> _loadDefaultTextForType(String textType, String language) async {
try {
final doc = await FirebaseFirestore.instance
    .collection('general_data')
    .doc('additional_texts')
    .get();

if (doc.exists) {
final data = doc.data()!;
final texts = data[textType] as Map<String, dynamic>?;
if (texts != null) {
final langTexts = texts[language] as Map<String, dynamic>?;
if (langTexts != null) {
return langTexts['standard'] ?? 'Kein Standardtext hinterlegt';
}
}
}
} catch (e) {
print('Fehler beim Laden des Standardtexts: $e');
}

return 'Kein Standardtext hinterlegt';
}
// In document_selection_manager.dart, nach anderen Methoden hinzufügen:

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
final totalDiscountDoc = await FirebaseFirestore.instance
    .collection('temporary_discounts')
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


        print("yuppp");
  print("documentLanguageNotifier passed: $documentLanguageNotifier");
  final hasSelection = documentSelection.values.any((selected) => selected == true);
  selectionCompleteNotifier.value = hasSelection;
  // Verwende den übergebenen documentLanguageNotifier direkt
  final languageNotifier = documentLanguageNotifier ?? ValueNotifier<String>('DE');
  final dependentDocuments = ['Lieferschein', 'Handelsrechnung', 'Packliste'];


  // In der showDocumentSelectionBottomSheet Funktion, fügen Sie diese neue Funktion hinzu:

  Future<void> showInvoiceSettingsDialog() async {
    double downPaymentAmount = 0.0;
    String downPaymentReference = '';
    DateTime? downPaymentDate;
    bool showDimensions = false;


    // Lade bestehende Einstellungen
    final existingSettings = await DocumentSelectionManager.loadInvoiceSettings();
    downPaymentAmount = (existingSettings['down_payment_amount'] ?? 0.0).toDouble();
    downPaymentReference = existingSettings['down_payment_reference'] ?? '';
    downPaymentDate = existingSettings['down_payment_date'];
    showDimensions = existingSettings['show_dimensions'] ?? false; // NEU

    final downPaymentController = TextEditingController(text: downPaymentAmount > 0 ? downPaymentAmount.toString() : '');
    final referenceController = TextEditingController(text: downPaymentReference);



    // In showInvoiceSettingsDialog(), nach der Berechnung des totalAmount:

// Hole den Gesamtbetrag aus dem Warenkorb
    double totalAmount = 0.0;
    try {
      // Berechne den Gesamtbetrag
      final basketSnapshot = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .get();

      final calculations = await _calculateDiscountsForPreview(
          basketSnapshot.docs.map((doc) => doc.data()).toList()
      );

      // Hier müssen wir den Bruttobetrag berechnen
      // Hier müssen wir den Bruttobetrag berechnen
      double subtotal = 0.0;
      for (final doc in basketSnapshot.docs) {
        final data = doc.data();
        final customPriceValue = data['custom_price_per_unit'];
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue as num).toDouble()
            : (data['price_per_unit'] as num).toDouble();

        // FIX: Hier war der Fehler - quantity muss auch sicher konvertiert werden
        final quantity = (data['quantity'] as num).toDouble();
        subtotal += quantity * pricePerUnit;
      }

      // Rabatte abziehen
      final netAmount = subtotal - calculations['item_discounts'] - calculations['total_discount_amount'];

      // Versandkosten hinzufügen
      final shippingCosts = await ShippingCostsManager.loadShippingCosts();
      double netWithShipping = netAmount;
      if (shippingCosts.isNotEmpty) {
        netWithShipping += (shippingCosts['amount'] ?? 0.0) + (shippingCosts['phytosanitaryCertificate'] ?? 0.0);
        netWithShipping += (shippingCosts['totalSurcharges'] ?? 0.0) - (shippingCosts['totalDeductions'] ?? 0.0);
      }

      // MwSt hinzufügen (Standard 8.1%)
      final taxDoc = await FirebaseFirestore.instance
          .collection('temporary_tax')
          .doc('current_tax')
          .get();

      final vatRate = taxDoc.exists ? (taxDoc.data()?['vat_rate'] ?? 8.1).toDouble() : 8.1;
      final taxOption = taxDoc.exists ? (taxDoc.data()?['tax_option'] ?? 0) : 0;

      if (taxOption == 0) { // Standard
        totalAmount = netWithShipping * (1 + vatRate / 100);
      } else {
        totalAmount = netWithShipping;
      }

      // NEU: Währungsumrechnung
      if (currency != 'CHF' && exchangeRates.containsKey(currency)) {
        totalAmount = totalAmount * exchangeRates[currency]!;
      }

    } catch (e) {
      print('Fehler beim Berechnen des Gesamtbetrags: $e');
    }



    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
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
                // Content
                Expanded(
                  child: SingleChildScrollView(
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
                                iconName: 'receipt',
                                defaultIcon: Icons.receipt,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Rechnung - Anzahlung',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: getAdaptiveIcon(
                                iconName: 'close',
                                defaultIcon: Icons.close,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

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
                                '${currency} ${totalAmount.toStringAsFixed(2)}',
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
                            labelText: 'Anzahlung BRUTTO (${currency})', // NEU: Dynamische Währung
                            prefixIcon: getAdaptiveIcon(
                              iconName: 'payments',
                              defaultIcon: Icons.payments,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            helperText: 'Betrag der bereits geleisteten Anzahlung',
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              downPaymentAmount = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // Nach dem Datum der Anzahlung, vor der Vorschau der Berechnung
                        const SizedBox(height: 16),

// NEU: Checkbox für Maße anzeigen
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CheckboxListTile(
                            title: const Text('Maße anzeigen'),
                            subtitle: const Text(
                              'Zeigt die Spalte "Maße" (Länge×Breite×Dicke) in der Rechnung an',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: showDimensions,
                            onChanged: (value) {
                              setDialogState(() {
                                showDimensions = value ?? false;
                              });
                            },
                            secondary:
                            getAdaptiveIcon(iconName: 'straighten', defaultIcon: Icons.straighten, size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),




                        // Belegnummer/Notiz
                        TextField(
                          controller: referenceController,
                          decoration: InputDecoration(
                            labelText: 'Belegnummer / Notiz',
                            prefixIcon: getAdaptiveIcon(
                              iconName: 'description',
                              defaultIcon: Icons.description,
                            ),
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
                              context: dialogContext,
                              initialDate: downPaymentDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              locale: const Locale('de', 'DE'),
                            );
                            if (picked != null) {
                              setDialogState(() {
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
                                getAdaptiveIcon(
                                  iconName: 'calendar_today',
                                  defaultIcon: Icons.calendar_today,
                                ),
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
                                    icon: getAdaptiveIcon(
                                      iconName: 'clear',
                                      defaultIcon: Icons.clear,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
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
                                    Text('${currency} ${totalAmount.toStringAsFixed(2)}'), // NEU
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Anzahlung:'),
                                    Text(
                                      '- ${currency} ${downPaymentAmount.toStringAsFixed(2)}', // NEU
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
                                      '${currency} ${(totalAmount - downPaymentAmount).toStringAsFixed(2)}', // NEU
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 32), // Fester Abstand statt Spacer

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Abbrechen'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await DocumentSelectionManager.saveInvoiceSettings({
                                    'down_payment_amount': downPaymentAmount,
                                    'down_payment_reference': downPaymentReference,
                                    'down_payment_date': downPaymentDate != null
                                        ? Timestamp.fromDate(downPaymentDate!)
                                        : null,
                                    'show_dimensions': showDimensions,
                                  });

                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Anzahlung gespeichert'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: getAdaptiveIcon(
                                  iconName: 'save',
                                  defaultIcon: Icons.save,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                                label: const Text('Speichern'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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

  Future<void> showQuoteSettingsDialog() async {
    DateTime? validityDate;
    bool showDimensions = false; // NEU: Standard deaktiviert

    // Lade bestehende Einstellungen
    final existingSettings = await DocumentSelectionManager.loadQuoteSettings();
    validityDate = existingSettings['validity_date'];
    showDimensions = existingSettings['show_dimensions'] ?? false; // NEU

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6, // Erhöht von 0.5
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
                                iconName: 'request_quote',
                                defaultIcon: Icons.request_quote,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Offerte - Einstellungen',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: getAdaptiveIcon(
                                iconName: 'close',
                                defaultIcon: Icons.close,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Gültigkeitsdatum
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: validityDate ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                              locale: const Locale('de', 'DE'),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                validityDate = picked;
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
                                getAdaptiveIcon(
                                  iconName: 'event',
                                  defaultIcon: Icons.event,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gültig bis',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        validityDate != null
                                            ? DateFormat('dd.MM.yyyy').format(validityDate!)
                                            : 'Datum auswählen',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                if (validityDate != null)
                                  IconButton(
                                    icon: getAdaptiveIcon(
                                      iconName: 'clear',
                                      defaultIcon: Icons.clear,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        validityDate = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // NEU: Checkbox für Maße anzeigen
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CheckboxListTile(
                            title: const Text('Maße anzeigen'),
                            subtitle: const Text(
                              'Zeigt die Spalte "Maße" (Länge×Breite×Dicke) in der Offerte an',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: showDimensions,
                            onChanged: (value) {
                              setDialogState(() {
                                showDimensions = value ?? false;
                              });
                            },
                            secondary:   getAdaptiveIcon(iconName: 'straighten', defaultIcon: Icons.straighten,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Info-Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              getAdaptiveIcon(
                                iconName: 'info',
                                defaultIcon: Icons.info,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Die Offerte ist standardmäßig 14 Tage gültig. Die Maße-Spalte ist standardmäßig ausgeblendet.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Abbrechen'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await DocumentSelectionManager.saveQuoteSettings({
                                    'validity_date': validityDate != null
                                        ? Timestamp.fromDate(validityDate!)
                                        : null,
                                    'show_dimensions': showDimensions, // NEU
                                  });

                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Offerten-Einstellungen gespeichert'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: getAdaptiveIcon(
                                  iconName: 'save',
                                  defaultIcon: Icons.save,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                                label: const Text('Speichern'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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


  // NEU: Definiere die Funktion INNERHALB von showDocumentSelectionBottomSheet
  Future<void> showDeliveryNoteSettingsDialog() async {
    DateTime? selectedDeliveryDate;
    DateTime? selectedPaymentDate;

    // Lade bestehende Einstellungen
    final existingSettings = await DocumentSelectionManager.loadDeliveryNoteSettings();
    selectedDeliveryDate = existingSettings['delivery_date'];
    selectedPaymentDate = existingSettings['payment_date'];

    // Debug
    print('Lade bestehende Einstellungen: $existingSettings');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
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
                                iconName: 'local_shipping',
                                defaultIcon: Icons.local_shipping,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Lieferschein',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: getAdaptiveIcon(
                                iconName: 'close',
                                defaultIcon: Icons.close,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Lieferdatum
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDeliveryDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              locale: const Locale('de', 'DE'),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDeliveryDate = picked;
                              });
                              print('Lieferdatum ausgewählt: $selectedDeliveryDate');
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
                                getAdaptiveIcon(
                                  iconName: 'calendar_today',
                                  defaultIcon: Icons.calendar_today,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lieferdatum',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        selectedDeliveryDate != null
                                            ? DateFormat('dd.MM.yyyy').format(selectedDeliveryDate!)
                                            : 'Datum auswählen',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedDeliveryDate != null)
                                  IconButton(
                                    icon: getAdaptiveIcon(
                                      iconName: 'clear',
                                      defaultIcon: Icons.clear,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedDeliveryDate = null;
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
                            final DateTime? picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedPaymentDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              locale: const Locale('de', 'DE'),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedPaymentDate = picked;
                              });
                              print('Zahlungsdatum ausgewählt: $selectedPaymentDate');
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
                                getAdaptiveIcon(
                                  iconName: 'payment',
                                  defaultIcon: Icons.payment,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Zahlungsdatum',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        selectedPaymentDate != null
                                            ? DateFormat('dd.MM.yyyy').format(selectedPaymentDate!)
                                            : 'Datum auswählen',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedPaymentDate != null)
                                  IconButton(
                                    icon: getAdaptiveIcon(
                                      iconName: 'clear',
                                      defaultIcon: Icons.clear,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedPaymentDate = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Abbrechen'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  print('Speichere Einstellungen:');
                                  print('Lieferdatum: $selectedDeliveryDate');
                                  print('Zahlungsdatum: $selectedPaymentDate');

                                  await DocumentSelectionManager.saveDeliveryNoteSettings(
                                    selectedDeliveryDate,
                                    selectedPaymentDate,
                                  );

                                  // Verifiziere, dass gespeichert wurde
                                  final saved = await DocumentSelectionManager.loadDeliveryNoteSettings();
                                  print('Gespeicherte Einstellungen: $saved');

                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Einstellungen gespeichert'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: getAdaptiveIcon(
                                  iconName: 'save',
                                  defaultIcon: Icons.save,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                                label: const Text('Speichern'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
  Future<void> showTaraSettingsDialog() async {
    int numberOfPackages = 1;
    double packagingWeight = 0.0;
    bool valuesFromPackingList = false;
    DateTime? commercialInvoiceDate;
    // Commercial Invoice Standardsätze
    bool originDeclaration = false;
    bool cites = false;
    bool exportReason = false;
    bool incoterms = false;
    bool deliveryDate = false;
    bool carrier = false;
    bool signature = false;
    List<String> selectedIncoterms = [];
    Map<String, String> incotermsFreeTexts = {};
    String exportReasonText = 'Ware';
    String carrierText = 'Swiss Post';
    DateTime? selectedDeliveryDate;
    bool deliveryDateMonthOnly = false;
    String? selectedSignature;

    // Lade Packlisten-Einstellungen zuerst
    final packingListSettings = await DocumentSelectionManager.loadPackingListSettings();
    final packages = packingListSettings['packages'] as List<dynamic>?;

    print("packages:$packages");
    // Prüfe, ob Packliste existiert und Pakete enthält
    if (packages != null && packages.isNotEmpty) {
      valuesFromPackingList = true;
      numberOfPackages = packages.length;

      // Berechne das Gesamtgewicht der Verpackungen
      packagingWeight = 0.0;
      for (final package in packages) {
        packagingWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
      }
      print("pW:$packagingWeight");
    } else {
      // Lade bestehende Tara-Einstellungen nur wenn keine Packliste existiert
      final existingSettings = await DocumentSelectionManager.loadTaraSettings();
      numberOfPackages = existingSettings['number_of_packages'] ?? 1;
      packagingWeight = (existingSettings['packaging_weight'] ?? 0.0).toDouble();

      // Laden Sie die Einstellung mit den anderen
      if (existingSettings['commercial_invoice_date'] != null) {
        final timestamp = existingSettings['commercial_invoice_date'];
        if (timestamp is Timestamp) {
          commercialInvoiceDate = timestamp.toDate();
        }
      }

    }


    // Lade immer die Commercial Invoice Einstellungen
    final existingSettings = await DocumentSelectionManager.loadTaraSettings();
    originDeclaration = existingSettings['commercial_invoice_origin_declaration'] ?? false;
    cites = existingSettings['commercial_invoice_cites'] ?? false;
    exportReason = existingSettings['commercial_invoice_export_reason'] ?? false;
    incoterms = existingSettings['commercial_invoice_incoterms'] ?? false;
    deliveryDate = existingSettings['commercial_invoice_delivery_date'] ?? false;
    carrier = existingSettings['commercial_invoice_carrier'] ?? false;
    signature = existingSettings['commercial_invoice_signature'] ?? false;
    selectedIncoterms = List<String>.from(existingSettings['commercial_invoice_selected_incoterms'] ?? []);
    incotermsFreeTexts = Map<String, String>.from(existingSettings['commercial_invoice_incoterms_freetexts'] ?? {});
    exportReasonText = existingSettings['commercial_invoice_export_reason_text'] ?? 'Ware';
    carrierText = existingSettings['commercial_invoice_carrier_text'] ?? 'Swiss Post';
    deliveryDateMonthOnly = existingSettings['commercial_invoice_delivery_date_month_only'] ?? false;
    selectedSignature = existingSettings['commercial_invoice_selected_signature'];

    if (existingSettings['commercial_invoice_delivery_date_value'] != null) {
      final timestamp = existingSettings['commercial_invoice_delivery_date_value'];
      if (timestamp is Timestamp) {
        selectedDeliveryDate = timestamp.toDate();
      }
    }

    final numberOfPackagesController = TextEditingController(text: numberOfPackages.toString());
    final packagingWeightController = TextEditingController(text: packagingWeight.toStringAsFixed(2) );
    final exportReasonTextController = TextEditingController(text: exportReasonText);
    final carrierTextController = TextEditingController(text: carrierText);

    final Map<String, TextEditingController> incotermControllers = {};
    for (String incotermId in selectedIncoterms) {
      incotermControllers[incotermId] = TextEditingController(text: incotermsFreeTexts[incotermId] ?? '');
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
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
                    child: SingleChildScrollView(
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
                                  iconName: 'inventory',
                                  defaultIcon: Icons.inventory,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Handelsrechnung',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: getAdaptiveIcon(
                                  iconName: 'close',
                                  defaultIcon: Icons.close,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

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

                          // Info-Box wenn Werte aus Packliste kommen
                          if (valuesFromPackingList)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  getAdaptiveIcon(iconName: 'info', defaultIcon:
                                    Icons.info,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Die Werte werden aus der Packliste übernommen und können nur dort bearbeitet werden.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Anzahl Packungen
                          TextField(
                            controller: numberOfPackagesController,
                            keyboardType: TextInputType.number,
                            enabled: !valuesFromPackingList, // Deaktiviert wenn aus Packliste
                            decoration: InputDecoration(
                              labelText: 'Anzahl Packungen',
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'inventory',
                                defaultIcon: Icons.inventory,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              helperText: valuesFromPackingList
                                  ? 'Wert aus Packliste'
                                  : 'Anzahl der Verpackungseinheiten',
                              suffixIcon: valuesFromPackingList
                                  ?

                              getAdaptiveIcon(iconName: 'lock', defaultIcon:
                                Icons.lock,
                                size: 20,
                                color: Theme.of(context).colorScheme.outline,
                              )
                                  : null,
                            ),
                            onChanged: valuesFromPackingList ? null : (value) {
                              setDialogState(() {
                                numberOfPackages = int.tryParse(value) ?? 1;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Verpackungsgewicht
                          TextField(
                            controller: packagingWeightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: !valuesFromPackingList, // Deaktiviert wenn aus Packliste
                            decoration: InputDecoration(
                              labelText: 'Verpackungsgewicht (kg)',
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'scale',
                                defaultIcon: Icons.scale,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              helperText: valuesFromPackingList
                                  ? 'Summe der Tara-Gewichte aus Packliste'
                                  : 'Gesamtgewicht der Verpackung in kg',
                              suffixIcon: valuesFromPackingList
                                  ?

                              getAdaptiveIcon(iconName: 'lock', defaultIcon:
                                Icons.lock,
                                size: 20,
                                color: Theme.of(context).colorScheme.outline,
                              )
                                  : null,
                            ),
                            onChanged: valuesFromPackingList ? null : (value) {
                              setDialogState(() {
                                packagingWeight = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),

                          // Zusätzlicher Hinweis unter den Feldern
                          if (!valuesFromPackingList)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Hinweis: Diese Werte können nur bearbeitet werden, solange keine Packliste erstellt wurde.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),
// Datum der Handelsrechnung
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: dialogContext,
                                initialDate: commercialInvoiceDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                locale: const Locale('de', 'DE'),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  commercialInvoiceDate = picked;
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
                                  getAdaptiveIcon(
                                    iconName: 'calendar_today',
                                    defaultIcon: Icons.calendar_today,
                                  ),
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
                                      icon: getAdaptiveIcon(
                                        iconName: 'clear',
                                        defaultIcon: Icons.clear,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          commercialInvoiceDate = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          // Commercial Invoice Standardsätze (Rest bleibt gleich)
                          Text(
                            'Standardsätze für Handelsrechnung',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),


                          // Ursprungserklärung - mit Info-Icon
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('Ursprungserklärung'),
                                  subtitle: const Text('Erklärung über Schweizer Ursprungswaren'),
                                  value: originDeclaration,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      originDeclaration = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                icon:    getAdaptiveIcon(iconName: 'info', defaultIcon:
                                  Icons.info,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () async {
                                  // Lade den Standardtext
                                  final defaultTexts = await _loadDefaultTextForType('origin_declaration', 'DE');

                                  showDialog(
                                    context: dialogContext,
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
                                                defaultTexts,
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
                                  value: cites,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      cites = value ?? false;
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
                                  final defaultTexts = await _loadDefaultTextForType('cites', 'DE');

                                  showDialog(
                                    context: dialogContext,
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
                                                defaultTexts,
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                getAdaptiveIcon(iconName: 'edit', defaultIcon:  Icons.edit,
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

                          // Grund des Exports - mit Freitext
                          CheckboxListTile(
                            title: const Text('Grund des Exports'),

                            value: exportReason,
                            onChanged: (value) {
                              setDialogState(() {
                                exportReason = value ?? false;
                              });
                            },
                          ),
                          if (exportReason)
                            Padding(
                              padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                              child: TextField(
                                controller: exportReasonTextController,
                                decoration: InputDecoration(
                                  labelText: 'Grund des Exports',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    exportReasonText = value;
                                  });
                                },
                              ),
                            ),

                          // Incoterms - Mehrfachauswahl mit individuellen Freitexten
                          CheckboxListTile(
                            title: const Text('Incoterms'),
                            value: incoterms,
                            onChanged: (value) {
                              setDialogState(() {
                                incoterms = value ?? false;
                                if (!incoterms) {
                                  selectedIncoterms.clear();
                                  incotermsFreeTexts.clear();
                                }
                              });
                            },
                          ),
                          if (incoterms) ...[
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
                                          final description = data['de'] as String? ?? data['en'] as String? ?? '';
                                          final isSelected = selectedIncoterms.contains(doc.id);

                                          return FilterChip(
                                            label: Text(name),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              setDialogState(() {
                                                if (selected) {
                                                  selectedIncoterms.add(doc.id);
                                                  incotermsFreeTexts[doc.id] = incotermsFreeTexts[doc.id] ?? '';
                                                  // Controller für neuen Incoterm erstellen
                                                  incotermControllers[doc.id] = TextEditingController(text: incotermsFreeTexts[doc.id] ?? '');
                                                } else {
                                                  selectedIncoterms.remove(doc.id);
                                                  incotermsFreeTexts.remove(doc.id);
                                                  // Controller entfernen
                                                  incotermControllers[doc.id]?.dispose();
                                                  incotermControllers.remove(doc.id);
                                                }
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

                          // Lieferdatum - mit Datumspicker und Format-Toggle
                          CheckboxListTile(
                            title: const Text('Lieferdatum'),
                            subtitle: selectedDeliveryDate != null
                                ? Text(deliveryDateMonthOnly
                                ? '${['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'][selectedDeliveryDate!.month - 1]} ${selectedDeliveryDate!.year}'
                                : '${selectedDeliveryDate!.day}.${selectedDeliveryDate!.month}.${selectedDeliveryDate!.year}')
                                : const Text('Datum auswählen'),
                            value: deliveryDate,
                            onChanged: (value) {
                              setDialogState(() {
                                deliveryDate = value ?? false;
                                if (!deliveryDate) selectedDeliveryDate = null;
                              });
                            },
                          ),
                          if (deliveryDate) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final date = await showDatePicker(
                                          context: dialogContext,
                                          initialDate: selectedDeliveryDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (date != null) {
                                          setDialogState(() {
                                            selectedDeliveryDate = date;
                                          });
                                        }
                                      },
                                      icon:getAdaptiveIcon(iconName: 'calendar_today', defaultIcon:Icons.calendar_today),
                                      label: Text(selectedDeliveryDate != null
                                          ? '${selectedDeliveryDate!.day}.${selectedDeliveryDate!.month}.${selectedDeliveryDate!.year}'
                                          : 'Datum auswählen'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                                      setDialogState(() {
                                        deliveryDateMonthOnly = index == 1;
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

                          // Transporteur - mit Freitext
                          CheckboxListTile(
                            title: const Text('Transporteur'),
                            subtitle: Text(carrierText),
                            value: carrier,
                            onChanged: (value) {
                              setDialogState(() {
                                carrier = value ?? false;
                              });
                            },
                          ),
                          if (carrier)
                            Padding(
                              padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                              child: TextField(
                                controller: carrierTextController,
                                decoration: InputDecoration(
                                  labelText: 'Transporteur',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    carrierText = value;
                                  });
                                },
                              ),
                            ),

                          // Signatur
                          CheckboxListTile(
                            title: const Text('Signatur'),
                            value: signature,
                            onChanged: (value) {
                              setDialogState(() {
                                signature = value ?? false;
                                if (!signature) selectedSignature = null;
                              });
                            },
                          ),
                          if (signature)
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
                                      setDialogState(() {
                                        selectedSignature = value;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Info-Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                getAdaptiveIcon(
                                  iconName: 'info',
                                  defaultIcon: Icons.info,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Diese Angaben werden für die Berechnung des Bruttogewichts und die Standardsätze in der Handelsrechnung verwendet.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Abbrechen'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Erweiterte Tara-Einstellungen speichern
                            await FirebaseFirestore.instance
                                .collection('temporary_document_settings')
                                .doc('tara_settings')
                                .set({
                              'number_of_packages': numberOfPackages,
                              'packaging_weight': packagingWeight,
                              'commercial_invoice_origin_declaration': originDeclaration,
                              'commercial_invoice_cites': cites,
                              'commercial_invoice_export_reason': exportReason,
                              'commercial_invoice_incoterms': incoterms,
                              'commercial_invoice_delivery_date': deliveryDate,
                              'commercial_invoice_carrier': carrier,
                              'commercial_invoice_signature': signature,
                              'commercial_invoice_export_reason_text': exportReasonText,
                              'commercial_invoice_selected_incoterms': selectedIncoterms,
                              'commercial_invoice_incoterms_freetexts': incotermsFreeTexts,
                              'commercial_invoice_delivery_date_value': selectedDeliveryDate != null ? Timestamp.fromDate(selectedDeliveryDate!) : null,
                              'commercial_invoice_delivery_date_month_only': deliveryDateMonthOnly,
                              'commercial_invoice_carrier_text': carrierText,
                              'commercial_invoice_selected_signature': selectedSignature,
                              'timestamp': FieldValue.serverTimestamp(),
                              'commercial_invoice_date': commercialInvoiceDate != null
                                  ? Timestamp.fromDate(commercialInvoiceDate!)
                                  : null,
                            });

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Handelsrechnung-Einstellungen gespeichert'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          icon: getAdaptiveIcon(
                            iconName: 'save',
                            defaultIcon: Icons.save,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          label: const Text('Speichern'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


// Hilfsfunktion zum Zuweisen aller Produkte zu einem Paket
  void _assignAllItemsToPackage(
      Map<String, dynamic> targetPackage,
      List<Map<String, dynamic>> items,
      List<Map<String, dynamic>> packages,
      StateSetter setDialogState,
      ) {
    setDialogState(() {
      // Leere zuerst alle Items aus dem Zielpaket
      targetPackage['items'].clear();

      // Füge alle verfügbaren Items hinzu
      for (final item in items) {
        final totalQuantity = item['quantity'] as double;

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
          'product_name_en': item['product_name_en'] ?? '',
          'quantity': totalQuantity,

          // Maße korrekt übernehmen
          'custom_length': item['custom_length'] ?? 0.0,
          'custom_width': item['custom_width'] ?? 0.0,
          'custom_thickness': item['custom_thickness'] ?? 0.0,
          'density': item['density'] ?? 0.0,
          'volume_per_unit': item['volume_per_unit'] ?? 0.0,

          // Weitere wichtige Felder
          'wood_code': item['wood_code'] ?? '',
          'wood_name': item['wood_name'] ?? '',
          'unit': item['unit'] ?? 'Stk',
          'instrument_code': item['instrument_code'] ?? '',
          'instrument_name': item['instrument_name'] ?? '',
          'instrument_name_en': item['instrument_name_en'] ?? '',
          'part_code': item['part_code'] ?? '',
          'part_name': item['part_name'] ?? '',
          'part_name_en': item['part_name_en'] ?? '',
          'quality_code': item['quality_code'] ?? '',
          'quality_name': item['quality_name'] ?? '',
        });
      }
    });
  }
  Future<void> showPackingListSettingsDialog() async {
    // Lade bestehende Packlisten-Einstellungen
    final existingSettings = await DocumentSelectionManager.loadPackingListSettings();
    List<Map<String, dynamic>> packages = List<Map<String, dynamic>>.from(existingSettings['packages'] ?? []);

    // NEU: Map für TextEditingController
    final Map<String, Map<String, TextEditingController>> packageControllers = {};

    // Lade die Produkte aus temporary_basket (wie bei den anderen Dokumenten)
    final basketSnapshot = await FirebaseFirestore.instance
        .collection('temporary_basket')
        .get();


// WICHTIG: Stelle sicher, dass ALLE Felder kopiert werden
    List<Map<String, dynamic>> items = basketSnapshot.docs.map((doc) {
      final data = doc.data();
      print('Lade Item aus Basket: ${data['product_name']}');
      print('  custom_length: ${data['custom_length']}');
      print('  custom_width: ${data['custom_width']}');
      print('  custom_thickness: ${data['custom_thickness']}');
      print('  density: ${data['density']}');
      return {
        ...data,  // Das kopiert ALLE Felder aus dem Dokument
        'doc_id': doc.id,
      };
    }).toList();

// NEU: Filtere Dienstleistungen heraus
    items = items.where((item) => item['is_service'] != true).toList();

// Debug-Ausgabe
    print('=== Verfügbare Items mit Maßen (ohne Dienstleistungen) ===');
    for (final item in items) {
      print('${item['product_name']}: ${item['custom_length']}×${item['custom_width']}×${item['custom_thickness']}');
    }
    // Falls noch keine Pakete existieren, erstelle Paket 1
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
        'gross_weight': null,
      });

      // Controller für das erste Paket
      packageControllers[firstPackageId] = {
        'length': TextEditingController(text: '0.0'),
        'width': TextEditingController(text: '0.0'),
        'height': TextEditingController(text: '0.0'),
        'weight': TextEditingController(text: '0.0'),
        'custom_name': TextEditingController(text: ''),
        'gross_weight': TextEditingController(text: ''),
      };
    } else {
      // Initialisiere Controller für existierende Pakete
      for (final package in packages) {
        final packageId = package['id'] as String;
        packageControllers[packageId] = {
          'length': TextEditingController(text: package['length'].toString()),
          'width': TextEditingController(text: package['width'].toString()),
          'height': TextEditingController(text: package['height'].toString()),
          'weight': TextEditingController(text: package['tare_weight'].toString()),

          'custom_name': TextEditingController(text: package['packaging_type'] ?? ''),
          'gross_weight': TextEditingController(
              text: package['gross_weight'] != null ? package['gross_weight'].toString() : ''
          ), // NEU: von Anfang an hinzufügen
        };
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // NEU: AnimatedPadding für Keyboard-Anpassung
          return AnimatedPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
              ),
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) => Container(
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
                          child: getAdaptiveIcon(
                            iconName: 'view_list',
                            defaultIcon: Icons.view_list,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Packliste',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: getAdaptiveIcon(
                            iconName: 'close',
                            defaultIcon: Icons.close,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                        controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                                        'Verfügbare Produkte',
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
                                          _assignAllItemsToPackage(
                                            packages.first, // Paket 1
                                            items,
                                            packages,
                                            setDialogState,
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Alle Produkte wurden Paket 1 zugewiesen'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        icon:getAdaptiveIcon(iconName: 'inbox', defaultIcon:
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
                                ...items.map((item) {
                                  final assignedQuantity = _getAssignedQuantity(item, packages);
                                  final remainingQuantity = (item['quantity'] as num? ?? 0).toDouble() - assignedQuantity;

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
                                            '$remainingQuantity/${item['quantity']} verbleibend',
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
                                  setDialogState(() {
                                    final newPackageId = DateTime.now().millisecondsSinceEpoch.toString(); // NEU: Eindeutige ID

                                    // Erstelle Controller für das neue Paket
                                    packageControllers[newPackageId] = {
                                      'length': TextEditingController(text: '0.0'),
                                      'width': TextEditingController(text: '0.0'),
                                      'height': TextEditingController(text: '0.0'),
                                      'weight': TextEditingController(text: '0.0'),
                                      'custom_name': TextEditingController(text: ''),
                                      'gross_weight': TextEditingController(text: ''),
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
                                      'gross_weight': null,
                                    });
                                  });
                                },
                                icon: getAdaptiveIcon(iconName: 'add', defaultIcon:Icons.add, size: 16),
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
                            return _buildPackageCard(
                              context,
                              package,
                              index,
                              items,
                              packages,
                              setDialogState,
                              packageControllers, // NEU: Controller Map übergeben
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Schließe den Dialog
                              Navigator.pop(dialogContext);

                              // Dispose alle Controller nach dem Schließen
                              Future.delayed(const Duration(milliseconds: 100), () {
                                packageControllers.forEach((packageId, controllers) {
                                  controllers.forEach((_, controller) {
                                    try {
                                      controller.dispose();
                                    } catch (e) {
                                      // Controller war bereits disposed
                                    }
                                  });
                                });
                                packageControllers.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Speichere die Packlisten-Einstellungen
                              await DocumentSelectionManager.savePackingListSettings(packages);

                              // Schließe den Dialog
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);

                                // Zeige Erfolgsmeldung
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Packliste-Einstellungen gespeichert'),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                // Dispose ALLE Controller nach dem Schließen des Dialogs
                                // Dies verhindert den "controller used after dispose" Fehler
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  packageControllers.forEach((packageId, controllers) {
                                    controllers.forEach((_, controller) {
                                      // Prüfe ob der Controller noch nicht disposed wurde
                                      try {
                                        controller.dispose();
                                      } catch (e) {
                                        // Controller war bereits disposed
                                      }
                                    });
                                  });
                                  packageControllers.clear();
                                });
                              }
                            },
                            icon: getAdaptiveIcon(
                              iconName: 'save',
                              defaultIcon: Icons.save,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            label: const Text('Speichern'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ));
        },
      ),
    );
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
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
                      const SizedBox(height: 20),

                      // In showDocumentSelectionBottomSheet, ersetze die Dokumenten-Liste mit dieser Version:
                      // NEU: Hinweis zu Abhängigkeiten
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
                                            await showDeliveryNoteSettingsDialog();
                                            break;
                                          case 'Handelsrechnung':
                                            await showTaraSettingsDialog();
                                            break;
                                          case 'Packliste':
                                            await showPackingListSettingsDialog();
                                            break;
                                          case 'Rechnung':
                                            await showInvoiceSettingsDialog();
                                            break;
                                          case 'Offerte':
                                            await showQuoteSettingsDialog();
                                            break;
                                          default:
                                          // Für alle anderen zeige eine Info-Nachricht
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
                                      value: documentSelection[docType] ?? false,
                                      onChanged: isDisabled ? null : (value) async {
                                        // Validierungslogik
                                        if (isDependent && value == true && documentSelection['Rechnung'] != true) {
                                          // Zeige Hinweis
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

                                        // Wenn Rechnung deaktiviert wird, deaktiviere auch abhängige Dokumente
                                        if (docType == 'Rechnung' && value == false) {
                                          bool hasActiveDependents = dependentDocuments.any(
                                                  (doc) => documentSelection[doc] == true
                                          );

                                          if (hasActiveDependents) {
                                            // Zeige Warndialog
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

                                            // Deaktiviere alle abhängigen Dokumente
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