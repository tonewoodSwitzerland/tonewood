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

/// Enum für Spaltenausrichtung
enum ColumnAlignment {
  left,
  center,
  right,
}

/// Konstanten für PDF-Typen
class PdfDocumentType {
  static const String quote = 'quote';
  static const String invoice = 'invoice';
  static const String commercialInvoice = 'commercial_invoice';
  static const String deliveryNote = 'delivery_note';
  static const String packingList = 'packing_list';

  static const List<String> all = [
    quote,
    invoice,
    commercialInvoice,
    deliveryNote,
    packingList,
  ];

  static String getDisplayName(String type) {
    switch (type) {
      case quote:
        return 'Offerte';
      case invoice:
        return 'Rechnung';
      case commercialInvoice:
        return 'Handelsrechnung';
      case deliveryNote:
        return 'Lieferschein';
      case packingList:
        return 'Packliste';
      default:
        return type;
    }
  }

  static IconData getIcon(String type) {
    switch (type) {
      case quote:
        return Icons.description;
      case invoice:
        return Icons.receipt_long;
      case commercialInvoice:
        return Icons.account_balance;
      case deliveryNote:
        return Icons.local_shipping;
      case packingList:
        return Icons.inventory_2;
      default:
        return Icons.article;
    }
  }
}

/// Spalten-Definitionen pro PDF-Typ
class PdfColumnDefinitions {
  /// Spalten für Offerte/Rechnung/Handelsrechnung (mit Preisen)
  static const List<Map<String, String>> priceColumns = [
    {'key': 'product', 'label_de': 'Produkt', 'label_en': 'Product'},
    {'key': 'instrument', 'label_de': 'Instrument', 'label_en': 'Instrument'},
    {'key': 'quality', 'label_de': 'Qualität', 'label_en': 'Quality'},
    {'key': 'fsc', 'label_de': 'FSC®', 'label_en': 'FSC®'},
    {'key': 'origin', 'label_de': 'Ursprung', 'label_en': 'Origin'},
    {'key': 'thermal', 'label_de': '°C (Thermo)', 'label_en': '°C (Thermal)'},
    {'key': 'dimensions', 'label_de': 'Masse', 'label_en': 'Dimensions'},
    {'key': 'parts', 'label_de': 'Teile', 'label_en': 'Parts'},
    {'key': 'quantity', 'label_de': 'Anzahl', 'label_en': 'Quantity'},
    {'key': 'unit', 'label_de': 'Einheit', 'label_en': 'Unit'},
    {'key': 'price_per_unit', 'label_de': 'Preis/Einheit', 'label_en': 'Price/Unit'},
    {'key': 'total', 'label_de': 'Gesamt', 'label_en': 'Total'},
    {'key': 'discount', 'label_de': 'Rabatt', 'label_en': 'Discount'},
    {'key': 'net_total', 'label_de': 'Netto Gesamt', 'label_en': 'Net Total'},
  ];

  /// Spalten für Lieferschein (ohne Preise)
  static const List<Map<String, String>> deliveryNoteColumns = [
    {'key': 'product', 'label_de': 'Produkt', 'label_en': 'Product'},
    {'key': 'instrument', 'label_de': 'Instrument', 'label_en': 'Instrument'},
    {'key': 'quality', 'label_de': 'Qualität', 'label_en': 'Quality'},
    {'key': 'fsc', 'label_de': 'FSC®', 'label_en': 'FSC®'},
    {'key': 'origin', 'label_de': 'Ursprung', 'label_en': 'Origin'},
    {'key': 'thermal', 'label_de': '°C (Thermo)', 'label_en': '°C (Thermal)'},
    {'key': 'quantity', 'label_de': 'Anzahl', 'label_en': 'Quantity'},
    {'key': 'unit', 'label_de': 'Einheit', 'label_en': 'Unit'},
  ];

  /// Spalten für Packliste (Gewicht/Volumen)
  static const List<Map<String, String>> packingListColumns = [
    {'key': 'product', 'label_de': 'Produkt', 'label_en': 'Product'},
    {'key': 'quality', 'label_de': 'Qualität', 'label_en': 'Quality'},
    {'key': 'quantity', 'label_de': 'Anzahl', 'label_en': 'Quantity'},
    {'key': 'unit', 'label_de': 'Einheit', 'label_en': 'Unit'},
    {'key': 'weight_pc', 'label_de': 'Gewicht/Stk', 'label_en': 'Weight/pc'},
    {'key': 'volume_pc', 'label_de': 'Volumen/Stk', 'label_en': 'Volume/pc'},
    {'key': 'total_weight', 'label_de': 'Gesamt Gewicht', 'label_en': 'Total Weight'},
    {'key': 'total_volume', 'label_de': 'Gesamt Volumen', 'label_en': 'Total Volume'},
  ];

