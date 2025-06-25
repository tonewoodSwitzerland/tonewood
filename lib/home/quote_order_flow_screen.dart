import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

import '../components/order_service.dart';
import '../components/quote_service.dart';
import '../services/document_selection_manager.dart';
import '../services/additional_text_manager.dart';
import '../services/shipping_costs_manager.dart';
import '../services/icon_helper.dart';

class QuoteOrderFlowScreen extends StatefulWidget {
  const QuoteOrderFlowScreen({Key? key}) : super(key: key);

  @override
  State<QuoteOrderFlowScreen> createState() => _QuoteOrderFlowScreenState();
}

class _QuoteOrderFlowScreenState extends State<QuoteOrderFlowScreen> {
  bool _isLoading = false;
  Map<String, bool> _documentSelection = {};
  bool _isQuoteOnly = false;

  @override
  void initState() {
    super.initState();
    _loadDocumentSelection();
  }

  Future<void> _loadDocumentSelection() async {
    final selection = await DocumentSelectionManager.loadDocumentSelection();
    setState(() {
      _documentSelection = selection;
      // Prüfe ob nur "Offerte" ausgewählt wurde
      _isQuoteOnly = selection['Offerte'] == true &&
          selection.entries.where((e) => e.key != 'Offerte' && e.value == true).isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isQuoteOnly ? 'Angebot erstellen' : 'Auftrag erstellen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildDocumentOverview(),
            const SizedBox(height: 24),
            if (_isQuoteOnly) _buildQuoteInfo(),
            const Spacer(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('temporary_basket')
          .snapshots(),
      builder: (context, snapshot) {
        final itemCount = snapshot.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Zusammenfassung',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('$itemCount Artikel im Warenkorb'),

              // Kunde
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('temporary_customer')
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final customer = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Kunde: ${customer['company'] ?? customer['fullName']}'),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Kein Kunde ausgewählt',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentOverview() {
    final selectedDocs = _documentSelection.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Folgende Dokumente werden erstellt:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...selectedDocs.map((doc) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  doc,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildQuoteInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Die Produkte werden für dieses Angebot reserviert und stehen anderen Kunden temporär nicht zur Verfügung.',
              style: TextStyle(color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              icon: getAdaptiveIcon(iconName: 'cancel', defaultIcon: Icons.cancel),
              label: const Text('Abbrechen'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _processDocuments,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check),
              label: Text(_isLoading ? 'Erstelle...' : 'Erstellen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processDocuments() async {
    setState(() => _isLoading = true);

    try {
      // Lade alle benötigten Daten
      final data = await _loadTransactionData();
      if (data == null) {
        throw Exception('Nicht alle erforderlichen Daten vorhanden');
      }

      if (_isQuoteOnly) {
        // Nur Angebot erstellen mit Reservierungen
        final quote = await QuoteService.createQuote(
          customerData: data['customer'],
          costCenter: data['costCenter'],
          fair: data['fair'],
          items: data['items'],
          calculations: data['calculations'],
          metadata: data['metadata'],
          createReservations: true, // Produkte reservieren
        );

        await _clearTemporaryData();

        if (mounted) {
          Navigator.pop(context);
          _showSuccessDialog(
            'Angebot erstellt',
            'Angebotsnummer: ${quote.quoteNumber}\n\n'
                'Die Produkte wurden für 14 Tage reserviert.',
            quote.id,
          );
        }
      } else {
        // Angebot + Auftrag + gewählte Dokumente erstellen

        // 1. Erstelle Angebot (ohne Reservierungen)
        final quote = await QuoteService.createQuote(
          customerData: data['customer'],
          costCenter: data['costCenter'],
          fair: data['fair'],
          items: data['items'],
          calculations: data['calculations'],
          metadata: data['metadata'],
          createReservations: false, // Keine Reservierungen, da direkt verkauft
        );

        // 2. Konvertiere zu Auftrag (bucht Produkte aus)
        final order = await OrderService.createOrderFromQuote(quote.id);

        // 3. Erstelle gewählte Dokumente
        final documentSelection = Map<String, bool>.from(_documentSelection);
        documentSelection.remove('Offerte'); // Entferne Offerte, da bereits erstellt

        final createdDocuments = await OrderService.createOrderDocuments(
          orderId: order.id,
          orderNumber: order.orderNumber,
          documentTypes: documentSelection,
          orderData: {
            'orderId': order.id,
            'quoteId': quote.id,
            'customer': data['customer'],
            'costCenter': data['costCenter'],
            'fair': data['fair'],
            'items': data['items'],
            'calculations': data['calculations'],
            'metadata': data['metadata'],
          },
          language: data['metadata']['language'] ?? 'DE',
        );

        await _clearTemporaryData();

        if (mounted) {
          Navigator.pop(context);
          _showSuccessDialog(
            'Auftrag erfolgreich erstellt',
            'Auftragsnummer: ${order.orderNumber}\n'
                'Angebotsnummer: ${quote.quoteNumber}\n\n'
                '${createdDocuments.length} Dokumente wurden erstellt.',
            order.id,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _loadTransactionData() async {
    try {
      // Kunde
      final customerSnapshot = await FirebaseFirestore.instance
          .collection('temporary_customer')
          .limit(1)
          .get();

      if (customerSnapshot.docs.isEmpty) {
        throw Exception('Kein Kunde ausgewählt');
      }

      // Kostenstelle
      final costCenterSnapshot = await FirebaseFirestore.instance
          .collection('temporary_cost_center')
          .limit(1)
          .get();

      // Warenkorb
      final basketSnapshot = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .get();

      if (basketSnapshot.docs.isEmpty) {
        throw Exception('Warenkorb ist leer');
      }

      // Messe (optional)
      final fairSnapshot = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .limit(1)
          .get();

      // Steuerdaten
      final taxDoc = await FirebaseFirestore.instance
          .collection('temporary_tax')
          .doc('current_tax')
          .get();

      // Währungsdaten
      final currencyDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('currency_settings')
          .get();

      // Versandkosten
      final shippingCosts = await ShippingCostsManager.loadShippingCosts();

      // Zusatztexte
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();

      // Berechne Summen
      final calculations = await _calculateTotals(basketSnapshot.docs);

      // Items vorbereiten
      final items = basketSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'basket_doc_id': doc.id,
        };
      }).toList();

      return {
        'customer': customerSnapshot.docs.first.data(),
        'costCenter': costCenterSnapshot.docs.isNotEmpty
            ? costCenterSnapshot.docs.first.data()
            : null,
        'fair': fairSnapshot.docs.isNotEmpty
            ? fairSnapshot.docs.first.data()
            : null,
        'items': items,
        'calculations': calculations,
        'metadata': {
          'taxOption': taxDoc.exists ? (taxDoc.data()?['tax_option'] ?? 0) : 0,
          'vatRate': taxDoc.exists ? (taxDoc.data()?['vat_rate'] ?? 8.1) : 8.1,
          'currency': currencyDoc.exists ? (currencyDoc.data()?['selected_currency'] ?? 'CHF') : 'CHF',
          'exchangeRates': currencyDoc.exists ? (currencyDoc.data()?['exchange_rates'] ?? {'CHF': 1.0}) : {'CHF': 1.0},
          'language': customerSnapshot.docs.first.data()['language'] ?? 'DE',
          'shippingCosts': shippingCosts,
          'additionalTexts': additionalTexts,
        },
      };
    } catch (e) {
      print('Fehler beim Laden der Transaktionsdaten: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _calculateTotals(List<QueryDocumentSnapshot> basketItems) async {
    double subtotal = 0.0;
    double itemDiscounts = 0.0;

    for (final doc in basketItems) {
      final data = doc.data() as Map<String, dynamic>;
      final customPriceValue = data['custom_price_per_unit'];
      final pricePerUnit = customPriceValue != null
          ? (customPriceValue as num).toDouble()
          : (data['price_per_unit'] as num).toDouble();

      final itemSubtotal = (data['quantity'] as int) * pricePerUnit;
      subtotal += itemSubtotal;

      // Rabatte
      final discount = data['discount'] as Map<String, dynamic>?;
      if (discount != null) {
        final percentage = (discount['percentage'] as num? ?? 0).toDouble();
        final absolute = (discount['absolute'] as num? ?? 0).toDouble();
        itemDiscounts += (itemSubtotal * (percentage / 100)) + absolute;
      }
    }

    // Gesamtrabatt
    double totalDiscountAmount = 0.0;
    final totalDiscountDoc = await FirebaseFirestore.instance
        .collection('temporary_discounts')
        .doc('total_discount')
        .get();

    if (totalDiscountDoc.exists) {
      final discountData = totalDiscountDoc.data()!;
      final percentage = (discountData['percentage'] as num? ?? 0).toDouble();
      final absolute = (discountData['absolute'] as num? ?? 0).toDouble();

      final afterItemDiscounts = subtotal - itemDiscounts;
      totalDiscountAmount = (afterItemDiscounts * (percentage / 100)) + absolute;
    }

    final netAmount = subtotal - itemDiscounts - totalDiscountAmount;

    // Steuern
    final taxDoc = await FirebaseFirestore.instance
        .collection('temporary_tax')
        .doc('current_tax')
        .get();

    final taxOption = taxDoc.exists ? (taxDoc.data()?['tax_option'] ?? 0) : 0;
    final vatRate = taxDoc.exists ? (taxDoc.data()?['vat_rate'] ?? 8.1).toDouble() : 8.1;

    double vatAmount = 0.0;
    double total = netAmount;

    if (taxOption == 0) { // Standard
      vatAmount = netAmount * (vatRate / 100);
      total = netAmount + vatAmount;
    }

    return {
      'subtotal': subtotal,
      'item_discounts': itemDiscounts,
      'total_discount': totalDiscountDoc.exists ? totalDiscountDoc.data() : {'percentage': 0.0, 'absolute': 0.0},
      'total_discount_amount': totalDiscountAmount,
      'net_amount': netAmount,
      'vat_rate': vatRate,
      'vat_amount': vatAmount,
      'total': total,
    };
  }

  Future<void> _clearTemporaryData() async {
    final batch = FirebaseFirestore.instance.batch();

    // Lösche Warenkorb
    final basketDocs = await FirebaseFirestore.instance
        .collection('temporary_basket')
        .get();
    for (final doc in basketDocs.docs) {
      batch.delete(doc.reference);
    }

    // Lösche Kunde
    final customerDocs = await FirebaseFirestore.instance
        .collection('temporary_customer')
        .get();
    for (final doc in customerDocs.docs) {
      batch.delete(doc.reference);
    }

    // Lösche weitere temporäre Daten...
    final costCenterDocs = await FirebaseFirestore.instance
        .collection('temporary_cost_center')
        .get();
    for (final doc in costCenterDocs.docs) {
      batch.delete(doc.reference);
    }

    final fairDocs = await FirebaseFirestore.instance
        .collection('temporary_fair')
        .get();
    for (final doc in fairDocs.docs) {
      batch.delete(doc.reference);
    }

    final taxDocs = await FirebaseFirestore.instance
        .collection('temporary_tax')
        .get();
    for (final doc in taxDocs.docs) {
      batch.delete(doc.reference);
    }

    final discountDocs = await FirebaseFirestore.instance
        .collection('temporary_discounts')
        .get();
    for (final doc in discountDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    // Lösche auch die anderen Manager-Daten
    await DocumentSelectionManager.clearSelection();
    await AdditionalTextsManager.clearAdditionalTexts();
    await ShippingCostsManager.clearShippingCosts();
  }

  void _showSuccessDialog(String title, String message, String documentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Navigiere zur Auftragsübersicht
                Navigator.pushReplacementNamed(context, '/orders_overview');
              },
              icon: getAdaptiveIcon(iconName: 'list', defaultIcon: Icons.list),
              label: const Text('Zur Auftragsübersicht'),
            ),
          ],
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

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fehler'),
        content: Text(error),
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