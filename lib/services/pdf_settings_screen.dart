// File: lib/home/pdf_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../customers/customer.dart';
import '../customers/customer_cache_service.dart';
import '../services/icon_helper.dart';

/// Enum für die Adressanzeige-Optionen
enum AddressDisplayMode {
  both,           // Beide Adressen anzeigen (wenn unterschiedlich)
  billingOnly,    // Nur Rechnungsadresse
  shippingOnly,   // Nur Lieferadresse
}

class PdfSettingsScreen extends StatefulWidget {
  const PdfSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PdfSettingsScreen> createState() => _PdfSettingsScreenState();
}

class _PdfSettingsScreenState extends State<PdfSettingsScreen> {
  bool _isLoading = true;

  // Lieferschein Einstellungen
  double _deliveryNoteAddressEmailSpacing = 6.0;

  // NEU: Adressanzeige-Einstellungen pro Dokumenttyp
  AddressDisplayMode _quoteAddressMode = AddressDisplayMode.both;
  AddressDisplayMode _invoiceAddressMode = AddressDisplayMode.both;
  AddressDisplayMode _commercialInvoiceAddressMode = AddressDisplayMode.both;
  AddressDisplayMode _deliveryNoteAddressMode = AddressDisplayMode.shippingOnly;
  AddressDisplayMode _packingListAddressMode = AddressDisplayMode.shippingOnly;

  // NEU: Test-Kunde für Vorschau
  Customer? _testCustomer;
  bool _isLoadingCustomer = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _deliveryNoteAddressEmailSpacing =
              (data['delivery_note_address_email_spacing'] as num?)?.toDouble() ?? 6.0;

