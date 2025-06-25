

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tonewood/home/quote_order_flow_screen.dart';

import 'package:tonewood/home/warehouse_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/manual_product_dialog.dart';
import '../services/additional_text_manager.dart';
import '../services/document_selection_manager.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
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
import 'customer_selection.dart';
import '../services/shipping_costs_manager.dart';

enum TaxOption {
  standard,  // Normales System mit Netto/Steuer/Brutto
  noTax,     // Komplett ohne Steuer (nur Netto)
  totalOnly  // Nur Bruttobetrag (inkl. MwSt), keine Steuerausweisung
}

class SalesScreen extends StatefulWidget {
const SalesScreen({Key? key}) : super(key: key);

@override
SalesScreenState createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen> {
  Fair? selectedFair;
  final ValueNotifier<TaxOption> _taxOptionNotifier = ValueNotifier<TaxOption>(TaxOption.standard);
  final ValueNotifier<bool> _documentSelectionCompleteNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _additionalTextsSelectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _shippingCostsConfiguredNotifier = ValueNotifier<bool>(false);

  // Sprache für Dokumente
  final ValueNotifier<String> _documentLanguageNotifier = ValueNotifier<String>('DE');

  final ValueNotifier<double> _vatRateNotifier = ValueNotifier<double>(8.1);
// In der SalesScreenState Klasse, bei den anderen State-Variablen:
  bool _isDetailExpanded = false;

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
          // Kunde - mit roter "Kunde wählen" Anzeige wenn kein Kunde ausgewählt
          // StreamBuilder<Customer?>(
          //   stream: _temporaryCustomerStream,
          //   builder: (context, snapshot) {
          //     final customer = snapshot.data;
          //
          //     return Column(
          //       children: [
          //         GestureDetector(
          //           onTap: _showCustomerSelection,
          //           child: Container(
          //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //             decoration: BoxDecoration(
          //               color: customer != null
          //                   ? Theme.of(context).colorScheme.secondaryContainer
          //                   : Theme.of(context).colorScheme.errorContainer,
          //               borderRadius: BorderRadius.circular(12),
          //             ),
          //             child: Row(
          //               mainAxisSize: MainAxisSize.min,
          //               children: [
          //                 getAdaptiveIcon(iconName: 'person', defaultIcon: Icons.person,),
          //                 const SizedBox(width: 4),
          //                 Text(
          //                   customer != null
          //                       ? customer.company.substring(0, min(2, customer.company.length)).toUpperCase()
          //                       : 'Kunde wählen',
          //                   style: TextStyle(
          //                     color: customer != null
          //                         ? Theme.of(context).colorScheme.onSecondaryContainer
          //                         : Theme.of(context).colorScheme.onErrorContainer,
          //                     fontWeight: FontWeight.bold,
          //                     fontSize: 13,
          //                   ),
          //                 ),
          //               ],
          //             ),
          //           ),
          //         ),
          //
          //       ],
          //     );
          //   },
          // ),
          // const SizedBox(width: 6),

          // Kostenstelle - bleibt unverändert
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

        // Email-Icon
        IconButton(
          icon:    getAdaptiveIcon(iconName: 'mail', defaultIcon: Icons.mail,),

          tooltip: 'Email-Konfiguration',
          onPressed: _showEmailConfigDialog,
        ),
        // Währungsumrechner-Icon

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
            iconName: 'delete_forever',
            defaultIcon: Icons.delete_forever,
          ),
          tooltip: 'Warenkorb leeren',
          onPressed: _showClearCartDialog,
        ),
        IconButton(
          icon: getAdaptiveIcon(iconName: 'sell', defaultIcon: Icons.sell,),
          tooltip: 'Rabatt',
          onPressed: _showTotalDiscountDialog,
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
          percentage: discountData['percentage'] ?? 0.0,
          absolute: discountData['absolute'] ?? 0.0,
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
                         getAdaptiveIcon(iconName: 'mail', defaultIcon: Icons.mail,),
                            const SizedBox(width: 8),
                            Text(
                              'Email',
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
                            title: const Text('Standard'),
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
                                    prefixIcon: getAdaptiveIcon(iconName: 'percent', defaultIcon: Icons.percent),
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

        print('Währungseinstellungen geladen: $_selectedCurrency, $_exchangeRates');
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

// Füge diese Methode zur SalesScreenState-Klasse hinzu
  Future<void> _fetchLatestExchangeRates() async {
    try {
      // Setze Meldung, dass Kurse aktualisiert werden
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktuelle Wechselkurse werden abgerufen...'),
          duration: Duration(seconds: 1),
        ),
      );

      // API-Aufruf
      final response = await http.get(
        Uri.parse('https://api.frankfurter.app/latest?from=CHF&to=EUR,USD'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        // Aktualisiere die Wechselkurse
        final updatedRates = {
          'CHF': 1.0,
          'EUR': rates['EUR'] as double,
          'USD': rates['USD'] as double,
        };

        // Speichere im ValueNotifier
        _exchangeRatesNotifier.value = updatedRates;

        // Speichere in Firebase
        await _saveCurrencySettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wechselkurse aktualisiert (Stand: ${data['date']})'),
              backgroundColor: Colors.green,
            ),
          );
        }

        print('Wechselkurse aktualisiert: $updatedRates');
      } else {
        throw Exception('Fehler beim Abrufen der Wechselkurse: ${response.statusCode}');
      }
    } catch (e) {
      print('Fehler beim Abrufen der Wechselkurse: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Abrufen der Wechselkurse: $e'),
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

// Überarbeitete Methode für den Währungsumrechner
  void _showCurrencyConverterDialog() {
    final eurRateController = TextEditingController(text: _exchangeRates['EUR']!.toString());
    final usdRateController = TextEditingController(text: _exchangeRates['USD']!.toString());
    String currentCurrency = _selectedCurrency;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(24),
              width: 400,
              // Machen wir eine maximale Höhe
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog-Header
                  Row(
                    children: [
                      Text(
                        'Währung',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(

                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),

                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  // Scrollbarer Inhalt
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),

                          // Aktuelle Währung
                          Text(
                            'Aktuelle Währung',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Währung auswählen',
                              border: OutlineInputBorder(),
                            ),
                            value: currentCurrency,
                            items: _exchangeRates.keys.map((currency) =>
                                DropdownMenuItem(
                                  value: currency,
                                  child: Text(currency),
                                )
                            ).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => currentCurrency = value);
                              }
                            },
                          ),

                          const SizedBox(height: 24),

                          // Umrechnungsfaktoren
                          Text(
                            'Umrechnungsfaktoren (1 CHF =)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // EUR Umrechnungsfaktor
                          TextFormField(
                            controller: eurRateController,
                            decoration: InputDecoration(
                              labelText: 'EUR Faktor',
                              border: OutlineInputBorder(),
                              prefixIcon:getAdaptiveIcon(iconName: 'euro', defaultIcon: Icons.euro,),
                              helperText: '1 CHF = x EUR',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,4}')),
                            ],
                            onChanged: (_) => setState(() {}),
                          ),

                          const SizedBox(height: 16),

                          // USD Umrechnungsfaktor
                          TextFormField(
                            controller: usdRateController,
                            decoration: InputDecoration(
                              labelText: 'USD Faktor',
                              border: OutlineInputBorder(),
                              prefixIcon: getAdaptiveIcon(iconName: 'attach_money', defaultIcon: Icons.attach_money,),
                              helperText: '1 CHF = x USD',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,4}')),
                            ],
                            onChanged: (_) => setState(() {}),
                          ),

                          const SizedBox(height: 24),

                          // Beispielumrechnungen
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Beispielumrechnungen:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('100 CHF = ${(100 * double.parse(eurRateController.text.replaceAll(',', '.'))).toStringAsFixed(2)} EUR'),
                                Text('100 CHF = ${(100 * double.parse(usdRateController.text.replaceAll(',', '.'))).toStringAsFixed(2)} USD'),
                                const SizedBox(height: 4),
                                Text('100 EUR = ${(100 / double.parse(eurRateController.text.replaceAll(',', '.'))).toStringAsFixed(2)} CHF'),
                                Text('100 USD = ${(100 / double.parse(usdRateController.text.replaceAll(',', '.'))).toStringAsFixed(2)} CHF'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Übernehmen Button
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                double eurRate = double.parse(eurRateController.text.replaceAll(',', '.'));
                                double usdRate = double.parse(usdRateController.text.replaceAll(',', '.'));

                                if (eurRate <= 0 || usdRate <= 0) {
                                  throw Exception('Faktoren müssen positiv sein');
                                }

                                // Aktualisiere die Werte
                                _exchangeRatesNotifier.value = {
                                  'CHF': 1.0,
                                  'EUR': eurRate,
                                  'USD': usdRate
                                };
                                _currencyNotifier.value = currentCurrency;

                                // Speichere in Firebase
                                await _saveCurrencySettings();

                                Navigator.pop(context);

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Währung auf $_selectedCurrency umgestellt'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Fehler: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check,),
                            label: const Text('Übernehmen'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 45),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Kurse abrufen Button
                          ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _fetchLatestExchangeRates();
                              _showCurrencyConverterDialog(); // Dialog erneut öffnen mit neuen Kursen
                            },
                            icon: getAdaptiveIcon(iconName: 'refresh', defaultIcon: Icons.refresh,),
                            label: const Text('Aktuelle Kurse abrufen'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 45),
                            ),
                          ),

                          // Quelle der Wechselkurse
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Quelle: Frankfurter API (Europäische Zentralbank)',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
                      prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search,),
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
                      key: UniqueKey(),
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
                    key: UniqueKey(),
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
                      prefixIcon:    getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search,),
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

              // Kompakteres Eingabefeld
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          isDense: true, // Kompaktere Darstellung
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),


                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (barcodeController.text.isNotEmpty) {
                      _fetchProductAndShowQuantityDialog(barcodeController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'barcode',
                    defaultIcon: Icons.qr_code,

                  ),
                ),
              ),
              // Search button in horizontal layout
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showWarehouseDialog();
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'search',
                    defaultIcon: Icons.search,
                  ),
                  label: const Text('Produkt suchen'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40), // Kleinere Höhe
                  ),
                ),
              ),
