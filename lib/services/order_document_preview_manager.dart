// File: services/order_document_preview_manager.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/order_model.dart';
import 'pdf_generators/quote_generator.dart';
import 'pdf_generators/invoice_generator.dart';
import 'pdf_generators/commercial_invoice_generator.dart';
import 'pdf_generators/delivery_note_generator.dart';
import 'pdf_generators/packing_list_generator.dart';
import 'preview_pdf_viewer_screen.dart';
import 'shipping_costs_manager.dart';

class OrderDocumentPreviewManager {
  // Zeige Dokument-Preview für einen Auftrag
  static Future<void> showDocumentPreview({
    required BuildContext context,
    required OrderX order,
    required String documentType,
  }) async {
    try {
      // Zeige Loading-Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Lade Auftragsdaten
      final orderData = await _loadOrderData(order);

      if (context.mounted) {
        Navigator.pop(context); // Schließe Loading-Dialog
      }

      if (orderData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler beim Laden der Auftragsdaten'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Generiere entsprechendes PDF
      switch (documentType) {
        case 'quote_pdf':
        case 'Angebot':
          await _showQuotePreview(context, orderData, order);
          break;
        case 'invoice_pdf':
        case 'Rechnung':
          await _showInvoicePreview(context, orderData, order);
          break;
        case 'commercial_invoice_pdf':
        case 'Handelsrechnung':
          await _showCommercialInvoicePreview(context, orderData, order);
          break;
        case 'delivery_note_pdf':
        case 'Lieferschein':
          await _showDeliveryNotePreview(context, orderData, order);
          break;
        case 'packing_list_pdf':
        case 'Packliste':
          await _showPackingListPreview(context, orderData, order);
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

  // Lade Auftragsdaten
  static Future<Map<String, dynamic>?> _loadOrderData(OrderX order) async {
    try {
      // Lade zusätzliche Daten falls nötig
      final metadata = order.metadata;

      // Lade Quote-Daten falls vorhanden
      Map<String, dynamic>? quoteData;
      if (order.quoteId != null && order.quoteId!.isNotEmpty) {
        final quoteDoc = await FirebaseFirestore.instance
            .collection('quotes')
            .doc(order.quoteId)
            .get();
        if (quoteDoc.exists) {
          quoteData = quoteDoc.data();
        }
      }

      // Lade Kostenstelle falls in Quote
      Map<String, dynamic>? costCenter;
      if (quoteData != null && quoteData['costCenter'] != null) {
        costCenter = quoteData['costCenter'];
      }

      // Lade Messe falls in Quote
      Map<String, dynamic>? fair;
      if (quoteData != null && quoteData['fair'] != null) {
        fair = quoteData['fair'];
      }

      return {
        'order': order,
        'customer': order.customer,
        'items': order.items,
        'calculations': order.calculations,
        'metadata': metadata,
        'costCenter': costCenter,
        'fair': fair,
        'quoteData': quoteData,
      };
    } catch (e) {
      print('Fehler beim Laden der Auftragsdaten: $e');
      return null;
    }
  }

  // Preview für Angebot
  static Future<void> _showQuotePreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      final customer = orderData['customer'] as Map<String, dynamic>;
    final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
      final metadata = orderData['metadata'] ?? {};

      // Lade Versandkosten aus Order-Metadaten
      final shippingCosts = metadata['shippingCosts'] ?? {};

      final currency = metadata['currency'] ?? 'CHF';
      final exchangeRates = Map<String, double>.from(metadata['exchangeRates'] ?? {'CHF': 1.0});
      final costCenterCode = orderData['costCenter']?['code'] ?? '00000';

      final pdfBytes = await QuoteGenerator.generateQuotePdf(
        items: orderData['items'],
        customerData: customer,
        fairData: orderData['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: language,
        quoteNumber: order.quoteNumber ?? 'PREVIEW',
        shippingCosts: shippingCosts,
        calculations: orderData['calculations'],
        taxOption: metadata['taxOption'] ?? 0,
        vatRate: (metadata['vatRate'] ?? 8.1).toDouble(),
      );

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Angebot_${order.quoteNumber}.pdf');
      }
    } catch (e) {
      print('Fehler bei Angebot-Preview: $e');
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> _loadOrderInvoiceSettings(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('settings')
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
        };
      }
    } catch (e) {
      print('Fehler beim Laden der Rechnungs-Einstellungen: $e');
    }

    return {
      'down_payment_amount': 0.0,
      'down_payment_reference': '',
      'down_payment_date': null,
    };
  }
  // Preview für Rechnung
// Preview für Rechnung
  static Future<void> _showInvoicePreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      print('=== _showInvoicePreview DEBUG START ===');

      final customer = orderData['customer'] as Map<String, dynamic>;
      print('Customer loaded: ${customer.keys.toList()}');

      final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
      print('Language: $language');

      final metadata = orderData['metadata'] ?? {};
      print('Metadata keys: ${metadata.keys.toList()}');

      final shippingCosts = metadata['shippingCosts'] ?? {};
      print('ShippingCosts: $shippingCosts');

      final currency = metadata['currency'] ?? 'CHF';
      final exchangeRates = Map<String, double>.from(metadata['exchangeRates'] ?? {'CHF': 1.0});
      print('Currency: $currency, ExchangeRates: $exchangeRates');

      final costCenterCode = orderData['costCenter']?['code'] ?? '00000';
      print('CostCenterCode: $costCenterCode');

      // HIER RUFST DU DIE METHODE AUF:
      final invoiceSettings = await _loadOrderInvoiceSettings(order.id);
      print('InvoiceSettings loaded: $invoiceSettings');

      print('Calling InvoiceGenerator.generateInvoicePdf...');
      print('Items count: ${orderData['items']?.length}');
      print('Calculations: ${orderData['calculations']}');

      final pdfBytes = await InvoiceGenerator.generateInvoicePdf(
        items: orderData['items'],
        customerData: customer,
        fairData: orderData['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: language,
        invoiceNumber: order.orderNumber,
        shippingCosts: shippingCosts,
        calculations: orderData['calculations'],
        paymentTermDays: 30,
        taxOption: metadata['taxOption'] ?? 0,
        vatRate: (metadata['vatRate'] ?? 8.1).toDouble(),
        downPaymentSettings: invoiceSettings,
      );

      print('PDF generated successfully');

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Rechnung_${order.orderNumber}.pdf');
      }
    } catch (e, stackTrace) {
      print('=== ERROR DETAILS ===');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('=== END ERROR ===');
      rethrow;
    }
  }
  // Preview für Handelsrechnung
  static Future<void> _showCommercialInvoicePreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      final customer = orderData['customer'] as Map<String, dynamic>;
    final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
      final metadata = orderData['metadata'] ?? {};

      final shippingCosts = metadata['shippingCosts'] ?? {};
      final currency = metadata['currency'] ?? 'CHF';
      final exchangeRates = Map<String, double>.from(metadata['exchangeRates'] ?? {'CHF': 1.0});
      final costCenterCode = orderData['costCenter']?['code'] ?? '00000';

      // Lade Tara-Einstellungen für diesen Auftrag
      final taraSettings = await _loadOrderTaraSettings(order.id);


      // NEU: Extrahiere das Datum aus den Tara-Einstellungen
      DateTime? invoiceDate;
      if (taraSettings['commercial_invoice_date'] != null) {
        final dateValue = taraSettings['commercial_invoice_date'];
        if (dateValue is Timestamp) {
          invoiceDate = dateValue.toDate();
        } else if (dateValue is DateTime) {
          invoiceDate = dateValue;
        }
      }

      print("testxxx:$invoiceDate");
      final pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
        items: orderData['items'],
        customerData: customer,
        fairData: orderData['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: language,
        invoiceNumber: '${order.orderNumber}-CI',
        shippingCosts: shippingCosts,
        calculations: orderData['calculations'],
        taxOption: metadata['taxOption'] ?? 0,
        vatRate: (metadata['vatRate'] ?? 8.1).toDouble(),
        taraSettings: taraSettings,
          invoiceDate: invoiceDate
      );

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Handelsrechnung_${order.orderNumber}.pdf');
      }
    } catch (e) {
      print('Fehler bei Handelsrechnung-Preview: $e');
      rethrow;
    }
  }

  // Preview für Lieferschein
  static Future<void> _showDeliveryNotePreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      print('=== DELIVERY NOTE PREVIEW DEBUG ===');
      print('Order ID: ${order.id}');
      print('Order Number: ${order.orderNumber}');

      // Prüfe customer
      final customer = orderData['customer'] as Map<String, dynamic>?;
      print('Customer exists: ${customer != null}');
      if (customer != null) {
        print('Customer keys: ${customer.keys.toList()}');
      }


      final language = orderData['metadata']?['language'] ?? customer?['language'] ?? 'DE';
      print('Language: $language');

      // Prüfe metadata
      final metadata = orderData['metadata'] as Map<String, dynamic>?;
      print('Metadata exists: ${metadata != null}');
      if (metadata != null) {
        print('Metadata keys: ${metadata.keys.toList()}');
      }

      final currency = metadata?['currency'] ?? 'CHF';
      print('Currency: $currency');

      final exchangeRatesRaw = metadata?['exchangeRates'];
      print('ExchangeRates raw: $exchangeRatesRaw');
      print('ExchangeRates type: ${exchangeRatesRaw.runtimeType}');

      final exchangeRates = Map<String, double>.from(exchangeRatesRaw ?? {'CHF': 1.0});
      print('ExchangeRates converted: $exchangeRates');

      // Prüfe costCenter
      final costCenter = orderData['costCenter'];
      print('CostCenter exists: ${costCenter != null}');
      final costCenterCode = costCenter?['code'] ?? '00000';
      print('CostCenterCode: $costCenterCode');

      // Prüfe items
      final items = orderData['items'];
      print('Items exists: ${items != null}');
      print('Items count: ${items?.length}');

      // Prüfe fair
      final fairData = orderData['fair'];
      print('Fair data exists: ${fairData != null}');

      // Lade Lieferschein-Einstellungen
      print('Loading delivery settings...');
      final deliverySettings = await _loadOrderDeliverySettings(order.id);
      print('Delivery settings: $deliverySettings');

      print('Calling DeliveryNoteGenerator...');

      final pdfBytes = await DeliveryNoteGenerator.generateDeliveryNotePdf(
        items: items,
        customerData: customer!,  // Hier könnte der Fehler sein
        fairData: fairData,
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: language,
        deliveryNoteNumber: '${order.orderNumber}-LS',
        deliveryDate: deliverySettings['delivery_date'],
        paymentDate: deliverySettings['payment_date'],
      );

      print('PDF generated successfully');

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Lieferschein_${order.orderNumber}.pdf');
      }
    } catch (e, stackTrace) {
      print('=== DELIVERY NOTE ERROR ===');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('=== END ERROR ===');
      rethrow;
    }
  }

  // Preview für Packliste
