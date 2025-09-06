import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tonewood/components/quote_model.dart';
import '../services/pdf_generators/quote_generator.dart';
import 'movement_model.dart';
import 'dart:typed_data';

class QuoteService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Generiere neue Angebotsnummer
  static Future<String> getNextQuoteNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = _firestore
          .collection('general_data')
          .doc('quote_counters');

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
      print('Fehler beim Erstellen der Angebotsnummer: $e');
      rethrow;
    }
  }

  static Future<Quote> createQuote({
    required Map<String, dynamic> customerData,
    required Map<String, dynamic>? costCenter,
    required Map<String, dynamic>? fair,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> calculations,
    required Map<String, dynamic> metadata,
    bool createReservations = true,
  }) async {
    try {
      final quoteNumber = await getNextQuoteNumber();
      final quoteId = 'Q-$quoteNumber';

      // Berechne finalen Total mit allen Aufschlägen
      final finalCalculations = Map<String, dynamic>.from(calculations);

      // Hole Aufschläge aus metadata
      final shippingCosts = metadata['shippingCosts'] ?? {};
      final freightCost = (shippingCosts['amount'] as num?)?.toDouble() ?? 0.0;
      final phytosanitaryCost = (shippingCosts['phytosanitaryCertificate'] as num?)?.toDouble() ?? 0.0;

      final totalDeductions = (shippingCosts['totalDeductions'] as num?)?.toDouble() ?? 0.0;
      final totalSurcharges = (shippingCosts['totalSurcharges'] as num?)?.toDouble() ?? 0.0;



      // Hole Steuerdaten aus metadata
      final taxOption = metadata['taxOption'] ?? 0;
      final vatRate = (metadata['vatRate'] ?? 8.1).toDouble();

// Berechne neuen Total vor Steuern
      final netAmountBeforeShipping = (calculations['net_amount'] as num?)?.toDouble() ?? 0.0;
      final netAmountWithShipping = netAmountBeforeShipping + freightCost + phytosanitaryCost + totalSurcharges - totalDeductions;


// Berechne MwSt neu basierend auf dem Total inkl. Versandkosten
      double newVatAmount = 0.0;
      double newTotal = netAmountWithShipping;

      if (taxOption == 0) { // Standard mit MwSt
        newVatAmount = netAmountWithShipping * (vatRate / 100);
        newTotal = netAmountWithShipping + newVatAmount;
      }

// Aktualisiere calculations mit korrekten Werten
      finalCalculations['subtotal'] = (calculations['subtotal'] as num?)?.toDouble() ?? 0.0;
      finalCalculations['net_amount'] = netAmountWithShipping;
      finalCalculations['freight'] = freightCost;
      finalCalculations['phytosanitary'] = phytosanitaryCost;
      finalCalculations['total_deductions'] = totalDeductions;  // NEU
      finalCalculations['total_surcharges'] = totalSurcharges;  // NEU

      finalCalculations['vat_amount'] = newVatAmount;
      finalCalculations['total'] = newTotal;

      final quote = Quote(
        id: quoteId,
        quoteNumber: quoteNumber,
        status: QuoteStatus.draft,
        customer: customerData,
        costCenter: costCenter,
        fair: fair,
        items: items,
        calculations: finalCalculations,  // Verwende die aktualisierten Berechnungen
        createdAt: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 14)),
        documents: {},
        metadata: metadata,
      );

      // Erstelle Angebot in Firestore
      await _firestore
          .collection('quotes')
          .doc(quoteId)
          .set(quote.toMap());

      // Erstelle Reservierungen wenn gewünscht
      if (createReservations) {
        await _createReservations(quoteId, items);
      }

      // Generiere Angebots-PDF
      await _generateQuotePdf(quote);

      return quote;
    } catch (e) {
      print('Fehler beim Erstellen des Angebots: $e');
      rethrow;
    }
  }

  // Erstelle Reservierungen für Angebot
  static Future<void> _createReservations(String quoteId, List<Map<String, dynamic>> items) async {
    final batch = _firestore.batch();

    for (final item in items) {
      // Überspringe manuelle Produkte
      // Überspringe manuelle Produkte und Dienstleistungen
      if (item['is_manual_product'] == true || item['is_service'] == true) continue;

      final movementRef = _firestore.collection('stock_movements').doc();

      // Sichere Konvertierung der Quantity
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;

      final movement = StockMovement(
        id: movementRef.id,
        type: StockMovementType.reservation,
        quoteId: quoteId,
        productId: item['product_id'],
        quantity: -quantity, // Negativ für Abgang
        status: StockMovementStatus.reserved,
        timestamp: DateTime.now(),
      );

      batch.set(movementRef, movement.toMap());
    }

    await batch.commit();
  }

  // Generiere Angebots-PDF
  static Future<void> _generateQuotePdf(Quote quote) async {
    try {
      final rawExchangeRates = quote.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};



      final exchangeRates = <String, double>{
        'CHF': 1.0,
      };

      rawExchangeRates.forEach((key, value) {
        if (key != 'CHF' && value != null) {
          exchangeRates[key] = (value as num).toDouble();
        }
      });
      // NEU: Lade Rundungseinstellungen aus den Metadaten oder aus Firebase
      Map<String, bool> roundingSettings;

      // Versuche zuerst aus den Quote-Metadaten zu laden
      if (quote.metadata.containsKey('roundingSettings')) {
        final rawSettings = quote.metadata['roundingSettings'] as Map<String, dynamic>;
        roundingSettings = {
          'CHF': rawSettings['CHF'] ?? true,
          'EUR': rawSettings['EUR'] ?? false,
          'USD': rawSettings['USD'] ?? false,
        };
      } else {
        // Fallback: Lade aus Firebase
        try {
          final doc = await FirebaseFirestore.instance
              .collection('general_data')
              .doc('currency_settings')
              .get();

          if (doc.exists && doc.data()!.containsKey('rounding_settings')) {
            final settings = doc.data()!['rounding_settings'] as Map<String, dynamic>;
            roundingSettings = {
              'CHF': settings['CHF'] ?? true,
              'EUR': settings['EUR'] ?? false,
              'USD': settings['USD'] ?? false,
            };
          } else {
            // Standard-Einstellungen
            roundingSettings = {
              'CHF': true,
              'EUR': false,
              'USD': false,
            };
          }
        } catch (e) {
          print('Fehler beim Laden der Rundungseinstellungen: $e');
          // Fallback zu Standard-Einstellungen
          roundingSettings = {
            'CHF': true,
            'EUR': false,
            'USD': false,
          };
        }
      }
      final pdfBytes = await QuoteGenerator.generateQuotePdf(
        roundingSettings: roundingSettings,
        items: quote.items,
        customerData: quote.customer,
        fairData: quote.fair,
        costCenterCode: quote.costCenter?['code'] ?? '00000',
        currency: quote.metadata['currency'] ?? 'CHF',
        exchangeRates: exchangeRates,
        quoteNumber: quote.quoteNumber,
        language: quote.metadata['language'] ?? 'DE',
        shippingCosts: quote.metadata['shippingCosts'],
        calculations: quote.calculations,
        taxOption: quote.metadata['taxOption'] ?? 0,
        vatRate: (quote.metadata['vatRate'] ?? 8.1).toDouble(),
      );

      // Speichere PDF in Storage - Neue Struktur: documents/quotes/[quote-nummer].pdf
      final pdfRef = _storage.ref().child('documents/quotes/${quote.quoteNumber}.pdf');
      await pdfRef.putData(pdfBytes);
      final pdfUrl = await pdfRef.getDownloadURL();

      // Aktualisiere Angebot mit PDF-URL
      await _firestore
          .collection('quotes')
          .doc(quote.id)
          .update({
        'documents.quote_pdf': pdfUrl,
      });
    } catch (e) {
      print('Fehler beim Generieren des Angebots-PDFs: $e');
      rethrow;
    }
  }

  // Aktualisiere Angebotsstatus
  static Future<void> updateQuoteStatus(String quoteId, QuoteStatus status) async {
    await _firestore
        .collection('quotes')
        .doc(quoteId)
        .update({
      'status': status.name,
      if (status == QuoteStatus.sent) 'sentAt': FieldValue.serverTimestamp(),
    });
  }

  // Storniere Reservierungen
  static Future<void> cancelReservations(String quoteId) async {
    final movements = await _firestore
        .collection('stock_movements')
        .where('quoteId', isEqualTo: quoteId)
        .where('status', isEqualTo: StockMovementStatus.reserved.name)
        .get();

    final batch = _firestore.batch();

    for (final doc in movements.docs) {
      batch.update(doc.reference, {
        'status': StockMovementStatus.cancelled.name,
      });
    }

    await batch.commit();
  }

  // Lade Angebot
  static Future<Quote?> getQuote(String quoteId) async {
    final doc = await _firestore
        .collection('quotes')
        .doc(quoteId)
        .get();

    if (!doc.exists) return null;

    return Quote.fromFirestore(doc);
  }