          // Adressanzeige-Einstellungen laden
          _quoteAddressMode = _parseAddressMode(data['quote_address_mode']);
          _invoiceAddressMode = _parseAddressMode(data['invoice_address_mode']);
          _commercialInvoiceAddressMode = _parseAddressMode(data['commercial_invoice_address_mode']);
          _deliveryNoteAddressMode = _parseAddressMode(data['delivery_note_address_mode'], defaultMode: AddressDisplayMode.shippingOnly);
          _packingListAddressMode = _parseAddressMode(data['packing_list_address_mode'], defaultMode: AddressDisplayMode.shippingOnly);
        });
      }
    } catch (e) {
      print('Fehler beim Laden der PDF-Einstellungen: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  AddressDisplayMode _parseAddressMode(String? value, {AddressDisplayMode defaultMode = AddressDisplayMode.both}) {
    if (value == null) return defaultMode;
    switch (value) {
      case 'both':
        return AddressDisplayMode.both;
      case 'billing_only':
        return AddressDisplayMode.billingOnly;
      case 'shipping_only':
        return AddressDisplayMode.shippingOnly;
      default:
        return defaultMode;
    }
  }

  String _addressModeToString(AddressDisplayMode mode) {
    switch (mode) {
      case AddressDisplayMode.both:
        return 'both';
      case AddressDisplayMode.billingOnly:
        return 'billing_only';
      case AddressDisplayMode.shippingOnly:
        return 'shipping_only';
    }
  }

  Future<void> _saveSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_settings')
          .set({
        'delivery_note_address_email_spacing': _deliveryNoteAddressEmailSpacing,
        // Adressanzeige-Einstellungen speichern
        'quote_address_mode': _addressModeToString(_quoteAddressMode),
        'invoice_address_mode': _addressModeToString(_invoiceAddressMode),
        'commercial_invoice_address_mode': _addressModeToString(_commercialInvoiceAddressMode),
        'delivery_note_address_mode': _addressModeToString(_deliveryNoteAddressMode),
        'packing_list_address_mode': _addressModeToString(_packingListAddressMode),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Einstellungen gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Speichern der PDF-Einstellungen: $e');
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

  /// Öffnet den Kundenwähler-Dialog
  Future<void> _selectTestCustomer() async {
    final customerCache = CustomerCacheService();

    // Stelle sicher, dass der Cache initialisiert ist
    if (!customerCache.isInitialized) {
      setState(() => _isLoadingCustomer = true);
      await customerCache.initialize();
      setState(() => _isLoadingCustomer = false);
    }

    if (!mounted) return;

    final selected = await showDialog<Customer>(
      context: context,
      builder: (context) => _CustomerSelectionDialog(
        customers: customerCache.customers,
      ),
    );

    if (selected != null) {
      setState(() {
        _testCustomer = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Einstellungen'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: getAdaptiveIcon(
                iconName: 'save',
                defaultIcon: Icons.save,
                size: 18,
              ),
              label: const Text('Speichern'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info-Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'info',
                    defaultIcon: Icons.info,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hier kannst du die Abstände, Positionierungen und Adressanzeigen in den PDF-Dokumenten anpassen.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // NEU: Adressanzeige-Einstellungen Sektion
            _buildSectionHeader(
              context,
              'Adressanzeige in PDFs',
              Icons.location_on,
            ),

            const SizedBox(height: 8),

            // Erklärungstext
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lege fest, welche Adresse(n) im Kopf der verschiedenen Dokumenttypen angezeigt werden sollen. '
                          'Bei "Beides" werden beide Adressen nebeneinander angezeigt, wenn der Kunde unterschiedliche Liefer- und Rechnungsadressen hat.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Adress-Einstellungen pro Dokumenttyp
            _buildAddressModeCard(
              context,
              title: 'Offerte / Angebot',
              icon: Icons.description,
              mode: _quoteAddressMode,
              onChanged: (mode) => setState(() => _quoteAddressMode = mode),
            ),

            _buildAddressModeCard(
              context,
              title: 'Rechnung',
              icon: Icons.receipt_long,
              mode: _invoiceAddressMode,
              onChanged: (mode) => setState(() => _invoiceAddressMode = mode),
            ),

            _buildAddressModeCard(
              context,
              title: 'Handelsrechnung',
              icon: Icons.account_balance,
              mode: _commercialInvoiceAddressMode,
              onChanged: (mode) => setState(() => _commercialInvoiceAddressMode = mode),
            ),

            _buildAddressModeCard(
              context,
              title: 'Lieferschein',
              icon: Icons.local_shipping,
              mode: _deliveryNoteAddressMode,
              onChanged: null, // NEU: null = deaktiviert
              disabledHint: 'Fenstertaschen-Layout', // NEU
            ),

            _buildAddressModeCard(
              context,
              title: 'Packliste',
              icon: Icons.inventory_2,
              mode: _packingListAddressMode,
              onChanged: (mode) => setState(() => _packingListAddressMode = mode),
            ),

            const SizedBox(height: 32),

            // Testkunde auswählen
            _buildSectionHeader(
              context,
              'Vorschau mit Testkunde',
              Icons.person_search,
            ),

            const SizedBox(height: 16),

            _buildTestCustomerSection(context),

            const SizedBox(height: 32),

            // Lieferschein Sektion (bestehend)
            _buildSectionHeader(
              context,
              'Lieferschein - Abstände',
              Icons.local_shipping,
            ),

            const SizedBox(height: 16),

            // Abstand Adresse - Email
            _buildSpacingControl(
              context,
              title: 'Abstand: Land → E-Mail',
              subtitle: 'Abstand zwischen Länderzeile und Kontaktdaten',
              value: _deliveryNoteAddressEmailSpacing,
              min: 0,
              max: 100,
              onChanged: (value) {
                setState(() {
                  _deliveryNoteAddressEmailSpacing = value;
                });
              },
            ),

            const SizedBox(height: 32),

            // Vorschau-Bereich
            _buildPreviewSection(context),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressModeCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required AddressDisplayMode mode,
        ValueChanged<AddressDisplayMode>? onChanged,
        String? disabledHint,
      }) {
    final bool isDisabled = onChanged == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDisabled
                    ? Colors.grey.shade200
                    : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDisabled
                    ? Colors.grey.shade500
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDisabled ? Colors.grey.shade600 : null,
                    ),
                  ),
                  if (disabledHint != null && isDisabled)
                    Text(
                      disabledHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            isDisabled
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Nur Lieferadresse',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            )
                : DropdownButton<AddressDisplayMode>(
              value: mode,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(8),
              items: const [
                DropdownMenuItem(
                  value: AddressDisplayMode.both,
                  child: Text('Beides'),
                ),
                DropdownMenuItem(
                  value: AddressDisplayMode.billingOnly,
                  child: Text('Nur Rechnungsadresse'),
                ),
                DropdownMenuItem(
                  value: AddressDisplayMode.shippingOnly,
                  child: Text('Nur Lieferadresse'),
                ),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCustomerSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _testCustomer != null
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _testCustomer!.company.isNotEmpty
                            ? _testCustomer!.company
                            : _testCustomer!.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _testCustomer!.hasDifferentShippingAddress
                            ? '✓ Hat abweichende Lieferadresse'
                            : '○ Keine abweichende Lieferadresse',
                        style: TextStyle(
                          fontSize: 12,
                          color: _testCustomer!.hasDifferentShippingAddress
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  )
                      : Text(
                    'Kein Testkunde ausgewählt',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoadingCustomer ? null : _selectTestCustomer,
                  icon: _isLoadingCustomer
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.person_search, size: 18),
                  label: Text(_testCustomer != null ? 'Ändern' : 'Auswählen'),
                ),
              ],
            ),

            // Adress-Vorschau wenn Kunde ausgewählt
            if (_testCustomer != null) ...[
              const Divider(height: 24),
              _buildAddressPreviewGrid(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressPreviewGrid(BuildContext context) {
    if (_testCustomer == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Adress-Vorschau:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 12),

        // Rechnungsadresse
        _buildAddressPreviewBox(
          context,
          title: 'Rechnungsadresse',
          icon: Icons.receipt,
          lines: [
            if (_testCustomer!.company.isNotEmpty) _testCustomer!.company,
            if (_testCustomer!.fullName.isNotEmpty) _testCustomer!.fullName,
            '${_testCustomer!.street} ${_testCustomer!.houseNumber}'.trim(),
            ..._testCustomer!.additionalAddressLines.where((l) => l.isNotEmpty),
            '${_testCustomer!.zipCode} ${_testCustomer!.city}'.trim(),
            if (_testCustomer!.province?.isNotEmpty == true) _testCustomer!.province!,
            _testCustomer!.country,
          ],
        ),

        const SizedBox(height: 12),

        // Lieferadresse
        _buildAddressPreviewBox(
          context,
          title: 'Lieferadresse',
          icon: Icons.local_shipping,
          isDifferent: _testCustomer!.hasDifferentShippingAddress,
          lines: _testCustomer!.hasDifferentShippingAddress
              ? [
            if (_testCustomer!.shippingCompany?.isNotEmpty == true)
              _testCustomer!.shippingCompany!,
            if (_testCustomer!.shippingRecipientName.isNotEmpty)
              _testCustomer!.shippingRecipientName,
            '${_testCustomer!.shippingStreet ?? ''} ${_testCustomer!.shippingHouseNumber ?? ''}'.trim(),
            ..._testCustomer!.shippingAdditionalAddressLines.where((l) => l.isNotEmpty),
            '${_testCustomer!.shippingZipCode ?? ''} ${_testCustomer!.shippingCity ?? ''}'.trim(),
            if (_testCustomer!.shippingProvince?.isNotEmpty == true)
              _testCustomer!.shippingProvince!,
            _testCustomer!.shippingCountry ?? '',
          ]
              : ['(Identisch mit Rechnungsadresse)'],
        ),
      ],
    );
  }

  Widget _buildAddressPreviewBox(
      BuildContext context, {
        required String title,
        required IconData icon,
        required List<String> lines,
        bool isDifferent = true,
      }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDifferent
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDifferent
              ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...lines.where((l) => l.isNotEmpty).map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 11,
                color: isDifferent
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.grey.shade600,
                fontStyle: isDifferent ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: getAdaptiveIcon(
            iconName: title.toLowerCase().replaceAll(' ', '_'),
            defaultIcon: icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSpacingControl(
      BuildContext context, {
        required String title,
        required String subtitle,
        required double value,
        required double min,
        required double max,
        required ValueChanged<double> onChanged,
      }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Minus Button (groß)
                _buildStepButton(
                  context,
                  icon: Icons.remove,
                  onPressed: value > min
                      ? () => onChanged((value - 10).clamp(min, max))
                      : null,
                  label: '-10',
                ),
                const SizedBox(width: 8),

                // Minus Button (klein)
                _buildStepButton(
                  context,
                  icon: Icons.remove,
                  onPressed: value > min
                      ? () => onChanged((value - 1).clamp(min, max))
                      : null,
                  label: '-1',
                  isSmall: true,
                ),

                // Wert-Anzeige
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${value.toStringAsFixed(0)} px',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),

                // Plus Button (klein)
                _buildStepButton(
                  context,
                  icon: Icons.add,
                  onPressed: value < max
                      ? () => onChanged((value + 1).clamp(min, max))
                      : null,
                  label: '+1',
                  isSmall: true,
                ),
                const SizedBox(width: 8),

                // Plus Button (groß)
                _buildStepButton(
                  context,
                  icon: Icons.add,
                  onPressed: value < max
                      ? () => onChanged((value + 10).clamp(min, max))
                      : null,
                  label: '+10',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              label: '${value.toStringAsFixed(0)} px',
              onChanged: onChanged,
            ),

            // Reset Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onChanged(6.0), // Standard-Wert
                icon: getAdaptiveIcon(
                  iconName: 'refresh',
                  defaultIcon: Icons.refresh,
                  size: 16,
                ),
                label: const Text('Zurücksetzen (6 px)'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton(
      BuildContext context, {
        required IconData icon,
        required VoidCallback? onPressed,
        required String label,
        bool isSmall = false,
      }) {
    return Column(
      children: [
        SizedBox(
          width: isSmall ? 40 : 48,
          height: isSmall ? 40 : 48,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: isSmall
                  ? Theme.of(context).colorScheme.surfaceVariant
                  : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: isSmall
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onPrimaryContainer,
              elevation: isSmall ? 0 : 1,
            ),
            child: Icon(icon, size: isSmall ? 18 : 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'preview',
                  defaultIcon: Icons.preview,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Abstand-Vorschau (Lieferschein)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Simulated Address Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _testCustomer?.company.isNotEmpty == true
                        ? _testCustomer!.company
                        : 'Musterfirma GmbH',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF37474F),
                    ),
                  ),
                  Text(
                    _testCustomer?.fullName.isNotEmpty == true
                        ? _testCustomer!.fullName
                        : 'Max Mustermann',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                  ),
                  Text(
                    _testCustomer != null
                        ? '${_testCustomer!.street} ${_testCustomer!.houseNumber}'.trim()
                        : 'Musterstraße 123',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B)),
                  ),
                  Text(
                    _testCustomer != null
                        ? '${_testCustomer!.zipCode} ${_testCustomer!.city}'.trim()
                        : '12345 Musterstadt',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B)),
                  ),
                  Text(
                    _testCustomer?.country ?? 'Deutschland',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B)),
                  ),

                  // Dynamischer Abstand
                  SizedBox(height: _deliveryNoteAddressEmailSpacing),

                  // Kontaktdaten
                  Row(
                    children: [
                      Text(
                        'E-Mail:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _testCustomer?.email ?? 'info@musterfirma.de',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF607D8B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Tel.:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _testCustomer?.phone1 ?? '+49 123 456789',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF607D8B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Abstandsanzeige
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  getAdaptiveIcon(
                    iconName: 'straighten',
                    defaultIcon: Icons.straighten,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Aktueller Abstand: ${_deliveryNoteAddressEmailSpacing.toStringAsFixed(0)} px',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog zur Kundenauswahl
class _CustomerSelectionDialog extends StatefulWidget {
  final List<Customer> customers;

  const _CustomerSelectionDialog({required this.customers});

  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  String _searchQuery = '';
  bool _onlyWithDifferentAddress = false;

  List<Customer> get _filteredCustomers {
    var list = widget.customers;

    // Filter: nur mit abweichender Adresse
    if (_onlyWithDifferentAddress) {
      list = list.where((c) => c.hasDifferentShippingAddress).toList();
    }

    // Suchfilter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((c) =>
      c.company.toLowerCase().contains(query) ||
          c.fullName.toLowerCase().contains(query) ||
          c.city.toLowerCase().contains(query) ||
          c.email.toLowerCase().contains(query)
      ).toList();
    }

    // Sortieren nach Firma/Name
    list.sort((a, b) {
      final aName = a.company.isNotEmpty ? a.company : a.fullName;
      final bName = b.company.isNotEmpty ? b.company : b.fullName;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCustomers;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.person_search),
                  const SizedBox(width: 8),
                  const Text(
                    'Testkunde auswählen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Suchfeld
              TextField(
                decoration: InputDecoration(
                  hintText: 'Suchen...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),

              const SizedBox(height: 8),

              // Filter-Checkbox
              CheckboxListTile(
                title: const Text('Nur Kunden mit abweichender Lieferadresse'),
                subtitle: const Text('Zum Testen der Zwei-Adressen-Ansicht'),
                value: _onlyWithDifferentAddress,
                onChanged: (value) => setState(() => _onlyWithDifferentAddress = value ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              const Divider(),

              // Kundenliste
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Text(
                    'Keine Kunden gefunden',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
                    : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: customer.hasDifferentShippingAddress
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          customer.hasDifferentShippingAddress
                              ? Icons.alt_route
                              : Icons.person,
                          color: customer.hasDifferentShippingAddress
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        customer.company.isNotEmpty
                            ? customer.company
                            : customer.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${customer.city}${customer.hasDifferentShippingAddress ? ' • Abw. Lieferadresse' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () => Navigator.of(context).pop(customer),
                    );
                  },
                ),
              ),

              // Info
              const SizedBox(height: 8),
              Text(
                '${filtered.length} Kunden${_onlyWithDifferentAddress ? ' mit abweichender Adresse' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Hilfsfunktion zum Laden der Einstellung (für andere Dateien)
// ============================================================================

class PdfSettingsHelper {
  static Future<Map<String, dynamic>> loadPdfSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_settings')
          .get();

      if (doc.exists) {
        return doc.data() ?? {};
      }
    } catch (e) {
      print('Fehler beim Laden der PDF-Einstellungen: $e');
    }

    // Standard-Werte
    return {
      'delivery_note_address_email_spacing': 6.0,
      'quote_address_mode': 'both',
      'invoice_address_mode': 'both',
      'commercial_invoice_address_mode': 'both',
      'delivery_note_address_mode': 'shipping_only',
      'packing_list_address_mode': 'shipping_only',
    };
  }

  static Future<double> getDeliveryNoteAddressEmailSpacing() async {
    final settings = await loadPdfSettings();
    return (settings['delivery_note_address_email_spacing'] as num?)?.toDouble() ?? 6.0;
  }

  /// Gibt den Adressanzeige-Modus für einen bestimmten Dokumenttyp zurück
  static Future<String> getAddressDisplayMode(String documentType) async {
    final settings = await loadPdfSettings();
    final key = '${documentType}_address_mode';

    // Standard-Werte pro Dokumenttyp
    final defaults = {
      'quote': 'both',
      'invoice': 'both',
      'commercial_invoice': 'both',
      'delivery_note': 'shipping_only',
      'packing_list': 'shipping_only',
    };

    return settings[key]?.toString() ?? defaults[documentType] ?? 'both';
  }

  /// Prüft ob beide Adressen angezeigt werden sollen
  static Future<bool> shouldShowBothAddresses(String documentType) async {
    final mode = await getAddressDisplayMode(documentType);
    return mode == 'both';
  }

  /// Prüft ob nur die Rechnungsadresse angezeigt werden soll
  static Future<bool> shouldShowBillingOnly(String documentType) async {
    final mode = await getAddressDisplayMode(documentType);
    return mode == 'billing_only';
  }

  /// Prüft ob nur die Lieferadresse angezeigt werden soll
  static Future<bool> shouldShowShippingOnly(String documentType) async {
    final mode = await getAddressDisplayMode(documentType);
    return mode == 'shipping_only';
  }
}