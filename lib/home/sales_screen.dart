

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tonewood/home/quote_order_flow_screen.dart';
import 'package:tonewood/home/service_selection_sheet.dart';

import 'package:tonewood/home/warehouse_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/swiss_rounding.dart'; // Pfad anpassen je nach Projektstruktur

import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/check_address.dart';
import '../components/manual_product_dialog.dart';
import '../services/additional_text_manager.dart';
import '../services/document_selection_manager.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:share_plus/share_plus.dart';
import '../analytics/sales/export_documents_integration.dart';
import '../analytics/sales/export_module.dart';
import '../constants.dart';
import '../services/cost_center.dart';
import '../services/customer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:intl/intl.dart';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'dart:typed_data';

import '../services/discount.dart';
import '../services/download_helper_mobile.dart' if (dart.library.html) '../services/download_helper_web.dart';
import '../services/fair_management_screen.dart';
import '../services/fairs.dart';

import 'package:csv/csv.dart';

import '../services/icon_helper.dart';
import 'barcode_scanner.dart';
import 'currency_converter_sheet.dart';
import 'customer_selection.dart';
import '../services/shipping_costs_manager.dart';

enum TaxOption {
  standard,  // Normales System mit Netto/Steuer/Brutto
  noTax,     // Komplett ohne Steuer (nur Netto)
  totalOnly  // Nur Bruttobetrag (inkl. MwSt), keine Steuerausweisung
}

class SalesScreen extends StatefulWidget {
  final Map<String, dynamic>? quoteToCopy;
  final Map<String, dynamic>? quoteToEdit;

  const SalesScreen({
    Key? key,
    this.quoteToCopy,
    this.quoteToEdit,
  }) : super(key: key);

@override
SalesScreenState createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen> {
  Fair? selectedFair;
  final ValueNotifier<TaxOption> _taxOptionNotifier = ValueNotifier<TaxOption>(TaxOption.noTax);
  final ValueNotifier<bool> _documentSelectionCompleteNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _additionalTextsSelectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _shippingCostsConfiguredNotifier = ValueNotifier<bool>(false);

  // Sprache für Dokumente
  final ValueNotifier<String> _documentLanguageNotifier = ValueNotifier<String>('DE');

  final ValueNotifier<double> _vatRateNotifier = ValueNotifier<double>(8.1);
// In der SalesScreenState Klasse, bei den anderen State-Variablen:
  bool _isDetailExpanded = false;


  String? _editingQuoteId;
  String? _editingQuoteNumber;

  final ValueNotifier<Fair?> _selectedFairNotifier = ValueNotifier<Fair?>(null);
bool isLoading = false;
final TextEditingController barcodeController = TextEditingController();
final TextEditingController quantityController = TextEditingController();
Customer? selectedCustomer;
final TextEditingController customerSearchController = TextEditingController();
final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true);
CostCenter? selectedCostCenter;
Map<String, dynamic>? selectedProduct;
// Füge diese Variablen zur SalesScreenState-Klasse hinzu
  bool sendPdfToCustomer = true;
  bool sendCsvToCustomer = false;
  bool sendPdfToOffice = true;
  bool sendCsvToOffice = true;

Stream<QuerySnapshot> get _basketStream => FirebaseFirestore.instance
    .collection('temporary_basket')
    .orderBy('timestamp', descending: true)
    .snapshots();

// Füge diese Variablen zur SalesScreenState-Klasse hinzu
  final ValueNotifier<String> _currencyNotifier = ValueNotifier<String>('CHF');
  final ValueNotifier<Map<String, double>> _exchangeRatesNotifier = ValueNotifier<Map<String, double>>({
    'CHF': 1.0,
    'EUR': 0.96,
    'USD': 1.08,
  });

// Diese Getter machen den Code kürzer
  String get _selectedCurrency => _currencyNotifier.value;
  Map<String, double> get _exchangeRates => _exchangeRatesNotifier.value;


  @override
  void initState() {
    super.initState();
    _checkDocumentSelection();
    _loadCurrencySettings();
    _checkAdditionalTexts();
    _loadCustomerLanguage();
    _checkShippingCosts();
    _loadTemporaryDiscounts();
    _loadTemporaryTax();
    _loadDocumentLanguage();

    if (widget.quoteToCopy != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadQuoteData(widget.quoteToCopy!);
      });
    } else if (widget.quoteToEdit != null) {  // NEU
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadQuoteDataForEdit(widget.quoteToEdit!);
      });
    }
  }