  static List<Map<String, String>> getColumnsForType(String documentType) {
    switch (documentType) {
      case PdfDocumentType.quote:
      case PdfDocumentType.invoice:
      case PdfDocumentType.commercialInvoice:
        return priceColumns;
      case PdfDocumentType.deliveryNote:
        return deliveryNoteColumns;
      case PdfDocumentType.packingList:
        return packingListColumns;
      default:
        return priceColumns;
    }
  }

  /// Standard-Ausrichtungen (typisch: Text links, Zahlen rechts)
  static Map<String, ColumnAlignment> getDefaultAlignments(String documentType) {
    final columns = getColumnsForType(documentType);
    final Map<String, ColumnAlignment> defaults = {};

    for (final col in columns) {
      final key = col['key']!;
      // Zahlen-Spalten standardmäßig rechts
      if (['quantity', 'price_per_unit', 'total', 'discount', 'net_total',
        'weight_pc', 'volume_pc', 'total_weight', 'total_volume'].contains(key)) {
        defaults[key] = ColumnAlignment.right;
      }
      // Zentrierte Spalten
      else if (['thermal', 'parts', 'unit'].contains(key)) {
        defaults[key] = ColumnAlignment.center;
      }
      // Rest linksbündig
      else {
        defaults[key] = ColumnAlignment.left;
      }
    }

    return defaults;
  }
}

class PdfSettingsScreen extends StatefulWidget {
  const PdfSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PdfSettingsScreen> createState() => _PdfSettingsScreenState();
}

