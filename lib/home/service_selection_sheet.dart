import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:tonewood/home/service_management_screen.dart';
import '../services/icon_helper.dart';


class ServiceSelectionSheet {
  static void show(
      BuildContext context, {
        required Function(Map<String, dynamic>) onServiceSelected,
        required ValueNotifier<String> currencyNotifier,
        required ValueNotifier<Map<String, double>> exchangeRatesNotifier,
      }) {
    final searchController = TextEditingController();
    String searchQuery = '';

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
                        child: getAdaptiveIcon(iconName: 'engineering', defaultIcon: Icons.engineering),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Dienstleistung',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Hinzufügen Button
                      IconButton(
                        onPressed: () {
                          showAddServiceDialog(context);
                        },
                        icon: getAdaptiveIcon(
                          iconName: 'add_circle',
                          defaultIcon: Icons.add_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        tooltip: 'Neue Dienstleistung',
                      ),
                      IconButton(
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1),

                // Suchfeld
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Dienstleistung suchen...',
                      prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),

                // Liste der Dienstleistungen
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('services')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              getAdaptiveIcon(iconName: 'error',defaultIcon:Icons.error, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Fehler: ${snapshot.error}'),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final services = snapshot.data?.docs ?? [];

                      // Filter basierend auf Suchbegriff
                      final filteredServices = services.where((service) {
                        final data = service.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final description = (data['description'] ?? '').toString().toLowerCase();
                        return name.contains(searchQuery) || description.contains(searchQuery);
                      }).toList();

                      if (filteredServices.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              getAdaptiveIcon(iconName: 'engineering', defaultIcon:
                                Icons.engineering,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isEmpty
                                    ? 'Keine Dienstleistungen vorhanden'
                                    : 'Keine Dienstleistungen gefunden',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (searchQuery.isEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                   showAddServiceDialog(context);
                                  },
                                  icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
                                  label: const Text('Dienstleistung anlegen'),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredServices.length,
                        itemBuilder: (context, index) {
                          final service = filteredServices[index];
                          final data = service.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => _showServiceQuantityDialog(
                                context,
                                currencyNotifier,
                                exchangeRatesNotifier,
                                service.id,
                                data,
                                onServiceSelected,

                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: getAdaptiveIcon(
                                        iconName: 'engineering',
                                        defaultIcon: Icons.engineering,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['name'] ?? 'Unbenannte Dienstleistung',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (data['description'] != null && data['description'].isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              data['description'],
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: ValueListenableBuilder<String>(
                                        valueListenable: currencyNotifier,
                                        builder: (context, currency, child) {
                                          return ValueListenableBuilder<Map<String, double>>(
                                            valueListenable: exchangeRatesNotifier,
                                            builder: (context, rates, child) {
                                              final priceInCHF = (data['price_CHF'] ?? 0.0) as double;
                                              final displayPrice = currency != 'CHF'
                                                  ? priceInCHF * rates[currency]!
                                                  : priceInCHF;

                                              return Text(
                                                '${currency} ${displayPrice.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Footer mit Verwaltungs-Link
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
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ServicesManagementScreen(),
                          ),
                        );
                      },
                      icon: getAdaptiveIcon(iconName: 'settings', defaultIcon: Icons.settings),
                      label: const Text('Dienstleistungen verwalten'),
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

  static void showAddServiceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Neue Dienstleistung',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    hintText: 'z.B. Lohnbehandlung Thermo',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    border: OutlineInputBorder(),
                    hintText: 'Optionale Beschreibung der Dienstleistung',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Preis in CHF *',
                    border: OutlineInputBorder(),
                    suffixText: 'CHF',
                    hintText: '0.00',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty || priceController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bitte alle Pflichtfelder ausfüllen'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        try {
                          await FirebaseFirestore.instance.collection('services').add({
                            'name': nameController.text.trim(),
                            'description': descriptionController.text.trim(),
                            'price_CHF': double.parse(priceController.text.replaceAll(',', '.')),
                            'created_at': FieldValue.serverTimestamp(),
                            'updated_at': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dienstleistung wurde angelegt'),
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
    );
  }
  static void _showServiceQuantityDialog(
      BuildContext context,
      ValueNotifier<String> currencyNotifier,  // NEU
      ValueNotifier<Map<String, double>> exchangeRatesNotifier,  // NEU
      String serviceId,
      Map<String, dynamic> serviceData,
      Function(Map<String, dynamic>) onServiceSelected,

      ) {
    final quantityController = TextEditingController(text: '1');
    final selectedCurrency = currencyNotifier.value;
    final exchangeRates = exchangeRatesNotifier.value;

// Preis in ausgewählter Währung
    final priceInCHF = serviceData['price_CHF'] as double;
    final displayPrice = selectedCurrency != 'CHF'
        ? priceInCHF * exchangeRates[selectedCurrency]!
        : priceInCHF;

    final customPriceController = TextEditingController(
        text: displayPrice.toStringAsFixed(2)  // Angepasst
    );
    bool useCustomPrice = false;

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
                      Text(
                        serviceData['name'],
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
                      children: [
                        if (serviceData['description'] != null && serviceData['description'].isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              serviceData['description'],
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Anzahl',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofocus: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: useCustomPrice,
                              onChanged: (value) {
                                setState(() {
                                  useCustomPrice = value ?? false;
                                });
                              },
                            ),
                            const Text('Individueller Preis'),
                          ],
                        ),
                        if (useCustomPrice) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: customPriceController,
                            decoration: InputDecoration(
                              labelText: 'Preis pro Einheit (${selectedCurrency})',
                              border: const OutlineInputBorder(),
                              suffixText: selectedCurrency,
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Standardpreis:'),
                              Text(
                                '${selectedCurrency} ${displayPrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
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
                            onPressed: () {
                              final quantity = int.tryParse(quantityController.text) ?? 1;

                              // Preis berechnen und in CHF konvertieren
                              double price;
                              if (useCustomPrice) {
                                final enteredPrice = double.tryParse(customPriceController.text.replaceAll(',', '.')) ?? displayPrice;
                                price = selectedCurrency != 'CHF'
                                    ? enteredPrice / exchangeRates[selectedCurrency]!
                                    : enteredPrice;
                              } else {
                                price = priceInCHF;
                              }

                              final serviceForBasket = {
                                'service_id': serviceId,
                                'name': serviceData['name'],
                                'description': serviceData['description'] ?? '',
                                'quantity': quantity,
                                'unit': "Stück",
                                'price_per_unit': price,
                                'is_price_customized': useCustomPrice,
                                'is_service': true,
                                'timestamp': FieldValue.serverTimestamp(),
                              };

                              Navigator.pop(context);
                              Navigator.pop(context);
                              onServiceSelected(serviceForBasket);
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
          );
        },
      ),
    );
  }

}