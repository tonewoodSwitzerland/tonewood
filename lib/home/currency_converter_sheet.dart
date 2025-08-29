import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/icon_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
class CurrencyConverterSheet {
  static void show(
      BuildContext context, {
        required ValueNotifier<String> currencyNotifier,
        required ValueNotifier<Map<String, double>> exchangeRatesNotifier,
        required Function() onSave,
      }) {
    final eurRateController = TextEditingController(
      text: exchangeRatesNotifier.value['EUR']!.toString(),
    );
    final usdRateController = TextEditingController(
      text: exchangeRatesNotifier.value['USD']!.toString(),
    );
    String currentCurrency = currencyNotifier.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          // Hilfsfunktion für die Umrechnung
          double convertFromCHF(double chfAmount, double rate) => chfAmount * rate;
          double convertToCHF(double foreignAmount, double rate) =>
              rate > 0 ? foreignAmount / rate : 0;

          // Füge diese Methode am Anfang des StatefulBuilder hinzu:
          double parseControllerValue(TextEditingController controller) {
            if (controller.text.isEmpty) return 0.0;
            return double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
          }



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
                        child: getAdaptiveIcon(
                          iconName: 'currency_exchange',
                          defaultIcon: Icons.currency_exchange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Währungseinstellungen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: getAdaptiveIcon(
                          iconName: 'close',
                          defaultIcon: Icons.close,
                        ),
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
                        // Aktuelle Währung
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
                                'Anzeigewährung',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Währung für Preisanzeige',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surface,
                                  prefixIcon: getAdaptiveIcon(
                                    iconName: 'paid',
                                    defaultIcon: Icons.paid,
                                  ),
                                ),
                                value: currentCurrency,
                                items: exchangeRatesNotifier.value.keys.map((currency) =>
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

// NEU: Letzte Aktualisierung anzeigen
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('general_data')
                              .doc('currency_settings')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              final lastUpdated = data['last_updated'] as Timestamp?;

                              if (lastUpdated != null) {
                                final dateTime = lastUpdated.toDate();
                                final now = DateTime.now();
                                final difference = now.difference(dateTime);

                                String timeAgo;
                                if (difference.inDays > 0) {
                                  timeAgo = 'vor ${difference.inDays} Tag${difference.inDays > 1 ? 'en' : ''}';
                                } else if (difference.inHours > 0) {
                                  timeAgo = 'vor ${difference.inHours} Stunde${difference.inHours > 1 ? 'n' : ''}';
                                } else if (difference.inMinutes > 0) {
                                  timeAgo = 'vor ${difference.inMinutes} Minute${difference.inMinutes > 1 ? 'n' : ''}';
                                } else {
                                  timeAgo = 'gerade eben';
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.update,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.tertiary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Kurse zuletzt aktualisiert: $timeAgo\n${DateFormat('dd.MM.yyyy HH:mm').format(dateTime)} Uhr',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Keine Information über letzte Aktualisierung verfügbar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),


                        const SizedBox(height: 16),
// Wechselkurse
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
                                'Wechselkurse',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // EUR Bereich
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        getAdaptiveIcon(
                                          iconName: 'euro',
                                          defaultIcon: Icons.euro,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'EUR - Euro',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        // Linke Spalte: CHF → EUR
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '1 CHF =',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextFormField(
                                                controller: eurRateController,
                                                decoration: InputDecoration(
                                                  suffixText: 'EUR',
                                                  isDense: true,
                                                  filled: true,
                                                  fillColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                ),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,4}')),
                                                ],
                                                onChanged: (_) => setState(() {}),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Mitte: Pfeile
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.swap_horiz,
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                                size: 24,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Rechte Spalte: EUR → CHF
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '1 EUR =',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  eurRateController.text.isEmpty
                                                      ? '- CHF'
                                                      : '${(1 / parseControllerValue(eurRateController)).toStringAsFixed(4)} CHF',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.secondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // USD Bereich
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        getAdaptiveIcon(
                                          iconName: 'attach_money',
                                          defaultIcon: Icons.attach_money,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'USD - US-Dollar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        // Linke Spalte: CHF → USD
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '1 CHF =',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextFormField(
                                                controller: usdRateController,
                                                decoration: InputDecoration(
                                                  suffixText: 'USD',
                                                  isDense: true,
                                                  filled: true,
                                                  fillColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                ),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,4}')),
                                                ],
                                                onChanged: (_) => setState(() {}),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Mitte: Pfeile
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.swap_horiz,
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                                size: 24,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Rechte Spalte: USD → CHF
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '1 USD =',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  usdRateController.text.isEmpty
                                                      ? '- CHF'
                                                      : '${(1 / double.parse(usdRateController.text.replaceAll(',', '.'))).toStringAsFixed(4)} CHF',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                  ),
                                                ),
                                              ],
                                            ),
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
                        const SizedBox(height: 16),