class _PdfSettingsScreenState extends State<PdfSettingsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;

  // Lieferschein Einstellungen
  double _deliveryNoteAddressEmailSpacing = 6.0;

  // Adressanzeige-Einstellungen pro Dokumenttyp
  AddressDisplayMode _quoteAddressMode = AddressDisplayMode.both;
  AddressDisplayMode _invoiceAddressMode = AddressDisplayMode.both;
  AddressDisplayMode _commercialInvoiceAddressMode = AddressDisplayMode.both;
  AddressDisplayMode _deliveryNoteAddressMode = AddressDisplayMode.shippingOnly;
  AddressDisplayMode _packingListAddressMode = AddressDisplayMode.shippingOnly;

  // NEU: Spaltenausrichtungen pro PDF-Typ
  Map<String, Map<String, ColumnAlignment>> _columnAlignments = {};

  // Test-Kunde für Vorschau
  Customer? _testCustomer;
  bool _isLoadingCustomer = false;

  // Tab-Controller für Spaltenausrichtung
  late TabController _alignmentTabController;

  @override
  void initState() {
    super.initState();
    _alignmentTabController = TabController(length: 5, vsync: this);
    _initializeDefaultAlignments();
    _loadSettings();
  }

  @override
  void dispose() {
    _alignmentTabController.dispose();
    super.dispose();
  }

  void _initializeDefaultAlignments() {
    for (final docType in PdfDocumentType.all) {
      _columnAlignments[docType] = PdfColumnDefinitions.getDefaultAlignments(docType);
    }
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

          // NEU: Spaltenausrichtungen laden
          final savedAlignments = data['column_alignments'] as Map<String, dynamic>?;
          if (savedAlignments != null) {
            for (final docType in PdfDocumentType.all) {
              final docAlignments = savedAlignments[docType] as Map<String, dynamic>?;
              if (docAlignments != null) {
                for (final entry in docAlignments.entries) {
                  _columnAlignments[docType]?[entry.key] = _parseColumnAlignment(entry.value as String?);
                }
              }
            }
          }
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

  ColumnAlignment _parseColumnAlignment(String? value) {
    if (value == null) return ColumnAlignment.left;
    switch (value) {
      case 'left':
        return ColumnAlignment.left;
      case 'center':
        return ColumnAlignment.center;
      case 'right':
        return ColumnAlignment.right;
      default:
        return ColumnAlignment.left;
    }
  }

  String _columnAlignmentToString(ColumnAlignment alignment) {
    switch (alignment) {
      case ColumnAlignment.left:
        return 'left';
      case ColumnAlignment.center:
        return 'center';
      case ColumnAlignment.right:
        return 'right';
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Spaltenausrichtungen für Firebase vorbereiten
      final Map<String, Map<String, String>> alignmentsForSave = {};
      for (final docType in PdfDocumentType.all) {
        alignmentsForSave[docType] = {};
        _columnAlignments[docType]?.forEach((key, value) {
          alignmentsForSave[docType]![key] = _columnAlignmentToString(value);
        });
      }

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
        // NEU: Spaltenausrichtungen speichern
        'column_alignments': alignmentsForSave,
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

  void _resetAlignmentsForType(String documentType) {
    setState(() {
      _columnAlignments[documentType] = PdfColumnDefinitions.getDefaultAlignments(documentType);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ausrichtungen für ${PdfDocumentType.getDisplayName(documentType)} zurückgesetzt'),
        backgroundColor: Colors.orange,
      ),
    );
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
                      'Hier kannst du die Abstände, Positionierungen, Adressanzeigen und Spaltenausrichtungen in den PDF-Dokumenten anpassen.',
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

            // ═══════════════════════════════════════════════════════════
            // NEU: Spaltenausrichtung Sektion
            // ═══════════════════════════════════════════════════════════
            _buildSectionHeader(
              context,
              'Spaltenausrichtung in PDFs',
              Icons.format_align_left,
            ),

            const SizedBox(height: 8),

            // Erklärungstext
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lege fest, ob die Spalten in den PDF-Tabellen linksbündig, zentriert oder rechtsbündig dargestellt werden sollen. '
                          'Typischerweise sind Texte linksbündig und Zahlen rechtsbündig.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tabs für die verschiedenen PDF-Typen
            _buildColumnAlignmentSection(context),

            const SizedBox(height: 32),

            // ═══════════════════════════════════════════════════════════
            // Adressanzeige-Einstellungen Sektion (bestehend)
            // ═══════════════════════════════════════════════════════════
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
              onChanged: null, // deaktiviert
              disabledHint: 'Fenstertaschen-Layout',
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

  // ═══════════════════════════════════════════════════════════════════════════
  // NEU: Spaltenausrichtung Widget
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildColumnAlignmentSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Tab-Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: TabBar(
              controller: _alignmentTabController,
              isScrollable: true,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: PdfDocumentType.all.map((type) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PdfDocumentType.getIcon(type), size: 18),
                      const SizedBox(width: 6),
                      Text(PdfDocumentType.getDisplayName(type)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Tab-Inhalt
          SizedBox(
            height: 450, // Feste Höhe für den Tab-Inhalt
            child: TabBarView(
              controller: _alignmentTabController,
              children: PdfDocumentType.all.map((docType) {
                return _buildAlignmentList(context, docType);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentList(BuildContext context, String documentType) {
    final columns = PdfColumnDefinitions.getColumnsForType(documentType);
    final alignments = _columnAlignments[documentType] ?? {};

    return Column(
      children: [
        // Reset-Button
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${columns.length} Spalten',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              TextButton.icon(
                onPressed: () => _resetAlignmentsForType(documentType),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Auf Standard zurücksetzen'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Spalten-Liste
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: columns.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final column = columns[index];
              final key = column['key']!;
              final label = column['label_de']!;
              final currentAlignment = alignments[key] ?? ColumnAlignment.left;

              return _buildAlignmentRow(
                context,
                label: label,
                columnKey: key,
                documentType: documentType,
                currentAlignment: currentAlignment,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlignmentRow(
      BuildContext context, {
        required String label,
        required String columnKey,
        required String documentType,
        required ColumnAlignment currentAlignment,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Spaltenname
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: _getAlignmentIcon(currentAlignment, Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Ausrichtungs-Buttons (Toggle-Gruppe)
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAlignmentToggleButton(
                    context,
                    alignment: ColumnAlignment.left,
                    currentAlignment: currentAlignment,
                    icon: Icons.format_align_left,
                    isFirst: true,
                    onTap: () => _setAlignment(documentType, columnKey, ColumnAlignment.left),
                  ),
                  _buildAlignmentToggleButton(
                    context,
                    alignment: ColumnAlignment.center,
                    currentAlignment: currentAlignment,
                    icon: Icons.format_align_center,
                    onTap: () => _setAlignment(documentType, columnKey, ColumnAlignment.center),
                  ),
                  _buildAlignmentToggleButton(
                    context,
                    alignment: ColumnAlignment.right,
                    currentAlignment: currentAlignment,
                    icon: Icons.format_align_right,
                    isLast: true,
                    onTap: () => _setAlignment(documentType, columnKey, ColumnAlignment.right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentToggleButton(
      BuildContext context, {
        required ColumnAlignment alignment,
        required ColumnAlignment currentAlignment,
        required IconData icon,
        required VoidCallback onTap,
        bool isFirst = false,
        bool isLast = false,
      }) {
    final isSelected = alignment == currentAlignment;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(7) : Radius.zero,
          right: isLast ? const Radius.circular(7) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(7) : Radius.zero,
              right: isLast ? const Radius.circular(7) : Radius.zero,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Icon _getAlignmentIcon(ColumnAlignment alignment, Color color) {
    switch (alignment) {
      case ColumnAlignment.left:
        return Icon(Icons.format_align_left, size: 16, color: color);
      case ColumnAlignment.center:
        return Icon(Icons.format_align_center, size: 16, color: color);
      case ColumnAlignment.right:
        return Icon(Icons.format_align_right, size: 16, color: color);
    }
  }

  void _setAlignment(String documentType, String columnKey, ColumnAlignment alignment) {
    setState(() {
      _columnAlignments[documentType] ??= {};
      _columnAlignments[documentType]![columnKey] = alignment;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Bestehende Widgets (leicht angepasst)
  // ═══════════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════════
  // NEU: Spaltenausrichtungs-Helper
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lädt alle Spaltenausrichtungen für einen Dokumenttyp
  static Future<Map<String, String>> getColumnAlignments(String documentType) async {
    final settings = await loadPdfSettings();
    final alignments = settings['column_alignments'] as Map<String, dynamic>?;

    if (alignments == null || alignments[documentType] == null) {
      // Standard-Werte zurückgeben
      return _getDefaultAlignmentStrings(documentType);
    }

    final docAlignments = alignments[documentType] as Map<String, dynamic>;
    return docAlignments.map((key, value) => MapEntry(key, value.toString()));
  }

  /// Gibt die Ausrichtung für eine spezifische Spalte zurück
  static Future<String> getColumnAlignment(String documentType, String columnKey) async {
    final alignments = await getColumnAlignments(documentType);
    return alignments[columnKey] ?? _getDefaultAlignment(columnKey);
  }

  /// Konvertiert String-Ausrichtung zu pw.TextAlign
  static dynamic toPdfTextAlign(String alignment) {
    // Diese Funktion wird im Generator verwendet
    // Rückgabe als String, da pw.TextAlign dort importiert wird
    switch (alignment) {
      case 'left':
        return 'left';
      case 'center':
        return 'center';
      case 'right':
        return 'right';
      default:
        return 'left';
    }
  }

  static Map<String, String> _getDefaultAlignmentStrings(String documentType) {
    final Map<String, String> defaults = {};
    List<String> columns;

    if (documentType == 'delivery_note') {
      columns = ['product', 'instrument', 'quality', 'fsc', 'origin', 'thermal', 'quantity', 'unit'];
    } else if (documentType == 'packing_list') {
      columns = ['product', 'quality', 'quantity', 'unit', 'weight_pc', 'volume_pc', 'total_weight', 'total_volume'];
    } else {
      columns = ['product', 'instrument', 'quality', 'fsc', 'origin', 'thermal', 'dimensions', 'parts', 'quantity', 'unit', 'price_per_unit', 'total', 'discount', 'net_total'];
    }

    for (final col in columns) {
      defaults[col] = _getDefaultAlignment(col);
    }

    return defaults;
  }

  static String _getDefaultAlignment(String columnKey) {
    // Zahlen-Spalten standardmäßig rechts
    if (['quantity', 'price_per_unit', 'total', 'discount', 'net_total',
      'weight_pc', 'volume_pc', 'total_weight', 'total_volume'].contains(columnKey)) {
      return 'right';
    }
    // Zentrierte Spalten
    if (['thermal', 'parts', 'unit'].contains(columnKey)) {
      return 'center';
    }
    // Rest linksbündig
    return 'left';
  }
}