// File: services/document_selection_manager.dart (Erweiterte Version)
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tonewood/services/pdf_generators/commercial_invoice_generator.dart';
import 'package:tonewood/services/pdf_generators/delivery_note_generator.dart';
import 'package:tonewood/services/pdf_generators/packing_list_generator.dart';
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
      await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('packing_list_settings')
          .set({
        'packages': packages,
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

  // Zeige Handelsrechnung-Preview
  static Future<void> _showCommercialInvoicePreview(BuildContext context, Map<String, dynamic> data, {String? language}) async {
    try {
      final customerData = data['customer'] as Map<String, dynamic>;
      final documentLanguage = language ?? customerData['language'] ?? 'DE';
      final shippingCosts = await ShippingCostsManager.loadShippingCosts();

      // NEU: Lade Tara-Einstellungen
      final taraSettings = await loadTaraSettings();

      final basketItems = data['basketItems'] as List<Map<String, dynamic>>;

      // Berechne Rabatte für Preview
      final calculations = await _calculateDiscountsForPreview(basketItems);

      // Lade Steuereinstellungen
      final taxOption = data['taxOption'] ?? 0;
      final vatRate = data['vatRate'] ?? 8.1;

      // Konvertiere Basket-Items zu Items für PDF
      final items = basketItems.map((basketItem) {
        final customPriceValue = basketItem['custom_price_per_unit'];
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue as num).toDouble()
            : (basketItem['price_per_unit'] as num).toDouble();

        final quantity = (basketItem['quantity'] as num).toDouble();
        final itemSubtotal = quantity * pricePerUnit;

        final discount = basketItem['discount'] as Map<String, dynamic>? ?? {'percentage': 0.0, 'absolute': 0.0};

        double discountAmount = 0.0;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();
          discountAmount = (itemSubtotal * (percentage / 100)) + absolute;
        }

        return {
          ...basketItem,
          'price_per_unit': pricePerUnit,
          'discount': discount,
          'discount_amount': discountAmount,
          'total': itemSubtotal - discountAmount,
        };
      }).toList();

      final currency = 'CHF';
      final exchangeRates = {'CHF': 1.0, 'EUR': 0.96, 'USD': 1.08};

      final costCenter = data['costCenter'];
      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';

      final pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
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
        taraSettings: taraSettings, // NEU: Übergebe Tara-Einstellungen
      );

      if (context.mounted) {
        Navigator.pop(context);
        _openPdfViewer(context, pdfBytes, 'Handelsrechnung_Preview.pdf');
      }
    } catch (e) {
      print('Fehler bei Handelsrechnung-Preview: $e');
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

// Lade Tara-Einstellungen
  static Future<Map<String, dynamic>> loadTaraSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('tara_settings')
          .get();

      if (doc.exists) {
        return doc.data()!;
      }
    } catch (e) {
      print('Fehler beim Laden der Tara-Einstellungen: $e');
    }

    return {'number_of_packages': 1, 'packaging_weight': 0.0};
  }



  // Löscht die aktuelle Auswahl
  static Future<void> clearSelection() async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_document_selection')
          .doc('current_selection')
          .delete();
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
        final customPriceValue = item['custom_price_per_unit'];
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue as num).toDouble()
            : (item['price_per_unit'] as num).toDouble();

        final itemSubtotal = (item['quantity'] as int) * pricePerUnit;

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
          return sum + ((item['quantity'] as int) * pricePerUnit);
        });

        final subtotalAfterItemDiscounts = subtotal - itemDiscounts;
        totalDiscountAmount = (subtotalAfterItemDiscounts * (totalPercentage / 100)) + totalAbsolute;

        // Debug
        print('Total discount data: $totalDiscountData');
        print('Calculated total discount: $totalDiscountAmount');
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

      final currency = 'CHF';
      final exchangeRates = {'CHF': 1.0, 'EUR': 0.96, 'USD': 1.08};

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
  static Future<void> _showPackingListPreview(BuildContext context, Map<String, dynamic> data, {String? language}) async {
    try {
      final customerData = data['customer'] as Map<String, dynamic>;
      final documentLanguage = language ?? customerData['language'] ?? 'DE';

      final costCenter = data['costCenter'];
      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';

      final pdfBytes = await PackingListGenerator.generatePackingListPdf(
        language: documentLanguage,
        packingListNumber: 'PREVIEW',
        customerData: data['customer'],
        fairData: data['fair'],
        costCenterCode: costCenterCode,
      );

      if (context.mounted) {
        Navigator.pop(context);
        _openPdfViewer(context, pdfBytes, 'Packliste_Preview.pdf');
      }
    } catch (e) {
      print('Fehler bei Packliste-Preview: $e');
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
  static Future<void> _showQuotePreview(BuildContext context, Map<String, dynamic> data, {String? language}) async {
    try {
      final customerData = data['customer'] as Map<String, dynamic>;
      final documentLanguage = language ?? customerData['language'] ?? 'DE';
      final shippingCosts = await ShippingCostsManager.loadShippingCosts();
      final taxOption = data['taxOption'] ?? 0;
      final vatRate = data['vatRate'] ?? 8.1;
      final basketItems = data['basketItems'] as List<Map<String, dynamic>>;

      // Berechne Rabatte für Preview - das lädt bereits den Gesamtrabatt!
      final calculations = await _calculateDiscountsForPreview(basketItems);

      // Konvertiere Basket-Items zu Items für PDF
      final items = basketItems.map((basketItem) {
        final customPriceValue = basketItem['custom_price_per_unit'];
        final pricePerUnit = customPriceValue != null
            ? (customPriceValue as num).toDouble()
            : (basketItem['price_per_unit'] as num).toDouble();

        final quantity = (basketItem['quantity'] as num).toDouble();
        final itemSubtotal = quantity * pricePerUnit;

        // Rabatt ist BEREITS im basketItem gespeichert!
        final discount = basketItem['discount'] as Map<String, dynamic>? ?? {'percentage': 0.0, 'absolute': 0.0};

        double discountAmount = 0.0;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();
          discountAmount = (itemSubtotal * (percentage / 100)) + absolute;
        }

        return {
          ...basketItem,
          'price_per_unit': pricePerUnit,
          'discount': discount,
          'discount_amount': discountAmount,
          'total': itemSubtotal - discountAmount,
        };
      }).toList();

      final currency = 'CHF';
      final exchangeRates = {'CHF': 1.0, 'EUR': 0.96, 'USD': 1.08};

      final costCenter = data['costCenter'];
      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';

      // Debug
      print('Total discount from calculations: ${calculations['total_discount_amount']}');

      final pdfBytes = await QuoteGenerator.generateQuotePdf(
        items: items,
        customerData: data['customer'],
        fairData: data['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: documentLanguage,
        quoteNumber: 'PREVIEW',
        shippingCosts: shippingCosts,
        calculations: calculations, // Hier wird der Gesamtrabatt übergeben!
        taxOption: taxOption,  // NEU
        vatRate: vatRate,      // NEU
      );

      if (context.mounted) {
        Navigator.pop(context);
        _openPdfViewer(context, pdfBytes, 'Offerte_Preview.pdf');
      }
    } catch (e) {
      print('Fehler bei Offerte-Preview: $e');
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

      final currency = 'CHF';
      final exchangeRates = {'CHF': 1.0, 'EUR': 0.96, 'USD': 1.08};

      final costCenter = data['costCenter'];
      final costCenterCode = costCenter != null ? costCenter['code'] : '00000';

      final pdfBytes = await InvoiceGenerator.generateInvoicePdf(
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
int _getAssignedQuantity(Map<String, dynamic> item, List<Map<String, dynamic>> packages) {
  int totalAssigned = 0;
  for (final package in packages) {
    final packageItems = package['items'] as List<dynamic>;
    for (final assignedItem in packageItems) {
      if (assignedItem['product_id'] == item['product_id']) {
        totalAssigned += assignedItem['quantity'] as int;
      }
    }
  }
  return totalAssigned;
}

Widget _buildPackageCard(
    BuildContext context,
    BuildContext dialogContext,
    Map<String, dynamic> package,
    int index,
    List<dynamic> availableItems,
    List<Map<String, dynamic>> packages,
    StateSetter setDialogState,
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
                    setDialogState(() {
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
              setDialogState(() {
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
                        setDialogState(() {
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
            onPressed: () => _showAddProductDialog(
              dialogContext,
              package,
              availableItems,
              packages,
              setDialogState,
            ),
            icon: Icon(Icons.add, size: 16),
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
            final remainingQuantity = (item['quantity'] as int) - assignedQuantity;

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
    int maxQuantity,
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
              // Debug vor dem Hinzufügen
              print('=== Füge zu Package hinzu ===');
              print('custom_length: ${item['custom_length']}');
              print('custom_width: ${item['custom_width']}');
              print('custom_thickness: ${item['custom_thickness']}');

              setDialogState(() {
                package['items'].add({
                  'product_id': item['product_id'],
                  'product_name': item['product_name'],
                  'quantity': selectedQuantity,
                  'weight_per_unit': item['weight'] ?? 0.0,
                  'volume_per_unit': item['volume'] ?? 0.0,
                  // Maße korrekt übernehmen
                  'custom_length': item['custom_length'] ?? 0.0,
                  'custom_width': item['custom_width'] ?? 0.0,
                  'custom_thickness': item['custom_thickness'] ?? 0.0,
                  // Weitere wichtige Felder
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



Future<void> showDocumentSelectionBottomSheet(BuildContext context, {
  required ValueNotifier<bool> selectionCompleteNotifier,
  ValueNotifier<String>? documentLanguageNotifier,
}) async {
  Map<String, bool> documentSelection = await DocumentSelectionManager.loadDocumentSelection();


  print("documentLanguageNotifier passed: $documentLanguageNotifier");
  final hasSelection = documentSelection.values.any((selected) => selected == true);
  selectionCompleteNotifier.value = hasSelection;
  // Verwende den übergebenen documentLanguageNotifier direkt
  final languageNotifier = documentLanguageNotifier ?? ValueNotifier<String>('DE');
  final dependentDocuments = ['Lieferschein', 'Handelsrechnung', 'Packliste'];


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

    // Commercial Invoice Standardsätze
    bool originDeclaration = false;
    bool cites = false;
    bool exportReason = false;
    bool incoterms = false;
    bool deliveryDate = false;
    bool carrier = false;
    bool signature = false;
    List<String> selectedIncoterms = [];
    Map<String, String> incotermsFreeTexts = {}; // Für jeden Incoterm eigener Freitext
    String exportReasonText = 'Ware';
    String carrierText = 'Swiss Post';
    DateTime? selectedDeliveryDate;
    bool deliveryDateMonthOnly = false; // Toggle für nur Monatsangabe
    String? selectedSignature;

    // Lade bestehende Einstellungen
    final existingSettings = await DocumentSelectionManager.loadTaraSettings();
    numberOfPackages = existingSettings['number_of_packages'] ?? 1;
    packagingWeight = (existingSettings['packaging_weight'] ?? 0.0).toDouble();

    // Lade Commercial Invoice Einstellungen
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

    // Lieferdatum aus Lieferschein laden falls vorhanden
    if (existingSettings['commercial_invoice_delivery_date_value'] != null) {
      final timestamp = existingSettings['commercial_invoice_delivery_date_value'];
      if (timestamp is Timestamp) {
        selectedDeliveryDate = timestamp.toDate();
      }
    }

    final numberOfPackagesController = TextEditingController(text: numberOfPackages.toString());
    final packagingWeightController = TextEditingController(text: packagingWeight.toString());
    final exportReasonTextController = TextEditingController(text: exportReasonText);
    final carrierTextController = TextEditingController(text: carrierText);

    // Controller für Incoterm-Freitexte - außerhalb des StatefulBuilder
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
                                  iconName: 'inventory_2',
                                  defaultIcon: Icons.inventory_2,
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

                          // Anzahl Packungen
                          TextField(
                            controller: numberOfPackagesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Anzahl Packungen',
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'inventory',
                                defaultIcon: Icons.inventory,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              helperText: 'Anzahl der Verpackungseinheiten',
                            ),
                            onChanged: (value) {
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
                            decoration: InputDecoration(
                              labelText: 'Verpackungsgewicht (kg)',
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'scale',
                                defaultIcon: Icons.scale,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              helperText: 'Gesamtgewicht der Verpackung in kg',
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                packagingWeight = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),

                          const SizedBox(height: 24),

                          // Commercial Invoice Standardsätze
                          Text(
                            'Standardsätze für Handelsrechnung',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Ursprungserklärung
                          CheckboxListTile(
                            title: const Text('Ursprungserklärung'),
                            subtitle: const Text('Erklärung über Schweizer Ursprungswaren'),
                            value: originDeclaration,
                            onChanged: (value) {
                              setDialogState(() {
                                originDeclaration = value ?? false;
                              });
                            },
                          ),

                          // CITES
                          CheckboxListTile(
                            title: const Text('CITES'),
                            subtitle: const Text('Waren stehen NICHT auf der CITES-Liste'),
                            value: cites,
                            onChanged: (value) {
                              setDialogState(() {
                                cites = value ?? false;
                              });
                            },
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
                                      icon: Icon(Icons.calendar_today),
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
                                  iconName: 'info_outline',
                                  defaultIcon: Icons.info_outline,
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
  Future<void> showPackingListSettingsDialog() async {
    // Lade bestehende Packlisten-Einstellungen
    final existingSettings = await DocumentSelectionManager.loadPackingListSettings();
    List<Map<String, dynamic>> packages = List<Map<String, dynamic>>.from(existingSettings['packages'] ?? []);

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

      return {
        ...data,  // Das kopiert ALLE Felder aus dem Dokument
        'doc_id': doc.id,
      };
    }).toList();

    // Debug-Ausgabe
    print('=== Verfügbare Items mit Maßen ===');
    for (final item in items) {
      print('${item['product_name']}: ${item['custom_length']}×${item['custom_width']}×${item['custom_thickness']}');
    }


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
        'items': <Map<String, dynamic>>[], // Zugewiesene Produkte
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                                'Verfügbare Produkte',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...items.map((item) {
                                final assignedQuantity = _getAssignedQuantity(item, packages);
                                final remainingQuantity = (item['quantity'] as int) - assignedQuantity;

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
                              icon: Icon(Icons.add, size: 16),
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

                          return _buildPackageCard(
                            context,
                            dialogContext,
                            package,
                            index,
                            items,
                            packages,
                            setDialogState,
                          );
                        }).toList(),
                      ],
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
                            await DocumentSelectionManager.savePackingListSettings(packages);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Packliste-Einstellungen gespeichert'),
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
                              Icon(
                                Icons.warning_amber_rounded,
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
                                                    'Wenn Sie die Rechnung deaktivieren, werden auch Lieferschein, '
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