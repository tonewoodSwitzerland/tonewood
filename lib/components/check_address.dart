// File: lib/home/check_address.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';

class CheckAddressSheet {
  static void show(BuildContext context) async {
    // Lade den temporären Kunden
    final tempCustomerDoc = await FirebaseFirestore.instance
        .collection('temporary_customer')
        .limit(1)
        .get();

    if (tempCustomerDoc.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kein Kunde ausgewählt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final customerData = tempCustomerDoc.docs.first.data();
    final customerId = tempCustomerDoc.docs.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CheckAddressContent(
        customerData: customerData,
        customerId: customerId,
      ),
    );
  }
}

class _CheckAddressContent extends StatefulWidget {
  final Map<String, dynamic> customerData;
  final String customerId;

  const _CheckAddressContent({
    required this.customerData,
    required this.customerId,
  });

  @override
  State<_CheckAddressContent> createState() => _CheckAddressContentState();
}

class _CheckAddressContentState extends State<_CheckAddressContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, TextEditingController> _shippingControllers;
  bool _hasDifferentShippingAddress = false;
  List<TextEditingController> shippingAdditionalAddressLines = [];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hasDifferentShippingAddress = widget.customerData['hasDifferentShippingAddress'] ?? false;
    _initializeControllers();
  }

  void _initializeControllers() {
    // Nur Lieferadresse Controller
    _shippingControllers = {
      'shippingCompany': TextEditingController(
          text: widget.customerData['shippingCompany'] ?? widget.customerData['company'] ?? ''
      ),
      'shippingFirstName': TextEditingController(
          text: widget.customerData['shippingFirstName'] ?? widget.customerData['firstName'] ?? ''
      ),
      'shippingLastName': TextEditingController(
          text: widget.customerData['shippingLastName'] ?? widget.customerData['lastName'] ?? ''
      ),
      'shippingStreet': TextEditingController(
          text: widget.customerData['shippingStreet'] ?? widget.customerData['street'] ?? ''
      ),
      'shippingHouseNumber': TextEditingController(
          text: widget.customerData['shippingHouseNumber'] ?? widget.customerData['houseNumber'] ?? ''
      ),
      'shippingZipCode': TextEditingController(
          text: widget.customerData['shippingZipCode'] ?? widget.customerData['zipCode'] ?? ''
      ),
      'shippingCity': TextEditingController(
          text: widget.customerData['shippingCity'] ?? widget.customerData['city'] ?? ''
      ),
      'shippingProvince': TextEditingController( // NEU
          text: widget.customerData['shippingProvince'] ?? widget.customerData['province'] ?? ''
      ),
      'shippingCountry': TextEditingController(
          text: widget.customerData['shippingCountry'] ?? widget.customerData['country'] ?? ''
      ),
      'shippingEmail': TextEditingController(
          text: widget.customerData['shippingEmail'] ?? widget.customerData['email'] ?? ''
      ),
      'shippingPhone': TextEditingController(
          text: widget.customerData['shippingPhone'] ?? widget.customerData['phone1'] ?? ''
      ),
      'shippingEoriNumber': TextEditingController(
          text: widget.customerData['shippingEoriNumber'] ?? widget.customerData['eoriNumber'] ?? ''
      ),
      'shippingVatNumber': TextEditingController(
          text: widget.customerData['shippingVatNumber'] ?? widget.customerData['vatNumber'] ?? ''
      ),
    };
    // NEU: Zusätzliche Adresszeilen aus customerData laden
    if (widget.customerData['shippingAdditionalAddressLines'] != null) {
      final lines = widget.customerData['shippingAdditionalAddressLines'] as List;
      shippingAdditionalAddressLines = lines
          .map((line) => TextEditingController(text: line.toString()))
          .toList();
    } else if (widget.customerData['additionalAddressLines'] != null) {
      // Fallback auf normale Adresszeilen wenn keine Lieferadress-Zeilen existieren
      final lines = widget.customerData['additionalAddressLines'] as List;
      shippingAdditionalAddressLines = lines
          .map((line) => TextEditingController(text: line.toString()))
          .toList();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shippingControllers.forEach((_, controller) => controller.dispose());

    // NEU: Zusätzliche Adresszeilen aufräumen
    for (var controller in shippingAdditionalAddressLines) {
      controller.dispose();
    }


    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    iconName: 'location_on',
                    defaultIcon: Icons.location_on,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Adressen überprüfen',
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

          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'receipt',
                      defaultIcon: Icons.receipt,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Rechnungsadresse'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'local_shipping',
                      defaultIcon: Icons.local_shipping,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Lieferadresse'),
                  ],
                ),
              ),
            ],
          ),

          Divider(height: 1),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBillingAddressTab(),
                _buildShippingAddressTab(),
              ],
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
                    child: ElevatedButton.icon(
                      onPressed: _saveAddresses,
                      icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save),
                      label: const Text('Für diesen Auftrag speichern'),
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

  Widget _buildBillingAddressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.error.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              getAdaptiveIcon(iconName: 'info', defaultIcon:
                Icons.info,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Rechnungsadresse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Die Rechnungsadresse kann nur im Kundenbereich geändert werden.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Aktuelle Rechnungsadresse anzeigen
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktuelle Rechnungsadresse:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.customerData['company'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (widget.customerData['firstName'] != null || widget.customerData['lastName'] != null)
                      Text('${widget.customerData['firstName'] ?? ''} ${widget.customerData['lastName'] ?? ''}'.trim()),
                    Text('${widget.customerData['street'] ?? ''} ${widget.customerData['houseNumber'] ?? ''}'.trim()),

                    // NEU: Zusätzliche Adresszeilen anzeigen
                    if (widget.customerData['additionalAddressLines'] != null)
                      ...(widget.customerData['additionalAddressLines'] as List).map((line) =>
                          Text(line.toString())
                      ).toList(),

                    Text('${widget.customerData['zipCode'] ?? ''} ${widget.customerData['city'] ?? ''}'.trim()),
                    // NEU: Provinz anzeigen
                    if (widget.customerData['province']?.toString().trim().isNotEmpty == true)
                      Text(widget.customerData['province']),

                    if (widget.customerData['country'] != null)
                      Text(widget.customerData['country']),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShippingAddressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warnung
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                getAdaptiveIcon(iconName: 'warning', defaultIcon:
                  Icons.warning,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temporäre Änderung',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Die Lieferadresse wird nur für dieses Angebot geändert. Für dauerhafte Änderungen nutze bitte den Kundenbereich.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Checkbox für abweichende Lieferadresse
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CheckboxListTile(
              title: const Text('Abweichende Lieferadresse'),
              subtitle: const Text('Aktiviere diese Option, wenn die Lieferadresse von der Rechnungsadresse abweicht'),
              value: _hasDifferentShippingAddress,
              onChanged: (value) {
                setState(() {
                  _hasDifferentShippingAddress = value ?? false;
                  if (!_hasDifferentShippingAddress) {
                    // Kopiere Rechnungsadresse zu Lieferadresse
                    _copyBillingToShipping();
                  }
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (_hasDifferentShippingAddress) ...[
            _buildSectionTitle('Unternehmensdaten'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _shippingControllers['shippingCompany']!,
              label: 'Firma',
              icon: Icons.business,
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Kontaktperson'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _shippingControllers['shippingFirstName']!,
                    label: 'Vorname',
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _shippingControllers['shippingLastName']!,
                    label: 'Nachname',
                    icon: Icons.person,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Adresse'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _shippingControllers['shippingStreet']!,
                    label: 'Straße',
                    icon: Icons.home,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _shippingControllers['shippingHouseNumber']!,
                    label: 'Nr.',
                    icon: Icons.numbers,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

// NEU: Zusätzliche Adresszeilen
            _buildAddressLinesSection(),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _shippingControllers['shippingZipCode']!,
                    label: 'PLZ',
                    icon: Icons.location_on,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _shippingControllers['shippingCity']!,
                    label: 'Ort',
                    icon: Icons.location_city,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // NEU: Provinz
            _buildTextField(
              controller: _shippingControllers['shippingProvince']!,
              label: 'Provinz/Bundesland/Kanton',
              icon: Icons.map,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _shippingControllers['shippingCountry']!,
              label: 'Land',
              icon: Icons.flag,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Kontaktdaten'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _shippingControllers['shippingEmail']!,
              label: 'E-Mail',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _shippingControllers['shippingPhone']!,
              label: 'Telefon',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Zusätzliche Informationen'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _shippingControllers['shippingEoriNumber']!,
              label: 'EORI-Nummer',
              icon: Icons.badge,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _shippingControllers['shippingVatNumber']!,
              label: 'MwSt-Nummer',
              icon: Icons.receipt_long,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  getAdaptiveIcon(iconName: 'info', defaultIcon:
                    Icons.info,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Die Lieferadresse entspricht der Rechnungsadresse',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildAddressLinesSection() {
    return Column(
      children: [
        ...shippingAdditionalAddressLines.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: controller,
                    label: 'Adresszeile ${index + 1}',
                    icon: Icons.notes,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      controller.dispose();
                      shippingAdditionalAddressLines.removeAt(index);
                    });
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: getAdaptiveIcon(
                      iconName: 'delete',
                      defaultIcon: Icons.delete,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                  ),
                  tooltip: 'Zeile entfernen',
                ),
              ],
            ),
          );
        }).toList(),

        // Button zum Hinzufügen weiterer Zeilen
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              shippingAdditionalAddressLines.add(TextEditingController());
            });
          },
          icon: getAdaptiveIcon(
            iconName: 'add',
            defaultIcon: Icons.add,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          label: const Text('Weitere Zeile hinzufügen'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  })
  {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14),
          prefixIcon: getAdaptiveIcon(iconName: icon.toString(), defaultIcon: icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  void _copyBillingToShipping() {
    _shippingControllers['shippingCompany']!.text = widget.customerData['company'] ?? '';
    _shippingControllers['shippingFirstName']!.text = widget.customerData['firstName'] ?? '';
    _shippingControllers['shippingLastName']!.text = widget.customerData['lastName'] ?? '';
    _shippingControllers['shippingStreet']!.text = widget.customerData['street'] ?? '';
    _shippingControllers['shippingHouseNumber']!.text = widget.customerData['houseNumber'] ?? '';
    _shippingControllers['shippingZipCode']!.text = widget.customerData['zipCode'] ?? '';
    _shippingControllers['shippingCity']!.text = widget.customerData['city'] ?? '';
    _shippingControllers['shippingProvince']!.text = widget.customerData['province'] ?? ''; // NEU
    _shippingControllers['shippingCountry']!.text = widget.customerData['country'] ?? '';
    _shippingControllers['shippingEmail']!.text = widget.customerData['email'] ?? '';
    _shippingControllers['shippingPhone']!.text = widget.customerData['phone1'] ?? '';
    _shippingControllers['shippingEoriNumber']!.text = widget.customerData['eoriNumber'] ?? '';
    _shippingControllers['shippingVatNumber']!.text = widget.customerData['vatNumber'] ?? '';
    // NEU: Zusätzliche Adresszeilen auch kopieren
    shippingAdditionalAddressLines.clear();
    if (widget.customerData['additionalAddressLines'] != null) {
      final lines = widget.customerData['additionalAddressLines'] as List;
      shippingAdditionalAddressLines = lines
          .map((line) => TextEditingController(text: line.toString()))
          .toList();
    }

    setState(() {});

  }

  Future<void> _saveAddresses() async {
    try {
      // Erstelle das Update-Map nur für temporäre Änderungen
      Map<String, dynamic> updateData = {
        'hasDifferentShippingAddress': _hasDifferentShippingAddress,
      };

      // Füge Lieferadresse-Daten hinzu
      if (_hasDifferentShippingAddress) {
        _shippingControllers.forEach((key, controller) {
          updateData[key] = controller.text.trim();
        });
        // NEU: Zusätzliche Adresszeilen speichern
        updateData['shippingAdditionalAddressLines'] = shippingAdditionalAddressLines
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
      } else {
        // Lösche Lieferadresse-Felder wenn gleiche Adresse
        _shippingControllers.keys.forEach((key) {
          updateData[key] = FieldValue.delete();
        });
      }

      // Update NUR in temporary_customer - NICHT in der customers Collection
      await FirebaseFirestore.instance
          .collection('temporary_customer')
          .doc(widget.customerId)
          .update(updateData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lieferadresse wurde temporär aktualisiert'),
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
  }
}