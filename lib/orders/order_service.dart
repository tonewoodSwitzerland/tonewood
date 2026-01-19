import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tonewood/quotes/quote_model.dart';
import 'package:tonewood/orders/order_model.dart';
import '../quotes/quote_service.dart';
import '../services/swiss_rounding.dart';
import '../components/movement_model.dart';

import '../services/pdf_generators/invoice_generator.dart';
import '../services/pdf_generators/delivery_note_generator.dart';
import '../services/pdf_generators/commercial_invoice_generator.dart';
import '../services/pdf_generators/packing_list_generator.dart';
import 'dart:typed_data';

class OrderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Generiere neue Auftragsnummer
  static Future<String> getNextOrderNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = _firestore
          .collection('general_data')
          .doc('order_counters');

      return await _firestore.runTransaction<String>((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        Map<String, dynamic> counters = {};
        if (counterDoc.exists) {
          counters = counterDoc.data() ?? {};
        }

        int currentNumber = counters[year.toString()] ?? 999;
        currentNumber++;

        transaction.set(counterRef, {
          year.toString(): currentNumber,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return '$year-$currentNumber';
      });
    } catch (e) {
      print('Fehler beim Erstellen der Auftragsnummer: $e');
      rethrow;
    }
  }


  // Konvertiere Angebot zu Auftrag
  static Future<OrderX> createOrderFromQuote(String quoteId) async {
    try {


      // Lade Angebot
      final quote = await QuoteService.getQuote(quoteId);


      if (quote == null) throw Exception('Angebot nicht gefunden');

      // Prüfe Verfügbarkeit nochmals
      final availability = await QuoteService.checkAvailability(quote.items,  excludeQuoteId: quoteId );

      for (final item in quote.items) {
        // Überspringe manuelle Produkte und Dienstleistungen
        if (item['is_manual_product'] == true || item['is_service'] == true) continue;

        final productId = item['product_id'] as String;


        final quantityRaw = item['quantity'];
        print('DEBUG: Raw quantity for $productId: $quantityRaw (${quantityRaw.runtimeType})');

        final required = quantityRaw is int ? quantityRaw.toDouble() : quantityRaw as double;
        final availableRaw = availability[productId];
        print('DEBUG: Available raw for $productId: $availableRaw (${availableRaw.runtimeType})');

        final available = availableRaw is int ? availableRaw?.toDouble() : (availableRaw ?? 0.0) as double;



        if (available! < required) {
          throw Exception(
              'Nicht genügend Bestand für ${item['product_name']}. '
                  'Benötigt: $required, Verfügbar: $available'
          );
        }
      }

      // Generiere Auftragsnummer
   ///   final orderNumber = await getNextOrderNumber();
      ///Achtung auf wunsch von Tonewood am 12.12. angepasst // Angebotsnummer = Auftragsnummer!
        final orderNumber = quote.quoteNumber;  // Spiegele die Angebotsnummer
      final orderId = 'O-$orderNumber';

      // Erstelle initialen Auftrag mit Quote-PDF
      final initialDocuments = <String, String>{};

      // Übernehme Quote-PDF falls vorhanden
      if (quote.documents.containsKey('quote_pdf')) {
        initialDocuments['quote_pdf'] = quote.documents['quote_pdf']!;
      }

      // Erstelle Auftrag
      final order = OrderX(
        id: orderId,
       quoteNumber: quote.quoteNumber,
        orderNumber: orderNumber,
        status: OrderStatus.processing,
        quoteId: quoteId,
        customer: quote.customer,
        items: quote.items,
        calculations: quote.calculations,
        orderDate: DateTime.now(),

        documents: initialDocuments,
          metadata: {
            ...quote.metadata, // NEU: Übernehme ALLE metadata aus der Quote
            'orderCreatedAt': DateTime.now().toIso8601String(),
          },
      );

      // Wichtig: Wir müssen sicherstellen, dass costCenter und fair auch übertragen werden
      final orderData = order.toMap();

      // Füge costCenter und fair hinzu, falls vorhanden
      if (quote.costCenter != null) {
        orderData['costCenter'] = quote.costCenter;
      }
      if (quote.fair != null) {
        orderData['fair'] = quote.fair;
      }

      // Transaktion für atomare Operationen
      await _firestore.runTransaction((transaction) async {
        // Erstelle Auftrag mit allen Daten
        transaction.set(
          _firestore.collection('orders').doc(orderId),
          orderData,  // Verwende orderData statt order.toMap()
        );

        // Aktualisiere Angebot
        transaction.update(
          _firestore.collection('quotes').doc(quoteId),
          {
            'status': QuoteStatus.accepted.name,
            'orderId': orderId,
            'acceptedAt': FieldValue.serverTimestamp(),
          },
        );

        // Hole alle Reservierungen für dieses Angebot
        final reservations = await _firestore
            .collection('stock_movements')
            .where('quoteId', isEqualTo: quoteId)
            .where('status', isEqualTo: StockMovementStatus.reserved.name)
            .get();

        // Konvertiere Reservierungen zu Verkäufen
        for (final doc in reservations.docs) {
          transaction.update(doc.reference, {
            'status': StockMovementStatus.confirmed.name,
            'type': StockMovementType.sale.name,
            'orderId': orderId,
            'confirmedAt': FieldValue.serverTimestamp(),
          });
        }

        // Aktualisiere Lagerbestände nur für reservierte Produkte
        // (Nicht-reservierte Produkte müssen den Bestand abziehen)
        final reservedProductIds = reservations.docs
            .map((doc) => doc.data()['productId'] as String)
            .toSet();

        for (final item in quote.items) {
          // Überspringe manuelle Produkte und Dienstleistungen
          if (item['is_manual_product'] == true || item['is_service'] == true) continue;

          final productId = item['product_id'] as String;

          // Wenn das Produkt NICHT reserviert war, müssen wir den Bestand abziehen
          if (!reservedProductIds.contains(productId)) {
            final inventoryRef = _firestore
                .collection('inventory')
                .doc(productId);

            transaction.update(inventoryRef, {
              'quantity': FieldValue.increment(-((item['quantity'] as num).toDouble())),
              'last_modified': FieldValue.serverTimestamp(),
            });

            // Erstelle neuen Stock Movement für nicht-reservierte Produkte
            final movementRef = _firestore.collection('stock_movements').doc();
            transaction.set(movementRef, {
              'id': movementRef.id,
              'type': StockMovementType.sale.name,
              'orderId': orderId,
              'quoteId': quoteId,
              'productId': productId,
              'quantity': -((item['quantity'] as num).toDouble()),
              'status': StockMovementStatus.confirmed.name,
              'timestamp': FieldValue.serverTimestamp(),
              'confirmedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      print('Auftrag erfolgreich erstellt: $orderId');

      return order;
    } catch (e) {
      print('Fehler beim Erstellen des Auftrags: $e');
      rethrow;
    }
  }

  // Generiere und speichere Auftragsdokument
// Aktualisiere die generateOrderDocument Methode:
  static Future<String> generateOrderDocument({
    required String orderId,
    required String orderNumber,
    required String documentType,
    required Map<String, dynamic> orderData,
    required String language,
  }) async {
    try
    {
      Uint8List pdfBytes;
      String filePrefix;


      // Extrahiere metadata für einfacheren Zugriff
      final metadata = orderData['metadata'] as Map<String, dynamic>? ?? {};
      final invoiceSettings = metadata['invoiceSettings'] as Map<String, dynamic>? ?? {};
      final paymentTermDays = invoiceSettings['payment_term_days'] ?? 30;
      // NEU: Hole Additional Texts aus metadata
      final additionalTexts = metadata['additionalTexts'] as Map<String, dynamic>?;

      // Konvertiere exchangeRates sicher
      final rawExchangeRates = metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
      final exchangeRates = <String, double>{
        'CHF': 1.0,
      };
      rawExchangeRates.forEach((key, value) {
        if (value != null) {
          exchangeRates[key] = (value as num).toDouble();
        }
      });
      final roundingSettings = await SwissRounding.loadRoundingSettings();
      
      // Generiere PDF basierend auf Dokumenttyp
      switch (documentType.toLowerCase()) {
        case 'rechnung':
        case 'invoice':
          filePrefix = 'invoice';
          pdfBytes = await InvoiceGenerator.generateInvoicePdf(
            items: orderData['items'],
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenter']?['code'] ?? '00000',
            currency: metadata['currency'] ?? 'CHF',
            exchangeRates: exchangeRates,
            invoiceNumber: orderNumber,
            quoteNumber: orderData['quoteNumber'], // NEU: Quote Number übergeben
            language: language,
            shippingCosts: metadata['shippingCosts'],
            calculations: orderData['calculations'],
            taxOption: metadata['taxOption'] ?? 0,
            vatRate: (metadata['vatRate'] ?? 8.1).toDouble(),
            additionalTexts: additionalTexts,
            roundingSettings: roundingSettings,
            paymentTermDays: paymentTermDays,
            downPaymentSettings: invoiceSettings,
          );
          break;

        case 'lieferschein':
        case 'delivery note':
          filePrefix = 'delivery-note';
          pdfBytes = await DeliveryNoteGenerator.generateDeliveryNotePdf(
            items: orderData['items'],
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenter']?['code'] ?? '00000',
            currency: metadata['currency'] ?? 'CHF',
            exchangeRates: exchangeRates,
            deliveryNoteNumber: orderNumber,
            language: language,
            deliveryDate: DateTime.now(),
            paymentDate: DateTime.now().add(const Duration(days: 30)),

          );
          break;

        case 'handelsrechnung':
        case 'commercial invoice':
          filePrefix = 'commercial-invoice';
          final taraSettings = metadata['taraSettings'] as Map<String, dynamic>? ?? {};

          pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
            items: orderData['items'],
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenter']?['code'] ?? '00000',
            currency: taraSettings['commercial_invoice_currency'] ?? metadata['currency'] ?? 'CHF',

            exchangeRates: exchangeRates,
            invoiceNumber: orderNumber,
            language: language,
            shippingCosts: metadata['shippingCosts'],
            calculations: orderData['calculations'],
            taxOption: metadata['taxOption'] ?? 0,
            vatRate: (metadata['vatRate'] ?? 8.1).toDouble(),
            taraSettings: taraSettings,

          );
          break;

        case 'packliste':
        case 'packing list':
          filePrefix = 'packing-list';
          pdfBytes = await PackingListGenerator.generatePackingListPdf(
            language: language,
            packingListNumber: orderNumber,
            customerData: orderData['customer'],
            fairData: orderData['fair'],
            costCenterCode: orderData['costCenter']?['code'] ?? '00000',
          );
          break;

        default:
          throw Exception('Unbekannter Dokumenttyp: $documentType');
      }

      // Speichere PDF in Storage
      final fileName = '$filePrefix-$orderNumber.pdf';
      final storageRef = _storage
          .ref()
          .child('documents/orders/$orderNumber/$fileName');

      await storageRef.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          cacheControl: 'max-age=3600',
        ),
      );

      // Hole Download-URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Speichere URL in Order
      await _firestore
          .collection('orders')
          .doc(orderId)
          .update({
        'documents.${filePrefix}_pdf': downloadUrl,
        'documents_updated_at': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      print('Fehler beim Generieren des Dokuments: $e');
      rethrow;
    }
  }

  // Erstelle mehrere Dokumente für einen Auftrag
  static Future<Map<String, String>> createOrderDocuments({
    required String orderId,
    required String orderNumber,
    required Map<String, bool> documentTypes,
    required Map<String, dynamic> orderData,
    required String language,
  }) async {
    final createdDocuments = <String, String>{};

    for (final entry in documentTypes.entries) {
      if (!entry.value) continue;

      try {
        final url = await generateOrderDocument(
          orderId: orderId,
          orderNumber: orderNumber,
          documentType: entry.key,
          orderData: orderData,
          language: language,
        );

        createdDocuments[entry.key] = url;
      } catch (e) {
        print('Fehler beim Erstellen von ${entry.key}: $e');
      }
    }

    return createdDocuments;
  }

  // Aktualisiere Auftragsstatus
  static Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _firestore
        .collection('orders')
        .doc(orderId)
        .update({
      'status': status.name,
      'status_updated_at': FieldValue.serverTimestamp(),
    });
  }



  // Lade Auftrag
  static Future<OrderX?> getOrder(String orderId) async {
    final doc = await _firestore
        .collection('orders')
        .doc(orderId)
        .get();

    if (!doc.exists) return null;

    return OrderX.fromFirestore(doc);
  }


  static Future<OrderX> createOrderFromQuoteWithConfig(
      String quoteId,
      Map<String, dynamic> additionalTexts,
      Map<String, dynamic> invoiceSettings,
      ) async {
    try {
      // 1. Zuerst die Quote mit den Additional Texts aktualisieren
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quoteId)
          .update({
        'metadata.additionalTexts': additionalTexts,
        'metadata.invoiceSettings': invoiceSettings,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2. Hole das aktualisierte Angebot
      final quoteDoc = await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quoteId)
          .get();

      if (!quoteDoc.exists) {
        throw Exception('Angebot nicht gefunden');
      }

      final quote = Quote.fromFirestore(quoteDoc);

      // 3. Erstelle den Auftrag (die Additional Texts sind jetzt in der Quote gespeichert)
      final order = await createOrderFromQuote(quoteId);
      // DEBUG
      print('DEBUG createOrderFromQuoteWithConfig:');
      print('Order created with ID: ${order.id}');
      print('invoiceSettings: $invoiceSettings');
      print('is_full_payment: ${invoiceSettings['is_full_payment']}');


      // 4. Erstelle die Rechnung mit den Einstellungen aus der Quote
      // HIER IST DIE KORREKTUR: Konvertiere exchangeRates zu Map<String, double>
      final rawExchangeRates = quote.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
      final exchangeRates = <String, double>{
        'CHF': 1.0,
      };
      rawExchangeRates.forEach((key, value) {
        if (value != null) {
          if (value is double) {
            exchangeRates[key] = value;
          } else if (value is int) {
            exchangeRates[key] = value.toDouble();
          } else if (value is num) {
            exchangeRates[key] = value.toDouble();
          } else if (value is String) {
            // Falls der Wert als String gespeichert wurde
            final parsed = double.tryParse(value);
            if (parsed != null) {
              exchangeRates[key] = parsed;
            }
          }
        }
      });

      final orderData = {
        'order': order,
        'items': quote.items,
        'customer': quote.customer,
        'calculations': quote.calculations,
        'settings': {
          'invoice': invoiceSettings,
        },
        'shippingCosts': quote.metadata['shippingCosts'] ?? {},
        'currency': quote.metadata['currency'] ?? 'CHF',
        'exchangeRates': exchangeRates, // VERWENDE DIE KONVERTIERTEN EXCHANGE RATES
        'costCenterCode': quote.costCenter?['code'] ?? '00000',
        'fair': quote.metadata['fairData'],
        'taxOption': quote.metadata['taxOption'] ?? 0,
        'vatRate': (quote.metadata['vatRate'] as num?)?.toDouble() ?? 8.1,
        'additionalTexts': additionalTexts,
      };

      // 5. Generiere Rechnung
      final pdfBytes = await InvoiceGenerator.generateInvoicePdf(
        items: orderData['items'],
        customerData: orderData['customer'],
        fairData: orderData['fair'],
        costCenterCode: orderData['costCenterCode'],
        currency: orderData['currency'],
        exchangeRates: orderData['exchangeRates'], // Jetzt ist es Map<String, double>
        language: orderData['customer']['language'] ?? 'DE',
        invoiceNumber: order.orderNumber,
        quoteNumber: order.quoteNumber, // NEU: Quote Number hinzufügen
        shippingCosts: orderData['shippingCosts'],
        calculations: orderData['calculations'],
        paymentTermDays: 30,
        taxOption: orderData['taxOption'],
        vatRate: orderData['vatRate'],
        downPaymentSettings: invoiceSettings,
        additionalTexts: additionalTexts,
        roundingSettings: await SwissRounding.loadRoundingSettings(),
      );

      // 6. Speichere PDF
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('orders')
          .child(order.id)
          .child('invoice_pdf.pdf');

      final uploadTask = await storageRef.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'orderNumber': order.orderNumber,
            'documentType': 'Rechnung',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final documentUrl = await uploadTask.ref.getDownloadURL();

      // 7. Update Order mit Dokument-URL
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
        'documents.invoice_pdf': documentUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return order;
    } catch (e) {
      print('Fehler beim Erstellen des Auftrags mit Konfiguration: $e');
      rethrow;
    }
  }




}