// Preview für Packliste
  static Future<void> _showPackingListPreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      final customer = orderData['customer'] as Map<String, dynamic>;
    final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
      final costCenterCode = orderData['costCenter']?['code'] ?? '00000';

      // Lade Packlisten-Einstellungen direkt aus Firebase
      final packingListDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .collection('packing_list')
          .doc('settings')
          .get();

      if (!packingListDoc.exists) {
        // Zeige Nachricht, dass keine Packliste konfiguriert ist
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Keine Packliste konfiguriert'),
              content: const Text(
                  'Für diesen Auftrag wurde noch keine Packliste konfiguriert. '
                      'Bitte erstellen Sie zuerst eine Packliste über "Dokumente erstellen".'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final pdfBytes = await PackingListGenerator.generatePackingListPdf(
        language: language,
        packingListNumber: '${order.orderNumber}-PL',
        customerData: customer,
        fairData: orderData['fair'],
        costCenterCode: costCenterCode,
        orderId: order.id,  // Übergebe die Order ID
      );

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Packliste_${order.orderNumber}.pdf');
      }
    } catch (e) {
      print('Fehler bei Packliste-Preview: $e');
      rethrow;
    }
  }

// Ersetze die _loadOrderTaraSettings Methode:
  static Future<Map<String, dynamic>> _loadOrderTaraSettings(String orderId) async {
    try {
      // Lade order-spezifische Einstellungen
      final orderSettingsDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('settings')
          .doc('tara_settings')
          .get();

      Map<String, dynamic> settings = {};
      if (orderSettingsDoc.exists) {
        settings = orderSettingsDoc.data() ?? {};
      }

      // NEU: Lade Verpackungsgewicht aus Packliste
      double packagingWeight = 0.0;
      int numberOfPackages = settings['number_of_packages'] ?? 1;

      try {
        final packingListDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
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
        print('Fehler beim Laden des Verpackungsgewichts aus Packliste: $e');
      }

      // Überschreibe mit Werten aus Packliste
      settings['number_of_packages'] = numberOfPackages;
      settings['packaging_weight'] = packagingWeight;

      return settings;
    } catch (e) {
      print('Fehler beim Laden der Tara-Einstellungen: $e');
      return {'number_of_packages': 1, 'packaging_weight': 0.0};
    }
  }

  static Future<Map<String, DateTime?>> _loadOrderDeliverySettings(String orderId) async {
    try {
      final orderSettingsDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('settings')
          .doc('delivery_settings')
          .get();

      if (orderSettingsDoc.exists) {
        final data = orderSettingsDoc.data()!;
        return {
          'delivery_date': data['delivery_date'] != null
              ? (data['delivery_date'] as Timestamp).toDate()
              : null,
          'payment_date': data['payment_date'] != null
              ? (data['payment_date'] as Timestamp).toDate()
              : null,
        };
      }

      return {'delivery_date': null, 'payment_date': null};
    } catch (e) {
      print('Fehler beim Laden der Lieferschein-Einstellungen: $e');
      return {'delivery_date': null, 'payment_date': null};
    }
  }



  // PDF Viewer öffnen
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

  // Nicht implementiert Nachricht
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