// Prüfe Verfügbarkeit (unter Berücksichtigung von Reservierungen)
  static Future<Map<String, double>> checkAvailability(
      List<Map<String, dynamic>> items,
      {String? excludeQuoteId}  // NEU: Optional Quote-ID zum Ausschließen
      ) async {
    print('=== START checkAvailability ===');
    print('Anzahl zu prüfender Items: ${items.length}');
    print('Exclude Quote ID: $excludeQuoteId');  // NEU

    final availability = <String, double>{};

    for (final item in items) {
      // ... (Debug-Ausgaben bleiben gleich)

      if (item['is_manual_product'] == true || item['is_service'] == true) {
        print('-> Überspringe manuelles Produkt oder Dienstleistung');
        continue;
      }

      final productId = item['product_id'] as String;

      // Hole aktuellen Bestand
      final inventoryDoc = await _firestore
          .collection('inventory')
          .doc(productId)
          .get();

      if (!inventoryDoc.exists) {
        availability[productId] = 0;
        continue;
      }

      final currentStock = (inventoryDoc.data()?['quantity'] as num?)?.toDouble() ?? 0.0;
      print('Aktueller Lagerbestand: $currentStock');

      // Hole alle aktiven Reservierungen
      print('\nLade Reservierungen für $productId...');
      var reservationsQuery = _firestore
          .collection('stock_movements')
          .where('productId', isEqualTo: productId)
          .where('type', isEqualTo: StockMovementType.reservation.name)
          .where('status', isEqualTo: StockMovementStatus.reserved.name);

      final reservations = await reservationsQuery.get();

      print('Anzahl gefundener Reservierungen: ${reservations.docs.length}');

      final reservedQuantity = reservations.docs.fold<double>(
        0,
            (sum, doc) {
          final data = doc.data();
          final quoteId = data['quoteId'] as String?;

          // NEU: Überspringe Reservierungen der aktuellen Quote
          if (excludeQuoteId != null && quoteId == excludeQuoteId) {
            print('  -> ÜBERSPRINGE eigene Reservierung für Quote $quoteId');
            return sum;
          }

          final qty = (data['quantity'] as num?)?.toDouble().abs() ?? 0.0;
          print('  -> Addiere ${qty} zur Gesamtreservierung (Quote: $quoteId)');
          return sum + qty;
        },
      );

      print('\nGesamte reservierte Menge (ohne eigene): $reservedQuantity');
      print('Verfügbare Menge: ${currentStock - reservedQuantity}');

      availability[productId] = currentStock - reservedQuantity;
    }

    return availability;
  }
}