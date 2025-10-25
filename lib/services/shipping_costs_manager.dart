import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../services/icon_helper.dart';

class ShippingCostsManager {
  static const String COLLECTION_NAME = 'temporary_shipping_costs';
  static const String DOCUMENT_ID = 'current_costs';

  // Standardwerte
  static const double DEFAULT_PLANT_CERTIFICATE = 50.0;
  static const double DEFAULT_PACKAGING = 50.0;
  static const double DEFAULT_FREIGHT = 50.0;
  static const String DEFAULT_CARRIER = 'Swiss Post';
  static const double DEFAULT_DEDUCTION_1 = 0.0;
  static const double DEFAULT_DEDUCTION_2 = 0.0;
  static const double DEFAULT_DEDUCTION_3 = 0.0;
  static const double DEFAULT_SURCHARGE_1 = 0.0;
  static const double DEFAULT_SURCHARGE_2 = 0.0;
  static const double DEFAULT_SURCHARGE_3 = 0.0;

  // Lade aus Firebase
  static Future<Map<String, dynamic>> loadShippingCosts() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(COLLECTION_NAME)
          .doc(DOCUMENT_ID)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        print('Geladene Firebase Versandkosten: $data'); // Debug
        return data;
      }
    } catch (e) {
      print('Fehler beim Laden der Firebase Versandkosten: $e');
    }

    print('Verwende Standard-Versandkosten'); // Debug
    return {
      'plant_certificate_enabled': false,
      'plant_certificate_cost': DEFAULT_PLANT_CERTIFICATE,
      'shipping_combined': true,
      'packaging_cost': DEFAULT_PACKAGING,
      'freight_cost': DEFAULT_FREIGHT,
      'carrier': DEFAULT_CARRIER,
      'deduction_1_text': '',
      'deduction_1_amount': DEFAULT_DEDUCTION_1,
      'deduction_2_text': '',
      'deduction_2_amount': DEFAULT_DEDUCTION_2,
      'deduction_3_text': '',
      'deduction_3_amount': DEFAULT_DEDUCTION_3,
      // NEU: Zuschläge
      'surcharge_1_text': 'Kleinmenge',
      'surcharge_1_amount': DEFAULT_SURCHARGE_1,
      'surcharge_2_text': 'Oberflächenbearbeitung',
      'surcharge_2_amount': DEFAULT_SURCHARGE_2,
      'surcharge_3_text': '',
      'surcharge_3_amount': DEFAULT_SURCHARGE_3,

    };
  }

  // Speichere in Firebase
  static Future<void> saveShippingCosts(Map<String, dynamic> costs) async {
    try {
      print('Speichere Firebase Versandkosten: $costs'); // Debug

      // Berechne den kombinierten Betrag für amount
      final double amount = (costs['packaging_cost'] ?? 0.0) + (costs['freight_cost'] ?? 0.0);
      final double phytosanitary = costs['plant_certificate_enabled'] == true
          ? (costs['plant_certificate_cost'] ?? 0.0)
          : 0.0;
      final double totalDeductions =
          (costs['deduction_1_amount'] ?? 0.0) +
              (costs['deduction_2_amount'] ?? 0.0) +
              (costs['deduction_3_amount'] ?? 0.0);

// Berechne die Gesamtsumme der Zuschläge
      final double totalSurcharges =
          (costs['surcharge_1_amount'] ?? 0.0) +
              (costs['surcharge_2_amount'] ?? 0.0) +
              (costs['surcharge_3_amount'] ?? 0.0);
      // Füge die berechneten Felder hinzu
      final dataToSave = {
        ...costs,
        'amount': amount, // Kombinierter Betrag für Verpackung & Fracht
        'phytosanitaryCertificate': phytosanitary, // Pflanzenschutzzeugnisse
        'timestamp': FieldValue.serverTimestamp(),
        'totalDeductions': totalDeductions,
        'totalSurcharges': totalSurcharges,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection(COLLECTION_NAME)
          .doc(DOCUMENT_ID)
          .set(dataToSave, SetOptions(merge: true));
    } catch (e) {
      print('Fehler beim Speichern der Firebase Versandkosten: $e');
      rethrow;
    }
  }


  // Nach der loadShippingCosts Methode hinzufügen:

// Lade Versandkosten und konvertiere in die gewünschte Währung
  static Future<Map<String, dynamic>> loadShippingCostsWithCurrency(
      String currency,
      Map<String, double> exchangeRates,
      ) async {
    final costs = await loadShippingCosts();

    // Wenn bereits in der Zielwährung gespeichert, direkt zurückgeben
    if (costs['currency'] == currency) {
      return costs;
    }

    // Konvertiere von CHF in die Zielwährung
    final rate = exchangeRates[currency] ?? 1.0;

    return {
      ...costs,
      'plant_certificate_cost': (costs['plant_certificate_cost'] ?? DEFAULT_PLANT_CERTIFICATE) * rate,
      'packaging_cost': (costs['packaging_cost'] ?? DEFAULT_PACKAGING) * rate,
      'freight_cost': (costs['freight_cost'] ?? DEFAULT_FREIGHT) * rate,
      'deduction_1_amount': (costs['deduction_1_amount'] ?? 0.0) * rate,
      'deduction_2_amount': (costs['deduction_2_amount'] ?? 0.0) * rate,
      'deduction_3_amount': (costs['deduction_3_amount'] ?? 0.0) * rate,
      'surcharge_1_amount': (costs['surcharge_1_amount'] ?? 0.0) * rate,
      'surcharge_2_amount': (costs['surcharge_2_amount'] ?? 0.0) * rate,
      'surcharge_3_amount': (costs['surcharge_3_amount'] ?? 0.0) * rate,
      'currency': currency,
    };
  }

// Speichere Versandkosten in CHF (für interne Verwendung)
  static Future<void> saveShippingCostsWithCurrency(
      Map<String, dynamic> costs,
      String currency,
      Map<String, double> exchangeRates,
      ) async {
    try {
      // Konvertiere zurück nach CHF für die Speicherung
      final rate = exchangeRates[currency] ?? 1.0;

      final chfCosts = {
        ...costs,
        'plant_certificate_cost': currency == 'CHF'
            ? costs['plant_certificate_cost']
            : (costs['plant_certificate_cost'] ?? 0.0) / rate,
        'packaging_cost': currency == 'CHF'
            ? costs['packaging_cost']
            : (costs['packaging_cost'] ?? 0.0) / rate,
        'freight_cost': currency == 'CHF'
            ? costs['freight_cost']
            : (costs['freight_cost'] ?? 0.0) / rate,
        'deduction_1_amount': currency == 'CHF'
            ? costs['deduction_1_amount']
            : (costs['deduction_1_amount'] ?? 0.0) / rate,
        'deduction_2_amount': currency == 'CHF'
            ? costs['deduction_2_amount']
            : (costs['deduction_2_amount'] ?? 0.0) / rate,
        'deduction_3_amount': currency == 'CHF'
            ? costs['deduction_3_amount']
            : (costs['deduction_3_amount'] ?? 0.0) / rate,
        'surcharge_1_amount': currency == 'CHF'
            ? costs['surcharge_1_amount']
            : (costs['surcharge_1_amount'] ?? 0.0) / rate,
        'surcharge_2_amount': currency == 'CHF'
            ? costs['surcharge_2_amount']
            : (costs['surcharge_2_amount'] ?? 0.0) / rate,
        'surcharge_3_amount': currency == 'CHF'
            ? costs['surcharge_3_amount']
            : (costs['surcharge_3_amount'] ?? 0.0) / rate,
        'stored_in_chf': true, // Markierung dass Werte in CHF gespeichert sind
      };

      await saveShippingCosts(chfCosts);
    } catch (e) {
      print('Fehler beim Speichern der Versandkosten mit Währung: $e');
      rethrow;
    }
  }




  // Speichere Versandkosten direkt aus Daten (für Quote-Kopie)
  static Future<void> saveShippingCostsFromData(Map<String, dynamic> costsData) async {
    try {
      await FirebaseFirestore.instance
          .collection(COLLECTION_NAME)
          .doc(DOCUMENT_ID)
          .set({
        ...costsData,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Versandkosten aus Quote-Daten gespeichert');
    } catch (e) {
      print('Fehler beim Speichern der Versandkosten aus Daten: $e');
      rethrow;
    }
  }
  // Lösche aus Firebase
  static Future<void> clearShippingCosts() async {
    try {
      await FirebaseFirestore.instance
          .collection(COLLECTION_NAME)
          .doc(DOCUMENT_ID)
          .delete();
    } catch (e) {
      print('Fehler beim Löschen der Firebase Versandkosten: $e');
      rethrow;
    }
  }
}

void showShippingCostsBottomSheet(BuildContext context, {
  required ValueNotifier<bool> costsConfiguredNotifier,
  required String currency, // NEU
  required Map<String, double> exchangeRates, // NEU
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      // Erstelle einen StatefulWidget für bessere State-Verwaltung
      return _ShippingCostsBottomSheet(
        costsConfiguredNotifier: costsConfiguredNotifier,
        currency: currency, // NEU
        exchangeRates: exchangeRates, // NEU
      );
    },
  );
}

class _ShippingCostsBottomSheet extends StatefulWidget {
  final ValueNotifier<bool> costsConfiguredNotifier;
  final String currency; // NEU
  final Map<String, double> exchangeRates; // NEU
  const _ShippingCostsBottomSheet({
    Key? key,
    required this.costsConfiguredNotifier,
    required this.currency, // NEU
    required this.exchangeRates, // NEU
  }) : super(key: key);

  @override
  _ShippingCostsBottomSheetState createState() => _ShippingCostsBottomSheetState();
}

class _ShippingCostsBottomSheetState extends State<_ShippingCostsBottomSheet> {
  Map<String, dynamic> shippingConfig = {};
  bool isLoading = true;
  bool isPersonalPickup = false;
  // Controller
  final plantCertificateController = TextEditingController();
  final packagingController = TextEditingController();
  final freightController = TextEditingController();
  final carrierController = TextEditingController();
  final combinedCostController = TextEditingController();


  final deduction1TextController = TextEditingController();
  final deduction1AmountController = TextEditingController();
  final deduction2TextController = TextEditingController();
  final deduction2AmountController = TextEditingController();
  final deduction3TextController = TextEditingController();
  final deduction3AmountController = TextEditingController();

// Zuschlag Controller
  final surcharge1TextController = TextEditingController();
  final surcharge1AmountController = TextEditingController();
  final surcharge2TextController = TextEditingController();
  final surcharge2AmountController = TextEditingController();
  final surcharge3TextController = TextEditingController();
  final surcharge3AmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadShippingCosts();
  }
// Hilfsmethode zum Berechnen des Gesamtgewichts
  Future<Map<String, dynamic>> _calculateTotalWeight() async {
    double totalWeight = 0.0;
    int itemsWithoutWeight = 0;
    List<Map<String, dynamic>> itemWeights = [];

    try {
      final basketSnapshot = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .get();

      for (var doc in basketSnapshot.docs) {
        final data = doc.data();
        final quantity = (data['quantity'] as num).toDouble();

        // Versuche das Volumen zu bekommen (volume_per_unit oder custom_volume)
        final volumePerUnit = (data['volume_per_unit'] as num?)?.toDouble() ??
            (data['custom_volume'] as num?)?.toDouble();

        double itemWeight = 0.0;

        // Ersetze die Gewichtsberechnung in _calculateTotalWeight mit:
        if (volumePerUnit != null && volumePerUnit > 0) {
          // Verwende die gespeicherte Dichte oder Standardwert
          final density = (data['density'] as num?)?.toDouble() ?? 0; // Fallback auf 0 kg/m³
          final weightPerUnit = volumePerUnit * density; // kg pro Einheit
          itemWeight = weightPerUnit * quantity;
          totalWeight += itemWeight;
        } else {
          itemsWithoutWeight++;
        }

        itemWeights.add({
          'name': data['product_name'] ?? 'Unbekanntes Produkt',
          'quantity': quantity,
          'unit': data['unit'] ?? 'Stück',
          'weight': itemWeight,
          'hasWeight': itemWeight > 0,
        });
      }
    } catch (e) {
      print('Fehler beim Berechnen des Gewichts: $e');
    }

    return {
      'totalWeight': totalWeight,
      'itemsWithoutWeight': itemsWithoutWeight,
      'itemWeights': itemWeights,
    };
  }

// Methode zum Anzeigen des Gewichts-Details Dialogs
  void _showWeightDetailsDialog(Map<String, dynamic> weightData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'scale', defaultIcon:
                      Icons.scale,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Gewichtsübersicht',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
                      onPressed: () => Navigator.pop(context),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Zusammenfassung
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gesamtgewicht:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(weightData['totalWeight'] as double).toStringAsFixed(2)} kg',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Liste der Artikel
                      ...(weightData['itemWeights'] as List).map((item) {
                        final hasWeight = item['hasWeight'] as bool;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: hasWeight
                                  ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                                  : Theme.of(context).colorScheme.error.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: hasWeight
                                ? null
                                : Theme.of(context).colorScheme.error.withOpacity(0.05),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item['quantity']} ${item['unit']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasWeight)
                                Text(
                                  '${(item['weight'] as double).toStringAsFixed(2)} kg',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Kein Gewicht',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.error,
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
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Schließen'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _loadShippingCosts() async {
    final config = await ShippingCostsManager.loadShippingCostsWithCurrency(
      widget.currency,
      widget.exchangeRates,
    );
    setState(() {
      shippingConfig = config;
      isLoading = false;

      isPersonalPickup = config['carrier'] == 'Persönlich abgeholt';
      if (!isPersonalPickup) {
        carrierController.text = config['carrier'] ?? ShippingCostsManager.DEFAULT_CARRIER;
      }

      // Setze Controller-Werte MIT den gespeicherten Werten
      plantCertificateController.text = config['plant_certificate_cost']?.toString() ?? '50.0';
      packagingController.text = config['packaging_cost']?.toString() ?? '50.0';
      freightController.text = config['freight_cost']?.toString() ?? '50.0';
      carrierController.text = config['carrier'] ?? ShippingCostsManager.DEFAULT_CARRIER;

      // Setze Abschlag-Controller
      deduction1TextController.text = config['deduction_1_text'] ?? 'Anzahlung';
      deduction1AmountController.text = config['deduction_1_amount']?.toString() ?? '0.0';
      deduction2TextController.text = config['deduction_2_text'] ?? '';
      deduction2AmountController.text = config['deduction_2_amount']?.toString() ?? '0.0';
      deduction3TextController.text = config['deduction_3_text'] ?? '';
      deduction3AmountController.text = config['deduction_3_amount']?.toString() ?? '0.0';

// Setze Zuschlag-Controller
      surcharge1TextController.text = config['surcharge_1_text'] ?? 'Kleinmenge';
      surcharge1AmountController.text = config['surcharge_1_amount']?.toString() ?? '0.0';
      surcharge2TextController.text = config['surcharge_2_text'] ?? 'Oberflächenbearbeitung';
      surcharge2AmountController.text = config['surcharge_2_amount']?.toString() ?? '0.0';
      surcharge3TextController.text = config['surcharge_3_text'] ?? '';
      surcharge3AmountController.text = config['surcharge_3_amount']?.toString() ?? '0.0';



      // Kombinierter Preis BASIEREND auf gespeicherten Werten
      final packaging = config['packaging_cost'] ?? 50.0;
      final freight = config['freight_cost'] ?? 50.0;
      combinedCostController.text = (packaging + freight).toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    plantCertificateController.dispose();
    packagingController.dispose();
    freightController.dispose();
    carrierController.dispose();
    combinedCostController.dispose();
    // Abschlag Controller
    deduction1TextController.dispose();
    deduction1AmountController.dispose();
    deduction2TextController.dispose();
    deduction2AmountController.dispose();
    deduction3TextController.dispose();
    deduction3AmountController.dispose();

// Zuschlag Controller
    surcharge1TextController.dispose();
    surcharge1AmountController.dispose();
    surcharge2TextController.dispose();
    surcharge2AmountController.dispose();
    surcharge3TextController.dispose();
    surcharge3AmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
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
                    child: getAdaptiveIcon(
                      iconName: 'local_shipping',
                      defaultIcon: Icons.local_shipping,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Versand & Zusatzkosten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. Pflanzenschutzzeugniss
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: shippingConfig['plant_certificate_enabled'] == true
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                            : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        width: shippingConfig['plant_certificate_enabled'] == true ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Pflanzenschutzzeugniss',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Switch(
                              value: shippingConfig['plant_certificate_enabled'] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  shippingConfig['plant_certificate_enabled'] = value;
                                });
                              },
                              activeColor: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                        if (shippingConfig['plant_certificate_enabled'] == true) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: plantCertificateController,
                            decoration:  InputDecoration(
                              labelText: 'Kosten (${widget.currency})',
                              border: OutlineInputBorder(),

                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Verpackung & Fracht
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verpackung & Fracht',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // NEU: Gewichtsanzeige
                        const SizedBox(height: 12),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _calculateTotalWeight(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Gewicht wird berechnet...'),
                                  ],
                                ),
                              );
                            }

                            final weightData = snapshot.data!;
                            final totalWeight = weightData['totalWeight'] as double;
                            final itemsWithoutWeight = weightData['itemsWithoutWeight'] as int;

                            return Container(
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
                                  Row(
                                    children: [
                                      getAdaptiveIcon(iconName: 'scale', defaultIcon:
                                        Icons.scale,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Netto Gesamtgewicht:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${totalWeight.toStringAsFixed(2)} kg',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _showWeightDetailsDialog(weightData),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child:
                                          getAdaptiveIcon(iconName: 'info', defaultIcon:
                                            Icons.info,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (itemsWithoutWeight > 0) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        getAdaptiveIcon(iconName: 'warning', defaultIcon:
                                          Icons.warning,
                                          size: 14,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Für $itemsWithoutWeight Artikel ist kein Gewicht gepflegt',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.error,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                        // Toggle für kombiniert/getrennt
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Kombiniert'),
                              icon:  getAdaptiveIcon(iconName: 'merge_type',defaultIcon:Icons.merge_type),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Getrennt'),
                              icon:  getAdaptiveIcon(iconName: 'call_split',defaultIcon:Icons.call_split),
                            ),
                          ],
                          selected: {shippingConfig['shipping_combined'] ?? true},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              shippingConfig['shipping_combined'] = newSelection.first;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        if (shippingConfig['shipping_combined'] == true) ...[
                          // Kombinierte Kosten
                          TextFormField(
                            controller: combinedCostController,
                            decoration: InputDecoration(
                              labelText: 'Gesamtkosten Verpackung & Fracht (${widget.currency})',
                              border: OutlineInputBorder(),
                              suffixText: widget.currency,
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                            onChanged: (value) {
                              final total = double.tryParse(value.replaceAll(',', '.')) ?? 100.0;
                              setState(() {
                                packagingController.text = (total / 2).toStringAsFixed(2);
                                freightController.text = (total / 2).toStringAsFixed(2);
                              });
                            },
                          ),
                        ] else ...[
                          // Getrennte Kosten
                          TextFormField(
                            controller: packagingController,
                            decoration: InputDecoration(
                              labelText: 'Verpackungskosten (${widget.currency})',
                              border: OutlineInputBorder(),

                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              // Update combined controller
                              final packaging = double.tryParse(value) ?? 0.0;
                              final freight = double.tryParse(freightController.text) ?? 0.0;
                              combinedCostController.text = (packaging + freight).toStringAsFixed(2);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: freightController,
                            decoration:  InputDecoration(
                              labelText: 'Frachtkosten (${widget.currency})',
                              border: OutlineInputBorder(),

                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              // Update combined controller
                              final packaging = double.tryParse(packagingController.text) ?? 0.0;
                              final freight = double.tryParse(value) ?? 0.0;
                              combinedCostController.text = (packaging + freight).toStringAsFixed(2);
                            },
                          ),
                        ],

                        const SizedBox(height: 16),

    const SizedBox(height: 16),

// Transporteur oder persönliche Abholung
    Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Checkbox für persönliche Abholung
      // Checkbox für persönliche Abholung
      CheckboxListTile(
        title: Text(
          'Persönlich abgeholt',
          style: TextStyle(
            fontWeight: isPersonalPickup ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          'Ware wird vom Kunden selbst abgeholt',
          style: TextStyle(fontSize: 12),
        ),
        value: isPersonalPickup,
        onChanged: (value) {
          setState(() {
            isPersonalPickup = value ?? false;
            if (isPersonalPickup) {
              carrierController.clear();
              // NEU: Setze alle Versandkosten auf 0
              packagingController.text = '0.0';
              freightController.text = '0.0';
              combinedCostController.text = '0.0';
            } else {
              // NEU: Setze Standardwerte zurück wenn nicht persönlich abgeholt
              packagingController.text = '50.0';
              freightController.text = '50.0';
              combinedCostController.text = '100.0';
            }
          });
        },
        activeColor: Theme.of(context).colorScheme.primary,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),

    const SizedBox(height: 12),

    // Transporteur Eingabefeld (nur wenn nicht persönlich abgeholt)
    AnimatedOpacity(
    opacity: isPersonalPickup ? 0.3 : 1.0,
    duration: const Duration(milliseconds: 200),
    child: TextFormField(
    controller: carrierController,
    enabled: !isPersonalPickup,
    decoration: InputDecoration(
    labelText: 'Transporteur',
    border: const OutlineInputBorder(),
    prefixIcon: getAdaptiveIcon(
    iconName: 'local_shipping',
    defaultIcon: Icons.local_shipping,
    color: isPersonalPickup ? Colors.grey : null,
    ),
    filled: isPersonalPickup,
    fillColor: isPersonalPickup ? Colors.grey.shade100 : null,
    ),
    ),
    ),
    ],
    ),
                      ],
                    ),
                  ),


                  const SizedBox(height: 24),

// 3. Abschläge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            getAdaptiveIcon(iconName: 'remove', defaultIcon:
                              Icons.remove,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Abschläge',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Abschlag 1
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: deduction1TextController,
                                decoration: const InputDecoration(
                                  labelText: 'Bezeichnung',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: deduction1AmountController,
                                decoration:  InputDecoration(
                                  labelText: 'Betrag (${widget.currency})',
                                  border: OutlineInputBorder(),

                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Abschlag 2
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: deduction2TextController,
                                decoration: const InputDecoration(
                                  labelText: 'Bezeichnung',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: deduction2AmountController,
                                decoration:  InputDecoration(
                                  labelText: 'Betrag (${widget.currency})',
                                  border: OutlineInputBorder(),

                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Abschlag 3
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: deduction3TextController,
                                decoration: const InputDecoration(
                                  labelText: 'Bezeichnung',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: deduction3AmountController,
                                decoration: InputDecoration(
                                  labelText: 'Betrag (${widget.currency})',
                                  border: OutlineInputBorder(),

                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

// 4. Zuschläge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            getAdaptiveIcon(iconName: 'add_circle', defaultIcon:
                              Icons.add_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Zuschläge',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Zuschlag 1
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: surcharge1TextController,
                                decoration: const InputDecoration(
                                  labelText: 'Bezeichnung',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: surcharge1AmountController,
                                decoration: InputDecoration(
                                  labelText: 'Betrag (${widget.currency})',
                                  border: OutlineInputBorder(),

                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Zuschlag 2
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: surcharge2TextController,
                                decoration: const InputDecoration(
                                  labelText: 'Bezeichnung',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: surcharge2AmountController,
                                decoration:  InputDecoration(
                                  labelText: 'Betrag (${widget.currency})',
                                  border: OutlineInputBorder(),

                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Zuschlag 3
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: surcharge3TextController,
                                decoration: const InputDecoration(
                                  labelText: 'Bezeichnung',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: surcharge3AmountController,
                                decoration:  InputDecoration(
                                  labelText: 'Betrag (${widget.currency})',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          // Speichere die finalen Werte
                          final finalConfig = {
                            'plant_certificate_enabled': shippingConfig['plant_certificate_enabled'] ?? false,
                            'plant_certificate_cost': double.tryParse(plantCertificateController.text) ?? 50.0,
                            'shipping_combined': shippingConfig['shipping_combined'] ?? true,
                            'packaging_cost': double.tryParse(packagingController.text) ?? 50.0,
                            'freight_cost': double.tryParse(freightController.text) ?? 50.0,
                            'carrier': isPersonalPickup
                                ? 'Persönlich abgeholt'
                                : (carrierController.text.isNotEmpty ? carrierController.text : 'Swiss Post'),
                            // NEU: Abschläge
                            'deduction_1_text': deduction1TextController.text,
                            'deduction_1_amount': double.tryParse(deduction1AmountController.text) ?? 0.0,
                            'deduction_2_text': deduction2TextController.text,
                            'deduction_2_amount': double.tryParse(deduction2AmountController.text) ?? 0.0,
                            'deduction_3_text': deduction3TextController.text,
                            'deduction_3_amount': double.tryParse(deduction3AmountController.text) ?? 0.0,
                            // NEU: Zuschläge
                            'surcharge_1_text': surcharge1TextController.text,
                            'surcharge_1_amount': double.tryParse(surcharge1AmountController.text) ?? 0.0,
                            'surcharge_2_text': surcharge2TextController.text,
                            'surcharge_2_amount': double.tryParse(surcharge2AmountController.text) ?? 0.0,
                            'surcharge_3_text': surcharge3TextController.text,
                            'surcharge_3_amount': double.tryParse(surcharge3AmountController.text) ?? 0.0,
                          };

                          // Speichere die Konfiguration in Firebase
                          await ShippingCostsManager.saveShippingCostsWithCurrency(
                            finalConfig,
                            widget.currency,
                            widget.exchangeRates,
                          );
                          // Setze den Notifier
                          widget.costsConfiguredNotifier.value = true;

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Versandkosten gespeichert'),
                                backgroundColor: Colors.green,
                              ),
                            );
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
                      },
                      icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save),
                      label: const Text('Speichern'),
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
      ),
    );
  }
}