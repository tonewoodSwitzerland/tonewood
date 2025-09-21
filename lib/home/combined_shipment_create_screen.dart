import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/icon_helper.dart';
import '../components/order_model.dart';
import '../services/combined_shipment_manager.dart';
import 'package:intl/intl.dart';

class CombinedShipmentCreateScreen extends StatefulWidget {
  const CombinedShipmentCreateScreen({Key? key}) : super(key: key);

  @override
  State<CombinedShipmentCreateScreen> createState() => _CombinedShipmentCreateScreenState();
}

class _CombinedShipmentCreateScreenState extends State<CombinedShipmentCreateScreen> {
  final Map<String, bool> _selectedOrders = {};
  final Map<String, OrderX> _ordersCache = {};

  // Lieferadresse
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _zipController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController(text: 'Schweiz');
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isCreating = false;

  @override
  void dispose() {
    _streetController.dispose();
    _houseNumberController.dispose();
    _zipController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neue Sammellieferung'),
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStepIndicator('1', 'Aufträge wählen', true),
                    Expanded(child: Container(height: 2, color: Colors.grey[300])),
                    _buildStepIndicator('2', 'Lieferadresse', _selectedOrders.values.any((v) => v)),
                    Expanded(child: Container(height: 2, color: Colors.grey[300])),
                    _buildStepIndicator('3', 'Erstellen', false),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Schritt 1: Aufträge auswählen
                  _buildSectionHeader('Schritt 1: Aufträge auswählen'),
                  const SizedBox(height: 16),

                  // Filter für offene Aufträge
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
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Es werden nur Aufträge mit Status "Ausstehend" oder "In Bearbeitung" angezeigt',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Auftragsliste
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('status', whereIn: ['pending', 'processing'])
                        .orderBy('orderDate', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final orders = snapshot.data!.docs;

                      if (orders.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              getAdaptiveIcon(
                                iconName: 'inbox',
                                defaultIcon: Icons.inbox,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Keine offenen Aufträge vorhanden',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: orders.map((doc) {
                          final order = OrderX.fromFirestore(doc);
                          _ordersCache[order.id] = order;

                          return _buildOrderSelectionCard(order);
                        }).toList(),
                      );
                    },
                  ),

                  // Schritt 2: Lieferadresse
                  if (_selectedOrders.values.any((v) => v)) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('Schritt 2: Gemeinsame Lieferadresse'),
                    const SizedBox(height: 16),

                    // Adressformular
                    _buildAddressForm(),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          if (_selectedOrders.values.any((v) => v))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedOrders.values.where((v) => v).length} Aufträge ausgewählt',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Gesamtwert: CHF ${_calculateTotalAmount().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isCreating || !_isFormValid() ? null : _createCombinedShipment,
                    child: _isCreating
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Sammellieferung erstellen'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String number, String label, bool isActive) {
    final color = isActive ? Theme.of(context).colorScheme.primary : Colors.grey;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isActive ? Colors.white : color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildOrderSelectionCard(OrderX order) {
    final isSelected = _selectedOrders[order.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            _selectedOrders[order.id] = value ?? false;
          });
        },
        title: Row(
          children: [
            Text(
              'Auftrag ${order.orderNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                order.customer['language'] ?? 'DE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              order.customer['company'] ?? order.customer['fullName'] ?? 'Unbekannter Kunde',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${order.customer['city'] ?? ''}, ${order.customer['countryCode'] ?? ''}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.items.length} Artikel',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'CHF ${(order.calculations['total'] as num? ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Straße',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _houseNumberController,
                decoration: const InputDecoration(
                  labelText: 'Nr.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _zipController,
                decoration: const InputDecoration(
                  labelText: 'PLZ',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Ort',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _countryController,
          decoration: const InputDecoration(
            labelText: 'Land',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactPersonController,
          decoration: const InputDecoration(
            labelText: 'Kontaktperson',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-Mail',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isFormValid() {
    return _selectedOrders.values.any((v) => v) &&
        _streetController.text.isNotEmpty &&
        _zipController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _countryController.text.isNotEmpty;
  }

  double _calculateTotalAmount() {
    double total = 0.0;
    _selectedOrders.forEach((orderId, isSelected) {
      if (isSelected && _ordersCache.containsKey(orderId)) {
        total += (_ordersCache[orderId]!.calculations['total'] as num? ?? 0).toDouble();
      }
    });
    return total;
  }

  Future<void> _createCombinedShipment() async {
    setState(() {
      _isCreating = true;
    });

    try {
      final selectedOrderIds = _selectedOrders.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final shipmentId = await CombinedShipmentManager.createCombinedShipment(
        orderIds: selectedOrderIds,
        shippingAddress: {
          'street': _streetController.text,
          'houseNumber': _houseNumberController.text,
          'zipCode': _zipController.text,
          'city': _cityController.text,
          'country': _countryController.text,
          'contactPerson': _contactPersonController.text,
          'phone': _phoneController.text,
          'email': _emailController.text,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sammellieferung $shipmentId wurde erstellt'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}