@override
Widget build(BuildContext context) {
final screenWidth = MediaQuery.of(context).size.width;
final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;

return Scaffold(
    appBar:
    AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          StreamBuilder<CostCenter?>(
            stream: _temporaryCostCenterStream,
            builder: (context, snapshot) {
              final costCenter = snapshot.data;

              return GestureDetector(
                onTap: _showCostCenterSelection,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: costCenter != null
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      getAdaptiveIcon(iconName: 'account_balance', defaultIcon: Icons.account_balance,),


                      const SizedBox(width: 4),
                      if (costCenter != null)
                        Tooltip(
                          message: '${costCenter.code} - ${costCenter.name}',
                          child: Text(
                            costCenter.code,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),

          // Messe - bleibt unverändert
          StreamBuilder<Fair?>(
            stream: _temporaryFairStream,
            builder: (context, snapshot) {
              final fair = snapshot.data;
              if (fair == null) return const SizedBox.shrink();

              return GestureDetector(
                onTap: _showFairSelection,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      getAdaptiveIcon(iconName: 'event', defaultIcon: Icons.event,),

                      const SizedBox(width: 4),
                      Tooltip(
                        message: fair.name,
                        child: Text(
                          fair.name.substring(0, min(2, fair.name.length)).toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        // Messe-Icon
        Tooltip(
          message: 'Messe',
          child: IconButton(
            icon:    getAdaptiveIcon(iconName: 'event', defaultIcon: Icons.event,),
            onPressed: _showFairSelection,
          ),
        ),



        ValueListenableBuilder<String>(
          valueListenable: _currencyNotifier,
          builder: (context, currency, child) {
            return IconButton(
              icon: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  getAdaptiveIcon(iconName: 'currency_exchange', defaultIcon: Icons.currency_exchange,),

                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      currency,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: 'Währungseinstellungen',
              onPressed: _showCurrencyConverterDialog,
            );
          },
        ),

        IconButton(
          icon: getAdaptiveIcon(
            iconName: 'delete',
            defaultIcon: Icons.delete,
          ),
          tooltip: 'Warenkorb leeren',
          onPressed: _showClearCartDialog,
        ),





      ],

    ),


  body: isDesktopLayout ? _buildDesktopLayout() : _buildMobileLayout(),
);
}

// Stream für die Büro-Email
  Stream<String> get _officeEmailStream => FirebaseFirestore.instance
      .collection('general_data')
      .doc('office')
      .snapshots()
      .map((snapshot) => snapshot.data()?['email'] as String? ?? 'keine Email hinterlegt');

  Stream<Map<String, dynamic>> get _officeSettingsStream => FirebaseFirestore.instance
      .collection('general_data')
      .doc('office')
      .snapshots()
      .map((snapshot) => snapshot.data() ?? {});

// Neue Methode ohne setState
  Future<void> _clearAllDataWithoutUIUpdate() async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Warenkorb leeren
      final basketDocs = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .get();
      for (var doc in basketDocs.docs) {
        batch.delete(doc.reference);
      }

      // 2. Kunde löschen
      final customerDocs = await FirebaseFirestore.instance
          .collection('temporary_customer')
          .get();
      for (var doc in customerDocs.docs) {
        batch.delete(doc.reference);
      }

      // 3. Kostenstelle löschen
      final costCenterDocs = await FirebaseFirestore.instance
          .collection('temporary_cost_center')
          .get();
      for (var doc in costCenterDocs.docs) {
        batch.delete(doc.reference);
      }

      // 4. Messe löschen
      final fairDocs = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .get();
      for (var doc in fairDocs.docs) {
        batch.delete(doc.reference);
      }

      // 5. Rabatte löschen
      final discountDoc = await FirebaseFirestore.instance
          .collection('temporary_discounts')
          .doc('total_discount')
          .get();
      if (discountDoc.exists) {
        batch.delete(discountDoc.reference);
      }

      await batch.commit();

      // 6. Weitere Löschungen
      await DocumentSelectionManager.clearSelection();
      await AdditionalTextsManager.clearAdditionalTexts();
      await ShippingCostsManager.clearShippingCosts();
      await _clearTemporaryTax();

      // Lokale States zurücksetzen (ohne setState)
      selectedProduct = null;
      _totalDiscount = const Discount();
      _itemDiscounts = {};
      _documentSelectionCompleteNotifier.value = false;
      _additionalTextsSelectedNotifier.value = false;
      _shippingCostsConfiguredNotifier.value = false;
      _documentLanguageNotifier.value = 'DE';
    } catch (e) {
      print('Fehler beim Löschen der temporären Daten: $e');
      rethrow;
    }
  }

  Future<void> _loadQuoteDataForEdit(Map<String, dynamic> quoteData) async {
    try {
      setState(() => isLoading = true);

      // Store quote info for later update
      _editingQuoteId = quoteData['quoteId'];
      _editingQuoteNumber = quoteData['quoteNumber'];

      // Erst alles löschen (ohne UI Update)
      await _clearAllDataWithoutUIUpdate();

      // Kurze Verzögerung
      await Future.delayed(const Duration(milliseconds: 100));

      // 1. Kunde laden
      final customerData = quoteData['customer'] as Map<String, dynamic>;
      final customerId = customerData['id'] ??
          customerData['customerId'] ??
          FirebaseFirestore.instance.collection('customers').doc().id;

      final customer = Customer.fromMap(customerData, customerId);
      await _saveTemporaryCustomer(customer);
      _documentLanguageNotifier.value = customer.language ?? 'DE';

      // 2. Kostenstelle laden
      if (quoteData['costCenter'] != null) {
        final costCenterData = quoteData['costCenter'] as Map<String, dynamic>;
        final costCenterId = costCenterData['id'] ??
            costCenterData['costCenterId'] ??
            FirebaseFirestore.instance.collection('cost_centers').doc().id;

        final costCenter = CostCenter.fromMap(costCenterData, costCenterId);
        await _saveTemporaryCostCenter(costCenter);
      }

      // 3. Währung und Steuereinstellungen
      _currencyNotifier.value = quoteData['currency'] ?? 'CHF';
      _exchangeRatesNotifier.value = Map<String, double>.from(quoteData['exchangeRates'] ?? {
        'CHF': 1.0,
        'EUR': 0.96,
        'USD': 1.08,
      });
      _vatRateNotifier.value = (quoteData['vatRate'] as num?)?.toDouble() ?? 8.1;
      _taxOptionNotifier.value = TaxOption.values[quoteData['taxOption'] ?? 0];
      await _saveCurrencySettings();
      await _saveTemporaryTax();

      // 4. Zusatztexte laden
      if (quoteData['additionalTexts'] != null) {
        await AdditionalTextsManager.saveAdditionalTexts(
            Map<String, dynamic>.from(quoteData['additionalTexts'])
        );
        _additionalTextsSelectedNotifier.value = true;
      }

      // 5. Artikel laden - OHNE Verfügbarkeitsprüfung bei Edit
      final items = List<Map<String, dynamic>>.from(quoteData['items'] ?? []);
      int successfulItems = 0;

      for (final item in items) {
        try {
          // Bei Edit-Modus: Keine Verfügbarkeitsprüfung, da bereits reserviert
          await FirebaseFirestore.instance.collection('temporary_basket').add({
            ...item,
            'timestamp': FieldValue.serverTimestamp(),
          });
          successfulItems++;
        } catch (e) {
          print('Fehler beim Hinzufügen des Artikels: $e');
        }
      }

      // 6. Versandkosten laden
      if (quoteData['shippingCosts'] != null) {
        await ShippingCostsManager.saveShippingCostsFromData(
            Map<String, dynamic>.from(quoteData['shippingCosts'])
        );
        _shippingCostsConfiguredNotifier.value = true;
      }

      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Angebot ${_editingQuoteNumber} zur Bearbeitung geladen'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadQuoteData(Map<String, dynamic> quoteData) async {
    try {
      setState(() => isLoading = true);
      // Erst alles löschen (ohne UI Update)
      await _clearAllDataWithoutUIUpdate();

      // Kurze Verzögerung
      await Future.delayed(const Duration(milliseconds: 100));
      // 1. Kunde laden
      final customerData = quoteData['customer'] as Map<String, dynamic>;
      // Extrahiere die ID aus den customerData oder generiere eine neue
      final customerId = customerData['id'] ??
          customerData['customerId'] ??
          FirebaseFirestore.instance.collection('customers').doc().id;

      final customer = Customer.fromMap(customerData, customerId);
      await _saveTemporaryCustomer(customer);
      _documentLanguageNotifier.value = customer.language ?? 'DE';

      // 2. Kostenstelle laden
      if (quoteData['costCenter'] != null) {
        final costCenterData = quoteData['costCenter'] as Map<String, dynamic>;
        // Extrahiere die ID aus den costCenterData oder generiere eine neue
        final costCenterId = costCenterData['id'] ??
            costCenterData['costCenterId'] ??
            FirebaseFirestore.instance.collection('cost_centers').doc().id;

        final costCenter = CostCenter.fromMap(costCenterData, costCenterId);
        await _saveTemporaryCostCenter(costCenter);
      }

      // 3. Währung und Steuereinstellungen
      _currencyNotifier.value = quoteData['currency'] ?? 'CHF';
      _exchangeRatesNotifier.value = Map<String, double>.from(quoteData['exchangeRates'] ?? {
        'CHF': 1.0,
        'EUR': 0.96,
        'USD': 1.08,
      });
      _vatRateNotifier.value = (quoteData['vatRate'] as num?)?.toDouble() ?? 8.1;
      _taxOptionNotifier.value = TaxOption.values[quoteData['taxOption'] ?? 0];
      await _saveCurrencySettings();
      await _saveTemporaryTax();

      // 4. Zusatztexte laden
      if (quoteData['additionalTexts'] != null) {
        await AdditionalTextsManager.saveAdditionalTexts(
            Map<String, dynamic>.from(quoteData['additionalTexts'])
        );
        _additionalTextsSelectedNotifier.value = true;
      }

      // 5. Artikel laden mit Verfügbarkeitsprüfung
      final items = List<Map<String, dynamic>>.from(quoteData['items'] ?? []);
      int successfulItems = 0;
      List<String> failedItems = [];

      for (final item in items) {
        try {
          // Dienstleistung
          if (item['is_service'] == true) {
            // Prüfe ob Dienstleistung noch existiert
            final serviceId = item['service_id'];
            if (serviceId != null) {
              final serviceDoc = await FirebaseFirestore.instance
                  .collection('services')
                  .doc(serviceId)
                  .get();

              if (serviceDoc.exists) {
                // Füge Dienstleistung hinzu
                await FirebaseFirestore.instance.collection('temporary_basket').add({
                  ...item,
                  'timestamp': FieldValue.serverTimestamp(),
                  // Aktualisiere Preis falls nötig
                  'price_per_unit': serviceDoc.data()!['price'] ?? item['price_per_unit'],
                });
                successfulItems++;
              } else {
                failedItems.add('${item['name']} (Dienstleistung nicht mehr verfügbar)');
              }
            }
          }
          // Manuelles Produkt
          else if (item['is_manual_product'] == true) {
            // Manuelle Produkte können immer hinzugefügt werden
            await FirebaseFirestore.instance.collection('temporary_basket').add({
              ...item,
              'timestamp': FieldValue.serverTimestamp(),
            });
            successfulItems++;
          }
          // Normales Lagerprodukt
          else {
            final productId = item['product_id'];
            if (productId != null) {
              // Prüfe Verfügbarkeit
              final inventoryDoc = await FirebaseFirestore.instance
                  .collection('inventory')
                  .doc(productId)
                  .get();

              if (inventoryDoc.exists) {
                final availableQuantity = await _getAvailableQuantity(productId);
                final requestedQuantity = (item['quantity'] as num).toDouble();

                if (availableQuantity >= requestedQuantity) {
                  // Produkt mit aktualisierten Daten hinzufügen
                  final productData = inventoryDoc.data()!;
                  await FirebaseFirestore.instance.collection('temporary_basket').add({
                    ...item,
                    'timestamp': FieldValue.serverTimestamp(),
                    // Aktualisiere Produktdaten falls sich etwas geändert hat
                    'product_name': productData['product_name'] ?? item['product_name'],
                    'price_per_unit': productData['price_CHF'] ?? item['price_per_unit'],
                    'instrument_name': productData['instrument_name'] ?? item['instrument_name'],
                    'part_name': productData['part_name'] ?? item['part_name'],
                    'wood_name': productData['wood_name'] ?? item['wood_name'],
                    'quality_name': productData['quality_name'] ?? item['quality_name'],
                  });
                  successfulItems++;
                } else if (availableQuantity > 0) {
                  // Teilweise verfügbar
                  failedItems.add(
                      '${item['product_name']} - Benötigt: ${requestedQuantity.toStringAsFixed(2)} ${item['unit']}, Verfügbar: ${availableQuantity.toStringAsFixed(2)} ${item['unit']}'
                  );
                } else {
                  // Nicht verfügbar
                  failedItems.add(
                      '${item['product_name']} - Nicht mehr auf Lager (Benötigt: ${requestedQuantity.toStringAsFixed(2)} ${item['unit']})'
                  );
                }
              } else {
                failedItems.add('${item['product_name']} - Produkt nicht mehr im Sortiment');
              }
            }
          }
        } catch (e) {
          failedItems.add('${item['product_name'] ?? item['name'] ?? 'Unbekannt'} (Fehler: $e)');
        }
      }
// 6. Versandkosten laden (falls vorhanden)
      if (quoteData['shippingCosts'] != null) {
        await ShippingCostsManager.saveShippingCostsFromData(
            Map<String, dynamic>.from(quoteData['shippingCosts'])
        );
        _shippingCostsConfiguredNotifier.value = true;
      }
      setState(() => isLoading = false);

      // Zeige Ergebnis
      if (mounted) {
        if (failedItems.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: failedItems.length == items.length ? 'error' : 'warning',
                    defaultIcon: failedItems.length == items.length ? Icons.error : Icons.warning,
                    color: failedItems.length == items.length ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      failedItems.length == items.length
                          ? 'Keine Artikel übernommen'
                          : 'Angebot teilweise kopiert',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (successfulItems > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            getAdaptiveIcon(
                              iconName: 'check_circle',
                              defaultIcon: Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$successfulItems von ${items.length} Artikeln übernommen',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (failedItems.isNotEmpty) ...[
                      const Text(
                        'Folgende Artikel konnten nicht übernommen werden:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: failedItems.length,
                            separatorBuilder: (context, index) => const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final item = failedItems[index];
                              final parts = item.split(' - ');

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: getAdaptiveIcon(
                                      iconName: 'error_outline',
                                      defaultIcon: Icons.error_outline,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          parts[0],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (parts.length > 1) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            parts.sublist(1).join(' - '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    if (failedItems.length == items.length) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            getAdaptiveIcon(
                              iconName: 'info',
                              defaultIcon: Icons.info,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Kunde und Einstellungen wurden trotzdem übernommen.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Verstanden'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'check_circle',
                    defaultIcon: Icons.check_circle,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text('Alle $successfulItems Artikel erfolgreich übernommen'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Angebotsdaten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // In sales_screen.dart, nach _saveTemporaryTax():
  Future<void> _saveDocumentLanguage() async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('language_settings')
          .set({
        'document_language': _documentLanguageNotifier.value,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Dokumentensprache: $e');
    }
  }

// Nach _loadTemporaryTax():
  Future<void> _loadDocumentLanguage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temporary_document_settings')
          .doc('language_settings')
          .get();

      if (doc.exists) {
        final language = doc.data()?['document_language'] ?? 'DE';
        _documentLanguageNotifier.value = language;
        print("Dokumentensprache geladen: $language");
      }
    } catch (e) {
      print('Fehler beim Laden der Dokumentensprache: $e');
    }
  }
  // Nach den anderen Load-Methoden hinzufügen:
  Future<void> _loadTemporaryTax() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temporary_tax')
          .doc('current_tax')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _vatRateNotifier.value = (data['vat_rate'] as num?)?.toDouble() ?? 8.1;

        // Falls auch die Steueroption gespeichert werden soll
        if (data.containsKey('tax_option')) {
          final taxOptionIndex = data['tax_option'] as int? ?? 0;
          if (taxOptionIndex >= 0 && taxOptionIndex < TaxOption.values.length) {
            _taxOptionNotifier.value = TaxOption.values[taxOptionIndex];
          }
        }

        print('Steuereinstellungen geladen: ${_vatRate}%, Option: ${_taxOptionNotifier.value}');
      } else {
        // Standardwerte setzen
        _vatRateNotifier.value = 8.1;
        print('Keine temporären Steuereinstellungen gefunden, verwende Standardwerte');
      }
    } catch (e) {
      print('Fehler beim Laden der Steuereinstellungen: $e');
      // Fallback auf Standardwerte
      _vatRateNotifier.value = 8.1;
    }
  }

  Future<void> _saveTemporaryTax() async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_tax')
          .doc('current_tax')
          .set({
        'vat_rate': _vatRate,
        'tax_option': _taxOptionNotifier.value.index,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Steuereinstellungen gespeichert: ${_vatRate}%, Option: ${_taxOptionNotifier.value}');
    } catch (e) {
      print('Fehler beim Speichern der Steuereinstellungen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern der Steuereinstellungen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearTemporaryTax() async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_tax')
          .doc('current_tax')
          .delete();

      print('Temporäre Steuereinstellungen gelöscht');
    } catch (e) {
      print('Fehler beim Löschen der temporären Steuereinstellungen: $e');
    }
  }

  Future<void> _loadTemporaryDiscounts() async {
    // Lade Gesamtrabatt
    await _loadTemporaryTotalDiscount();

    // Lade Item-Rabatte aus dem Warenkorb
    final basketSnapshot = await FirebaseFirestore.instance
        .collection('temporary_basket')
        .get();

    final Map<String, Discount> loadedDiscounts = {};

    for (final doc in basketSnapshot.docs) {
      final data = doc.data();
      if (data['discount'] != null) {
        final discountData = data['discount'] as Map<String, dynamic>;
        loadedDiscounts[doc.id] = Discount(
          percentage: (discountData['percentage'] != null)
              ? (discountData['percentage'] is int
              ? (discountData['percentage'] as int).toDouble()
              : discountData['percentage'] as double)
              : 0.0,
          absolute: (discountData['absolute'] != null)
              ? (discountData['absolute'] is int
              ? (discountData['absolute'] as int).toDouble()
              : discountData['absolute'] as double)
              : 0.0,
        );
      }
    }

    setState(() {
      _itemDiscounts = loadedDiscounts;
    });
  }
// Füge diese Methode zur SalesScreenState-Klasse hinzu
  Future<void> _checkAdditionalTexts() async {
    final hasTexts = await AdditionalTextsManager.hasTextsSelected();
    _additionalTextsSelectedNotifier.value = hasTexts;
  }

// Füge diese Methode zur SalesScreenState-Klasse hinzu
  void _showAdditionalTextsDialog() {
    showAdditionalTextsBottomSheet(
      context,
      textsSelectedNotifier: _additionalTextsSelectedNotifier,
    );
  }

// Füge diese Methode zur SalesScreenState-Klasse hinzu
  Future<void> _checkDocumentSelection() async {
    final selection = await DocumentSelectionManager.loadDocumentSelection();
    final hasSelection = selection.values.any((selected) => selected == true);
    _documentSelectionCompleteNotifier.value = hasSelection;
  }
  Future<void> _checkShippingCosts() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temporary_shipping_costs')
          .doc('current_costs')
          .get();

      _shippingCostsConfiguredNotifier.value = doc.exists;
    } catch (e) {
      print('Fehler beim Prüfen der Versandkosten: $e');
    }
  }
// Lade die Sprache aus dem temporären Kunden beim Start
  Future<void> _loadCustomerLanguage() async {
    try {
      final tempCustomerDoc = await FirebaseFirestore.instance
          .collection('temporary_customer')
          .limit(1)
          .get();

      if (tempCustomerDoc.docs.isNotEmpty) {
        final customerData = tempCustomerDoc.docs.first.data();
        final language = customerData['language'] ?? 'DE';

        setState(() {
          _documentLanguageNotifier.value = language;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Kundensprache: $e');
    }
  }
// Füge diese Methode zur SalesScreenState-Klasse hinzu
  void _showDocumentTypeSelection() {
    showDocumentSelectionBottomSheet(
      context,
      selectionCompleteNotifier: _documentSelectionCompleteNotifier,
      documentLanguageNotifier: _documentLanguageNotifier,
    );
  }
  // Füge diese Methode zur SalesScreenState-Klasse hinzu
  void _showEmailConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: StreamBuilder<Map<String, dynamic>>(
                  stream: _officeSettingsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final settings = snapshot.data!;
                      sendPdfToCustomer = settings['sendPdfToCustomer'] ?? true;
                      sendCsvToCustomer = settings['sendCsvToCustomer'] ?? false;
                      sendPdfToOffice = settings['sendPdfToOffice'] ?? true;
                      sendCsvToOffice = settings['sendCsvToOffice'] ?? true;
                    }

                    return Column(
                      children: [
                        // Header - Fixed at top
                        Row(
                          children: [
                         getAdaptiveIcon(iconName: 'mail', defaultIcon: Icons.mail),
                            const SizedBox(width: 8),
                            Text(
                              'Email',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon:    getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Scrollable content
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Kundenbereich
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email an Kunden',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      StreamBuilder<Customer?>(
                                        stream: _temporaryCustomerStream,
                                        builder: (context, snapshot) {
                                          final customer = snapshot.data;
                                          return Text(
                                            customer?.email ?? 'Kein Kunde ausgewählt',
                                            style: TextStyle(
                                              color: customer == null
                                                  ? Theme.of(context).colorScheme.error
                                                  : Theme.of(context).colorScheme.onSurface,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      CheckboxListTile(
                                        title: const Text('PDF anhängen', style: TextStyle(fontSize: 14,)),
                                        value: sendPdfToCustomer,
                                        onChanged: (value) async {
                                          setState(() => sendPdfToCustomer = value ?? false);
                                          await _saveOfficeSettings({
                                            'sendPdfToCustomer': value,
                                          });
                                        },
                                      ),
                                      CheckboxListTile(
                                        title: const Text('CSV anhängen', style: TextStyle(fontSize: 14,)),
                                        value: sendCsvToCustomer,
                                        onChanged: (value) async {
                                          setState(() => sendCsvToCustomer = value ?? false);
                                          await _saveOfficeSettings({
                                            'sendCsvToCustomer': value,
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Bürobereich
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email ans Büro',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      StreamBuilder<String>(
                                        stream: _officeEmailStream,
                                        builder: (context, snapshot) {
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: Text(snapshot.data ?? 'Lädt...'),
                                              ),
                                              IconButton(
                                                icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit,),
                                                onPressed: () => _showEditOfficeEmailDialog(context),
                                                tooltip: 'Büro-Email bearbeiten',
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      CheckboxListTile(
                                        title: const Text('PDF anhängen', style: TextStyle(fontSize: 14,)),
                                        value: sendPdfToOffice,
                                        onChanged: (value) async {
                                          setState(() => sendPdfToOffice = value ?? false);
                                          await _saveOfficeSettings({
                                            'sendPdfToOffice': value,
                                          });
                                        },
                                      ),
                                      CheckboxListTile(
                                        title: const Text('CSV anhängen', style: TextStyle(fontSize: 14,)),
                                        value: sendCsvToOffice,
                                        onChanged: (value) async {
                                          setState(() => sendCsvToOffice = value ?? false);
                                          await _saveOfficeSettings({
                                            'sendCsvToOffice': value,
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Footer - Fixed at bottom
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Schließen'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'warning',
              defaultIcon: Icons.warning,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Alles löschen?'),
          ],
        ),
        content: const Text(
          'Möchten Sie wirklich den gesamten Warenkorb und alle Einstellungen löschen?\n\n'
              'Dies entfernt:\n'
              '• Alle Artikel im Warenkorb\n'
              '• Kundenauswahl\n'
              '• Kostenstelle\n'
              '• Messe\n'
              '• Dokumentenauswahl\n'
              '• Zusatztexte\n'
              '• Versandkosten\n'
              '• Rabatte\n'
              '• Steuereinstellungen',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllTemporaryData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Alles löschen'),
          ),
        ],
      ),
    );
  }
  Future<void> _clearAllTemporaryData() async {
    setState(() => isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Warenkorb leeren
      final basketDocs = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .get();
      for (var doc in basketDocs.docs) {
        batch.delete(doc.reference);
      }

      // 2. Kunde löschen
      final customerDocs = await FirebaseFirestore.instance
          .collection('temporary_customer')
          .get();
      for (var doc in customerDocs.docs) {
        batch.delete(doc.reference);
      }

      // 3. Kostenstelle löschen
      final costCenterDocs = await FirebaseFirestore.instance
          .collection('temporary_cost_center')
          .get();
      for (var doc in costCenterDocs.docs) {
        batch.delete(doc.reference);
      }

      // 4. Messe löschen
      final fairDocs = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .get();
      for (var doc in fairDocs.docs) {
        batch.delete(doc.reference);
      }

      // 5. Rabatte löschen
      final discountDoc = await FirebaseFirestore.instance
          .collection('temporary_discounts')
          .doc('total_discount')
          .get();
      if (discountDoc.exists) {
        batch.delete(discountDoc.reference);
      }

      // Führe alle Löschungen aus
      await batch.commit();

      // 6. Dokumentenauswahl löschen
      await DocumentSelectionManager.clearSelection();

      // 7. Zusatztexte löschen
      await AdditionalTextsManager.clearAdditionalTexts();

      // 8. Versandkosten löschen
      await ShippingCostsManager.clearShippingCosts();

      // 9. Steuereinstellungen löschen
      await _clearTemporaryTax();

      // 10. Lokale States zurücksetzen
      setState(() {
        selectedProduct = null;
        _totalDiscount = const Discount();
        _itemDiscounts = {};
        _documentSelectionCompleteNotifier.value = false;
        _additionalTextsSelectedNotifier.value = false;
        _shippingCostsConfiguredNotifier.value = false;
        _documentLanguageNotifier.value = 'DE';
        isLoading = false;
      });

      // Bestätigung anzeigen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warenkorb und alle Einstellungen wurden gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
// Methode zum Anzeigen des Steueroptionen-Dialogs
  void _showTaxOptionsDialog() {
    TaxOption selectedOption = _taxOptionNotifier.value;
    double selectedVatRate = _vatRate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: getAdaptiveIcon(iconName: 'settings', defaultIcon: Icons.settings),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Steuer',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1),

                // Scrollbarer Inhalt
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Option 1: Standard
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedOption == TaxOption.standard
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: selectedOption == TaxOption.standard
                                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
                                : null,
                          ),
                          child: RadioListTile<TaxOption>(
                            title: const Text('Gesamt exkl. MwSt'),
                            subtitle: const Text('Netto, MwSt und Brutto separat ausgewiesen',style: TextStyle(fontSize: 10),),
                            value: TaxOption.standard,
                            groupValue: selectedOption,
                            onChanged: (value) {
                              setState(() => selectedOption = value!);
                            },
                          ),
                        ),

                        // Steuersatz-Eingabe (nur für Standard)
                        if (selectedOption == TaxOption.standard) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MwSt-Satz anpassen',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  initialValue: selectedVatRate.toString(),
                                  decoration: InputDecoration(
                                    labelText: 'MwSt-Satz',
                                    suffixText: '%',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: getAdaptiveIcon(iconName: 'percent', defaultIcon: Icons.percent),
                                    ),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                  ],
                                  onChanged: (value) {
                                    final String normalizedInput = value.replaceAll(',', '.');
                                    final newRate = double.tryParse(normalizedInput);
                                    if (newRate != null) {
                                      selectedVatRate = newRate;
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Option 2: Ohne Steuer
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedOption == TaxOption.noTax
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: selectedOption == TaxOption.noTax
                                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
                                : null,
                          ),
                          child: RadioListTile<TaxOption>(
                            title: const Text('Ohne MwSt'),
                            subtitle: const Text('Nur Nettobetrag, keine Steuer'),
                            value: TaxOption.noTax,
                            groupValue: selectedOption,
                            onChanged: (value) {
                              setState(() => selectedOption = value!);
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Option 3: Nur Bruttobetrag
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedOption == TaxOption.totalOnly
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: selectedOption == TaxOption.totalOnly
                                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
                                : null,
                          ),
                          child: RadioListTile<TaxOption>(
                            title: const Text('Gesamt inkl. MwSt'),
                            subtitle: const Text('Bruttobetrag ohne separate Steuer'),
                            value: TaxOption.totalOnly,
                            groupValue: selectedOption,
                            onChanged: (value) {
                              setState(() => selectedOption = value!);
                            },
                          ),
                        ),

                       
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: getAdaptiveIcon(iconName: 'cancel', defaultIcon: Icons.cancel),
                            label: const Text('Abbrechen'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Aktualisiere die Werte
                              this.setState(() {
                                _taxOptionNotifier.value = selectedOption;
                                _vatRateNotifier.value = selectedVatRate;
                              });

                              // Speichere in Firebase
                              await _saveTemporaryTax();

                              Navigator.pop(context);

                              // Bestätigung anzeigen
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Steuereinstellungen aktualisiert'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check),
                            label: const Text('Übernehmen'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
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

// Hilfsmethode für die Vorschau
  String _getPreviewText(TaxOption option, double vatRate) {
    switch (option) {
      case TaxOption.standard:
        return 'Es wird ein MwSt-Satz von ${vatRate.toStringAsFixed(1)}% berechnet und separat ausgewiesen.';
      case TaxOption.noTax:
        return 'Es wird keine Mehrwertsteuer berechnet oder ausgewiesen.';
      case TaxOption.totalOnly:
        return 'Der Gesamtbetrag wird als "inkl. MwSt" angezeigt, ohne separate Steuerausweisung.';
    }
  }


  Map<String, bool> _roundingSettings = {
    'CHF': true,  // Standard
    'EUR': false,
    'USD': false,
  };
  // Diese Methode lädt die Währungseinstellungen aus Firebase
  Future<void> _loadCurrencySettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('currency_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // Lade die Wechselkurse
        if (data.containsKey('exchange_rates')) {
          final rates = data['exchange_rates'] as Map<String, dynamic>;
          final ratesMap = {
            'CHF': 1.0,
            'EUR': rates['EUR'] as double? ?? 0.96,
            'USD': rates['USD'] as double? ?? 1.08,
          };
          _exchangeRatesNotifier.value = ratesMap;
        }

        // Lade die ausgewählte Währung
        if (data.containsKey('selected_currency')) {
          _currencyNotifier.value = data['selected_currency'] as String? ?? 'CHF';
        }

        // NEU: Lade die Rundungseinstellungen
        if (data.containsKey('rounding_settings')) {
          final settings = data['rounding_settings'] as Map<String, dynamic>;
          setState(() {
            _roundingSettings = {
              'CHF': settings['CHF'] ?? true,
              'EUR': settings['EUR'] ?? false,
              'USD': settings['USD'] ?? false,
            };
          });
        }

        print('Währungseinstellungen geladen: $_selectedCurrency, $_exchangeRates, Rundung: $_roundingSettings');
      }
    } catch (e) {
      print('Fehler beim Laden der Währungseinstellungen: $e');
    }
  }

// Diese Methode speichert die Währungseinstellungen in Firebase
  Future<void> _saveCurrencySettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('currency_settings')
          .set({
        'selected_currency': _selectedCurrency,
        'exchange_rates': {
          'EUR': _exchangeRates['EUR'],
          'USD': _exchangeRates['USD'],
        },
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Währungseinstellungen gespeichert');
    } catch (e) {
      print('Fehler beim Speichern der Währungseinstellungen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _saveTemporaryDiscounts() async {
    try {
      // Nur den Gesamtrabatt speichern
      await FirebaseFirestore.instance
          .collection('temporary_discounts')
          .doc('total_discount')
          .set({
        'percentage': _totalDiscount.percentage,
        'absolute': _totalDiscount.absolute,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern des Gesamtrabatts: $e');
    }
  }
// Hilfsmethode zur Formatierung von Preisen
  String _formatPrice(double amount) {
    // Konvertiere von CHF in die ausgewählte Währung
    double convertedAmount = amount;

    if (_selectedCurrency != 'CHF') {
      convertedAmount = amount * _exchangeRates[_selectedCurrency]!;
    }

    return NumberFormat.currency(
        locale: 'de_DE',
        symbol: _selectedCurrency,
        decimalDigits: 2
    ).format(convertedAmount);
  }

// Die Methode ersetzen
  void _showCurrencyConverterDialog() {
    CurrencyConverterSheet.show(
      context,
      currencyNotifier: _currencyNotifier,
      exchangeRatesNotifier: _exchangeRatesNotifier,
      onSave: _saveCurrencySettings,
    );
  }




  Future<void> _saveOfficeSettings(Map<String, dynamic> updates) async {
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      print('Fehler beim Speichern der Einstellungen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _showEditOfficeEmailDialog(BuildContext context) {
    final emailController = TextEditingController();

    // Aktuelle Email laden
    FirebaseFirestore.instance
        .collection('general_data')
        .doc('office')
        .get()
        .then((doc) {
      if (doc.exists) {
        emailController.text = doc.data()?['email'] ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Büro-Email bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email-Adresse',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte Email-Adresse eingeben';
                }
                if (!value.contains('@')) {
                  return 'Bitte gültige Email-Adresse eingeben';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty && emailController.text.contains('@')) {
                try {
                  await FirebaseFirestore.instance
                      .collection('general_data')
                      .doc('office')
                      .set({
                    'email': emailController.text.trim(),
                    'last_modified': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email-Adresse wurde aktualisiert'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Speichern: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
// Füge diese Methode zur SalesScreenState-Klasse hinzu

  // In deiner sales_screen.dart

  Future<void> _sendConfiguredEmails(
      String receiptId,
      Uint8List pdfBytes,
      Uint8List? csvBytes,
      Map<String, dynamic> receiptData,
      ) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('sendEmail');

      final customer = Customer.fromMap(
        receiptData['customer'] as Map<String, dynamic>,
        '',
      );

      // Hole die Office-Einstellungen
      final officeDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .get();

      final officeSettings = officeDoc.data() ?? {};

      print('Office Settings: $officeSettings'); // Debug

      // Email an Kunden
      if ((officeSettings['sendPdfToCustomer'] == true ||
          officeSettings['sendCsvToCustomer'] == true) &&
          customer.email.isNotEmpty) {
        try {
          print('Preparing customer email attachments...'); // Debug

          final attachments = <Map<String, String>>[];

          if (officeSettings['sendPdfToCustomer'] == true && pdfBytes != null) {
            print('Adding PDF for customer (${pdfBytes.length} bytes)'); // Debug
            attachments.add({
              'filename': 'Lieferschein_$receiptId.pdf',
              'content': base64Encode(pdfBytes),
              'encoding': 'base64',
            });
          }

          if (officeSettings['sendCsvToCustomer'] == true && csvBytes != null) {
            print('Adding CSV for customer (${csvBytes.length} bytes)'); // Debug
            attachments.add({
              'filename': 'Bestellung_$receiptId.csv',
              'content': base64Encode(csvBytes),
              'encoding': 'base64',
            });
          }

          print('Sending customer email with ${attachments.length} attachments...'); // Debug

          final result = await callable.call({
            'to': customer.email,
            'subject': 'Ihre Bestellung bei Tonewood Switzerland',
            'html': '''
            <p>Sehr geehrte Damen und Herren,</p>
            <p>vielen Dank für Ihren Einkauf bei Tonewood Switzerland.</p>
            <p>Im Anhang finden Sie die gewünschten Dokumente zu Ihrer Bestellung.</p>
            <p>Mit freundlichen Grüßen<br>Ihr Tonewood Switzerland Team</p>
          ''',
            'attachments': attachments,
          });

          print('Customer email result: ${result.data}'); // Debug
        } catch (e) {
          print('Error sending customer email: $e');
          rethrow;
        }
      }

      // Email ans Büro
      final officeEmail = officeDoc.data()?['email'];
      if (officeEmail != null &&
          (officeSettings['sendPdfToOffice'] == true ||
              officeSettings['sendCsvToOffice'] == true)) {
        try {
          print('Preparing office email attachments...'); // Debug

          final attachments = <Map<String, String>>[];

          if (officeSettings['sendPdfToOffice'] == true && pdfBytes != null) {
            print('Adding PDF for office (${pdfBytes.length} bytes)'); // Debug
            attachments.add({
              'filename': 'Lieferschein_$receiptId.pdf',
              'content': base64Encode(pdfBytes),
              'encoding': 'base64',
            });
          }

          if (officeSettings['sendCsvToOffice'] == true && csvBytes != null) {
            print('Adding CSV for office (${csvBytes.length} bytes)'); // Debug
            attachments.add({
              'filename': 'Bestellung_$receiptId.csv',
              'content': base64Encode(csvBytes),
              'encoding': 'base64',
            });
          }

          print('Sending office email with ${attachments.length} attachments...'); // Debug

          final result = await callable.call({
            'to': officeEmail,
            'subject': 'Neue Bestellung: ${customer.company}',
            'html': '''
            <h2>Neue Bestellung eingegangen</h2>
            <p><strong>Kunde:</strong> ${customer.company}<br>
            <strong>Kontakt:</strong> ${customer.fullName}<br>
            <strong>Adresse:</strong> ${customer.fullAddress}<br>
            <strong>Email:</strong> ${customer.email}</p>
            <p>Die Dokumente finden Sie im Anhang.</p>
            <p>Mit freundlichen Grüßen<br>Ihr Verkaufssystem</p>
          ''',
            'attachments': attachments,
          });

          print('Office email result: ${result.data}'); // Debug
        } catch (e) {
          print('Error sending office email: $e');
          rethrow;
        }
      }
    } catch (e) {
      print('Error in _sendConfiguredEmails: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Email-Versand: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Stream<Fair?> get _temporaryFairStream => FirebaseFirestore.instance
      .collection('temporary_fair')
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return Fair.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  });

// Methode zum Speichern der temporären Messe
  Future<void> _saveTemporaryFair(Fair fair) async {
    try {
      // Lösche vorherige temporäre Messe
      final tempDocs = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tempDocs.docs) {
        batch.delete(doc.reference);
      }

      // Füge neue temporäre Messe hinzu
      batch.set(
        FirebaseFirestore.instance.collection('temporary_fair').doc(fair.id),
        {
          ...fair.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Fehler beim Speichern der temporären Messe: $e');
    }
  }

// Methode zum Löschen der temporären Messe
  Future<void> _clearTemporaryFair() async {
    try {
      final tempDocs = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tempDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Fehler beim Löschen der temporären Messe: $e');
    }
  }
  void _showFairSelection() {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Messe',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Suchen',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search,),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('fairs')
                          .where('endDate', isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
                          .orderBy('endDate')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                getAdaptiveIcon(iconName: 'error', defaultIcon: Icons.error,size: 48),

                                const SizedBox(height: 16),
                                Text(
                                  'Fehler beim Laden der Messen',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final fairs = snapshot.data?.docs
                            .map((doc) => Fair.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                            .toList() ?? [];

                        final searchTerm = searchController.text.toLowerCase();
                        final filteredFairs = fairs.where((fair) =>
                        fair.name.toLowerCase().contains(searchTerm) ||
                            fair.city.toLowerCase().contains(searchTerm) ||
                            fair.country.toLowerCase().contains(searchTerm)
                        ).toList();

                        if (filteredFairs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                getAdaptiveIcon(iconName: 'event_busy', defaultIcon: Icons.event_busy,size: 48),

                                const SizedBox(height: 16),
                                Text(
                                  'Keine aktiven Messen gefunden',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return StreamBuilder<Fair?>(
                          stream: _temporaryFairStream,
                          builder: (context, selectedSnapshot) {
                            return ListView.builder(
                              itemCount: filteredFairs.length,
                              itemBuilder: (context, index) {
                                final fair = filteredFairs[index];
                                final isSelected = selectedSnapshot.data?.id == fair.id;

                                return Card(
                                  elevation: isSelected ? 2 : 0,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : null,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child:   getAdaptiveIcon(iconName: 'event', defaultIcon: Icons.event,size: 48),

                                    ),
                                    title: Text(
                                      fair.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${fair.city}, ${fair.country}\n'
                                          '${DateFormat('dd.MM.yyyy').format(fair.startDate)} - '
                                          '${DateFormat('dd.MM.yyyy').format(fair.endDate)}',
                                    ),
                                    isThreeLine: true,
                                    onTap: () async {
                                      try {
                                        setState(() => selectedFair = fair);
                                        await _saveTemporaryFair(fair);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Messe ausgewählt'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        print('Fehler beim Speichern der Messe: $e');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Fehler: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SafeArea(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FairManagementScreen(),
                              ),
                            );
                          },
                          icon:    getAdaptiveIcon(iconName: 'settings', defaultIcon: Icons.settings,),

                          label: const Text('Messen verwalten'),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () async {
                                try {
                                  setState(() => selectedFair = null);
                                  await _clearTemporaryFair();
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Messe-Auswahl zurückgesetzt'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  print('Fehler beim Zurücksetzen der Messe: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Fehler: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Keine Messe (Standard)'),
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  // Stream für die temporäre Kostenstelle
  Stream<CostCenter?> get _temporaryCostCenterStream => FirebaseFirestore.instance
      .collection('temporary_cost_center')
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return CostCenter.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  });
  void _showWarehouseDialog() {
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;

    // Erstelle einen stabilen Key außerhalb des Builders
    final warehouseKey = GlobalKey();

    // Web mit großem Bildschirm: Dialog mit begrenzter Breite
    if (isWeb && screenWidth > 600) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.1, // 10% Abstand an beiden Seiten
              vertical: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: screenWidth * 0.8, // 80% der Bildschirmbreite
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  // Titel mit Schließen-Button
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(iconName: 'warehouse', defaultIcon: Icons.warehouse),
                        SizedBox(width: 12),
                        Text(
                          'Lager durchsuchen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Hauptinhalt
                  Expanded(
                    child: WarehouseScreen(
                      key: warehouseKey,
                      isDialog: true,
                      mode: 'shopping',
                      onBarcodeSelected: (barcode) {
                        print("bc:$barcode");
                        Navigator.pop(context);
                        _fetchProductAndShowQuantityDialog(barcode);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    // Mobile oder kleine Bildschirme: Standard ModalBottomSheet
    else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          // Wichtig: StatefulBuilder hinzufügen für Mobile
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag Handle oben
                    Container(
                      margin: EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Titel mit Schließen-Button
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          getAdaptiveIcon(iconName: 'warehouse', defaultIcon: Icons.warehouse),
                          SizedBox(width: 12),
                          Text(
                            'Lager durchsuchen',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Hauptinhalt
                    Expanded(
                      child: WarehouseScreen(
                        key: warehouseKey,
                        isDialog: true,
                        mode: 'shopping',
                        onBarcodeSelected: (barcode) {
                          print("bc:$barcode");
                          Navigator.pop(context);
                          _fetchProductAndShowQuantityDialog(barcode);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  // Future<void> _checkAndHandleOnlineShopItem(String barcode) async {
  //   try {
  //     // Check if it's an online shop item by looking in the onlineshop collection
  //     final onlineShopDocs = await FirebaseFirestore.instance
  //         .collection('onlineshop')
  //         .where('short_barcode', isEqualTo: barcode)
  //         .where('sold', isEqualTo: false)
  //         .limit(1)
  //         .get();
  //
  //     if (onlineShopDocs.docs.isNotEmpty) {
  //       // It's an online shop item
  //       final onlineShopDoc = onlineShopDocs.docs.first;
  //       final onlineShopBarcode = onlineShopDoc.id; // The document ID is the full barcode
  //
  //       // Get the product from inventory
  //       final doc = await FirebaseFirestore.instance
  //           .collection('inventory')
  //           .doc(barcode)
  //           .get();
  //
  //       if (doc.exists) {
  //         // Add to cart with quantity 1 and mark as shop item
  //         await _addToTemporaryBasket(barcode, doc.data()!, 1, onlineShopBarcode);
  //
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text('Online-Shop Artikel wurde zum Warenkorb hinzugefügt'),
  //             backgroundColor: Colors.green,
  //           ),
  //         );
  //       }
  //     } else {
  //       // Regular inventory product
  //       _fetchProductAndShowQuantityDialog(barcode);
  //     }
  //   } catch (e) {
  //     print('Error in _checkAndHandleOnlineShopItem: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Fehler: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }


  // Methode zum Speichern der temporären Kostenstelle
  Future<void> _saveTemporaryCostCenter(CostCenter costCenter) async {
    try {
      // Lösche vorherige temporäre Kostenstelle
      final tempDocs = await FirebaseFirestore.instance
          .collection('temporary_cost_center')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tempDocs.docs) {
        batch.delete(doc.reference);
      }

      // Füge neue temporäre Kostenstelle hinzu
      batch.set(
        FirebaseFirestore.instance.collection('temporary_cost_center').doc(),
        {
          ...costCenter.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Fehler beim Speichern der temporären Kostenstelle: $e');
    }
  }

  // Methode zum Anzeigen des Kostenstellen-Dialogs
  void _showCostCenterSelection() {
    final searchController = TextEditingController();


    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Kostenstelle',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                       icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Suchen',
                      prefixIcon:    Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search,),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('cost_centers')
                          .orderBy('code')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Fehler: ${snapshot.error}'),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final costCenters = snapshot.data?.docs
                            .map((doc) => CostCenter.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                            .toList() ?? [];

                        final searchTerm = searchController.text.toLowerCase();
                        final filteredCostCenters = costCenters.where((cc) =>
                        cc.code.toLowerCase().contains(searchTerm) ||
                            cc.name.toLowerCase().contains(searchTerm) ||
                            cc.description.toLowerCase().contains(searchTerm)
                        ).toList();

                        if (filteredCostCenters.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [

                                   getAdaptiveIcon(iconName: 'account_balance', defaultIcon: Icons.account_balance,size: 48),

                                const SizedBox(height: 16),
                                Text(
                                  'Keine Kostenstellen gefunden',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filteredCostCenters.length,
                          itemBuilder: (context, index) {
                            final costCenter = filteredCostCenters[index];
                            final isSelected = selectedCostCenter?.id == costCenter.id;

                            return Card(
                              elevation: isSelected ? 2 : 0,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Text(
                                    costCenter.code.substring(0, 2),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${costCenter.code} - ${costCenter.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : null,
                                  ),
                                ),
                                subtitle: Text(costCenter.description,style:TextStyle(
                                  fontSize: 12,

                                ),),
                                onTap: () async {
                                  await _saveTemporaryCostCenter(costCenter);
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Kostenstelle ausgewählt'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showNewCostCenterDialog();
                          },
                          icon:    getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add,),

                          label: const Text('Neue Kostenstelle'),
                        ),

                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _showNewCostCenterDialog() {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Neue Kostenstelle',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),

                          icon:    getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),

                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basisdaten',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: codeController,
                            decoration: const InputDecoration(
                              labelText: 'Code *',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            validator: (value) => value?.isEmpty == true
                                ? 'Bitte Code eingeben'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name *',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            validator: (value) => value?.isEmpty == true
                                ? 'Bitte Namen eingeben'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Beschreibung',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        Text(
                          '* Pflichtfelder',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Abbrechen'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (formKey.currentState?.validate() == true) {
                                  try {
                                    final newCostCenter = CostCenter(
                                      id: '',
                                      code: codeController.text.trim(),
                                      name: nameController.text.trim(),
                                      description: descriptionController.text.trim(),
                                      createdAt: DateTime.now(),  // Füge das aktuelle Datum hinzu
                                    );

                                    final docRef = await FirebaseFirestore.instance
                                        .collection('cost_centers')
                                        .add(newCostCenter.toMap());

                                    if (mounted) {
                                      Navigator.pop(context);
                                      AppToast.show(
                                        message: 'Kostenstelle wurde erfolgreich angelegt',
                                        height: h,
                                      );

                                      // Optional: Direkt die neue Kostenstelle auswählen
                                      await _saveTemporaryCostCenter(
                                        CostCenter.fromMap(newCostCenter.toMap(), docRef.id),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      AppToast.show(
                                        message: 'Fehler beim Anlegen: $e',
                                        height: h,
                                      );
                                    }
                                  }
                                }
                              },
                              icon:   getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save,),

                              label: const Text('Speichern'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Future<String> _getNextReceiptNumber() async {
    try {
      // Transaktion um Race Conditions zu vermeiden
      DocumentReference counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('counters');

      return await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
        DocumentSnapshot counterDoc = await transaction.get(counterRef);

        int currentNumber;
        if (!counterDoc.exists || !(counterDoc.data() as Map<String, dynamic>).containsKey('lastReceiptNumber')) {
          currentNumber = 1;
        } else {
          currentNumber = (counterDoc.data() as Map<String, dynamic>)['lastReceiptNumber'] + 1;
        }

        transaction.set(counterRef, {
          'lastReceiptNumber': currentNumber,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return currentNumber.toString().padLeft(6, '0');
      });
    } catch (e) {
      print('Error getting next receipt number: $e');
      rethrow;
    }
  }


// Desktop Layout
  Widget _buildDesktopLayout() {
    final bool hasSelectedProduct = selectedProduct != null;

    return Row(
      children: [

        // Linke Seite - kompaktere Produktauswahl
        Container(
          width: 320, // Reduzierte Breite
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'people',
                      defaultIcon: Icons.people,
                      color: primaryAppColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Kunde auswählen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: StreamBuilder<Customer?>(
                  stream: _temporaryCustomerStream,
                  builder: (context, snapshot) {
                    final customer = snapshot.data;

                    return GestureDetector(
                      onTap: _showCustomerSelection,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: customer != null
                              ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
                              : Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: customer != null
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.error,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            getAdaptiveIcon(
                              iconName: 'person',
                              defaultIcon: Icons.person,
                              color: customer != null
                                  ? Theme.of(context).colorScheme.onSecondaryContainer
                                  : Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: customer != null
                                  ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.company.isNotEmpty
                                        ? customer.company
                                        : customer.fullName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (customer.company.isNotEmpty)
                                    Text(
                                      '${customer.fullName} • ${customer.city}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              )
                                  : Text(
                                'Kunde auswählen',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            if (customer != null)
                              IconButton(
                                icon: getAdaptiveIcon(
                                  iconName: 'location_on',
                                  defaultIcon: Icons.location_on,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                                onPressed: () {
                                  CheckAddressSheet.show(context);
                                },
                                tooltip: 'Adressen überprüfen',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                iconSize: 20,
                              ),
                            getAdaptiveIcon(iconName: 'arrow_drop_down', defaultIcon:
                              Icons.arrow_drop_down,
                              color: customer != null
                                  ? Theme.of(context).colorScheme.onSecondaryContainer
                                  : Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Header mit kompakterem Padding
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'shopping_cart',
                      defaultIcon: Icons.shopping_cart,
                      color: primaryAppColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Produkt hinzufügen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showWarehouseDialog();
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'search',
                    defaultIcon: Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    'Produkt suchen',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              // Search button in horizontal layout

              // Kompakteres Eingabefeld

              // Barcode-Eingabe mit dicken grünen Rändern
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: barcodeController,
                        decoration: InputDecoration(
                          labelText: 'Barcode',
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 56,
                      width: 56,
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            if (barcodeController.text.isNotEmpty) {
                              _fetchProductAndShowQuantityDialog(barcodeController.text);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: getAdaptiveIcon(
                              iconName: 'qr_code',
                              defaultIcon: Icons.qr_code,
                              size: 28,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

// Button für manuelle Produkte mit dickerer Schrift
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showManualProductDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          getAdaptiveIcon(
                            iconName: 'add_circle',
                            defaultIcon: Icons.add_circle,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Manuelles Produkt',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),


              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: _showServiceSelectionDialog,
                  icon: getAdaptiveIcon(
                    iconName: 'engineering',
                    defaultIcon: Icons.engineering,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    'Dienstleistung',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),


              Divider(height: 16, thickness: 1, color: Colors.grey.shade200),

              // Ausgewähltes Produkt oder Hilfetext
              Expanded(
                child: hasSelectedProduct
                    ? _buildSelectedProductInfo()
                    : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        getAdaptiveIcon(
                          iconName: 'inventory',
                          defaultIcon: Icons.inventory,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scanne einen Barcode oder suche ein Produkt aus dem Lager',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Rechte Seite - Warenkorb
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'shopping_cart',
                      defaultIcon: Icons.shopping_cart,
                      color: primaryAppColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Warenkorb',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildCartList()),
              _buildTotalBar(),
            ],
          ),
        ),
      ],
    );
  }

// Mobile Layout
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Neue Kundenanzeige als oberste Zeile
        StreamBuilder<Customer?>(
          stream: _temporaryCustomerStream,
          builder: (context, snapshot) {
            final customer = snapshot.data;

            return GestureDetector(
              onTap: _showCustomerSelection,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: customer != null
                      ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
                      : Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: customer != null
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'person',
                      defaultIcon: Icons.person,
                      color: customer != null
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    customer != null
                        ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          customer.company.isNotEmpty ? customer.company : customer.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        // Nur Subtitle zeigen wenn Firma vorhanden ist
                        if (customer.company.isNotEmpty)
                          Text(
                            ' • ${customer.fullName} • ${customer.city}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
                            ),
                          )
                        else
                          Text(
                            ' • ${customer.city}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
                            ),
                          )
                      ],
                    )
                        : Text(
                      'Bitte Kunde auswählen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    if (customer != null)
                      IconButton(
                        icon: getAdaptiveIcon(
                          iconName: 'location_on',
                          defaultIcon: Icons.location_on,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                        onPressed: () {
                          CheckAddressSheet.show(context);
                        },
                        tooltip: 'Adressen überprüfen',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        iconSize: 20,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        _buildMobileActions(),
        Expanded(
          child: _buildCartList(),
        ),
        _buildTotalBar(),
      ],
    );
  }


  void _showCustomerSelection() async {
    // Zeige das Customer Selection Sheet an und warte auf das Ergebnis
    final selectedCustomer = await CustomerSelectionSheet.show(context);

    // Wenn ein Kunde ausgewählt wurde, speichere ihn
    if (selectedCustomer != null) {
      await _saveTemporaryCustomer(selectedCustomer);
      // Sprache aus Kundendaten setzen
      setState(() {
        _documentLanguageNotifier.value = selectedCustomer.language ?? 'DE';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde ausgewählt'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }






  // Stream für den temporären Kunden
  Stream<Customer?> get _temporaryCustomerStream => FirebaseFirestore.instance
      .collection('temporary_customer')
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return Customer.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  });

  // Methode zum Speichern des temporären Kunden
  Future<void> _saveTemporaryCustomer(Customer customer) async {
    try {
      // Lösche vorherige temporäre Kunden
      final tempDocs = await FirebaseFirestore.instance
          .collection('temporary_customer')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tempDocs.docs) {
        batch.delete(doc.reference);
      }

      // Füge neuen temporären Kunden hinzu
      batch.set(
        FirebaseFirestore.instance.collection('temporary_customer').doc(customer.id),
        {
          ...customer.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Fehler beim Speichern des temporären Kunden: $e');
    }
  }
  void _showServiceSelectionDialog() {
    ServiceSelectionSheet.show(
      context,
      currencyNotifier: _currencyNotifier,          // NEU
      exchangeRatesNotifier: _exchangeRatesNotifier, // NEU
      onServiceSelected: (serviceData) async {
        try {
          // Füge die Dienstleistung zum temporären Warenkorb hinzu
          await FirebaseFirestore.instance
              .collection('temporary_basket')
              .add(serviceData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dienstleistung wurde hinzugefügt'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fehler beim Hinzufügen: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildMobileActions() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Dienstleistung
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _showServiceSelectionDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'engineering',
                        defaultIcon: Icons.engineering,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Manuell
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _showManualProductDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'add_circle',
                        defaultIcon: Icons.add_circle,
                        size: 20,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Suchen
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _showWarehouseDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'search',
                        defaultIcon: Icons.search,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Scan
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _scanProduct,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'qr_code',
                        defaultIcon: Icons.qr_code,
                        size: 20,
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Eingabe
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _showBarcodeInputDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'keyboard',
                        defaultIcon: Icons.keyboard,
                        size: 20,
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualProductDialog() {
    ManualProductSheet.show(
      context,
      onProductAdded: (manualProductData) async {
        try {
          // Füge das manuelle Produkt direkt zum Warenkorb hinzu
          await FirebaseFirestore.instance
              .collection('temporary_basket')
              .add(manualProductData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Manuelles Produkt wurde hinzugefügt'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fehler beim Hinzufügen: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }


// Erweiterte Warenkorb-Anzeige
  Widget _buildCartList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _basketStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Ein Fehler ist aufgetreten'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final basketItems = snapshot.data?.docs ?? [];

        if (basketItems.isEmpty) {
          return const Center(child: Text('Keine Produkte im Warenkorb'));
        }

        return ListView.builder(
          itemCount: basketItems.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final doc = basketItems[index];
            final item = doc.data() as Map<String, dynamic>;
            final itemId = doc.id;

            final Discount itemDiscount;
            if (item['discount'] != null) {
              final discountData = item['discount'] as Map<String, dynamic>;
              itemDiscount = Discount(
                percentage: (discountData['percentage'] as num?)?.toDouble() ?? 0.0,
                absolute: (discountData['absolute'] as num?)?.toDouble() ?? 0.0,
              );
              // Synchronisiere mit lokalem State
              if (!_itemDiscounts.containsKey(itemId)) {
                _itemDiscounts[itemId] = itemDiscount;

                
              }
            } else {
              itemDiscount = _itemDiscounts[itemId] ?? const Discount();
            }

            final isGratisartikel = item['is_gratisartikel'] == true;
            final pricePerUnit = isGratisartikel
                ? 0.0
                : ((item['custom_price_per_unit'] ?? item['price_per_unit']) as num).toDouble();


            final quantity = (item['quantity'] as num).toDouble();

            final subtotal = quantity * pricePerUnit;

            final discountAmount = itemDiscount.calculateDiscount(subtotal);

            return GestureDetector(
              onTap: () => _showPriceEditDialog(doc.id, item),
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hauptzeile mit allen Produktinfos und Preis
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Linke Seite: Produktinfos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Erste Zeile: Badge + Instrument + Holz
                                        Row(
                                          children: [
                                            if (item['is_service'] == true) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(3),
                                                  border: Border.all(
                                                    color: Colors.blue.withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  'DL',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            if (item['is_manual_product'] == true) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(3),
                                                  border: Border.all(
                                                    color: Colors.purple.withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  'M',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple[700],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),

                                            ],
                                            if (item['is_gratisartikel'] == true) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(3),
                                                  border: Border.all(
                                                    color: Colors.green.withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  'GRATIS',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],

                                            Expanded(
                                              child: Text(
                                                item['is_service'] == true
                                                    ? item['name'] ?? 'Unbenannte Dienstleistung'
                                                    : '${item['instrument_name'] ?? 'N/A'} - ${item['wood_name'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),


                                          ],
                                        ),
                                        const SizedBox(height: 2),

                                        // Zweite Zeile: Part + Quality
                                        // Zweite Zeile: Part + Quality ODER Beschreibung bei Dienstleistungen
                                        Text(
                                          item['is_service'] == true
                                              ? (item['description'] != null && item['description'].toString().isNotEmpty
                                              ? item['description'].toString()
                                              : 'Keine Beschreibung')
                                              : '${item['part_name'] ?? 'N/A'} - ${item['quality_name'] ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: item['is_service'] == true ? 2 : 1, // Bei Dienstleistungen 2 Zeilen erlauben
                                        ),

// Nach der Qualitätszeile hinzufügen:
                                        // Nach der Qualitätszeile hinzufügen:
                                        if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              getAdaptiveIcon(
                                                iconName: 'note',
                                                defaultIcon: Icons.note,
                                                size: 10,
                                                color: Colors.amber[700],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  item['notes'].toString(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.amber[700],
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 2),
                                        // Dritte Zeile: Menge × Preis
                                        // Im _buildCartList, bei der Mengenanzeige:
                                        ValueListenableBuilder<String>(
                                          valueListenable: _currencyNotifier,
                                          builder: (context, currency, child) {
                                            final String quantityDisplay = item['unit'] == 'Stück'
                                                ? quantity.toStringAsFixed(0)
                                                : quantity.toStringAsFixed(2);

                                            if (isGratisartikel && item['proforma_value'] != null) {
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$quantityDisplay ${item['unit']} × GRATIS',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.green[700],
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Pro-forma: ${_formatPrice(item['proforma_value'])}',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.grey[600],
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }

                                            return Text(
                                              '$quantityDisplay ${item['unit']} × ${_formatPrice(pricePerUnit)}${item['is_price_customized'] == true ? ' *' : ''}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontStyle: item['is_price_customized'] == true
                                                    ? FontStyle.italic
                                                    : FontStyle.normal,
                                                color: item['is_price_customized'] == true
                                                    ? Colors.green[700]
                                                    : Colors.grey[600],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Mitte: Preisspalte
                                  SizedBox(
                                    width: 85,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ValueListenableBuilder<String>(
                                          valueListenable: _currencyNotifier,
                                          builder: (context, currency, child) {
                                            return Text(
                                              _formatPrice(subtotal),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                decoration: discountAmount > 0
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: discountAmount > 0
                                                    ? Colors.grey
                                                    : Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                        if (discountAmount > 0) ...[
                                          const SizedBox(height: 2),
                                          ValueListenableBuilder<String>(
                                            valueListenable: _currencyNotifier,
                                            builder: (context, currency, child) {
                                              return Text(
                                                _formatPrice(subtotal - discountAmount),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Rechte Seite: Aktions-Buttons
                                  SizedBox(
                                    width: 80,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            iconSize: 20,
                                            icon: getAdaptiveIcon(
                                              iconName: 'sell',
                                              defaultIcon: Icons.sell,
                                            ),
                                            onPressed: () => _showItemDiscountDialog(itemId, subtotal),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            iconSize: 20,
                                            icon: getAdaptiveIcon(
                                              iconName: 'delete',
                                              defaultIcon: Icons.delete,
                                            ),
                                            onPressed: () => _removeFromBasket(doc.id),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Rabatt-Zeile (wenn vorhanden)
                        if (itemDiscount.hasDiscount)
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: ValueListenableBuilder<String>(
                              valueListenable: _currencyNotifier,
                              builder: (context, currency, child) {
                                return Row(
                                  children: [
                                    getAdaptiveIcon(iconName: 'discount', defaultIcon:
                                      Icons.discount,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Rabatt: ${itemDiscount.percentage > 0 ? '${itemDiscount.percentage.toStringAsFixed(2)}% ' : ''}'
                                            '${itemDiscount.absolute > 0 ? _formatPrice(itemDiscount.absolute) : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '- ${_formatPrice(discountAmount)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),

                    // Online Shop Badge (oben rechts)
                    if (item['is_online_shop_item'] == true)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon:
                                Icons.shopping_cart,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  'Shop - ${item['online_shop_barcode']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  void _showShippingCostsDialog() {
    showShippingCostsBottomSheet(
      context,
      costsConfiguredNotifier: _shippingCostsConfiguredNotifier,
      currency: _selectedCurrency, // NEU
      exchangeRates: _exchangeRates, // NEU
    );
  }
  Widget _buildTotalBar() {
    return ValueListenableBuilder<String>(
      valueListenable: _currencyNotifier,
      builder: (context, selectedCurrency, _) {
        return ValueListenableBuilder<Map<String, double>>(
          valueListenable: _exchangeRatesNotifier,
          builder: (context, exchangeRates, _) {
            return ValueListenableBuilder<TaxOption>(
              valueListenable: _taxOptionNotifier,
              builder: (context, taxOption, _) {
                return ValueListenableBuilder<double>( // NEU hinzufügen
                    valueListenable: _vatRateNotifier,
                    builder: (context, vatRate, _) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _basketStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();

                        final basketItems = snapshot.data!.docs;

                        // Berechne Zwischensummen
                        double subtotal = 0.0;
                        double itemDiscounts = 0.0;

                        // In der StreamBuilder-Berechnung:
                        for (var doc in basketItems) {
                          final data = doc.data() as Map<String, dynamic>;

                          // NEU: Gratisartikel-Check
                          final isGratisartikel = data['is_gratisartikel'] == true;

                          // Preis berechnen - 0 für Gratisartikel
                          final customPriceValue = data['custom_price_per_unit'];
                          final pricePerUnit = isGratisartikel
                              ? 0.0
                              : (customPriceValue != null
                              ? (customPriceValue as num).toDouble()
                              : (data['price_per_unit'] as num).toDouble());

                          final itemSubtotal = (data['quantity']) * pricePerUnit;
                          subtotal += itemSubtotal;

                          // Rabatte nur auf bezahlte Artikel anwenden
                          if (!isGratisartikel) {
                            final itemDiscount = _itemDiscounts[doc.id] ?? const Discount();
                            itemDiscounts += itemDiscount.calculateDiscount(itemSubtotal);
                          }
                        }

                        final afterItemDiscounts = subtotal - itemDiscounts;
                        final totalDiscountAmount = _totalDiscount.calculateDiscount(
                          afterItemDiscounts,
                        );
                        final netAmount = afterItemDiscounts - totalDiscountAmount;

                        // NEU: StreamBuilder für Versandkosten
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('temporary_shipping_costs')
                              .doc('current_costs')
                              .snapshots(),
                          builder: (context, shippingSnapshot) {
                            double freightCost = 0.0;
                            double phytosanitaryCost = 0.0;
                            double totalDeductions = 0.0;  // NEU
                            double totalSurcharges = 0.0;  // NEU

                            if (shippingSnapshot.hasData && shippingSnapshot.data!.exists) {
                              final shippingData = shippingSnapshot.data!.data() as Map<String, dynamic>;
                              freightCost = (shippingData['amount'] as num?)?.toDouble() ?? 0.0;
                              phytosanitaryCost = (shippingData['phytosanitaryCertificate'] as num?)?.toDouble() ?? 0.0;
                              totalDeductions = (shippingData['totalDeductions'] as num?)?.toDouble() ?? 0.0;  // NEU
                              totalSurcharges = (shippingData['totalSurcharges'] as num?)?.toDouble() ?? 0.0;  // NEU
                            }

// Berechne neuen Total mit Versandkosten, Abschlägen und Zuschlägen
                            final netWithShipping = netAmount + freightCost + phytosanitaryCost + totalSurcharges - totalDeductions;

                            // MwSt nur berechnen, wenn es Standard-Option ist
                            double vatAmount = 0.0;
                            double total = netWithShipping;

                            if (taxOption == TaxOption.standard) {
                              // NEU: Erst Nettobetrag auf 2 Nachkommastellen runden
                              final netAmountRounded = double.parse(netWithShipping.toStringAsFixed(2));

                              // NEU: MwSt berechnen und auf 2 Nachkommastellen runden
                              vatAmount = double.parse((netAmountRounded * (_vatRate / 100)).toStringAsFixed(2));

                              // NEU: Total ist Summe der gerundeten Beträge
                              total = netAmountRounded + vatAmount;
                            } else {
                              // Bei anderen Steueroptionen auch auf 2 Nachkommastellen runden
                              total = double.parse(netWithShipping.toStringAsFixed(2));
                            }
// NEU: 5er rundung anwenden
                            double displayTotal = total;
                            if (_selectedCurrency != 'CHF') {
                              displayTotal = total * _exchangeRates[_selectedCurrency]!;
                            }

                            final roundedDisplayTotal = SwissRounding.round(
                              displayTotal,
                              currency: _selectedCurrency,
                              roundingSettings: _roundingSettings,
                            );

// Zurück in CHF umrechnen für interne Berechnungen
                            final roundedTotal = _selectedCurrency == 'CHF'
                                ? roundedDisplayTotal
                                : roundedDisplayTotal / _exchangeRates[_selectedCurrency]!;

                            final roundingDifference = SwissRounding.getRoundingDifference(
                              displayTotal,  // Verwende den Betrag in der Anzeigewährung
                              currency: _selectedCurrency,
                              roundingSettings: _roundingSettings,
                            );

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                child: Column(
                                  children: [
                                    // Zwischensumme
                                    Container(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            // Details-Toggle und Gesamtbetrag in einer Zeile
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Toggle-Button links
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _isDetailExpanded = !_isDetailExpanded;
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    child:
                                                      _isDetailExpanded
                                                          ? getAdaptiveIcon(iconName: 'expand_less', defaultIcon:Icons.expand_less, size: 20, color: Theme.of(context).colorScheme.primary,)
                                                          : getAdaptiveIcon(iconName: 'expand_more', defaultIcon:Icons.expand_more, size: 20, color: Theme.of(context).colorScheme.primary),

                                                  ),
                                                ),
                                                const SizedBox(width: 16),

                                                // Gesamtbetrag rechts
                                                Expanded(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        taxOption == TaxOption.standard
                                                            ? 'Gesamtbetrag:'
                                                            : taxOption == TaxOption.noTax
                                                            ? 'Nettobetrag:'
                                                            : 'Gesamt inkl. MwSt:',
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          // NEU: Wenn gerundet wurde, zeige Original durchgestrichen
                                                          if (_roundingSettings[_selectedCurrency] == true && roundingDifference != 0) ...[
                                                            Text(
                                                              _formatPrice(total),
                                                              style: const TextStyle(
                                                                fontSize: 14,
                                                                decoration: TextDecoration.lineThrough,
                                                                color: Colors.grey,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                          ],
                                                          // Gerundeter oder normaler Betrag
                                                          Text(
                                                            _formatPrice( roundedTotal),
                                                            style: const TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          // NEU: Rundungsdifferenz anzeigen (optional)
                                                          if (_roundingSettings[_selectedCurrency] == true && roundingDifference != 0) ...[
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              'Rundung: ${roundingDifference > 0 ? '+' : ''}${_formatPrice(roundingDifference)}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: roundingDifference > 0 ? Colors.green : Colors.orange,
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Details nur wenn expanded
                                            if (_isDetailExpanded) ...[
                                              const Divider(height: 16),

                                              // Zwischensumme
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('Zwischensumme'),
                                                  Text(_formatPrice(subtotal)),
                                                ],
                                              ),

                                              // Positionsrabatte
                                              if (itemDiscounts > 0) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text('Positionsrabatte'),
                                                    Text(
                                                      '- ${_formatPrice(itemDiscounts)}',
                                                      style: TextStyle(
                                                        color: Theme.of(context).colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],

                                              // Gesamtrabatt
                                              if (_totalDiscount.hasDiscount) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                        'Gesamtrabatt '
                                                            '${_totalDiscount.percentage > 0 ? '(${_totalDiscount.percentage}%)' : ''}'
                                                            '${_totalDiscount.absolute > 0 ? ' ${_formatPrice(_totalDiscount.absolute)}' : ''}'
                                                    ),
                                                    Text(
                                                      '- ${_formatPrice(totalDiscountAmount)}',
                                                      style: TextStyle(
                                                        color: Theme.of(context).colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],

                                              // MwSt-Bereich basierend auf gewählter Option
                                              if (taxOption == TaxOption.standard) ...[
                                                const SizedBox(height: 4),
                                                // Nettobetrag
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text('Nettobetrag'),
                                                    Text(_formatPrice(netAmount)),
                                                  ],
                                                ),

                                                // NEU: Versandkosten anzeigen
                                                if (freightCost > 0) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Verpackung & Fracht'),
                                                      Text(_formatPrice(freightCost)),
                                                    ],
                                                  ),
                                                ],

                                                if (phytosanitaryCost > 0) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Pflanzenschutzzeugnisse'),
                                                      Text(_formatPrice(phytosanitaryCost)),
                                                    ],
                                                  ),
                                                ],
                                                if (  totalDeductions > 0) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Abschläge'),
                                                      Text(
                                                        '- ${_formatPrice(totalDeductions)}',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                const SizedBox(height: 4),
                                                if (  totalSurcharges > 0) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Zuschläge'),
                                                      Text(_formatPrice(totalSurcharges)),
                                                    ],
                                                  ),
                                                ],
                                                const SizedBox(height: 4),
                                                // MwSt mit Einstellungsrad
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text('MwSt ($_vatRate%)'),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          icon: getAdaptiveIcon(iconName: 'settings', defaultIcon: Icons.settings,),
                                                          onPressed: _showTaxOptionsDialog,
                                                          tooltip: 'Steuereinstellungen ändern',
                                                        ),
                                                        Text(_formatPrice(vatAmount)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ] else if (taxOption == TaxOption.noTax) ...[
                                                const SizedBox(height: 4),

                                                // NEU: Auch bei noTax die Versandkosten anzeigen
                                                if (freightCost > 0 || phytosanitaryCost > 0) ...[
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Nettobetrag'),
                                                      Text(_formatPrice(netAmount)),
                                                    ],
                                                  ),
                                                ],

                                                if (freightCost > 0) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Verpackung & Fracht'),
                                                      Text(_formatPrice(freightCost)),
                                                    ],
                                                  ),
                                                ],

                                                if (phytosanitaryCost > 0) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Pflanzenschutzzeugnisse'),
                                                      Text(_formatPrice(phytosanitaryCost)),
                                                    ],
                                                  ),
                                                ],

                                                // Einstellungs-Button
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    IconButton(
                                                      icon: getAdaptiveIcon(iconName: 'settings', defaultIcon: Icons.settings,),
                                                      onPressed: _showTaxOptionsDialog,
                                                      tooltip: 'Steuereinstellungen ändern',
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Es wird keine Mehrwertsteuer berechnet.',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ] else ...[
                                                // totalOnly
                                                const SizedBox(height: 4),

                                                // NEU: Auch bei totalOnly die Versandkosten anzeigen
                                                if (freightCost > 0 || phytosanitaryCost > 0) ...[
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Warenwert'),
                                                      Text(_formatPrice(netAmount)),
                                                    ],
                                                  ),
                                                ],

                                                if (freightCost > 0) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Verpackung & Fracht'),
                                                      Text(_formatPrice(freightCost)),
                                                    ],
                                                  ),
                                                ],

                                                if (phytosanitaryCost > 0) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text('Pflanzenschutzzeugnisse'),
                                                      Text(_formatPrice(phytosanitaryCost)),
                                                    ],
                                                  ),
                                                ],

                                                // Einstellungs-Button
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    IconButton(
                                                      icon: getAdaptiveIcon(iconName: 'settings', defaultIcon: Icons.settings,),
                                                      onPressed: _showTaxOptionsDialog,
                                                      tooltip: 'Steuereinstellungen ändern',
                                                    ),
                                                  ],
                                                ),

                                              ],
                                              // NEU: Rappenrundung in der Detail-Ansicht zeigen
                                              if (_roundingSettings[_selectedCurrency] == true && roundingDifference != 0) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text('5er Rundung'),
                                                        const SizedBox(width: 4),
                                                        Tooltip(
                                                          message: SwissRounding.getRoundingDetails(total, currency: _selectedCurrency)['rule'],
                                                          child: getAdaptiveIcon(
                                                            iconName: 'info',
                                                            defaultIcon: Icons.info,
                                                            size: 14,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      '${roundingDifference > 0 ? '+' : ''}${_formatPrice(roundingDifference)}',
                                                      style: TextStyle(
                                                        color: roundingDifference > 0 ? Colors.green : Colors.orange,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],

                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                // Sprache
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [


                                    //Rabattfeld
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _additionalTextsSelectedNotifier,
                                      builder: (context, hasTexts, child) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.green
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _showTotalDiscountDialog,
                                              borderRadius: BorderRadius.circular(4),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [

                                                    getAdaptiveIcon(iconName: 'sell', defaultIcon: Icons.sell,color: Colors.green)

                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Zusatztexte Button
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _additionalTextsSelectedNotifier,
                                      builder: (context, hasTexts, child) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: hasTexts ? Colors.green : Colors.red,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _showAdditionalTextsDialog,
                                              borderRadius: BorderRadius.circular(4),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    hasTexts
                                                        ?
                                                    getAdaptiveIcon(iconName: 'text_fields', defaultIcon: Icons.text_fields,color: Colors.green):
                                                    getAdaptiveIcon(iconName: 'text_fields', defaultIcon: Icons.text_fields,color:  Colors.red),


                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Nach dem Zusatztexte Button

                    // Versandkosten Button
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _shippingCostsConfiguredNotifier,
                                      builder: (context, hasShippingCosts, child) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: hasShippingCosts ? Colors.green : Colors.red.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _showShippingCostsDialog,
                                              borderRadius: BorderRadius.circular(4),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    hasShippingCosts
                                                        ?
                                                    getAdaptiveIcon(iconName: 'local_shipping', defaultIcon: Icons.local_shipping,color: Colors.green):
                                                    getAdaptiveIcon(iconName: 'local_shipping', defaultIcon: Icons.local_shipping,color:  Colors.red),

                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    ValueListenableBuilder<bool>(
                                      valueListenable: _documentSelectionCompleteNotifier,
                                      builder: (context, isComplete, child) {
                                        return ValueListenableBuilder<String>(
                                          valueListenable: _documentLanguageNotifier,
                                          builder: (context, language, child) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: isComplete ? Colors.green : Colors.red.shade300,
                                                ),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: _showDocumentTypeSelection,
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5), // VERGRÖSSERT
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        // Sprach-Toggle
                                                        GestureDetector(
                                                          onTap: () {
                                                            _documentLanguageNotifier.value =
                                                            _documentLanguageNotifier.value == 'DE' ? 'EN' : 'DE';
                                                            _saveDocumentLanguage();
                                                          },
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // AUCH VERGRÖSSERT
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.primary,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              language,
                                                              style: TextStyle(
                                                                color: Theme.of(context).colorScheme.onPrimary,
                                                                fontSize: 12, // GRÖSSERE SCHRIFT
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12), // MEHR ABSTAND
                                                        getAdaptiveIcon(
                                                          iconName: 'description',
                                                          defaultIcon: Icons.description,
                                                          color: isComplete ? Colors.green : Colors.red,
                                                          size: 20, // GRÖSSERES ICON
                                                        ),

                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),


                                    ValueListenableBuilder<bool>(
                                      valueListenable: _documentSelectionCompleteNotifier,
                                      builder: (context, isDocSelectionComplete, child) {
                                        return ValueListenableBuilder<bool>(
                                          valueListenable: _additionalTextsSelectedNotifier,
                                          builder: (context, hasTexts, child) {
                                            return ValueListenableBuilder<bool>(
                                              valueListenable: _shippingCostsConfiguredNotifier,
                                              builder: (context, hasShipping, child) {
                                                return StreamBuilder<Customer?>(
                                                  stream: _temporaryCustomerStream,
                                                  builder: (context, customerSnapshot) {
                                                    return StreamBuilder<CostCenter?>(
                                                      stream: _temporaryCostCenterStream,
                                                      builder: (context, costCenterSnapshot) {
                                                        // Prüfe alle Bedingungen
                                                        final hasCustomer = customerSnapshot.data != null;
                                                        final hasCostCenter = costCenterSnapshot.data != null;
                                                        final allConfigured = isDocSelectionComplete &&
                                                            hasTexts &&
                                                            hasShipping &&
                                                            hasCustomer &&
                                                            hasCostCenter;

                                                        final canProceed = basketItems.isNotEmpty &&
                                                            !isLoading &&
                                                            allConfigured;

                                                        return Container(
                                                          decoration: BoxDecoration(
                                                            border: Border.all(
                                                              color: allConfigured
                                                                  ? Colors.green
                                                                  : Colors.red.shade300,
                                                            ),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Material(
                                                            color: allConfigured
                                                                ? Theme.of(context).colorScheme.primary
                                                                : Colors.red,
                                                            borderRadius: BorderRadius.circular(3),
                                                            child: InkWell(
                                                              onTap: canProceed ? _processTransaction : null,
                                                              borderRadius: BorderRadius.circular(3),
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                child: isLoading
                                                                    ? const SizedBox(
                                                                  width: 18,
                                                                  height: 18,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                    color: Colors.white,
                                                                  ),
                                                                )
                                                                    :
                                                                allConfigured
                                                                    ?
                                                                getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check,color:  Colors.green, size: 18)
                                                               : getAdaptiveIcon(iconName: 'warning', defaultIcon: Icons.warning,color:  Colors.white, size: 18,
                                                              ),


                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),



                                ],
                              ),
                            ),
                            );
                          },
                        );
                      },
                    );
                    }
                );
              },
            );
          },
        );
      },
    );
  }
// Hilfsmethoden
  Future<double> _getAvailableQuantity(String shortBarcode) async {
    try {
      // Aktuellen Bestand aus inventory collection abrufen
      final inventoryDoc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(shortBarcode)
          .get();

      final currentStock = (inventoryDoc.data()?['quantity'] as num?)?.toDouble() ?? 0.0;

      // Temporär gebuchte Menge abrufen
      final tempBasketDocs = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .where('product_id', isEqualTo: shortBarcode)
          .get();

      final reservedQuantity = tempBasketDocs.docs.fold<double>(
        0,
            (sum, doc) => sum + ((doc.data()['quantity'] as num?)?.toDouble() ?? 0.0),
      );

      // Reservierte Menge aus stock_movements abrufen
      var reservationsQuery = FirebaseFirestore.instance
          .collection('stock_movements')
          .where('productId', isEqualTo: shortBarcode)
          .where('type', isEqualTo: 'reservation')
          .where('status', isEqualTo: 'reserved');

      // NEU: Bei Edit-Modus, schließe eigene Reservierungen aus
      if (_editingQuoteId != null) {
        // Hole alle Reservierungen und filtere manuell
        final allReservations = await reservationsQuery.get();

        final reservedFromMovements = allReservations.docs.fold<double>(
          0,
              (sum, doc) {
            final data = doc.data();
            // Überspringe Reservierungen des aktuell bearbeiteten Angebots
            if (data['quoteId'] == _editingQuoteId) {
              return sum;
            }
            return sum + (((data['quantity'] as num?)?.toDouble() ?? 0.0).abs());
          },
        );

        return currentStock - reservedQuantity - reservedFromMovements;
      } else {
        // Normaler Modus: Alle Reservierungen berücksichtigen
        final reservationsDoc = await reservationsQuery.get();

        final reservedFromMovements = reservationsDoc.docs.fold<double>(
          0,
              (sum, doc) => sum + (((doc.data()['quantity'] as num?)?.toDouble() ?? 0.0).abs()),
        );

        return currentStock - reservedQuantity - reservedFromMovements;
      }
    } catch (e) {
      print('Fehler beim Abrufen der verfügbaren Menge: $e');
      return 0;
    }
  }
  void _showPriceEditDialog(String basketItemId, Map<String, dynamic> itemData) {
    // Sicheres Konvertieren von int oder double nach double
    final double originalPrice = (itemData['price_per_unit'] as num).toDouble();
    final bool isService = itemData['is_service'] == true;
    final descriptionController = TextEditingController(
        text: itemData['description'] ?? ''
    );
    final descriptionEnController = TextEditingController(
        text: itemData['description_en'] ?? ''
    );
    // Falls bereits ein angepasster Preis existiert, diesen verwenden, sonst Originalpreis
    final customTariffController = TextEditingController(
        text: itemData['custom_tariff_number']?.toString() ?? ''
    );
    final customPriceValue = itemData['custom_price_per_unit'];
    final double currentPriceInCHF = customPriceValue != null
        ? (customPriceValue as num).toDouble()
        : originalPrice;

    // Umrechnung in aktuelle Währung
    double displayPrice = currentPriceInCHF;
    if (_selectedCurrency != 'CHF') {
      displayPrice = currentPriceInCHF * _exchangeRates[_selectedCurrency]!;
    }

    final priceController = TextEditingController(text: displayPrice.toStringAsFixed(2));

    // Controller für die Maße - mit bestehenden Werten oder leer
    final lengthController = TextEditingController(
        text: itemData['custom_length']?.toString() ?? ''
    );
    final widthController = TextEditingController(
        text: itemData['custom_width']?.toString() ?? ''
    );
    final thicknessController = TextEditingController(
        text: itemData['custom_thickness']?.toString() ?? ''
    );

    // NEU: Controller für Thermobehandlung
    final temperatureController = TextEditingController(
        text: itemData['thermal_treatment_temperature']?.toString() ?? ''
    );

    // NEU: Variable für Thermobehandlung-Status
    bool hasThermalTreatment = itemData['has_thermal_treatment'] ?? false;
    // NEU: Controller für Volumen - mit Standard-Volumen initialisieren falls leer
    final volumeController = TextEditingController();

    // Variable um zu verfolgen ob Standardwerte gesetzt wurden
    bool standardValuesLoaded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
            
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                            iconName: isService ? 'engineering' : 'edit',
                            defaultIcon: isService ? Icons.engineering : Icons.edit
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isService ? 'Dienstleistung anpassen' : 'Artikel anpassen',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
            
            
                  Divider(height: 1),
            
                  // Scrollbarer Inhalt
            Expanded(
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Produktinfo - angepasst für Dienstleistungen
            Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isService
                        ? 'Dienstleistung: ${itemData['name'] ?? 'Unbenannt'}'
                        : 'Artikel: ${itemData['product_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  // Zeige englischen Namen falls vorhanden
                  if (isService && itemData['name_en'] != null && itemData['name_en'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'EN: ${itemData['name_en']}',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            if (isService && itemData['description'] != null && itemData['description'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
            itemData['description'],
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            ],
            const SizedBox(height: 8),
            Text('Originalpreis: ${NumberFormat.currency(locale: 'de_CH', symbol: 'CHF').format(originalPrice)}'),
            if (currentPriceInCHF != originalPrice)
            Text(
            'Aktueller Preis: ${NumberFormat.currency(locale: 'de_CH', symbol: 'CHF').format(currentPriceInCHF)}',
            style: TextStyle(color: Colors.green[700]),
            ),
            const SizedBox(height: 8),
            Text('Menge: ${itemData['quantity']} ${itemData['unit'] ?? 'Stück'}'),
            ],
            ),
            ),
            
            const SizedBox(height: 24),
            
            // Preis anpassen
            Text(
            'Preis anpassen',
            style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            ),
            ),
            
              // Nach dem Preis-Eingabefeld und vor den Artikel-spezifischen Optionen:
            
            // Bei Dienstleistungen: Beschreibung bearbeiten
              if (isService) ...[
                const SizedBox(height: 24),

                // Beschreibung bearbeiten
                Text(
                  'Beschreibung anpassen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Beschreibung (Deutsch)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
                    ),
                    helperText: 'Optionale Beschreibung der Dienstleistung',
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: descriptionEnController,
                  decoration: InputDecoration(
                    labelText: 'Beschreibung (English)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: getAdaptiveIcon(iconName: 'language', defaultIcon: Icons.language),
                    ),
                    helperText: 'Optional description of the service',
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
              ],
            
            const SizedBox(height: 8),
            
            ValueListenableBuilder<String>(
            valueListenable: _currencyNotifier,
            builder: (context, currency, child) {
            return TextFormField(
            controller: priceController,
            decoration: InputDecoration(
            labelText: 'Neuer Preis in $_selectedCurrency',
            suffixText: _selectedCurrency,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: getAdaptiveIcon(iconName: 'euro', defaultIcon: Icons.euro),
            ),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
            ],
            );
            },
            ),


              const SizedBox(height: 24),

// Zolltarifnummer (für ALLE - Produkte UND Dienstleistungen)
              Text(
                'Zolltarifnummer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

// Bei PRODUKTEN: Zeige Standard-Zolltarifnummer an
              if (!isService) ...[
                FutureBuilder<String>(
                  future: _getStandardTariffNumber(itemData),
                  builder: (context, snapshot) {
                    final standardTariff = snapshot.data ?? 'Wird geladen...';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Standard-Zolltarifnummer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      standardTariff,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ],

// Bei DIENSTLEISTUNGEN: Info-Box
              if (isService) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'info',
                        defaultIcon: Icons.info,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Zolltarifnummer für Dienstleistungen (optional für Handelsrechnungen)',
                          style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

// Freitextfeld für BEIDE (Produkte UND Dienstleistungen)
              TextFormField(
                controller: customTariffController,
                decoration: InputDecoration(
                  labelText: isService
                      ? 'Zolltarifnummer (optional)'
                      : 'Individuelle Zolltarifnummer',
                  hintText: 'z.B. 4407.1200',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: getAdaptiveIcon(
                      iconName: 'local_shipping',
                      defaultIcon: Icons.local_shipping,
                    ),
                  ),
                  helperText: isService
                      ? 'Für Handelsrechnungen'
                      : 'Überschreibt die Standard-Zolltarifnummer',
                  suffixIcon: customTariffController.text.isNotEmpty
                      ? IconButton(
                    icon: getAdaptiveIcon(
                      iconName: 'clear',
                      defaultIcon: Icons.clear,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        customTariffController.clear();
                      });
                    },
                  )
                      : null,
                ),
                onChanged: (value) => setDialogState(() {}),
              ),
              const SizedBox(height: 24),



            // NUR bei Artikeln (nicht bei Dienstleistungen) die weiteren Optionen anzeigen





            if (!isService) ...[
            const SizedBox(height: 24),
            
            // FSC-Auswahl
            Text(
            'FSC-Zertifizierung',
            style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            ),
            ),


            const SizedBox(height: 8),
            
            // FSC Status Dropdown
            DropdownButtonFormField<String>(
            decoration: InputDecoration(
            labelText: 'FSC-Status',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: getAdaptiveIcon(iconName: 'eco', defaultIcon: Icons.eco),
            ),
            ),
            value: itemData['fsc_status'] as String? ?? '100%',
            items: const [
            DropdownMenuItem(value: '100%', child: Text('100% FSC')),
            DropdownMenuItem(value: 'Mix', child: Text('FSC Mix')),
            DropdownMenuItem(value: 'Recycled', child: Text('FSC Recycled')),
            DropdownMenuItem(value: 'Controlled', child: Text('FSC Controlled Wood')),
            DropdownMenuItem(value: '-', child: Text('Kein FSC')),
            ],
            onChanged: (value) {
            // Temporär speichern für später
            },
            ),
              const SizedBox(height: 24),



            
            // NEU: Thermobehandlung
              Text(
                'Thermobehandlung',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  title: const Text('Thermobehandelt'),
                  subtitle: const Text('Artikel wurde thermisch behandelt'),
                  value: hasThermalTreatment,
                  onChanged: (value) {
                    setDialogState(() { // NEU: setDialogState statt setState
                      hasThermalTreatment = value ?? false;
                      if (!hasThermalTreatment) {
                        temperatureController.clear();
                      }
                    });
                  },
                  secondary: getAdaptiveIcon(
                    iconName: 'whatshot',
                    defaultIcon: Icons.whatshot,
                    color: hasThermalTreatment
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
              ),
            
            // Temperatur-Eingabe (nur wenn Thermobehandlung aktiviert)
              if (hasThermalTreatment) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: temperatureController,
                  decoration: InputDecoration(
                    labelText: 'Temperatur (°C)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: getAdaptiveIcon(
                        iconName: 'thermostat',
                        defaultIcon: Icons.thermostat,
                      ),
                    ),
                    suffixText: '°C',
                    helperText: 'Behandlungstemperatur (z.B. 180, 200, 212)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
              ],
            
            
            
            
            const SizedBox(height: 24),
            
                          // Maße anpassen - JETZT MIT FutureBuilder für Standard-Volumen
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _getStandardVolumeForItem(itemData),
                            builder: (context, snapshot) {
                              // Standardwerte nur einmal setzen
                              if (snapshot.connectionState == ConnectionState.done &&
                                  !standardValuesLoaded) {
            
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  // Setze vorhandene custom_volume oder Standard-Volumen
                                  if (itemData['custom_volume'] != null) {
                                    volumeController.text = itemData['custom_volume'].toString();
                                  } else if (snapshot.hasData && snapshot.data != null) {
                                    final standardVolume = snapshot.data!['volume'] ?? 0.0;
                                    if (standardVolume > 0) {
                                      volumeController.text = standardVolume.toStringAsFixed(7);
                                    }
                                  }
                                  standardValuesLoaded = true;
                                });
                              }
            
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Maße anpassen',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (snapshot.hasData && snapshot.data != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Standardwerte',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
            
                                  // Maß-Eingabefelder
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: lengthController,
                                          decoration: InputDecoration(
                                            labelText: 'Länge (mm)',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Theme.of(context).colorScheme.surface,
                                            prefixIcon:   Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: getAdaptiveIcon(iconName: 'straighten', defaultIcon:Icons.straighten, size: 20),
                                            ),
                                          ),
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: widthController,
                                          decoration: InputDecoration(
                                            labelText: 'Breite (mm)',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Theme.of(context).colorScheme.surface,
                                            prefixIcon:   Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: getAdaptiveIcon(iconName: 'swap_horiz', defaultIcon:Icons.swap_horiz, size: 20),
                                            ),
                                          ),
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: thicknessController,
                                    decoration: InputDecoration(
                                      labelText: 'Dicke (mm)',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surface,
                                      prefixIcon:   Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: getAdaptiveIcon(iconName: 'layers', defaultIcon:Icons.layers, size: 20),
                                      ),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                    ],
                                  ),
            
                                  // Volumen-Feld mit Standard-Volumen
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: volumeController,
                                    decoration: InputDecoration(
                                      labelText: 'Volumen (m³)',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surface,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: getAdaptiveIcon(iconName: 'view_in_ar', defaultIcon:Icons.view_in_ar, size: 20),
                                      ),
                                      helperText: snapshot.hasData && snapshot.data != null
                                          ? 'Standardvolumen geladen - kann angepasst werden'
                                          : 'Optional: Manuelles Volumen überschreibt berechneten Wert',
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,7}')),
                                    ],
                                  ),
            
                                  const SizedBox(height: 16),
                                  Text(
                                    'Maße sind optional und werden nur gespeichert, wenn sie eingegeben werden.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
            ],
                      ),
                    ),
                  ),
            
                  // Action Buttons (bleibt unverändert)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          // Zurücksetzen Button (falls bereits angepasst)
                          // Zurücksetzen Button - angepasste Bedingung
                          if (currentPriceInCHF != originalPrice ||
                              (!isService && (itemData['custom_length'] != null ||
                                  itemData['custom_width'] != null ||
                                  itemData['custom_thickness'] != null ||
                                  itemData['custom_volume'] != null ||
                                  itemData['has_thermal_treatment'] == true ||
              itemData['custom_tariff_number'] != null)) ||
                              (isService && (descriptionController.text != (itemData['description'] ?? '') ||
                                  descriptionEnController.text != (itemData['description_en'] ?? ''))))

                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    Map<String, dynamic> updateData = {
                                      'custom_price_per_unit': FieldValue.delete(),
                                      'is_price_customized': false,
                                    };
            
                                    // Nur bei Artikeln die Maße löschen
                                    if (!isService) {
                                      updateData['custom_length'] = FieldValue.delete();
                                      updateData['custom_width'] = FieldValue.delete();
                                      updateData['custom_thickness'] = FieldValue.delete();
                                      updateData['custom_volume'] = FieldValue.delete();
            
                                      updateData['has_thermal_treatment'] = false;
                                      updateData['thermal_treatment_temperature'] = FieldValue.delete();
                                      updateData['custom_tariff_number'] = FieldValue.delete();
                                    }
            
                                    // Bei Dienstleistungen: Beschreibung aus Originaldaten wiederherstellen
                                    // Bei Dienstleistungen: Beschreibung aus Originaldaten wiederherstellen
                                    if (isService) {
                                      // Hole die Original-Dienstleistungsdaten aus Firebase
                                      final serviceDoc = await FirebaseFirestore.instance
                                          .collection('services')
                                          .doc(itemData['service_id'])
                                          .get();

                                      if (serviceDoc.exists) {
                                        updateData['description'] = serviceDoc.data()!['description'] ?? '';
                                        updateData['description_en'] = serviceDoc.data()!['description_en'] ?? '';
                                      }
                                    }
            
                                    await FirebaseFirestore.instance
                                        .collection('temporary_basket')
                                        .doc(basketItemId)
                                        .update(updateData);
            
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isService
                                            ? 'Dienstleistung wurde auf Original zurückgesetzt'
                                            : 'Artikel wurde auf Original zurückgesetzt'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Fehler beim Zurücksetzen: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: getAdaptiveIcon(iconName: 'refresh', defaultIcon: Icons.refresh),
                                label: const Text('Zurücksetzen'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          if (currentPriceInCHF != originalPrice ||
                              itemData['custom_length'] != null ||
                              itemData['custom_width'] != null ||
                              itemData['custom_thickness'] != null ||
                              itemData['custom_volume'] != null)
                            const SizedBox(width: 16),
            
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  // Neuen Preis parsen (Komma oder Punkt akzeptieren)
                                  final String normalizedInput = priceController.text.replaceAll(',', '.');
                                  final newPrice = double.tryParse(normalizedInput) ?? 0.0;
                                  if (newPrice <= 0) {
                                    throw Exception('Bitte gib einen gültigen Preis ein');
                                  }
            
                                  // Umrechnen in CHF für die Speicherung
                                  double priceInCHF = newPrice;
                                  if (_selectedCurrency != 'CHF') {
                                    priceInCHF = newPrice / _exchangeRates[_selectedCurrency]!;
                                  }
            
                                  // Update-Map vorbereiten
                                  Map<String, dynamic> updateData = {
                                    'custom_price_per_unit': priceInCHF,
                                    'is_price_customized': true,
                                  };
            
            
            if (!isService) {
                                  // Maße hinzufügen, wenn sie eingegeben wurden
                                  if (lengthController.text.isNotEmpty) {
                                    final length = double.tryParse(lengthController.text.replaceAll(',', '.'));
                                    if (length != null && length > 0) {
                                      updateData['custom_length'] = length;
                                    }
                                  } else {
                                    updateData['custom_length'] = FieldValue.delete();
                                  }
            
                                  if (widthController.text.isNotEmpty) {
                                    final width = double.tryParse(widthController.text.replaceAll(',', '.'));
                                    if (width != null && width > 0) {
                                      updateData['custom_width'] = width;
                                    }
                                  } else {
                                    updateData['custom_width'] = FieldValue.delete();
                                  }
            
                                  if (thicknessController.text.isNotEmpty) {
                                    final thickness = double.tryParse(thicknessController.text.replaceAll(',', '.'));
                                    if (thickness != null && thickness > 0) {
                                      updateData['custom_thickness'] = thickness;
                                    }
                                  } else {
                                    updateData['custom_thickness'] = FieldValue.delete();
                                  }
            
                                  // Volumen hinzufügen
                                  if (volumeController.text.isNotEmpty) {
                                    final volume = double.tryParse(volumeController.text.replaceAll(',', '.'));
                                    if (volume != null && volume > 0) {
                                      updateData['custom_volume'] = volume;
                                    }
                                  } else {
                                    updateData['custom_volume'] = FieldValue.delete();
                                  }
                                  if (customTariffController.text.trim().isNotEmpty) {
                                    updateData['custom_tariff_number'] = customTariffController.text.trim();
                                  } else {
                                    updateData['custom_tariff_number'] = FieldValue.delete();
                                  }

            }
            
            
            updateData['has_thermal_treatment'] = hasThermalTreatment;
            if (hasThermalTreatment && temperatureController.text.isNotEmpty) {
            final temperature = int.tryParse(temperatureController.text);
            if (temperature != null && temperature > 0) {
            updateData['thermal_treatment_temperature'] = temperature;
            }
            } else {
            updateData['thermal_treatment_temperature'] = FieldValue.delete();
            }
            
            
                                  // Bei Dienstleistungen die Beschreibung mit updaten
                                  // Bei Dienstleistungen die Beschreibungen mit updaten
                                  if (isService) {
                                    if (descriptionController.text != itemData['description']) {
                                      updateData['description'] = descriptionController.text.trim();
                                    }
                                    if (descriptionEnController.text != (itemData['description_en'] ?? '')) {
                                      updateData['description_en'] = descriptionEnController.text.trim();
                                    }
                                  }
                                  // Speichere die Änderungen
                                  await FirebaseFirestore.instance
                                      .collection('temporary_basket')
                                      .doc(basketItemId)
                                      .update(updateData);
            
                                  Navigator.pop(context);
            
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isService
                                          ? 'Dienstleistung wurde aktualisiert'
                                          : 'Artikel wurde aktualisiert'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Fehler: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save),
                              label: const Text('Speichern'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<String> _getStandardTariffNumber(Map<String, dynamic> itemData) async {
    try {
      final woodCode = itemData['wood_code'] as String?;
      if (woodCode == null) return 'Keine Zolltarifnummer';

      // Lade Holzart-Info
      final woodTypeDoc = await FirebaseFirestore.instance
          .collection('wood_types')
          .doc(woodCode)
          .get();

      if (!woodTypeDoc.exists) return 'Keine Zolltarifnummer';

      final woodInfo = woodTypeDoc.data()!;

      // Bestimme Zolltarifnummer basierend auf Dicke
      final thickness = (itemData['custom_thickness'] != null)
          ? (itemData['custom_thickness'] is int
          ? (itemData['custom_thickness'] as int).toDouble()
          : itemData['custom_thickness'] as double)
          : 0.0;

      if (thickness <= 6.0) {
        return woodInfo['z_tares_1'] ?? '4408.1000';
      } else {
        return woodInfo['z_tares_2'] ?? '4407.1200';
      }
    } catch (e) {
      print('Fehler beim Laden der Zolltarifnummer: $e');
      return 'Fehler beim Laden';
    }
  }
// NEU: Hilfsmethode zum Laden des Standard-Volumens für einen bestimmten Artikel
// NEU: Hilfsmethode zum Laden des Standard-Volumens für einen bestimmten Artikel
  Future<Map<String, dynamic>?> _getStandardVolumeForItem(Map<String, dynamic> itemData) async {
    try {
      final instrumentCode = itemData['instrument_code'] as String?;
      final partCode = itemData['part_code'] as String?;

      if (instrumentCode == null || partCode == null) {
        return null;
      }

      final articleNumber = instrumentCode + partCode;

      // Suche in der standardized_products Collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('standardized_products')
          .where('articleNumber', isEqualTo: articleNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final standardProduct = querySnapshot.docs.first.data();

        // Versuche verschiedene Volumen-Felder
        final mm3Volume = standardProduct['volume']?['mm3_withAddition'];
        final dm3Volume = standardProduct['volume']?['dm3_withAddition'];
        final parts = standardProduct['parts'];
        print("parts::$parts");

        if (mm3Volume != null && mm3Volume > 0) {
          // Konvertiere mm³ zu m³
          final volumeInM3 = (mm3Volume as num).toDouble() / 1000000000.0;
          print("volumeInM3:$volumeInM3");
          return {
            'volume': volumeInM3,
            'type': 'mm3',
            'original_value': mm3Volume,
            'parts': parts, // NEU: Hier fehlte es!
          };
        } else if (dm3Volume != null && dm3Volume > 0) {
          // Konvertiere dm³ zu m³
          final volumeInM3 = (dm3Volume as num).toDouble() / 1000.0;
          return {
            'volume': volumeInM3,
            'type': 'dm3',
            'original_value': dm3Volume,
            'parts': parts,
          };
        }
      }

      return null;
    } catch (e) {
      print('Fehler beim Laden des Standard-Volumens für Artikel: $e');
      return null;
    }
  }

// Erweiterte _addToTemporaryBasket Methode in sales_screen.dart

  Future<void> _addToTemporaryBasket(String shortBarcode, Map<String, dynamic> productData, num quantity, String? onlineShopBarcode) async {
    print("quan:$quantity");
    await FirebaseFirestore.instance
        .collection('temporary_basket')
        .add({

      if (productData.containsKey('notes') && productData['notes'] != null && productData['notes'].toString().isNotEmpty)
        'notes': productData['notes'],

      'product_id': shortBarcode,
      'product_name': productData['product_name'],
      'quantity': quantity,
      'timestamp': FieldValue.serverTimestamp(),
      'price_per_unit': productData['price_CHF'],
      'unit': productData['unit'],
      'instrument_name': productData['instrument_name'],
      'instrument_code': productData['instrument_code'],
      'part_name': productData['part_name'],
      'part_code': productData['part_code'],
      'wood_name': productData['wood_name'],
      'wood_code': productData['wood_code'],
      'quality_name': productData['quality_name'],
      'quality_code': productData['quality_code'],

      // NEU: Englische Bezeichnungen hinzufügen
      'instrument_name_en': productData['instrument_name_en'] ?? '',
      'part_name_en': productData['part_name_en'] ?? '',
      'wood_name_en': productData['wood_name_en'] ?? '',
      'product_name_en': productData['product_name_en'] ?? '',

      // NEU: Gratisartikel-Felder hinzufügen
      if (productData.containsKey('is_gratisartikel'))
        'is_gratisartikel': productData['is_gratisartikel'],
      if (productData.containsKey('proforma_value'))
        'proforma_value': productData['proforma_value'],

      // Füge das Feld nur hinzu, wenn es gesetzt ist
      if (onlineShopBarcode != null) 'online_shop_barcode': onlineShopBarcode,
      if (onlineShopBarcode != null) 'is_online_shop_item': true,

      // Maße hinzufügen, falls sie in productData vorhanden sind
      if (productData.containsKey('custom_length') && productData['custom_length'] != null)
        'custom_length': productData['custom_length'],
      if (productData.containsKey('custom_width') && productData['custom_width'] != null)
        'custom_width': productData['custom_width'],
      if (productData.containsKey('custom_thickness') && productData['custom_thickness'] != null)
        'custom_thickness': productData['custom_thickness'],
      // NEU: Volumen hinzufügen
      if (productData.containsKey('volume_per_unit') && productData['volume_per_unit'] != null)
        'volume_per_unit': productData['volume_per_unit'],
      if (productData.containsKey('density') && productData['density'] != null)
        'density': productData['density'],


      // FSC-Status hinzufügen
      if (productData.containsKey('fsc_status') && productData['fsc_status'] != null)
        'fsc_status': productData['fsc_status'],
    });
  }

// Ersetze die bestehende _removeFromBasket Methode in sales_screen.dart:

  Future<void> _removeFromBasket(String basketItemId) async {
    // Hole die Artikeldaten für die Anzeige
    final itemDoc = await FirebaseFirestore.instance
        .collection('temporary_basket')
        .doc(basketItemId)
        .get();

    if (!itemDoc.exists) return;

    final itemData = itemDoc.data()!;
    final isService = itemData['is_service'] == true;
    final isManual = itemData['is_manual_product'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: getAdaptiveIcon(
                iconName: 'delete',
                defaultIcon: Icons.delete,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Artikel entfernen?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artikel-Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isService)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Text(
                            'DIENSTLEISTUNG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        )
                      else if (isManual)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.purple.withOpacity(0.3)),
                          ),
                          child: Text(
                            'MANUELL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isService
                              ? (itemData['name'] ?? 'Unbenannte Dienstleistung')
                              : (itemData['product_name'] ?? 'Unbekanntes Produkt'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (!isService) ...[
                    Text(
                      '${itemData['instrument_name'] ?? ''} - ${itemData['wood_name'] ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${itemData['part_name'] ?? ''} - ${itemData['quality_name'] ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Menge: ${itemData['quantity']} ${itemData['unit'] ?? 'Stück'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      ValueListenableBuilder<String>(
                        valueListenable: _currencyNotifier,
                        builder: (context, currency, child) {
                          final price = itemData['custom_price_per_unit'] ?? itemData['price_per_unit'] ?? 0;
                          final total = (itemData['quantity'] as num) * (price as num);
                          return Text(
                            _formatPrice(total.toDouble()),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Möchten Sie diesen Artikel wirklich aus dem Warenkorb entfernen?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Behalten'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // NEU: Batch für atomare Operation
                final batch = FirebaseFirestore.instance.batch();

                // 1. Lösche aus temporary_basket
                batch.delete(
                    FirebaseFirestore.instance
                        .collection('temporary_basket')
                        .doc(basketItemId)
                );

                // 2. NEU: Lösche alle Packlisten-Zuordnungen für diesen Artikel
                final packingListAssignments = await FirebaseFirestore.instance
                    .collection('temporary_packing_lists')
                    .where('basket_item_id', isEqualTo: basketItemId)
                    .get();

                for (final doc in packingListAssignments.docs) {
                  batch.delete(doc.reference);
                }

                // 3. Führe alle Löschungen aus
                await batch.commit();

                // Entferne aus lokalem State
                setState(() {
                  _itemDiscounts.remove(basketItemId);
                });

                // Zeige Bestätigung
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text(
                //         packingListAssignments.docs.isNotEmpty
                //             ? 'Artikel wurde entfernt (inkl. ${packingListAssignments.docs.length} Packlisten-Zuordnung${packingListAssignments.docs.length > 1 ? "en" : ""})'
                //             : 'Artikel wurde entfernt'
                //     ),
                //     backgroundColor: Colors.orange,
                //     action: SnackBarAction(
                //       label: 'Rückgängig',
                //       textColor: Colors.white,
                //       onPressed: () async {
                //         try {
                //           final restorationBatch = FirebaseFirestore.instance.batch();
                //
                //           // 1. Artikel wiederherstellen
                //           restorationBatch.set(
                //               FirebaseFirestore.instance
                //                   .collection('temporary_basket')
                //                   .doc(basketItemId),
                //               itemData
                //           );
                //
                //           // 2. Packlisten-Zuordnungen wiederherstellen
                //           for (final packingDoc in packingListAssignments.docs) {
                //             restorationBatch.set(
                //                 packingDoc.reference,
                //                 packingDoc.data()
                //             );
                //           }
                //
                //           await restorationBatch.commit();
                //
                //           ScaffoldMessenger.of(context).showSnackBar(
                //             const SnackBar(
                //               content: Text('Artikel wurde wiederhergestellt'),
                //               backgroundColor: Colors.green,
                //               duration: Duration(seconds: 2),
                //             ),
                //           );
                //         } catch (e) {
                //           ScaffoldMessenger.of(context).showSnackBar(
                //             SnackBar(
                //               content: Text('Fehler beim Wiederherstellen: $e'),
                //               backgroundColor: Colors.red,
                //             ),
                //           );
                //         }
                //       },
                //     ),
                //   ),
                // );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fehler beim Entfernen: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
            label: const Text('Entfernen'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  // Ergänzung für _showQuantityDialog in sales_screen.dart
// Hilfsmethode zum Abrufen der Dichte aus der Holzart
  Future<double?> _getDensityForProduct(Map<String, dynamic> productData) async {
    try {
      final woodCode = productData['wood_code'] as String?;
      if (woodCode == null) return null;

      final woodDoc = await FirebaseFirestore.instance
          .collection('wood_types')
          .where('code', isEqualTo: woodCode)
          .limit(1)
          .get();

      if (woodDoc.docs.isNotEmpty) {
        final woodData = woodDoc.docs.first.data();
        return (woodData['density'] as num?)?.toDouble();
      }
    } catch (e) {
      print('Fehler beim Abrufen der Dichte: $e');
    }
    return null;
  }
  void _showQuantityDialog(String barcode, Map<String, dynamic> productData) {
    quantityController.clear();

    print(productData);
    // Controller für die Maße
    final lengthController = TextEditingController();
    final widthController = TextEditingController();
    final thicknessController = TextEditingController();
    final notesController = TextEditingController();
    final volumeController = TextEditingController();
    final densityController = TextEditingController();

    // FSC-Status Variable
    String selectedFscStatus = '-'; // Standard
    if (productData['wood_name']?.toString().toLowerCase() == 'fichte') {
      selectedFscStatus = '100%';
    }
    // NEU: Gratisartikel Variablen hier definieren
    bool isGratisartikel = false;
    final proformaController = TextEditingController(
        text: (productData['price_CHF'] as num).toDouble().toStringAsFixed(2)
    );


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Text(
                            'Produkt hinzufügen',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1),

                    // Scrollbarer Inhalt
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Produktinfo
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Produkt:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${productData['instrument_name'] ?? 'N/A'} - ${productData['part_name'] ?? 'N/A'}'),
                                  Text('${productData['wood_name'] ?? 'N/A'} - ${productData['quality_name'] ?? 'N/A'}'),
                                  const SizedBox(height: 8),
                                  FutureBuilder<double>(
                                    future: _getAvailableQuantity(barcode),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Text(
                                          'Verfügbar: ${productData['unit']?.toLowerCase() == 'stück'
                                              ? snapshot.data!.toStringAsFixed(0)
                                              : snapshot.data!.toStringAsFixed(3)} ${productData['unit'] ?? 'Stück'}',
                                          style: TextStyle(
                                            color: snapshot.data! > 0 ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }
                                      return const CircularProgressIndicator();
                                    },
                                  ),
                                  // In der Produktinfo Container, nach der Verfügbarkeitsanzeige:
                                  const SizedBox(height: 8),
                                  Divider(color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Preis pro ${productData['unit'] ?? 'Stück'}:',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      ValueListenableBuilder<String>(
                                        valueListenable: _currencyNotifier,
                                        builder: (context, currency, child) {
                                          return Text(
                                            _formatPrice((productData['price_CHF'] as num).toDouble()),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Menge
                            Text(
                              'Menge',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: quantityController,
                              decoration: InputDecoration(
                                labelText: 'Menge',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: getAdaptiveIcon(iconName: 'numbers', defaultIcon: Icons.numbers),
                                ),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                if (productData['unit'] == 'Stück')
                                  FilteringTextInputFormatter.digitsOnly
                                else if (productData['unit'] == 'kg' ||
                                    productData['unit'] == 'Kg' ||
                                    productData['unit'] == 'm³' ||
                                    productData['unit'] == 'm²')
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,3}'))
                                else
                                  FilteringTextInputFormatter.digitsOnly,
                              ],
                              autofocus: true,
                            ),

                            const SizedBox(height: 24),

                            // FSC-Auswahl
                            Text(
                              'FSC-Zertifizierung',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'FSC-Status',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: getAdaptiveIcon(iconName: 'eco', defaultIcon: Icons.eco),
                                ),
                              ),
                              value: selectedFscStatus,
                              items: const [
                                DropdownMenuItem(value: '100%', child: Text('100% FSC')),
                                DropdownMenuItem(value: 'Mix', child: Text('FSC Mix')),
                                DropdownMenuItem(value: 'Recycled', child: Text('FSC Recycled')),
                                DropdownMenuItem(value: 'Controlled', child: Text('FSC Controlled Wood')),
                                DropdownMenuItem(value: '-', child: Text('Kein FSC')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedFscStatus = value ?? '100%';
                                });
                              },
                            ),
// Nach dem Gratisartikel-Abschnitt hinzufügen:
                            const SizedBox(height: 24),

// Hinweise-Abschnitt
                            Text(
                              'Hinweise',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            TextFormField(
                              controller: notesController,
                              decoration: InputDecoration(
                                labelText: 'Spezielle Hinweise (optional)',
                                hintText: 'z.B. besondere Qualitätsmerkmale, Lagerort, etc.',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                prefixIcon: getAdaptiveIcon(
                                  iconName: 'note',
                                  defaultIcon: Icons.note_alt,
                                ),
                              ),
                              maxLines: 3,
                              minLines: 2,
                            ),
                            const SizedBox(height: 24),

                            // Maße - mit FutureBuilder für Standardmaße
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _getStandardMeasurements(productData),
                              builder: (context, snapshot) {
                                // Ergänze den zweiten FutureBuilder für Volumen
                                return FutureBuilder<Map<String, dynamic>?>(
                                  future: _getStandardVolumeForItem(productData),
                                  builder: (context, volumeSnapshot) {

                                    print("test2");
                                    print( volumeSnapshot.data!['parts']);
                                    // Einmalig die Standardwerte setzen, aber nur wenn Controller leer sind
                                    if (snapshot.connectionState == ConnectionState.done &&
                                        snapshot.hasData &&
                                        snapshot.data != null) {

                                      final standardMeasures = snapshot.data!;

                                      // Verwende WidgetsBinding um sicherzustellen, dass es nur einmal gesetzt wird
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (lengthController.text.isEmpty && standardMeasures['length'] != null) {
                                          lengthController.text = standardMeasures['length']?.toString() ?? '';
                                        }
                                        if (widthController.text.isEmpty && standardMeasures['width'] != null) {
                                          widthController.text = standardMeasures['width']?.toString() ?? '';
                                        }
                                        if (thicknessController.text.isEmpty && standardMeasures['thickness'] != null) {
                                          thicknessController.text = standardMeasures['thickness']?.toString() ?? '';
                                        }
                                      });
                                    }

                                    // Setze Volumen einmalig
                                    if (volumeSnapshot.connectionState == ConnectionState.done &&
                                        volumeSnapshot.hasData &&
                                        volumeSnapshot.data != null &&
                                        volumeController.text.isEmpty) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        final standardVolume = volumeSnapshot.data!['volume'] ?? 0.0;
                                        if (standardVolume > 0) {
                                          volumeController.text = standardVolume.toStringAsFixed(7);
                                        }
                                      });
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Maße',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if ((snapshot.hasData && snapshot.data != null) ||
                                                (volumeSnapshot.hasData && volumeSnapshot.data != null))
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primaryContainer,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Standardmaße',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
// NEU: Anzahl Bauteile (Info-Feld)
                                        if (volumeSnapshot.connectionState == ConnectionState.done &&
                                            volumeSnapshot.hasData &&
                                            volumeSnapshot.data != null &&
                                            volumeSnapshot.data!['parts'] != null) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                getAdaptiveIcon(
                                                  iconName: 'category',
                                                  defaultIcon: Icons.category,
                                                  size: 20,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Anzahl Bauteile',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${volumeSnapshot.data!['parts']} Teile',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        // Maß-Eingabefelder - User-Eingaben haben Vorrang
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: lengthController,
                                                decoration: InputDecoration(
                                                  labelText: 'Länge (mm)',
                                                  border: const OutlineInputBorder(),
                                                  filled: true,
                                                  fillColor: Theme.of(context).colorScheme.surface,
                                                  prefixIcon:
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: getAdaptiveIcon(iconName: 'straighten', defaultIcon:Icons.straighten, size: 20),
                                                  ),

                                                ),
                                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                onChanged: (value) {
                                                  setState(() {});
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller: widthController,
                                                decoration: InputDecoration(
                                                  labelText: 'Breite (mm)',
                                                  border: const OutlineInputBorder(),
                                                  filled: true,
                                                  fillColor: Theme.of(context).colorScheme.surface,
                                                  prefixIcon:
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: getAdaptiveIcon(iconName: 'swap_horiz', defaultIcon:Icons.swap_horiz, size: 20),
                                                  ),

                                                ),
                                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                onChanged: (value) {
                                                  setState(() {});
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: thicknessController,
                                          decoration: InputDecoration(
                                            labelText: 'Dicke (mm)',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Theme.of(context).colorScheme.surface,
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: getAdaptiveIcon(iconName: 'layers', defaultIcon:Icons.layers, size: 20),
                                            ),

                                          ),
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) {
                                            setState(() {});
                                          },
                                        ),

                                        // NEU: Volumen-Feld
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: volumeController,
                                          decoration: InputDecoration(
                                            labelText: 'Volumen (m³)',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Theme.of(context).colorScheme.surface,
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: getAdaptiveIcon(
                                                  iconName: 'view_in_ar',
                                                  defaultIcon: Icons.view_in_ar,
                                                  size: 20
                                              ),
                                            ),
                                            helperText: volumeSnapshot.hasData && volumeSnapshot.data != null
                                                ? 'Standardvolumen aus Produktdefinition'
                                                : 'Optional: Volumen manuell eingeben',
                                          ),
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,7}')),
                                          ],
                                          onChanged: (value) {
                                            setState(() {});
                                          },
                                        ),

                                        if ((snapshot.hasData && snapshot.data != null) ||
                                            (volumeSnapshot.hasData && volumeSnapshot.data != null))
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              'Die Standardmaße können individuell angepasst werden',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),

                                        const SizedBox(height: 12),
                                        FutureBuilder<double?>(
                                          future: _getDensityForProduct(productData),
                                          builder: (context, densitySnapshot) {
                                            // Setze Dichte-Wert wenn verfügbar
                                            if (densitySnapshot.hasData && densitySnapshot.data != null && densityController.text.isEmpty) {
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                densityController.text = densitySnapshot.data!.toStringAsFixed(0);
                                              });
                                            }

                                            return Column(
                                              children: [
                                                TextFormField(
                                                  controller: densityController,
                                                  decoration: InputDecoration(
                                                    labelText: 'Spezifisches Gewicht (kg/m³)',
                                                    border: const OutlineInputBorder(),
                                                    filled: true,
                                                    fillColor: Theme.of(context).colorScheme.surface,
                                                    prefixIcon: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: getAdaptiveIcon(
                                                          iconName: 'grain',
                                                          defaultIcon: Icons.grain,
                                                          size: 20
                                                      ),
                                                    ),
                                                    helperText: densitySnapshot.hasData
                                                        ? 'Dichte aus Holzart: ${densitySnapshot.data} kg/m³'
                                                        : 'Manuell eingeben falls nicht automatisch geladen',
                                                  ),
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,0}')),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {}); // Trigger rebuild für Gewichtsberechnung
                                                  },
                                                ),

                                                // NEU: Gewichtsberechnung
                                                const SizedBox(height: 16),

                                                // Berechne und zeige das Gewicht
                                                Builder(
                                                  builder: (context) {
                                                    // Parse Werte
                                                    final quantityText = quantityController.text.replaceAll(',', '.');
                                                    final volumeText = volumeController.text.replaceAll(',', '.');
                                                    final densityText = densityController.text.replaceAll(',', '.');

                                                    final quantity = double.tryParse(quantityText) ?? 0.0;
                                                    final volumePerUnit = double.tryParse(volumeText) ?? 0.0;
                                                    final density = double.tryParse(densityText) ?? 0.0;

                                                    // Berechne Gewicht
                                                    final weightPerUnit = volumePerUnit * density; // kg pro Einheit
                                                    final totalWeight = weightPerUnit * quantity; // Gesamtgewicht

                                                    if (volumePerUnit > 0 && density > 0) {
                                                      return Container(
                                                        padding: const EdgeInsets.all(12),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                getAdaptiveIcon(iconName: 'scale', defaultIcon:
                                                                  Icons.scale,
                                                                  size: 20,
                                                                  color: Theme.of(context).colorScheme.primary,
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Text(
                                                                  'Gewichtsberechnung',
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Theme.of(context).colorScheme.primary,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 8),
                                                            Text(
                                                              'Volumen: ${volumePerUnit.toStringAsFixed(7)} m³ × Dichte: ${density.toStringAsFixed(0)} kg/m³',
                                                              style: TextStyle(fontSize: 12),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                              children: [
                                                                Text('Gewicht pro ${productData['unit'] ?? 'Stück'}:'),
                                                                Text(
                                                                  '${weightPerUnit.toStringAsFixed(2)} kg',
                                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                                ),
                                                              ],
                                                            ),
                                                            if (quantity > 0) ...[
                                                              const SizedBox(height: 4),
                                                              Divider(),
                                                              const SizedBox(height: 4),
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Text(
                                                                    'Gesamtgewicht:',
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 14,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    '${totalWeight.toStringAsFixed(2)} kg',
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 16,
                                                                      color: Theme.of(context).colorScheme.primary,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      );
                                                    } else {
                                                      return Container(
                                                        padding: const EdgeInsets.all(12),
                                                        decoration: BoxDecoration(
                                                          color: Colors.orange.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: Colors.orange.withOpacity(0.3),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            getAdaptiveIcon(iconName: 'info', defaultIcon:
                                                              Icons.info,
                                                              size: 16,
                                                              color: Colors.orange,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                'Gewichtsberechnung erfordert Volumen und Dichte',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.orange[800],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        ),

                                      ],
                                    );
                                  },
                                );
                              },
                            ),


// Nach dem Maße-Abschnitt und vor dem Ende des SingleChildScrollView:

                            const SizedBox(height: 24),

// Gratisartikel-Abschnitt
                            Text(
                              'Gratisartikel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),

// Checkbox für Gratisartikel
                            StatefulBuilder(
                              builder: (context, setCheckboxState) {

                                return Column(
                                  children: [
                                    CheckboxListTile(
                                      title: const Text('Als Gratisartikel markieren'),
                                      subtitle: const Text(
                                        'Artikel wird mit 0.00 berechnet, Pro-forma-Wert nur für Handelsrechnung',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      value: isGratisartikel,
                                      onChanged: (value) {
                                        setCheckboxState(() {
                                          print("yoooQQ");
                                          isGratisartikel = value ?? false;
                                        });
                                      },
                                    ),

                                    // Pro-forma-Wert Eingabe (nur sichtbar wenn Checkbox aktiv)
                                    if (isGratisartikel) ...[
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: proformaController,
                                        decoration: InputDecoration(
                                          labelText: 'Pro-forma-Wert für Handelsrechnung',
                                          suffixText: _selectedCurrency,
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: Theme.of(context).colorScheme.surface,
                                          prefixIcon: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: getAdaptiveIcon(
                                                iconName: 'receipt_long',
                                                defaultIcon: Icons.receipt_long
                                            ),
                                          ),
                                          helperText: 'Dieser Wert erscheint nur auf der Handelsrechnung',
                                        ),
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                        ],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),


                          ],
                        ),
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Abbrechen'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child:
                              ElevatedButton(
                                onPressed: () async {
                                  if (quantityController.text.isNotEmpty) {
                                    // Ersetze Komma durch Punkt für die Konvertierung
                                    final normalizedInput = quantityController.text.replaceAll(',', '.');

                                    // Parse als double wenn die Einheit Nachkommastellen erlaubt
                                    num quantity;
                                    if (productData['unit'] == 'Stück') {
                                      quantity = int.tryParse(normalizedInput) ?? 0;
                                    } else if (productData['unit'] == 'kg' ||
                                        productData['unit'] == 'Kg' ||
                                        productData['unit'] == 'm³' ||
                                        productData['unit'] == 'm²') {
                                      quantity = double.tryParse(normalizedInput) ?? 0;
                                    } else {
                                      quantity = int.tryParse(normalizedInput) ?? 0;
                                    }
                                    final availableQuantity = await _getAvailableQuantity(barcode);

                                    if (quantity <= availableQuantity) {
                                      // Erweitere productData um die Maße und FSC
                                      final updatedProductData = Map<String, dynamic>.from(productData);

                                      // Füge Maße hinzu, wenn sie eingegeben wurden
                                      if (lengthController.text.isNotEmpty) {
                                        updatedProductData['custom_length'] = double.tryParse(lengthController.text.replaceAll(',', '.')) ?? 0.0;
                                      }
                                      if (widthController.text.isNotEmpty) {
                                        updatedProductData['custom_width'] = double.tryParse(widthController.text.replaceAll(',', '.')) ?? 0.0;
                                      }
                                      if (thicknessController.text.isNotEmpty) {
                                        updatedProductData['custom_thickness'] = double.tryParse(thicknessController.text.replaceAll(',', '.')) ?? 0.0;
                                      }

                                      print("volumenC:$volumeController");
                                      if (volumeController.text.isNotEmpty) {
                                        updatedProductData['volume_per_unit'] =
                                            double.tryParse(volumeController.text.replaceAll(',', '.')) ?? 0.0;
                                      }
                                      if (densityController.text.isNotEmpty) {
                                        updatedProductData['density'] = double.tryParse(densityController.text.replaceAll(',', '.')) ?? 0.0;
                                      }


                                      // Füge FSC-Status hinzu
                                      updatedProductData['fsc_status'] = selectedFscStatus;

                                      // NEU: Erweitere productData um die Gratisartikel-Info
                                      if (isGratisartikel) {
                                        updatedProductData['is_gratisartikel'] = true;

                                        // Proforma-Wert parsen
                                        double proformaValue = double.tryParse(
                                            proformaController.text.replaceAll(',', '.')) ??
                                            (productData['price_CHF'] as num).toDouble();

                                        // In CHF umrechnen, falls andere Währung ausgewählt
                                        if (_selectedCurrency != 'CHF') {
                                          proformaValue = proformaValue / _exchangeRates[_selectedCurrency]!;
                                        }

                                        updatedProductData['proforma_value'] = proformaValue;
                                      }
                                      if (notesController.text.trim().isNotEmpty) {
                                        updatedProductData['notes'] = notesController.text.trim();
                                      }

                                      await _addToTemporaryBasket(barcode, updatedProductData, quantity, null);
                                      Navigator.pop(context);
                                    } else {
                                      AppToast.show(message: "Nicht genügend Bestand verfügbar", height: h);
                                    }
                                  }
                                },
                                child: const Text('Hinzufügen'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

// Neue Hilfsmethode zum Abrufen der Standardmaße
  Future<Map<String, dynamic>?> _getStandardMeasurements(Map<String, dynamic> productData) async {
    try {
      // Erstelle die Artikelnummer aus Instrument- und Bauteil-Code
      final instrumentCode = productData['instrument_code'] as String?;
      final partCode = productData['part_code'] as String?;

      if (instrumentCode == null || partCode == null) {
        return null;
      }

      final articleNumber = instrumentCode + partCode;

      // Suche in der standardized_products Collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('standardized_products')
          .where('articleNumber', isEqualTo: articleNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final standardProduct = querySnapshot.docs.first.data();

        // Extrahiere die Standardmaße (ohne Zumaß)
        return {
          'length': standardProduct['dimensions']?['length']?['withAddition'],
          'width': standardProduct['dimensions']?['width']?['withAddition'],
          'thickness': standardProduct['dimensions']?['thickness']?['value'],
        };
      }

      return null;
    } catch (e) {
      print('Fehler beim Abrufen der Standardmaße: $e');
      return null;
    }
  }

  Future<void> _fetchProductAndShowQuantityDialog(String barcode) async {
    try {
      // Prüfe zuerst, ob es ein Online-Shop-Item ist
      final onlineShopDocs = await FirebaseFirestore.instance
          .collection('onlineshop')
          .where('barcode', isEqualTo: barcode)  // Changed from short_barcode to barcode
          .where('sold', isEqualTo: false) // Nur nicht verkaufte
          .limit(1)
          .get();

      if (onlineShopDocs.docs.isNotEmpty) {
        final onlineShopDoc = onlineShopDocs.docs.first;
        final onlineShopBarcode = onlineShopDoc.id; // Der Dokument-ID ist der vollständige Barcode
        final onlineShopData = onlineShopDoc.data();

        // Es ist ein Online-Shop-Item, füge es direkt mit Menge 1 hinzu
        final doc = await FirebaseFirestore.instance
            .collection('inventory')
            .doc(onlineShopData['short_barcode']) // Fixed: use onlineShopData instead of onlineShopDocs
            .get();

        if (doc.exists) {
          // Hier das Online-Shop-Barcode übergeben
          await _addToTemporaryBasket(
              onlineShopData['short_barcode'], // Use the short barcode for inventory reference
              doc.data()!,
              1,
              onlineShopBarcode
          );

          // Online-Shop-Item als "im Warenkorb" markieren
          await FirebaseFirestore.instance
              .collection('onlineshop')
              .doc(onlineShopBarcode)
              .update({'in_cart': true});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Online-Shop Artikel wurde zum Warenkorb hinzugefügt'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        return;
      }

      // Normales Lagerprodukt - bestehender Code
      final doc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(barcode)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final productData = doc.data() as Map<String, dynamic>;
        _showQuantityDialog(barcode, productData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produkt nicht gefunden'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
    void _showBarcodeInputDialog() {
barcodeController.clear();
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: const Text('Barcode eingeben'),
content: TextFormField(
controller: barcodeController,
decoration: const InputDecoration(
labelText: 'Barcode',
border: OutlineInputBorder(),
),
keyboardType: TextInputType.number,
//inputFormatters: [FilteringTextInputFormatter.digitsOnly],
autofocus: true,
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Abbrechen'),
),
ElevatedButton(
onPressed: () {
if (barcodeController.text.isNotEmpty) {
Navigator.pop(context);
_fetchProductAndShowQuantityDialog(barcodeController.text);
}
},
child: const Text('Suchen'),
),
],
);
},
);
}

    Future<void> _scanProduct() async {
try {
  final String? barcodeResult = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (context) => SimpleBarcodeScannerPage(),
    ),
  );

if (barcodeResult != '-1') {
await _fetchProductAndShowQuantityDialog(barcodeResult!);
}
} on PlatformException {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Fehler beim Scannen'),
backgroundColor: Colors.red,
),
);
}
}

  Future<void> _processTransaction() async {
    // Navigiere zum neuen Flow
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>  QuoteOrderFlowScreen(
          editingQuoteId: _editingQuoteId,  // NEU
          editingQuoteNumber: _editingQuoteNumber,  // NEU
        ),
      ),
    );
  }


  DateTime getDateTimeFromTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) return DateTime.parse(timestamp);
    return DateTime.now();
  }

// CSV-Generierung
  Future<Uint8List> _generateCsv(String receiptId) async {
    final receiptDoc = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .doc(receiptId)
        .get();

    final data = receiptDoc.data()!;
    final receiptNumber = data['receiptNumber'] as String;
    final items = data['items'] as List<dynamic>;
    final calculations = data['calculations'] as Map<String, dynamic>;
    final timestamp = getDateTimeFromTimestamp(data['metadata']['timestamp']);

    // Kopfzeile mit Beleg-Info
    final List<List<dynamic>> csvData = [
      [
        'Lieferschein Nr.:', 'LS-$receiptNumber',
        'Datum:', DateFormat('dd.MM.yyyy').format(timestamp),
      ],
      [], // Leerzeile
      [
        // Header für Artikel
        'Artikelnummer',
        'Artikelbezeichnung',
        'Qualität',
        'Menge',
        'Einheit',
        'Einzelpreis',
        'Positionsrabatt %',
        'Positionsrabatt CHF',
        'Positionssumme',
        'Zwischensumme',
        'Positionsrabatte',
        'Gesamtrabatt %',
        'Gesamtrabatt CHF',
        'Nettobetrag',
        'MwSt %',
        'MwSt CHF',
        'Gesamtbetrag'
      ]
    ];

    // Artikel-Daten
    for (final item in items) {
      csvData.add([
        item['product_id'] ?? '',
        item['product_name'] ?? '',
        item['quality_name'] ?? '',
        item['quantity'] ?? 0,
        item['unit'] ?? '',
        item['price_per_unit'] ?? 0,
        (item['discount'] as Map<String, dynamic>?)?['percentage'] ?? 0,
        item['discount_amount'] ?? 0,
        item['total'] ?? 0,
        // Summen nur in der ersten Zeile
        if (items.indexOf(item) == 0) ...[
          calculations['subtotal'] ?? 0,
          calculations['item_discounts'] ?? 0,
          (calculations['total_discount'] as Map<String, dynamic>?)?['percentage'] ?? 0,
          calculations['total_discount_amount'] ?? 0,
          calculations['net_amount'] ?? 0,
          calculations['vat_rate'] ?? 0,
          calculations['vat_amount'] ?? 0,
          calculations['total'] ?? 0,
        ] else ...[
          '', '', '', '', '', '', '', '', // Leere Zellen für die Summen
        ],
      ]);
    }

    // Formatierung als CSV mit deutschem Excel-Format
    final csvString = const ListToCsvConverter().convert(
      csvData,
      fieldDelimiter: ';',
      textDelimiter: '"',
      textEndDelimiter: '"',
    );

    // BOM für Excel + CSV Daten
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)];
    return Uint8List.fromList(bytes);
  }


// Optional: Hilfsmethode für die Analyse der Messeverkäufe
  Future<Map<String, dynamic>> analyzeFairSales(String fairId) async {
    final sales = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .where('metadata.fairId', isEqualTo: fairId)
        .get();

    double totalRevenue = 0;
    double totalVat = 0;
    Map<String, double> productsSold = {};
    Set<String> uniqueCustomers = {};

    for (final sale in sales.docs) {
      final data = sale.data();
      final calculations = data['calculations'] as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;

      totalRevenue += calculations['total'] as double;
      totalVat += calculations['vat_amount'] as double;
      uniqueCustomers.add(data['customer']['id'] as String);

      for (final item in items) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as double;
        productsSold[productId] = (productsSold[productId] ?? 0) + quantity;
      }
    }

    return {
      'totalRevenue': totalRevenue,
      'totalVat': totalVat,
      'totalSales': sales.docs.length,
      'uniqueCustomers': uniqueCustomers.length,
      'productsSold': productsSold,
    };
  }


  // Future<Uint8List> _generatePdf(String receiptId) async {
  //   final pdf = pw.Document();
  //   final receiptDoc = await FirebaseFirestore.instance
  //       .collection('sales_receipts')
  //       .doc(receiptId)
  //       .get();
  //
  //   final receiptData = receiptDoc.data()!;
  //   final customerData = receiptData['customer'] as Map<String, dynamic>;
  //   final items = (receiptData['items'] as List).cast<Map<String, dynamic>>();
  //
  //   // Lade das Firmenlogo
  //   final logoImage = await rootBundle.load('images/logo.png');
  //   final logo = pw.MemoryImage(logoImage.buffer.asUint8List());
  //
  //   pdf.addPage(
  //     pw.Page(
  //       build: (pw.Context context) {
  //         return pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //           children: [
  //             // Header mit Logo und Firmeninformationen
  //             pw.Row(
  //               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //               children: [
  //                 pw.Column(
  //                   crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                   children: [
  //                     pw.Text(
  //                       'Lieferschein',
  //                       style: pw.TextStyle(
  //                         fontSize: 24,
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //                     pw.SizedBox(height: 4),
  //                     pw.Text(
  //                       'Nummer: $receiptId',
  //                       style: const pw.TextStyle(fontSize: 12),
  //                     ),
  //                     pw.Text(
  //                       'Datum: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
  //                       style: const pw.TextStyle(fontSize: 12),
  //                     ),
  //                   ],
  //                 ),
  //                 pw.Image(logo, width: 150),
  //               ],
  //             ),
  //             pw.SizedBox(height: 40),
  //
  //             // Kundenadresse
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(10),
  //               decoration: pw.BoxDecoration(
  //                 border: pw.Border.all(color: PdfColors.grey300),
  //               ),
  //               child: pw.Column(
  //                 crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                 children: [
  //                   pw.Text(
  //                     customerData['company'],
  //                     style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                   ),
  //                   pw.Text(customerData['fullName']),
  //                   pw.Text(customerData['address']),
  //                 ],
  //               ),
  //             ),
  //             pw.SizedBox(height: 20),
  //
  //             // Artikel-Tabelle
  //             pw.Table(
  //               border: pw.TableBorder.all(color: PdfColors.grey300),
  //               columnWidths: {
  //                 0: const pw.FlexColumnWidth(4), // Produkt
  //                 1: const pw.FlexColumnWidth(1), // Menge
  //                 2: const pw.FlexColumnWidth(1), // Einheit
  //                 3: const pw.FlexColumnWidth(2), // Preis/Einheit
  //                 4: const pw.FlexColumnWidth(2), // Gesamt
  //               },
  //               children: [
  //                 // Header
  //                 pw.TableRow(
  //                   decoration: pw.BoxDecoration(
  //                     color: PdfColors.grey200,
  //                   ),
  //                   children: [
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Produkt',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Menge',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Einheit',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Preis/Einheit',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Gesamt',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 // Artikel
  //                 ...items.map((item) => pw.TableRow(
  //                   children: [
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Column(
  //                         crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                         children: [
  //                           pw.Text(item['product_name']),
  //                           pw.SizedBox(height: 2),
  //                           pw.Text(
  //                             '${item['instrument_name']} - ${item['part_name']} - ${item['wood_name']} - ${item['quality_name']}',
  //                             style: const pw.TextStyle(
  //                               fontSize: 10,
  //                               color: PdfColors.grey700,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(item['quantity'].toString()),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(item['unit']),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         '${item['price_per_unit'].toStringAsFixed(2)} CHF',
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         '${item['total_price'].toStringAsFixed(2)} CHF',
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                   ],
  //                 )),
  //               ],
  //             ),
  //             pw.SizedBox(height: 20),
  //
  //             // Gesamtsumme
  //             pw.Container(
  //               alignment: pw.Alignment.centerRight,
  //               child: pw.Column(
  //                 crossAxisAlignment: pw.CrossAxisAlignment.end,
  //                 children: [
  //                   pw.Text(
  //                     'Gesamtbetrag: ${receiptData['total_amount'].toStringAsFixed(2)} CHF',
  //                     style: pw.TextStyle(
  //                       fontSize: 16,
  //                       fontWeight: pw.FontWeight.bold,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //
  //             // Footer
  //             pw.Positioned(
  //               bottom: 30,
  //               child: pw.Container(
  //                 alignment: pw.Alignment.center,
  //                 width: 500,
  //                 child: pw.Text(
  //                   'Vielen Dank für Ihren Einkauf!',
  //                   style: const pw.TextStyle(
  //                     color: PdfColors.grey700,
  //                     fontSize: 12,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         );
  //       },
  //     ),
  //   );
  //
  //   return pdf.save();
  // }
// 2. Erweiterte PDF-Generierung

  Future<Map<String, String>> _getReceiptAdditionalTexts(String receiptId) async {
    try {
      final receiptDoc = await FirebaseFirestore.instance
          .collection('sales_receipts')
          .doc(receiptId)
          .get();

      if (!receiptDoc.exists) return {};

      final data = receiptDoc.data();
      if (data == null || !data.containsKey('additional_texts')) return {};

      final texts = data['additional_texts'] as Map<String, dynamic>;

      final result = <String, String>{};

      // Legende
      if (texts['legend']?['selected'] == true) {
        final legendSettings = texts['legend'] as Map<String, dynamic>;
        result['legend'] = AdditionalTextsManager.getTextContent(legendSettings, 'legend');
      }

      // FSC
      if (texts['fsc']?['selected'] == true) {
        final fscSettings = texts['fsc'] as Map<String, dynamic>;
        result['fsc'] = AdditionalTextsManager.getTextContent(fscSettings, 'fsc');
      }

      // Naturprodukt
      if (texts['natural_product']?['selected'] == true) {
        final naturalProductSettings = texts['natural_product'] as Map<String, dynamic>;
        result['natural_product'] = AdditionalTextsManager.getTextContent(naturalProductSettings, 'natural_product');
      }

      // Bankverbindung
      if (texts['bank_info']?['selected'] == true) {
        final bankInfoSettings = texts['bank_info'] as Map<String, dynamic>;
        result['bank_info'] = AdditionalTextsManager.getTextContent(bankInfoSettings, 'bank_info');
      }

      return result;
    } catch (e) {
      print('Fehler beim Laden der Zusatztexte für den Beleg: $e');
      return {};
    }
  }




  pw.Widget _buildTotalRowWithCurrency(
      String label,
      num amount,
      String currency,
      double exchangeRate, {
        bool isDiscount = false,
        bool isBold = false,
        double fontSize = 10,
      }) {
    // Umrechnung von CHF zur Zielwährung
    final convertedAmount = amount * exchangeRate;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.Text(
            isDiscount
                ? '-${convertedAmount.toStringAsFixed(2)} $currency'
                : '${convertedAmount.toStringAsFixed(2)} $currency',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: isDiscount ? PdfColors.red : PdfColors.blueGrey800,
            ),
          ),
        ],
      ),
    );
  }
// Neue Hilfsmethode für Gesamtbeträge
  pw.Widget _buildTotalRow(
      String label,
      num amount, {
        bool isDiscount = false,
        bool isBold = false,
        double fontSize = 10,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.Text(
            isDiscount
                ? '-${amount.toStringAsFixed(2)} CHF'
                : '${amount.toStringAsFixed(2)} CHF',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: isDiscount ? PdfColors.red : PdfColors.blueGrey800,
            ),
          ),
        ],
      ),
    );
  }

// Hilfsmethoden für einheitliche Zellen-Formatierung
  pw.Widget _buildHeaderCell(String text,double fontSize, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
  fontSize:fontSize,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildContentCell(pw.Widget content) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: content,
    );
  }




  Future<void> _sendReceiptEmail(
      String receiptId,
      Uint8List pdfBytes,
      String recipientEmail,
      ) async {
    try {
      // Hole die PDF-URL aus dem Storage
      final receiptDoc = await FirebaseFirestore.instance
          .collection('sales_receipts')
          .doc(receiptId)
          .get();

      final pdfUrl = receiptDoc.data()?['pdf_url'];

      if (pdfUrl != null) {
        final emailContent = '''
Sehr geehrte Damen und Herren,

vielen Dank für Ihren Einkauf. Im Anhang finden Sie Ihren Lieferschein.

Mit freundlichen Grüßen
Ihr Team''';

        // Formatiere die URI-Komponenten separat
        final subject = Uri.encodeComponent('Ihr Lieferschein Nr. $receiptId');
        final body = Uri.encodeComponent('$emailContent\n\nLieferschein: $pdfUrl');

        // Baue die mailto-URI
        final emailUrl = 'mailto:$recipientEmail?subject=$subject&body=$body';
        final uri = Uri.parse(emailUrl);

        // Debug-Ausgabe
        print('Versuche E-Mail-Client zu öffnen mit URI: $uri');

        // Prüfe ob die URI geöffnet werden kann
        if (await canLaunchUrl(uri)) {
          // Versuche die URI zu öffnen
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );

          if (launched) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('E-Mail-Client wurde geöffnet'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw 'E-Mail-Client konnte nicht gestartet werden';
          }
        } else {
          // Alternative Methode versuchen
          final altUri = Uri(
            scheme: 'mailto',
            path: recipientEmail,
            queryParameters: {
              'subject': 'Ihr Lieferschein Nr. $receiptId',
              'body': '$emailContent\n\nLieferschein: $pdfUrl',
            },
          );

          print('Versuche alternative URI: $altUri');

          if (await canLaunchUrl(altUri)) {
            final launched = await launchUrl(
              altUri,
              mode: LaunchMode.externalApplication,
            );

            if (!launched) {
              throw 'Alternative Methode fehlgeschlagen';
            }
          } else {
            throw 'Kein E-Mail-Client verfügbar';
          }
        }
      } else {
        throw 'PDF-URL nicht gefunden';
      }
    } catch (e) {
      print('Fehler beim E-Mail-Versand: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Öffnen des E-Mail-Clients: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Fehlerdetails'),
                    content: SingleChildScrollView(
                      child: Text('$e'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Schließen'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }


  // Replace the existing _shareReceipt method with this one
  Future<void> _shareReceipt(String receiptId, Uint8List pdfBytes) async {
    try {
      if (kIsWeb) {
        // For web, use the DownloadHelper class (which should handle web downloads)
        final fileName = 'Lieferschein_$receiptId.pdf';
        await DownloadHelper.downloadFile(pdfBytes, fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // For mobile, use the Share.shareXFiles method
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/Lieferschein_$receiptId.pdf');
        await tempFile.writeAsBytes(pdfBytes);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          subject: 'Lieferschein',
        );

        // Optional: Lösche die temporäre Datei nach einer Weile
        Future.delayed(const Duration(minutes: 5), () async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Teilen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Replace the existing _shareCsv method with this one
  Future<void> _shareCsv(String receiptId, Uint8List? csvBytes) async {
    try {
      if (csvBytes == null) {
        throw Exception('CSV-Daten sind nicht verfügbar');
      }

      if (kIsWeb) {
        // For web, use the DownloadHelper class
        final fileName = 'Bestellung_$receiptId.csv';
        await DownloadHelper.downloadFile(csvBytes, fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // For mobile, use the Share.shareXFiles method
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/Bestellung_$receiptId.csv');
        await tempFile.writeAsBytes(csvBytes);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          subject: 'Bestellung CSV',
        );

        // Optional: Lösche die temporäre Datei nach einer Weile
        Future.delayed(const Duration(minutes: 5), () async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Teilen der CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> saveReceiptLocally(Uint8List pdfBytes, String receiptId) async {
    String filePath = '';
    try {
      final fileName = 'receipt_$receiptId.pdf';
      final downloadedPath = await DownloadHelper.downloadFile(pdfBytes, fileName);

      if (mounted) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (downloadedPath != null) {
          filePath = downloadedPath;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gespeichert unter: $filePath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return filePath;
  }
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

Widget _buildSelectedProductInfo() {
  if (selectedProduct == null) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedProduct!['product_name'] ?? 'Unbekanntes Produkt',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<double>(
          future: _getAvailableQuantity(selectedProduct!['barcode']),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                'Verfügbar: ${selectedProduct!['unit']?.toLowerCase() == 'stück'
                    ? snapshot.data!.toStringAsFixed(0)
                    : snapshot.data!.toStringAsFixed(3)} ${selectedProduct!['unit'] ?? 'Stück'}',
              );
            }
            return const CircularProgressIndicator();
          },
        ),
        Text(
          'Preis: ${_formatPrice(selectedProduct!['price_CHF'] ?? 0.0)}',
        ),
      ],
    ),
  );
}


// Neue Methode zum Speichern des Gesamtrabatts
  Future<void> _saveTemporaryTotalDiscount() async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_discounts')
          .doc('total_discount')
          .set({
        'percentage': _totalDiscount.percentage,
        'absolute': _totalDiscount.absolute,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern des Gesamtrabatts: $e');
    }
  }

// Neue Methode zum Laden des Gesamtrabatts
  Future<void> _loadTemporaryTotalDiscount() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temporary_discounts')
          .doc('total_discount')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _totalDiscount = Discount(
            percentage: (data['percentage'] != null)
                ? (data['percentage'] is int
                ? (data['percentage'] as int).toDouble()
                : data['percentage'] as double)
                : 0.0,
            absolute: (data['absolute'] != null)
                ? (data['absolute'] is int
                ? (data['absolute'] as int).toDouble()
                : data['absolute'] as double)
                : 0.0,
          );
        });
      }
    } catch (e) {
      print('Fehler beim Laden des Gesamtrabatts: $e');
    }
  }


// Neue Zustandsvariablen für die Klasse
  double get _vatRate => _vatRateNotifier.value;
  Discount _totalDiscount = const Discount();
  Map<String, Discount> _itemDiscounts = {};

// Methode zum Anpassen des Rabatts für einen Artikel
  // Methode zum Anpassen des Rabatts für einen Artikel
// Methode zum Anpassen des Rabatts für einen Artikel
  void _showItemDiscountDialog(String itemId, double originalAmount) {
    final percentageController = TextEditingController(
        text: _itemDiscounts[itemId]?.percentage.toString() ?? '0.0'
    );
    final absoluteController = TextEditingController(
        text: _itemDiscounts[itemId]?.absolute.toString() ?? '0.0'
    );
    final targetAmountController = TextEditingController();

    // Flag um zu verhindern, dass Listener sich gegenseitig triggern
    bool _isUpdating = false;

    // Merke welches Feld zuletzt bearbeitet wurde
    String _lastEdited = 'none';

    // Listener für Prozent-Feld
    percentageController.addListener(() {
      if (_isUpdating) return;
      _isUpdating = true;
      _lastEdited = 'percentage';

      final percentage = double.tryParse(percentageController.text) ?? 0;
      final discount = originalAmount * (percentage / 100);
      final newAmount = originalAmount - discount;

      absoluteController.text = discount.toStringAsFixed(2);
      targetAmountController.text = newAmount.toStringAsFixed(2);

      _isUpdating = false;
    });

    // Listener für Absolut-Feld
    absoluteController.addListener(() {
      if (_isUpdating) return;
      _isUpdating = true;
      _lastEdited = 'absolute';

      final absolute = double.tryParse(absoluteController.text) ?? 0;
      final percentage = (absolute / originalAmount) * 100;
      final newAmount = originalAmount - absolute;

      percentageController.text = percentage.toStringAsFixed(2);
      targetAmountController.text = newAmount.toStringAsFixed(2);

      _isUpdating = false;
    });

    // Listener für Zielbetrag-Feld
    targetAmountController.addListener(() {
      if (_isUpdating) return;
      _isUpdating = true;
      _lastEdited = 'target';

      final targetAmount = double.tryParse(targetAmountController.text) ?? originalAmount;
      final discount = originalAmount - targetAmount;
      final percentage = (discount / originalAmount) * 100;

      absoluteController.text = discount.toStringAsFixed(2);
      percentageController.text = percentage.toStringAsFixed(2);

      _isUpdating = false;
    });

    // Initialisiere Zielbetrag basierend auf Original-Betrag
    final initialDiscount = _itemDiscounts[itemId];
    if (initialDiscount != null) {
      // Prüfe welcher Wert gesetzt ist
      if (initialDiscount.percentage > 0) {
        _lastEdited = 'percentage';
        final discount = originalAmount * (initialDiscount.percentage / 100);
        targetAmountController.text = (originalAmount - discount).toStringAsFixed(2);
      } else if (initialDiscount.absolute > 0) {
        _lastEdited = 'absolute';
        final discount = initialDiscount.absolute;
        targetAmountController.text = (originalAmount - discount).toStringAsFixed(2);
      } else {
        targetAmountController.text = originalAmount.toStringAsFixed(2);
      }
    } else {
      targetAmountController.text = originalAmount.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rabatt'),
        content: ValueListenableBuilder<String>(
          valueListenable: _currencyNotifier,
          builder: (context, currency, child) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Aktueller Betrag
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ursprungsbetrag:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatPrice(originalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rabatt in Prozent
                  TextFormField(
                    controller: percentageController,
                    decoration: const InputDecoration(
                      labelText: 'Rabatt %',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      helperText: 'Prozentuale Ermäßigung',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Rabatt absolut
                  TextFormField(
                    controller: absoluteController,
                    decoration: InputDecoration(
                      labelText: 'Rabatt $currency',
                      suffixText: currency,
                      border: const OutlineInputBorder(),
                      helperText: 'Absoluter Rabattbetrag',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Divider(),
                  const SizedBox(height: 12),

                  // Zielbetrag (neuer Preis)
                  TextFormField(
                    controller: targetAmountController,
                    decoration: InputDecoration(
                      labelText: 'Neuer Betrag $currency',
                      suffixText: currency,
                      border: const OutlineInputBorder(),
                      helperText: 'Gewünschter Endbetrag',
                      filled: true,
                      fillColor: Colors.green[50],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              percentageController.dispose();
              absoluteController.dispose();
              targetAmountController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Abbrechen'),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _currencyNotifier,
            builder: (context, currency, child) {
              return ElevatedButton(
                onPressed: () async {
                  // Speichere NUR den Wert, der zuletzt bearbeitet wurde
                  double percentageValue = 0.0;
                  double absoluteValue = 0.0;

                  if (_lastEdited == 'percentage') {
                    percentageValue = double.tryParse(percentageController.text) ?? 0;
                    absoluteValue = 0.0;
                  } else {
                    // Bei 'absolute' oder 'target' speichern wir den absoluten Wert
                    absoluteValue = double.tryParse(absoluteController.text) ?? 0;
                    if (currency != 'CHF') {
                      absoluteValue = absoluteValue / _exchangeRates[currency]!;
                    }
                    percentageValue = 0.0;
                  }

                  setState(() {
                    _itemDiscounts[itemId] = Discount(
                      percentage: percentageValue,
                      absolute: absoluteValue,
                    );
                  });

                  await FirebaseFirestore.instance
                      .collection('temporary_basket')
                      .doc(itemId)
                      .update({
                    'discount': {
                      'percentage': percentageValue,
                      'absolute': absoluteValue,
                    },
                    'discount_timestamp': FieldValue.serverTimestamp(),
                  });

                  percentageController.dispose();
                  absoluteController.dispose();
                  targetAmountController.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Übernehmen'),
              );
            },
          ),
        ],
      ),
    );
  }

  Stream<double> _calculateItemDiscount(
      double amount,
      double percentage,
      double absolute,
      ) {
    return Stream.value(
        (amount * (percentage / 100)) + absolute
    );
  }

// Methode für den Gesamtrabatt
  // Methode für den Gesamtrabatt
  void _showTotalDiscountDialog() {
    bool distributeToItems = false; // Neue Variable am Anfang der Methode
    // Konvertiere den absoluten Wert von CHF in die aktuelle Währung für die Anzeige
    double displayAbsolute = _totalDiscount.absolute;
    if (_selectedCurrency != 'CHF') {
      displayAbsolute = _totalDiscount.absolute * _exchangeRates[_selectedCurrency]!;
    }

    final percentageController = TextEditingController(
        text: _totalDiscount.percentage.toString()
    );
    final absoluteController = TextEditingController(
        text: displayAbsolute.toStringAsFixed(2)
    );
    final targetTotalController = TextEditingController(); // Neu: Controller für Zielbetrag

    // Temporäre Variablen für den aktuellen Status
    double tempPercentage = _totalDiscount.percentage;
    double tempAbsolute = _totalDiscount.absolute;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Wichtig für anpassbare Höhe
      backgroundColor: Colors.transparent, // Transparenter Hintergrund für abgerundete Ecken
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.95, // 80% der Bildschirmhöhe
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag-Handle oben
                Container(
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Titel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      getAdaptiveIcon(iconName: 'sell', defaultIcon: Icons.sell),
                      const SizedBox(width: 10),
                      Text(
                        'Gesamtrabatt',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Spacer(),
                      IconButton(
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Divider(),

                // Scrollbarer Inhalt
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _currencyNotifier,
                    builder: (context, currency, child) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: _basketStream,
                        builder: (context, basketSnapshot) {
                          // Berechne den aktuellen Nettobetrag und Gesamtbetrag mit Steuern
                          double subtotal = 0.0;
                          double itemDiscounts = 0.0;

                          if (basketSnapshot.hasData) {
                            for (var doc in basketSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;

                              // Hier den korrekten Preis verwenden (custom oder standard)
                              final customPriceValue = data['custom_price_per_unit'];
                              final pricePerUnit = customPriceValue != null
                                  ? (customPriceValue as num).toDouble()
                                  : (data['price_per_unit'] as num).toDouble();

                              final qty = data['quantity'];
                              final quantityDouble = qty is int ? qty.toDouble() : qty as double;
                              final itemSubtotal = quantityDouble * pricePerUnit;
                              subtotal += itemSubtotal;

                              final itemDiscount = _itemDiscounts[doc.id] ?? const Discount();
                              itemDiscounts += itemDiscount.calculateDiscount(itemSubtotal);
                            }
                          }

                          final afterItemDiscounts = subtotal - itemDiscounts;

                          // Aktueller Prozent- und absoluter Rabatt aus den Controllern
                          final percentage = double.tryParse(percentageController.text.replaceAll(',', '.')) ?? 0;
                          double absolute = double.tryParse(absoluteController.text.replaceAll(',', '.')) ?? 0;
                          if (currency != 'CHF') {
                            absolute = absolute / _exchangeRates[currency]!;
                          }

                          // Gesamtrabatt berechnen
                          final totalDiscountAmount = (afterItemDiscounts * (percentage / 100)) + absolute;
                          final netAmount = afterItemDiscounts - totalDiscountAmount;

                          // MwSt und Gesamtbetrag berechnen basierend auf aktueller Steueroption
                          double vatAmount = 0.0;
                          double totalAmount = netAmount;

// Steuerberechnung entsprechend der gewählten Steueroption
                          if (_taxOptionNotifier.value == TaxOption.standard) {
                            // NEU: Erst Nettobetrag auf 2 Nachkommastellen runden
                            final netAmountRounded = double.parse(netAmount.toStringAsFixed(2));

                            // NEU: MwSt berechnen und auf 2 Nachkommastellen runden
                            vatAmount = double.parse((netAmountRounded * (_vatRate / 100)).toStringAsFixed(2));

                            // NEU: Total ist Summe der gerundeten Beträge
                            totalAmount = netAmountRounded + vatAmount;
                          } else {
                            // NEU: Bei anderen Steueroptionen auch auf 2 Nachkommastellen runden
                            totalAmount = double.parse(netAmount.toStringAsFixed(2));
                          }

                          void calculateTargetTotal() {
                            final targetTotal = double.tryParse(targetTotalController.text.replaceAll(',', '.')) ?? 0;

                            print('=== DEBUG: calculateTargetTotal ===');
                            print('Gewünschter Endbetrag: $targetTotal $currency');
                            print('Nettobetrag nach Artikelrabatten: ${_formatPrice(afterItemDiscounts)}');

                            if (targetTotal <= 0 || afterItemDiscounts <= 0) return;

                            // Je nach Steueroption unterschiedlich berechnen
                            double targetNetAmount;
                            if (_taxOptionNotifier.value == TaxOption.standard) {
                              // Bei Standardsteuer: Zielbetrag enthält MwSt
                              targetNetAmount = targetTotal / (1 + (_vatRate / 100));
                              print('Ziel-Nettobetrag (MwSt abgezogen): ${_formatPrice(targetNetAmount)}');
                            } else {
                              // Bei anderen Optionen: Zielbetrag ist direkt der Nettobetrag
                              targetNetAmount = targetTotal;
                              print('Ziel-Nettobetrag: ${_formatPrice(targetNetAmount)}');
                            }

                            // Berechne benötigten Rabatt in der angezeigten Währung
                            final neededDiscountInDisplayCurrency = (afterItemDiscounts * _exchangeRates[currency]!) - targetNetAmount;
                            print('Benötigter Rabatt: ${_formatPrice(afterItemDiscounts)} - ${targetNetAmount} $currency = $neededDiscountInDisplayCurrency $currency');

                            if (neededDiscountInDisplayCurrency >= 0) {
                              setState(() {
                                percentageController.text = '0';
                                absoluteController.text = neededDiscountInDisplayCurrency.toStringAsFixed(2);

                                // Speichere in CHF für interne Verwendung
                                tempAbsolute = neededDiscountInDisplayCurrency / _exchangeRates[currency]!;
                                print('Gespeicherter Rabatt (CHF): $tempAbsolute');
                              });
                            }

                            print('=== ENDE DEBUG ===');
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Aktuelle Beträge anzeigen
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Aktuelle Beträge',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Nettobetrag:'),
                                          Text(
                                            _formatPrice(afterItemDiscounts),
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      if (_taxOptionNotifier.value == TaxOption.standard) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('MwSt (${_vatRate.toStringAsFixed(1)}%):'),
                                            Text(_formatPrice(afterItemDiscounts * _vatRate / 100)),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Gesamtbetrag:'),
                                          Text(
                                            _formatPrice(_taxOptionNotifier.value == TaxOption.standard ?
                                            afterItemDiscounts * (1 + _vatRate / 100) : afterItemDiscounts),
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Rabatt-Optionen
                                Text(
                                  'Rabatt anpassen',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Rabatt Prozentual
                                TextFormField(
                                  controller: percentageController,
                                  decoration: InputDecoration(
                                    labelText: 'Rabatt %',
                                    suffixText: '%',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: getAdaptiveIcon(iconName: 'percent', defaultIcon: Icons.percent),
                                    ),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                  ],
                                  onChanged: (value) {
                                    // Leere den Zielbetrag, wenn Prozent geändert wird
                                    setState(() {
                                      targetTotalController.text = '';
                                      tempPercentage = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Rabatt Absolut
                                TextFormField(
                                  controller: absoluteController,
                                  decoration: InputDecoration(
                                    labelText: 'Rabatt $currency',
                                    suffixText: currency,
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: getAdaptiveIcon(iconName: 'money_off', defaultIcon: Icons.money_off),
                                    ),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                  ],
                                  onChanged: (value) {
                                    // Leere den Zielbetrag, wenn absoluter Rabatt geändert wird
                                    setState(() {
                                      targetTotalController.text = '';

                                      // In CHF umrechnen und speichern
                                      double absoluteValue = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                                      if (currency != 'CHF') {
                                        absoluteValue = absoluteValue / _exchangeRates[currency]!;
                                      }
                                      tempAbsolute = absoluteValue;
                                    });
                                  },
                                ),
                                const SizedBox(height: 20),

                                // ODER-Trennlinie
                                Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'ODER',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Zielpreis-Option
                                Text(
                                  'Gewünschten Endbetrag eingeben',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // NEU: Gewünschter Endbetrag
                                TextFormField(
                                  controller: targetTotalController,
                                  decoration: InputDecoration(
                                    labelText: 'Gewünschter Endbetrag',
                                    suffixText: currency,
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: getAdaptiveIcon(iconName: 'price_check', defaultIcon: Icons.price_check),
                                    ),
                                    helperText: _taxOptionNotifier.value == TaxOption.standard
                                        ? 'Gewünschter Endbetrag inkl. MwSt'
                                        : 'Gewünschter Endbetrag',
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                                  ],
                                  onChanged: (_) => calculateTargetTotal(),
                                ),

                                // Nach dem Zielpreis-Feld hinzufügen:
                                const SizedBox(height: 24),

// Checkbox für Rabattverteilung
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CheckboxListTile(
                                        title: const Text('Errechneten Betrag prozentual auf die Einzelpositionen aufteilen'),
                                        subtitle: const Text(
                                          'Der Gesamtrabatt wird anteilig auf alle Positionen verteilt',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        value: distributeToItems,
                                        onChanged: (value) {
                                          setState(() {
                                            distributeToItems = value ?? false;
                                          });
                                        },
                                        controlAffinity: ListTileControlAffinity.leading,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            getAdaptiveIcon(iconName: 'info', defaultIcon:
                                              Icons.info,
                                              size: 16,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Ist dieser Haken gesetzt, wird kein Gesamtrabatt ausgewiesen, sondern die einzelnen Positionen werden rabattiert.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Vorschau der Effekte
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vorschau der Änderungen',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Rabattbetrag:'),
                                          Text(
                                            '-${_formatPrice(totalDiscountAmount)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Nettobetrag nach Rabatt:'),
                                          Text(
                                            _formatPrice(netAmount),
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      if (_taxOptionNotifier.value == TaxOption.standard) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('MwSt nach Rabatt:'),
                                            Text(_formatPrice(vatAmount)),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Gesamtbetrag nach Rabatt:'),
                                          Text(
                                            _formatPrice(totalAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (distributeToItems && totalDiscountAmount > 0) ...[
                                        const SizedBox(height: 8),
                                        Divider(),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Verteilung auf Positionen:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Jede Position erhält zusätzlich ${((totalDiscountAmount / afterItemDiscounts) * 100).toStringAsFixed(2)}% Rabatt',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Buttons unten
                // Buttons unten
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: getAdaptiveIcon(iconName: 'cancel', defaultIcon: Icons.cancel),
                          label: const Text('Abbrechen'),
                        ),
                        const SizedBox(width: 16),

                        // StreamBuilder um den Button für Zugriff auf Warenkorb-Daten
                        StreamBuilder<QuerySnapshot>(
                          stream: _basketStream,
                          builder: (context, basketSnapshot) {
                            return ElevatedButton.icon(
                              onPressed: () async {
                                // NEU: Prüfe ob Rabatt auf Positionen verteilt werden soll
                                if (distributeToItems && basketSnapshot.hasData) {
                                  // Hole aktuelle Werte aus den Controllern
                                  final percentage = double.tryParse(percentageController.text.replaceAll(',', '.')) ?? 0;
                                  double absolute = double.tryParse(absoluteController.text.replaceAll(',', '.')) ?? 0;

                                  // Konvertiere absolute Werte in CHF
                                  if (_selectedCurrency != 'CHF') {
                                    absolute = absolute / _exchangeRates[_selectedCurrency]!;
                                  }

                                  // Berechne Zwischensumme für effektiven Rabatt
                                  double subtotal = 0.0;
                                  for (var doc in basketSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final customPriceValue = data['custom_price_per_unit'];
                                    final pricePerUnit = customPriceValue != null
                                        ? (customPriceValue as num).toDouble()
                                        : (data['price_per_unit'] as num).toDouble();
                                    final quantity = (data['quantity'] as num).toDouble();
                                    subtotal += quantity * pricePerUnit;
                                  }

                                  // Berechne effektiven Rabatt-Prozentsatz
                                  final totalDiscountAmount = (subtotal * (percentage / 100)) + absolute;
                                  final effectiveDiscountPercentage = (totalDiscountAmount / subtotal) * 100;

                                  // Verteile auf alle Artikel
                                  final batch = FirebaseFirestore.instance.batch();

                                  for (var doc in basketSnapshot.data!.docs) {
                                    // Bestehende Item-Rabatte abrufen
                                    final existingDiscount = _itemDiscounts[doc.id] ?? const Discount();

                                    // Addiere den neuen Rabatt zum bestehenden Prozentsatz
                                    final newPercentage = existingDiscount.percentage + effectiveDiscountPercentage;

                                    batch.update(
                                        FirebaseFirestore.instance.collection('temporary_basket').doc(doc.id),
                                        {
                                          'discount': {
                                            'percentage': newPercentage,
                                            'absolute': existingDiscount.absolute, // Absolute Rabatte bleiben erhalten
                                          },
                                          'discount_timestamp': FieldValue.serverTimestamp(),
                                        }
                                    );

                                    // Update lokalen State
                                    this.setState(() {
                                      _itemDiscounts[doc.id] = Discount(
                                        percentage: newPercentage,
                                        absolute: existingDiscount.absolute,
                                      );
                                    });
                                  }

                                  await batch.commit();

                                  // Setze Gesamtrabatt auf 0
                                  this.setState(() {
                                    _totalDiscount = const Discount();
                                  });
                                  await _saveTemporaryTotalDiscount();

                                  Navigator.pop(context);

                                  // Zeige Bestätigung
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Rabatt wurde auf ${basketSnapshot.data!.docs.length} Positionen verteilt'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );

                                } else {
                                  // BISHERIGES VERHALTEN (wenn Checkbox nicht gesetzt ist)
                                  double absoluteValue = tempAbsolute;
                                  double percentageValue = tempPercentage;

                                  // Aktualisiere die Gesamtrabatt-Instanz im SalesScreenState
                                  this.setState(() {
                                    _totalDiscount = Discount(
                                      percentage: percentageValue,
                                      absolute: absoluteValue,
                                    );
                                  });
                                  await _saveTemporaryTotalDiscount();
                                  Navigator.pop(context);

                                  // Zeige Bestätigung
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gesamtrabatt angewendet'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              icon: getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check),
                              label: const Text('Übernehmen'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            );
                          },
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







@override
void dispose() {
  _currencyNotifier.dispose();
  _exchangeRatesNotifier.dispose();
  _taxOptionNotifier.dispose();
  _isLoading.dispose();
  _vatRateNotifier.dispose();
  _selectedFairNotifier.dispose();
  customerSearchController.dispose();
  _documentSelectionCompleteNotifier.dispose();
  _additionalTextsSelectedNotifier.dispose();
  barcodeController.dispose();
  quantityController.dispose();
  _documentLanguageNotifier.dispose();
  _shippingCostsConfiguredNotifier.dispose();
  super.dispose();
}
}