                        // Umrechnungstabelle
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Umrechnungsübersicht',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Tabelle
                              Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(1),
                                  1: FlexColumnWidth(1),
                                },
                                children: [
                                  // Header
                                  TableRow(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Von CHF',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Nach CHF',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // EUR Zeile - KORREKT
                                  _buildCurrencyRow(
                                    '100 CHF',
                                    eurRateController.text.isEmpty
                                        ? '- EUR'
                                        : '${convertFromCHF(100, parseControllerValue(eurRateController)).toStringAsFixed(2)} EUR',
                                    '100 EUR',
                                    eurRateController.text.isEmpty
                                        ? '- CHF'
                                        : '${convertToCHF(100, parseControllerValue(eurRateController)).toStringAsFixed(2)} CHF',
                                  ),

// USD Zeile - KORRIGIERT
                                  _buildCurrencyRow(
                                    '100 CHF',
                                    usdRateController.text.isEmpty
                                        ? '- USD'
                                        : '${convertFromCHF(100, parseControllerValue(usdRateController)).toStringAsFixed(2)} USD',
                                    '100 USD',
                                    usdRateController.text.isEmpty
                                        ? '- CHF'
                                        : '${convertToCHF(100, parseControllerValue(usdRateController)).toStringAsFixed(2)} CHF',
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Erweiterte Beispiele
                              Text(
                                'Weitere Beispiele:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // 1000er Beispiele
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '1\'000 CHF = ${convertFromCHF(1000, parseControllerValue(eurRateController)).toStringAsFixed(2)} EUR',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    '1\'000 EUR = ${convertToCHF(1000, parseControllerValue(eurRateController)).toStringAsFixed(2)} CHF',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '1\'000 CHF = ${convertFromCHF(1000, parseControllerValue(usdRateController)).toStringAsFixed(2)} USD',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    '1\'000 USD = ${convertToCHF(1000, parseControllerValue(usdRateController)).toStringAsFixed(2)} CHF',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Quelle
                        Center(
                          child: Text(
                            'Quelle: Frankfurter API (Europäische Zentralbank)',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
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
                        // Kurse abrufen Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              // Speichere den BuildContext vor dem Navigator.pop
                              final parentContext = context;

                              // Führe den API-Aufruf aus OHNE den Dialog zu schließen
                              await _fetchLatestExchangeRates(
                                parentContext,
                                exchangeRatesNotifier,
                              );

                              // Aktualisiere die Controller mit den neuen Werten
                              eurRateController.text = exchangeRatesNotifier.value['EUR']!.toString();
                              usdRateController.text = exchangeRatesNotifier.value['USD']!.toString();

                              // Trigger ein Rebuild des Dialogs
                              setState(() {});
                            },
                            icon: getAdaptiveIcon(
                              iconName: 'refresh',
                              defaultIcon: Icons.refresh,
                            ),
                            label: const Text('Aktuelle Kurse'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Übernehmen Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              try {
                                double eurRate = double.parse(
                                  eurRateController.text.replaceAll(',', '.'),
                                );
                                double usdRate = double.parse(
                                  usdRateController.text.replaceAll(',', '.'),
                                );

                                if (eurRate <= 0 || usdRate <= 0) {
                                  throw Exception('Kurse müssen positiv sein');
                                }

                                // Aktualisiere die Werte
                                exchangeRatesNotifier.value = {
                                  'CHF': 1.0,
                                  'EUR': eurRate,
                                  'USD': usdRate,
                                };
                                currencyNotifier.value = currentCurrency;

                                // Speichere über Callback
                                onSave();

                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Währung auf $currentCurrency umgestellt',
                                    ),
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
                            icon: getAdaptiveIcon(
                              iconName: 'check',
                              defaultIcon: Icons.check,
                            ),
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

  static TableRow _buildCurrencyRow(
      String fromLabel,
      String fromValue,
      String toLabel,
      String toValue,
      ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fromLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '= $fromValue',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                toLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '= $toValue',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> _fetchLatestExchangeRates(
      BuildContext context,
      ValueNotifier<Map<String, double>> exchangeRatesNotifier,
      ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktuelle Wechselkurse werden abgerufen...'),
          duration: Duration(seconds: 1),
        ),
      );

      final response = await http.get(
        Uri.parse('https://api.frankfurter.app/latest?from=CHF&to=EUR,USD'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        exchangeRatesNotifier.value = {
          'CHF': 1.0,
          'EUR': rates['EUR'] as double,
          'USD': rates['USD'] as double,
        };

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wechselkurse aktualisiert (Stand: ${data['date']})'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Fehler beim Abrufen der Wechselkurse');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Abrufen der Wechselkurse: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


}