// NEUER BUTTON FÜR MANUELLE PRODUKTE
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: _showManualProductDialog,
                  icon: getAdaptiveIcon(
                    iconName: 'add_circle_outline',
                    defaultIcon: Icons.add_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: const Text('Manuelles Produkt'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              // Separator
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
  void _showEditCustomerDialog(Customer customer) {
    final formKey = GlobalKey<FormState>();
    final companyController = TextEditingController(text: customer.company);
    final firstNameController = TextEditingController(text: customer.firstName);
    final lastNameController = TextEditingController(text: customer.lastName);
    final streetController = TextEditingController(text: customer.street);
    final houseNumberController = TextEditingController(text: customer.houseNumber);
    final zipCodeController = TextEditingController(text: customer.zipCode);
    final cityController = TextEditingController(text: customer.city);
    final countryController = TextEditingController(text: customer.country);
    final emailController = TextEditingController(text: customer.email);

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
                          'Kunde',
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
                            'Unternehmensdaten',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: companyController,
                            decoration: const InputDecoration(
                              labelText: 'Firma *',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            validator: (value) =>
                            value?.isEmpty == true ? 'Bitte Firma eingeben' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                            'Kontaktperson',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Vorname *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Vorname eingeben' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nachname *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Nachname eingeben' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'E-Mail *',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            validator: (value) {
                              if (value?.isEmpty == true) {
                                return 'Bitte E-Mail eingeben';
                              }
                              if (!value!.contains('@')) {
                                return 'Bitte gültige E-Mail eingeben';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                            'Adresse',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: streetController,
                                  decoration: const InputDecoration(
                                    labelText: 'Straße *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Straße eingeben' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: houseNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nr. *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Nr. eingeben' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: zipCodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'PLZ *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte PLZ eingeben' : null,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: cityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ort *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Ort eingeben' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: countryController,
                            decoration: const InputDecoration(
                              labelText: 'Land *',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            validator: (value) =>
                            value?.isEmpty == true ? 'Bitte Land eingeben' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Abbrechen'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState?.validate() == true) {
                              try {
                                final updatedCustomer = Customer(
                                  id: customer.id, // Behalte die original ID
                                  company: companyController.text.trim(),
                                  name: companyController.text.trim(),
                                  firstName: firstNameController.text.trim(),
                                  lastName: lastNameController.text.trim(),
                                  street: streetController.text.trim(),
                                  houseNumber: houseNumberController.text.trim(),
                                  zipCode: zipCodeController.text.trim(),
                                  city: cityController.text.trim(),
                                  country: countryController.text.trim(),
                                  email: emailController.text.trim(),
                                );

                                // Update den Kunden in der Datenbank
                                await FirebaseFirestore.instance
                                    .collection('customers')
                                    .doc(customer.id)
                                    .update(updatedCustomer.toMap());

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Kunde wurde aktualisiert'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Fehler beim Aktualisieren: $e'),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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


// Mobile Aktionsbuttons
  Widget _buildMobileActions() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Erste Reihe mit bestehenden Buttons
          Row(
            children: [
              // Neuer Suchen-Button
              Expanded(
                child: ElevatedButton(
                  onPressed: _showManualProductDialog,
                  child: getAdaptiveIcon(iconName: 'add_circle_outline', defaultIcon: Icons.add_circle_outline),
                ),
              ),
              const SizedBox(width: 6),
              // Neuer Suchen-Button
              Expanded(
                child: ElevatedButton(
                  onPressed: _showWarehouseDialog,
                  child: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
                ),
              ),
              const SizedBox(width: 6),
              // Bestehender Scan-Button
              Expanded(
                child: ElevatedButton(
                  onPressed: _scanProduct,
                  child: getAdaptiveIcon(iconName: 'qr_code', defaultIcon: Icons.qr_code),
                ),
              ),
              const SizedBox(width: 6),
              // Bestehender Eingabe-Button
              Expanded(
                child: ElevatedButton(
                  onPressed: _showBarcodeInputDialog,
                  child: getAdaptiveIcon(iconName: 'keyboard', defaultIcon: Icons.keyboard),
                ),
              ),
            ],
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
                percentage: discountData['percentage'] ?? 0.0,
                absolute: discountData['absolute'] ?? 0.0,
              );
              // Synchronisiere mit lokalem State
              if (!_itemDiscounts.containsKey(itemId)) {
                _itemDiscounts[itemId] = itemDiscount;
              }
            } else {
              itemDiscount = _itemDiscounts[itemId] ?? const Discount();
            }



            final quantity = item['quantity'] as int;
           // final pricePerUnit = (item['price_per_unit'] as num).toDouble();
            final pricePerUnit = ((item['custom_price_per_unit'] ?? item['price_per_unit']) as num).toDouble();
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
                          title: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [

                if (item['is_manual_product'] == true) ...[
              Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
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
            const SizedBox(width: 8),
                ],

                                        Text(
                                          item['instrument_name'] ?? 'N/A',
                                          style: const TextStyle(fontWeight: FontWeight.bold,   fontSize: 12,),
                                        ),
                                        Text(
                                          ' - ',
                                          style: const TextStyle(fontWeight: FontWeight.bold,   fontSize: 12,),
                                        ),
                                        Text(
                                          item['wood_name'] ?? 'N/A',
                                          style: const TextStyle(fontWeight: FontWeight.bold,   fontSize: 12,),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          item['part_name'] ?? 'N/A',
                                          style: const TextStyle(fontWeight: FontWeight.bold,   fontSize: 12,),
                                        ),
                                        Text(
                                          ' - ',
                                          style: const TextStyle(fontWeight: FontWeight.bold,   fontSize: 12,),
                                        ),
                                        Text(
                                          item['quality_name'] ?? 'N/A',
                                          style: const TextStyle(fontWeight: FontWeight.bold,   fontSize: 12,),
                                        ),
                                      ],
                                    ),

                                    ValueListenableBuilder<String>(
                                      valueListenable: _currencyNotifier,
                                      builder: (context, currency, child) {
                                        return Text(
                                          '${quantity} ${item['unit']} × ${_formatPrice(pricePerUnit)}${item['is_price_customized'] == true ? ' *' : ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: item['is_price_customized'] == true ? FontStyle.italic : FontStyle.normal,
                                            color: item['is_price_customized'] == true ? Colors.green[700] : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  ValueListenableBuilder<String>(
                                    valueListenable: _currencyNotifier,
                                    builder: (context, currency, child) {
                                      return Text(
                                        _formatPrice(subtotal),
                                        style: TextStyle(
                                          fontSize: 11,
                                          decoration: discountAmount > 0 ?
                                          TextDecoration.lineThrough : null,
                                          color: discountAmount > 0 ?
                                          Colors.grey : null,
                                        ),
                                      );
                                    },
                                  ),
                                  if (discountAmount > 0)
                                    ValueListenableBuilder<String>(
                                      valueListenable: _currencyNotifier,
                                      builder: (context, currency, child) {
                                        return Text(
                                          _formatPrice(subtotal - discountAmount),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 4,0,0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [

                                IconButton(
                                  icon:
                                    getAdaptiveIcon(iconName: 'sell', defaultIcon: Icons.sell,),

                                  onPressed: () => _showItemDiscountDialog(itemId, subtotal),
                                ),
                                IconButton(
                                  icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete,),

                                  onPressed: () => _removeFromBasket(doc.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (itemDiscount.hasDiscount)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: ValueListenableBuilder<String>(
                              valueListenable: _currencyNotifier,
                              builder: (context, currency, child) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Rabatt: ${itemDiscount.percentage > 0 ? '${itemDiscount.percentage}% ' : ''}'
                                          '${itemDiscount.absolute > 0 ? _formatPrice(itemDiscount.absolute) : ''}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      '- ${_formatPrice(discountAmount)}',
                                      style: TextStyle(
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
                    if (item['is_online_shop_item'] == true)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                             getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon: Icons.shopping_cart,),

                              SizedBox(width: 4),
                              Text(
                                'Shop - ${item['online_shop_barcode']}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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

                        for (var doc in basketItems) {
                          final data = doc.data() as Map<String, dynamic>;

                          // Hier den korrekten Preis verwenden (custom oder standard)
                          final customPriceValue = data['custom_price_per_unit'];
                          final pricePerUnit = customPriceValue != null
                              ? (customPriceValue as num).toDouble()
                              : (data['price_per_unit'] as num).toDouble();

                          final itemSubtotal = (data['quantity'] as int) * pricePerUnit;
                          subtotal += itemSubtotal;

                          final itemDiscount = _itemDiscounts[doc.id] ?? const Discount();
                          itemDiscounts += itemDiscount.calculateDiscount(
                            itemSubtotal,
                          );
                        }

                        final afterItemDiscounts = subtotal - itemDiscounts;
                        final totalDiscountAmount = _totalDiscount.calculateDiscount(
                          afterItemDiscounts,
                        );
                        final netAmount = afterItemDiscounts - totalDiscountAmount;

                        // MwSt nur berechnen, wenn es Standard-Option ist
                        double vatAmount = 0.0;
                        double total = netAmount;

                        if (taxOption == TaxOption.standard) {
                          vatAmount = netAmount * (_vatRate / 100);
                          total = netAmount + vatAmount;
                        }

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
                                                child: Icon(
                                                  _isDetailExpanded
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                  size: 20,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
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
                                                        : 'Gesamtbetrag inkl. MwSt:',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatPrice(taxOption == TaxOption.standard ? total : netAmount),
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
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
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        // Sprach-Toggle
                                                        GestureDetector(
                                                          onTap: () {
                                                            _documentLanguageNotifier.value =
                                                            _documentLanguageNotifier.value == 'DE' ? 'EN' : 'DE';
                                                          },
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.primary,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              language,
                                                              style: TextStyle(
                                                                color: Theme.of(context).colorScheme.onPrimary,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Icon(
                                                          isComplete
                                                              ? Icons.check_circle_outline
                                                              : Icons.error_outline,
                                                          size: 18,
                                                          color: isComplete ? Colors.green : Colors.red,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        const Text(
                                                          'Dok.',
                                                          style: TextStyle(fontSize: 12),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Icon(
                                                          Icons.arrow_drop_down,
                                                          size: 18,
                                                          color: Colors.grey.shade700,
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
                                                    Icon(
                                                      hasTexts
                                                          ? Icons.text_fields
                                                          : Icons.text_fields_outlined,
                                                      size: 18,
                                                      color: hasTexts ? Colors.green : Colors.red,
                                                    ),

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
                                                    Icon(
                                                      hasShippingCosts
                                                          ? Icons.local_shipping
                                                          : Icons.local_shipping_outlined,
                                                      size: 18,
                                                      color: hasShippingCosts ? Colors.green : Colors.red,
                                                    ),

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
                                                                    : Icon(
                                                                  allConfigured
                                                                      ? Icons.check
                                                                      : Icons.warning_outlined,
                                                                  size: 18,
                                                                  color: Colors.white,
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


                                // const SizedBox(height: 12),
                                //
                                // // Aktionsbuttons
                                // Row(
                                //   children: [
                                //     // Rabatt-Button
                                //     Expanded(
                                //       child: ElevatedButton.icon(
                                //         onPressed: basketItems.isEmpty ? null : _showTotalDiscountDialog,
                                //         icon: getAdaptiveIcon(iconName: 'sell', defaultIcon: Icons.sell,),
                                //         label: const Text('Rabatt'),
                                //       ),
                                //     ),
                                //     const SizedBox(width: 16),
                                //     // Abschließen-Button
                                //     Expanded(
                                //       child: ValueListenableBuilder<bool>(
                                //         valueListenable: _documentSelectionCompleteNotifier,
                                //         builder: (context, isDocSelectionComplete, child) {
                                //           final canProceed = basketItems.isNotEmpty &&
                                //               !isLoading &&
                                //               isDocSelectionComplete;
                                //
                                //           final String buttonText = isDocSelectionComplete
                                //               ? 'Abschließen'
                                //               : '-';
                                //
                                //           return ElevatedButton.icon(
                                //             onPressed: canProceed
                                //                 ? _processTransaction
                                //                 : isDocSelectionComplete
                                //                 ? null  // Wenn Dokumente ausgewählt aber Warenkorb leer
                                //                 : _showDocumentTypeSelection,  // Dokumente auswählen
                                //             icon: isLoading
                                //                 ? const SizedBox(
                                //               width: 20,
                                //               height: 20,
                                //               child: CircularProgressIndicator(strokeWidth: 2),
                                //             )
                                //                 : isDocSelectionComplete
                                //                 ? getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check,)
                                //                 : getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description,),
                                //             label: Text(buttonText),
                                //             style: ElevatedButton.styleFrom(
                                //               backgroundColor: isDocSelectionComplete
                                //                   ? null  // Standard-Farbe
                                //                   : Colors.amber,  // Hervorgehobene Farbe für Dokumentenauswahl
                                //             ),
                                //           );
                                //         },
                                //       ),
                                //     ),
                                //   ],
                                // ),
                              ],
                            ),
                          ),
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
  Future<int> _getAvailableQuantity(String shortBarcode) async {
    try {
      // Aktuellen Bestand aus inventory collection abrufen
      final inventoryDoc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(shortBarcode)
          .get();

      final currentStock = (inventoryDoc.data()?['quantity'] ?? 0) as int;

      // Temporär gebuchte Menge abrufen - HIER IST DAS PROBLEM
      final tempBasketDocs = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .where('product_id', isEqualTo: shortBarcode)
          .get();

      final reservedQuantity = tempBasketDocs.docs.fold<int>(
        0,
            (sum, doc) => sum + (doc.data()['quantity'] as int),
      );

      return currentStock - reservedQuantity;
    } catch (e) {
      print('Fehler beim Abrufen der verfügbaren Menge: $e');
      return 0;
    }
  }


  void _showPriceEditDialog(String basketItemId, Map<String, dynamic> itemData) {
    // Sicheres Konvertieren von int oder double nach double
    final double originalPrice = (itemData['price_per_unit'] as num).toDouble();

    // Falls bereits ein angepasster Preis existiert, diesen verwenden, sonst Originalpreis
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
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
                    getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
                    const SizedBox(width: 10),
                    Text(
                      'Artikel anpassen',
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
                            Text(
                              'Artikel: ${itemData['product_name']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
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
                              prefixIcon: getAdaptiveIcon(iconName: 'euro', defaultIcon: Icons.euro),
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                          );
                        },
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

                      // FSC Status Dropdown
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'FSC-Status',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: getAdaptiveIcon(iconName: 'eco', defaultIcon: Icons.eco),
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

                      // Maße anpassen
                      Text(
                        'Maße anpassen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
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
                                prefixIcon: Icon(Icons.straighten, size: 20),
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
                                prefixIcon: Icon(Icons.swap_horiz, size: 20),
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
                          prefixIcon: Icon(Icons.layers, size: 20),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
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
                      // Zurücksetzen Button (falls bereits angepasst)
                      if (currentPriceInCHF != originalPrice ||
                          itemData['custom_length'] != null ||
                          itemData['custom_width'] != null ||
                          itemData['custom_thickness'] != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('temporary_basket')
                                    .doc(basketItemId)
                                    .update({
                                  'custom_price_per_unit': FieldValue.delete(),
                                  'is_price_customized': false,
                                  'custom_length': FieldValue.delete(),
                                  'custom_width': FieldValue.delete(),
                                  'custom_thickness': FieldValue.delete(),
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Artikel wurde auf Original zurückgesetzt'),
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
                          itemData['custom_thickness'] != null)
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

                              // FSC-Status hinzufügen
                              // TODO: Hier den ausgewählten FSC-Status hinzufügen
                              // updateData['fsc_status'] = selectedFscStatus;

                              // Speichere die Änderungen
                              await FirebaseFirestore.instance
                                  .collection('temporary_basket')
                                  .doc(basketItemId)
                                  .update(updateData);

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Artikel wurde aktualisiert'),
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
      },
    );
  }


// Erweiterte _addToTemporaryBasket Methode in sales_screen.dart

  Future<void> _addToTemporaryBasket(String shortBarcode, Map<String, dynamic> productData, int quantity, String? onlineShopBarcode) async {
    await FirebaseFirestore.instance
        .collection('temporary_basket')
        .add({
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

      // FSC-Status hinzufügen
      if (productData.containsKey('fsc_status') && productData['fsc_status'] != null)
        'fsc_status': productData['fsc_status'],
    });
  }

  Future<void> _removeFromBasket(String basketItemId) async {
await FirebaseFirestore.instance
    .collection('temporary_basket')
    .doc(basketItemId)
    .delete();
}

  // Ergänzung für _showQuantityDialog in sales_screen.dart

  void _showQuantityDialog(String barcode, Map<String, dynamic> productData) {
    quantityController.clear();

    // Controller für die Maße
    final lengthController = TextEditingController();
    final widthController = TextEditingController();
    final thicknessController = TextEditingController();

    // FSC-Status Variable
    String selectedFscStatus = '100%'; // Standard

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
                                  FutureBuilder<int>(
                                    future: _getAvailableQuantity(barcode),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Text(
                                          'Verfügbar: ${snapshot.data} ${productData['unit'] ?? 'Stück'}',
                                          style: TextStyle(
                                            color: snapshot.data! > 0 ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }
                                      return const CircularProgressIndicator();
                                    },
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
                                prefixIcon: getAdaptiveIcon(iconName: 'numbers', defaultIcon: Icons.numbers),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                                prefixIcon: getAdaptiveIcon(iconName: 'eco', defaultIcon: Icons.eco),
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

                            const SizedBox(height: 24),

                            // Maße - mit FutureBuilder für Standardmaße
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _getStandardMeasurements(productData),
                              builder: (context, snapshot) {
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
                                        if (snapshot.hasData && snapshot.data != null)
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
                                              prefixIcon: Icon(Icons.straighten, size: 20),
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
                                              prefixIcon: Icon(Icons.swap_horiz, size: 20),
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
                                        prefixIcon: Icon(Icons.layers, size: 20),
                                      ),
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (value) {
                                        setState(() {});
                                      },
                                    ),

                                    if (snapshot.hasData && snapshot.data != null)
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
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (quantityController.text.isNotEmpty) {
                                    final quantity = int.parse(quantityController.text);
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

                                      // Füge FSC-Status hinzu
                                      updatedProductData['fsc_status'] = selectedFscStatus;

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
          'length': standardProduct['dimensions']?['length']?['standard'],
          'width': standardProduct['dimensions']?['width']?['standard'],
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
String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
'#ff6666',
'Abbrechen',
true,
ScanMode.BARCODE,
);

if (barcodeResult != '-1') {
await _fetchProductAndShowQuantityDialog(barcodeResult);
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
        builder: (context) => const QuoteOrderFlowScreen(),
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
    Map<String, int> productsSold = {};
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
        final quantity = item['quantity'] as int;
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



  Future<Uint8List> _generateEnhancedPdf(String receiptId) async {
    final pdf = pw.Document();
    final receiptDoc = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .doc(receiptId)
        .get();

    final receiptData = receiptDoc.data()!;
    final customerData = receiptData['customer'] as Map<String, dynamic>;
    final metaData = receiptData['metadata'] as Map<String, dynamic>;
    final items = (receiptData['items'] as List).cast<Map<String, dynamic>>();
    final calculations = receiptData['calculations'] as Map<String, dynamic>;
    final receiptNumber = receiptData['receiptNumber'] as String;
    final taxOption = TaxOption.values[metaData['tax_option'] ?? 0]; // Standard als Fallback


print("taxOption:$taxOption");
print("test:${receiptData['tax_option']}");
print(TaxOption.values);
    print(TaxOption.values[2]);
    // Lade das Firmenlogo
    final logoImage = await rootBundle.load('images/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Hilfsfunktion für PDF-Währungsformatierung
    String formatPdfCurrency(double amount) {
      // Konvertiere von CHF in die ausgewählte Währung
      double convertedAmount = amount;

      if (_selectedCurrency != 'CHF') {
        convertedAmount = amount * _exchangeRates[_selectedCurrency]!;
      }

      return '${convertedAmount.toStringAsFixed(2)} $_selectedCurrency';
    }

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header bleibt gleich
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Lieferschein',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Nr.: LS-$receiptNumber',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
                      ),
                      pw.Text(
                        'Datum: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
                      ),
                    ],
                  ),
                  pw.Image(logo, width: 180),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  color: PdfColors.grey50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      customerData['company'] ?? '',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      customerData['fullName'] ?? '',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700),
                    ),
                    pw.SizedBox(height: 4),
                    // Straße und Hausnummer in einer Zeile
                    pw.Text(
                      '${customerData['street'] ?? ''} ${customerData['houseNumber'] ?? ''}',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700),
                    ),
                    // PLZ und Stadt in einer Zeile
                    pw.Text(
                      '${customerData['zipCode'] ?? ''} ${customerData['city'] ?? ''}',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700),
                    ),
                    // Land in einer eigenen Zeile
                    pw.Text(
                      customerData['country'] ?? '',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'per mail an:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      customerData['email'] ?? '',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700,  fontSize: 8,),
                    ),
                  ],
                ),
              ),




              pw.SizedBox(height: 15),

              // Währungshinweis hinzufügen
              if (_selectedCurrency != 'CHF')
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
                  ),
                  child: pw.Text(
                    'Alle Preise in $_selectedCurrency (Umrechnungskurs: 1 CHF = ${_exchangeRates[_selectedCurrency]!.toStringAsFixed(4)} $_selectedCurrency)',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.amber900),
                  ),
                ),
              pw.SizedBox(height: 15),

              // Artikel-Tabelle
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(5), // Produkt
                  1: const pw.FlexColumnWidth(2), // Menge
                  2: const pw.FlexColumnWidth(2), // Einheit
                  3: const pw.FlexColumnWidth(3), // Preis/Einheit
                  4: const pw.FlexColumnWidth(2), // Rabatt
                  5: const pw.FlexColumnWidth(3), // Summe
                },
                children: [
                  // Header anpassen
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey50,
                    ),
                    children: [
                      _buildHeaderCell('Produkt', 12),
                      _buildHeaderCell('Menge', 9),
                      _buildHeaderCell('Einheit', 9),
                      _buildHeaderCell('Preis/Einheit', 9, align: pw.TextAlign.right),
                      _buildHeaderCell('Rabatt', 9, align: pw.TextAlign.right),
                      _buildHeaderCell('Summe', 12, align: pw.TextAlign.right),
                    ],
                  ),
                  // Artikel mit angepassten Währungsbezeichnungen
                  ...items.map((item) {
                    final quantity = item['quantity'] as num? ?? 0;
                    final pricePerUnit = item['price_per_unit'] as num? ?? 0;

                    final discount = item['discount'] as Map<String, dynamic>?;
                    final discountAmount = item['discount_amount'] as num? ?? 0;
                    final total = item['total'] as num? ?? 0;

                    return pw.TableRow(
                      children: [
                        _buildContentCell(
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item['product_name'] ?? '',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${'Artikelnummer:'} - ${item['product_id'] ?? ''}',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.blueGrey600,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${'Qualität:'} - ${item['quality_name'] ?? ''}',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.blueGrey600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildContentCell(pw.Text(quantity.toString(), style: const pw.TextStyle(fontSize: 9,),)),
                        _buildContentCell(pw.Text(item['unit'] ?? '', style: const pw.TextStyle(fontSize: 9,),)),
                        _buildContentCell(
                          pw.Text(
                            // Preisformatierung angepasst
                            formatPdfCurrency(pricePerUnit.toDouble()),
                            style: const pw.TextStyle(fontSize: 9,),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        _buildContentCell(
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              if (discount != null && discount['percentage'] > 0)
                                pw.Text(
                                  '${discount['percentage']}%',
                                  style: const pw.TextStyle(color: PdfColors.red, fontSize: 9,),
                                  textAlign: pw.TextAlign.right,
                                ),
                              if (discount != null && discount['absolute'] > 0)
                                pw.Text(
                                  // Rabattformatierung angepasst
                                  formatPdfCurrency(discount['absolute'].toDouble()),
                                  style: const pw.TextStyle(color: PdfColors.red, fontSize: 9,),
                                  textAlign: pw.TextAlign.right,
                                ),
                              if (discountAmount > 0)
                                pw.Text(
                                  // Rabattbetrag formatieren
                                  '-${formatPdfCurrency(discountAmount.toDouble())}',
                                  style: const pw.TextStyle(color: PdfColors.red, fontSize: 9,),
                                  textAlign: pw.TextAlign.right,
                                ),
                            ],
                          ),
                        ),
                        _buildContentCell(
                          pw.Text(
                            style: const pw.TextStyle(fontSize: 9,),
                            // Gesamtbetrag formatieren
                            formatPdfCurrency(total.toDouble()),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Zwischensumme
                      _buildTotalRowWithCurrency(
                        'Zwischensumme:',
                        calculations['subtotal'] as num? ?? 0,
                        _selectedCurrency,
                        _exchangeRates[_selectedCurrency] ?? 1.0,
                      ),

                      // Positionsrabatte
                      if ((calculations['item_discounts'] as num? ?? 0) > 0)
                        _buildTotalRowWithCurrency(
                          'Positionsrabatte:',
                          calculations['item_discounts'] as num? ?? 0,
                          _selectedCurrency,
                          _exchangeRates[_selectedCurrency] ?? 1.0,
                          isDiscount: true,
                        ),

                      // Gesamtrabatt
                      if ((calculations['total_discount_amount'] as num? ?? 0) > 0) ...[
                        if ((calculations['total_discount'] as Map<String, dynamic>)['percentage'] > 0)
                          _buildTotalRowWithCurrency(
                            'Gesamtrabatt (${(calculations['total_discount'] as Map<String, dynamic>)['percentage']}%):',
                            calculations['total_discount_amount'] as num? ?? 0,
                            _selectedCurrency,
                            _exchangeRates[_selectedCurrency] ?? 1.0,
                            isDiscount: true,
                          ),
                        if ((calculations['total_discount'] as Map<String, dynamic>)['absolute'] > 0)
                          _buildTotalRowWithCurrency(
                            'Gesamtrabatt (absolut):',
                            (calculations['total_discount'] as Map<String, dynamic>)['absolute'] as num? ?? 0,
                            _selectedCurrency,
                            _exchangeRates[_selectedCurrency] ?? 1.0,
                            isDiscount: true,
                          ),
                      ],

                      // Je nach Steueroption unterschiedliche Darstellung
                      if (taxOption == TaxOption.standard) ...[
                        // Nettobetrag
                        _buildTotalRowWithCurrency(
                          'Nettobetrag:',
                          calculations['net_amount'] as num? ?? 0,
                          _selectedCurrency,
                          _exchangeRates[_selectedCurrency] ?? 1.0,
                        ),

                        // MwSt
                        _buildTotalRowWithCurrency(
                          'MwSt (${(calculations['vat_rate'] as num? ?? 0).toStringAsFixed(1)}%):',
                          calculations['vat_amount'] as num? ?? 0,
                          _selectedCurrency,
                          _exchangeRates[_selectedCurrency] ?? 1.0,
                        ),

                        pw.Divider(color: PdfColors.blueGrey300),

                        // Gesamtbetrag
                        _buildTotalRowWithCurrency(
                          'Gesamtbetrag:',
                          calculations['total'] as num? ?? 0,
                          _selectedCurrency,
                          _exchangeRates[_selectedCurrency] ?? 1.0,
                          isBold: true,
                          fontSize: 12,
                        ),
                      ] else if (taxOption == TaxOption.noTax) ...[
                        pw.Divider(color: PdfColors.blueGrey300),

                        // Nettobetrag (als Gesamt)
                        _buildTotalRowWithCurrency(
                          'Nettobetrag:',
                          calculations['net_amount'] as num? ?? 0,
                          _selectedCurrency,
                          _exchangeRates[_selectedCurrency] ?? 1.0,
                          isBold: true,
                          fontSize: 12,
                        ),

                        // Steuerhinweis
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Es wird keine Mehrwertsteuer berechnet.',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontStyle: pw.FontStyle.italic,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ] else ...[
                        // TaxOption.totalOnly
                        pw.Divider(color: PdfColors.blueGrey300),

                        // Bruttobetrag (einfach der Nettobetrag ohne Steuer)
                        _buildTotalRowWithCurrency(
                          'Gesamtbetrag inkl. MwSt:',
                          calculations['net_amount'] as num? ?? 0,
                          _selectedCurrency,
                          _exchangeRates[_selectedCurrency] ?? 1.0,
                          isBold: true,
                          fontSize: 12,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer bleibt gleich...
              pw.Expanded(child: pw.SizedBox()),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Florinett AG',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                        pw.Text('Tonewood Switzerland',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('Veja Zinols 6',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('7482 Bergün',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('Switzerland',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('phone: +41 81 407 21 34',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('e-mail: info@tonewood.ch',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('VAT: CHE-102.853.600 MWST',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );




    // Zusatztexte im Footer
    final additionalTexts = await _getReceiptAdditionalTexts(receiptId);

    if (additionalTexts.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Titel
                pw.Text(
                  'Zusätzliche Informationen',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 20),

                // Legende
                if (additionalTexts.containsKey('legend') && additionalTexts['legend']!.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Legende',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          additionalTexts['legend']!,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],

                // FSC
                if (additionalTexts.containsKey('fsc') && additionalTexts['fsc']!.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FSC-Zertifizierung',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          additionalTexts['fsc']!,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Naturprodukt
                if (additionalTexts.containsKey('natural_product') && additionalTexts['natural_product']!.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Naturprodukt',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          additionalTexts['natural_product']!,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Bankverbindung
                if (additionalTexts.containsKey('bank_info') && additionalTexts['bank_info']!.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bankverbindung',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          additionalTexts['bank_info']!,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],

                pw.Expanded(child: pw.SizedBox()),

                // Fußzeile
                pw.Container(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Seite 2/2',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
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
        FutureBuilder<int>(
          future: _getAvailableQuantity(selectedProduct!['barcode']),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                'Verfügbar: ${snapshot.data} ${selectedProduct!['unit'] ?? 'Stück'}',
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
            percentage: data['percentage'] ?? 0.0,
            absolute: data['absolute'] ?? 0.0,
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
  void _showItemDiscountDialog(String itemId, double currentAmount) {
    final percentageController = TextEditingController(
        text: _itemDiscounts[itemId]?.percentage.toString() ?? '0.0'
    );
    final absoluteController = TextEditingController(
        text: _itemDiscounts[itemId]?.absolute.toString() ?? '0.0'
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rabatt eingeben'),
        content: ValueListenableBuilder<String>(
          valueListenable: _currencyNotifier,
          builder: (context, currency, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: percentageController,
                        decoration: const InputDecoration(
                          labelText: 'Rabatt %',
                          suffixText: '%',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: absoluteController,
                        decoration: InputDecoration(
                          labelText: 'Rabatt $currency',
                          suffixText: currency,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<double>(
                  stream: _calculateItemDiscount(
                    currentAmount,
                    double.tryParse(percentageController.text) ?? 0,
                    // Konvertiere den absoluten Rabatt in CHF, wenn eine andere Währung ausgewählt ist
                    currency != 'CHF'
                        ? (double.tryParse(absoluteController.text) ?? 0) / _exchangeRates[currency]!
                        : double.tryParse(absoluteController.text) ?? 0,
                  ),
                  builder: (context, snapshot) {
                    final discount = snapshot.data ?? 0.0;
                    return Text(
                      'Rabattbetrag: ${_formatPrice(discount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _currencyNotifier,
            builder: (context, currency, child) {
              return ElevatedButton(
                onPressed: () async {

                  // Konvertiere den absoluten Rabatt in CHF, wenn eine andere Währung ausgewählt ist
                  double absoluteValue = double.tryParse(absoluteController.text) ?? 0;
                  if (currency != 'CHF') {
                    absoluteValue = absoluteValue / _exchangeRates[currency]!;
                  }

                  setState(() {
                    _itemDiscounts[itemId] = Discount(
                      percentage: double.tryParse(percentageController.text) ?? 0,
                      absolute: absoluteValue, // Immer in CHF speichern
                    );
                  });

                  await FirebaseFirestore.instance
                      .collection('temporary_basket')
                      .doc(itemId)
                      .update({
                    'discount': {
                      'percentage': double.tryParse(percentageController.text) ?? 0,
                      'absolute': absoluteValue,
                    },
                    'discount_timestamp': FieldValue.serverTimestamp(),
                  });

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
                        'Gesamtrabatt anpassen',
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

                              final itemSubtotal = (data['quantity'] as int) * pricePerUnit;
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
                            vatAmount = netAmount * (_vatRate / 100);
                            totalAmount = netAmount + vatAmount;
                          }

                          // Funktionen für die Umrechnung
                          void calculateTargetTotal() {
                            final targetTotal = double.tryParse(targetTotalController.text.replaceAll(',', '.')) ?? 0;
                            if (targetTotal <= 0 || afterItemDiscounts <= 0) return;

                            // Je nach Steueroption unterschiedlich berechnen
                            double targetNetAmount;
                            if (_taxOptionNotifier.value == TaxOption.standard) {
                              // Bei Standardsteuer: Zielbetrag enthält MwSt
                              targetNetAmount = targetTotal / (1 + (_vatRate / 100));
                            } else {
                              // Bei anderen Optionen: Zielbetrag ist direkt der Nettobetrag
                              targetNetAmount = targetTotal;
                            }

                            // Berechne benötigten Rabatt
                            final neededDiscount = afterItemDiscounts - targetNetAmount;

                            // Setze den Rabatt als absoluten Wert (Prozent auf 0)
                            if (neededDiscount >= 0) {
                              setState(() {
                                percentageController.text = '0';

                                // Wenn eine andere Währung als CHF ausgewählt ist, umrechnen
                                double displayDiscount = neededDiscount;
                                if (currency != 'CHF') {
                                  displayDiscount = neededDiscount * _exchangeRates[currency]!;
                                }

                                absoluteController.text = displayDiscount.toStringAsFixed(2);

                                // Speichere auch in den temporären Variablen
                                tempPercentage = 0;
                                tempAbsolute = neededDiscount;
                              });
                            }
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
                                    prefixIcon: getAdaptiveIcon(iconName: 'percent', defaultIcon: Icons.percent),
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
                                    prefixIcon: getAdaptiveIcon(iconName: 'money_off', defaultIcon: Icons.money_off),
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
                                    prefixIcon: getAdaptiveIcon(iconName: 'price_check', defaultIcon: Icons.price_check),
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
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Sichere die temporären Werte in der Hauptklasse
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
                                content: Text('Rabatt angewendet'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check),
                          label: const Text('Übernehmen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
