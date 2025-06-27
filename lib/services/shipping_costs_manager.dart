import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';

class ShippingCostsManager {
  static const String COLLECTION_NAME = 'temporary_shipping_costs';
  static const String DOCUMENT_ID = 'current_costs';

  // Standardwerte
  static const double DEFAULT_PLANT_CERTIFICATE = 50.0;
  static const double DEFAULT_PACKAGING = 50.0;
  static const double DEFAULT_FREIGHT = 50.0;
  static const String DEFAULT_CARRIER = 'Swiss Post';

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

      // Füge die berechneten Felder hinzu
      final dataToSave = {
        ...costs,
        'amount': amount, // Kombinierter Betrag für Verpackung & Fracht
        'phytosanitaryCertificate': phytosanitary, // Pflanzenschutzzeugnisse
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
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      // Erstelle einen StatefulWidget für bessere State-Verwaltung
      return _ShippingCostsBottomSheet(
        costsConfiguredNotifier: costsConfiguredNotifier,
      );
    },
  );
}

class _ShippingCostsBottomSheet extends StatefulWidget {
  final ValueNotifier<bool> costsConfiguredNotifier;

  const _ShippingCostsBottomSheet({
    Key? key,
    required this.costsConfiguredNotifier,
  }) : super(key: key);

  @override
  _ShippingCostsBottomSheetState createState() => _ShippingCostsBottomSheetState();
}

class _ShippingCostsBottomSheetState extends State<_ShippingCostsBottomSheet> {
  Map<String, dynamic> shippingConfig = {};
  bool isLoading = true;

  // Controller
  final plantCertificateController = TextEditingController();
  final packagingController = TextEditingController();
  final freightController = TextEditingController();
  final carrierController = TextEditingController();
  final combinedCostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadShippingCosts();
  }

  Future<void> _loadShippingCosts() async {
    final config = await ShippingCostsManager.loadShippingCosts();

    setState(() {
      shippingConfig = config;
      isLoading = false;

      // Setze Controller-Werte MIT den gespeicherten Werten
      plantCertificateController.text = config['plant_certificate_cost']?.toString() ?? '50.0';
      packagingController.text = config['packaging_cost']?.toString() ?? '50.0';
      freightController.text = config['freight_cost']?.toString() ?? '50.0';
      carrierController.text = config['carrier'] ?? ShippingCostsManager.DEFAULT_CARRIER;

      // Kombinierter Preis BASIEREND auf gespeicherten Werten
      final packaging = config['packaging_cost'] ?? 50.0;
      final freight = config['freight_cost'] ?? 50.0;
      combinedCostController.text = (packaging + freight).toString();
    });
  }

  @override
  void dispose() {
    plantCertificateController.dispose();
    packagingController.dispose();
    freightController.dispose();
    carrierController.dispose();
    combinedCostController.dispose();
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
                            decoration: const InputDecoration(
                              labelText: 'Kosten (CHF)',
                              border: OutlineInputBorder(),
                              prefixText: 'CHF ',
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

                        // Toggle für kombiniert/getrennt
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Kombiniert'),
                              icon: Icon(Icons.merge_type),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Getrennt'),
                              icon: Icon(Icons.call_split),
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
                            decoration: const InputDecoration(
                              labelText: 'Gesamtkosten Verpackung & Fracht (CHF)',
                              border: OutlineInputBorder(),
                              prefixText: 'CHF ',
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              final total = double.tryParse(value) ?? 100.0;
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
                            decoration: const InputDecoration(
                              labelText: 'Verpackungskosten (CHF)',
                              border: OutlineInputBorder(),
                              prefixText: 'CHF ',
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
                            decoration: const InputDecoration(
                              labelText: 'Frachtkosten (CHF)',
                              border: OutlineInputBorder(),
                              prefixText: 'CHF ',
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

                        // Transporteur
                        TextFormField(
                          controller: carrierController,
                          decoration: InputDecoration(
                            labelText: 'Transporteur',
                            border: const OutlineInputBorder(),
                            prefixIcon: getAdaptiveIcon(
                                iconName: 'local_shipping',
                                defaultIcon: Icons.local_shipping
                            ),
                          ),
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
                            'carrier': carrierController.text.isNotEmpty ? carrierController.text : 'Swiss Post',
                          };

                          // Speichere die Konfiguration in Firebase
                          await ShippingCostsManager.saveShippingCosts(finalConfig);

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