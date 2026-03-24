import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../orders/order_model.dart';
import '../orders/order_service.dart';
import '../services/postal_document_service.dart';
import '../services/user_basket_service.dart';
import 'quote_model.dart';

import 'quote_service.dart';
import 'quote_doc_selection_manager.dart';
import 'additional_text_manager.dart';
import 'shipping_costs_manager.dart';
import '../services/icon_helper.dart';

class QuoteOrderFlowScreen extends StatefulWidget {
  final String? editingQuoteId;  // NEU
  final String? editingQuoteNumber;  // NEU

  const QuoteOrderFlowScreen({
    Key? key,
    this.editingQuoteId,
    this.editingQuoteNumber,
  }) : super(key: key);

  @override
  State<QuoteOrderFlowScreen> createState() => _QuoteOrderFlowScreenState();
}

class _QuoteOrderFlowScreenState extends State<QuoteOrderFlowScreen> {
  bool _isLoading = false;
  Map<String, bool> _documentSelection = {};
  bool _isQuoteOnly = false;
  String? _selectedDistributionChannelId;
  Map<String, dynamic>? _selectedDistributionChannel;
  String? _customerLanguage;
  @override
  void initState() {
    super.initState();
    _loadDocumentSelection();
    _loadCustomerLanguage();
  }
// Neue Methode hinzufügen:
  Future<void> _loadCustomerLanguage() async {
    try {
      final customerSnapshot = await
      UserBasketService.temporaryCustomer
          .limit(1)
          .get();

      if (customerSnapshot.docs.isNotEmpty) {
        setState(() {
          _customerLanguage = customerSnapshot.docs.first.data()['language'] ?? 'DE';
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Kundensprache: $e');
    }
  }
  Future<void> _loadDocumentSelection() async {
    final selection = await DocumentSelectionManager.loadDocumentSelection();
    setState(() {
      _documentSelection = selection;
      // Prüfe ob nur "Offerte" ausgewählt wurde
      _isQuoteOnly = selection['Offerte'] == true &&
          selection.entries.where((e) => e.key != 'Offerte' && e.value == true).isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isQuoteOnly ? 'Angebot erstellen' : 'Auftrag erstellen'),
      ),
      body: SingleChildScrollView(  // NEU: Scrollable machen
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildDocumentOverview(),
            const SizedBox(height: 24),

            _buildLanguageInfo(), // NEU
            const SizedBox(height: 24),
            _buildDistributionChannelSelection(),
            const SizedBox(height: 24),
            if (_isQuoteOnly) _buildQuoteInfo(),
            const SizedBox(height: 100), // Platz für den Button
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(  // NEU: Button als bottomNavigationBar
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildActionButtons(),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return StreamBuilder<QuerySnapshot>(
      stream:
      UserBasketService.temporaryBasket
          .snapshots(),
      builder: (context, snapshot) {
        final itemCount = snapshot.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'shopping_cart',
                    defaultIcon: Icons.shopping_cart,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Zusammenfassung',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('$itemCount Artikel im Warenkorb'),

              // Kunde
              StreamBuilder<QuerySnapshot>(
                stream:
                UserBasketService.temporaryCustomer
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final customer = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Kunde: ${customer['company'] ?? customer['fullName']}'),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Kein Kunde ausgewählt',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildLanguageInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'language',
                defaultIcon: Icons.language,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Spracheinstellungen',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Voreingestellte Sprache des Kunden: ${_customerLanguage ?? 'Nicht definiert'}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          StreamBuilder<DocumentSnapshot>(
            stream:
            UserBasketService.temporaryDocumentSettings
                .doc('language_settings')
                .snapshots(),
            builder: (context, snapshot) {
              String documentLanguage = 'DE'; // Standardwert

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                documentLanguage = data?['document_language'] ?? 'DE';
              }

              return Text(
                'Gewählte Dokumentensprache: $documentLanguage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildDocumentOverview() {
    final selectedDocs = _documentSelection.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'description',
                defaultIcon: Icons.description,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Folgende Dokumente werden erstellt:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...selectedDocs.map((doc) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'check_circle',
                  defaultIcon: Icons.check_circle,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  doc,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }


  Widget _buildDistributionChannelSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            getAdaptiveIcon(
              iconName: 'storefront',
              defaultIcon: Icons.storefront,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Bestellart',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            if (_selectedDistributionChannelId == null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'Erforderlich',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('distribution_channel')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Keine Vertriebswege verfügbar'),
              );
            }

            final channels = snapshot.data!.docs;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 800;

                // Responsive Werte
                final crossAxisCount = isWideScreen ? 6 : 3;
                final childAspectRatio = isWideScreen ? 2.0 : 1.2;
                final iconSize = isWideScreen ? 32.0 : 28.0;
                final fontSize = isWideScreen ? 14.0 : 11.0;
                final containerPadding = isWideScreen
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                    : const EdgeInsets.all(12);
                final maxWidth = isWideScreen ? 2000.0 : double.infinity;

                return Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                      children: channels.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final channelId = doc.id;
                        final isSelected = _selectedDistributionChannelId == channelId;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDistributionChannelId = channelId;
                              _selectedDistributionChannel = data;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: containerPadding,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ] : null,
                            ),
                            child: isWideScreen
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildChannelIcon(
                                  data['name']?.toString() ?? '',
                                  isSelected: isSelected,
                                  size: iconSize,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    data['name']?.toString() ?? 'Unbekannt',
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                          : Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildChannelIcon(
                                  data['name']?.toString() ?? '',
                                  isSelected: isSelected,
                                  size: iconSize,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  data['name']?.toString() ?? 'Unbekannt',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimaryContainer
                                        : Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

// Aktualisierte _buildChannelIcon Methode mit size Parameter
  Widget _buildChannelIcon(String channelName, {required bool isSelected, double size = 28}) {
    final name = channelName.toLowerCase();
    String iconName;
    IconData defaultIcon;

    if (name.contains('website') || name.contains('online')) {
      iconName = 'language';
      defaultIcon = Icons.language;
    } else if (name.contains('telefon') || name.contains('phone')) {
      iconName = 'phone';
      defaultIcon = Icons.phone;
    } else if (name.contains('email') || name.contains('mail')) {
      iconName = 'email';
      defaultIcon = Icons.email;
    } else if (name.contains('messe') || name.contains('fair')) {
      iconName = 'event';
      defaultIcon = Icons.event;
    } else if (name.contains('besuch') || name.contains('visit')) {
      iconName = 'business';
      defaultIcon = Icons.business;
    } else if (name.contains('whatsapp')) {
      iconName = 'chat';
      defaultIcon = Icons.chat;
    } else if (name.contains('social')) {
      iconName = 'share';
      defaultIcon = Icons.share;
    } else {
      iconName = 'storefront';
      defaultIcon = Icons.storefront;
    }

    return getAdaptiveIcon(
      iconName: iconName,
      defaultIcon: defaultIcon,
      size: size,
      color: isSelected
          ? Theme.of(context).colorScheme.primary
          : Colors.grey[600],
    );
  }

  Widget _buildQuoteInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(iconName: 'info', defaultIcon:Icons.info, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Die Produkte werden für dieses Angebot reserviert und stehen anderen Kunden temporär nicht zur Verfügung.',
              style: TextStyle(color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              icon: getAdaptiveIcon(iconName: 'cancel', defaultIcon: Icons.cancel),
              label: const Text('Abbrechen'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (_isLoading || _selectedDistributionChannelId == null) ? null : _processDocuments,

              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check),
              label: Text(_isLoading ? 'Erstelle...' : 'Erstellen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processDocuments() async {
    print('🔧 FLOW-DEBUG: _processDocuments START');
    print('🔧 FLOW-DEBUG: widget.editingQuoteId=${widget.editingQuoteId}');
    print('🔧 FLOW-DEBUG: widget.editingQuoteNumber=${widget.editingQuoteNumber}');
    print('🔧 FLOW-DEBUG: _isQuoteOnly=$_isQuoteOnly');
    print('🔧 FLOW-DEBUG: _documentSelection=$_documentSelection');
    setState(() => _isLoading = true);

    try {
      final data = await _loadTransactionData();
      if (data == null) throw Exception('Nicht alle erforderlichen Daten vorhanden');

      if (_isQuoteOnly) {
        print('🔧 FLOW-DEBUG: _isQuoteOnly=true');
        print('🔧 FLOW-DEBUG: editingQuoteId=${widget.editingQuoteId}');
        print('🔧 FLOW-DEBUG: editingQuoteNumber=${widget.editingQuoteNumber}');
        Quote quote;
        if (widget.editingQuoteId != null && widget.editingQuoteNumber != null) {
          quote = await QuoteService.updateQuote(
            widget.editingQuoteId!,
            widget.editingQuoteNumber!,
            customerData: data['customer'],
            costCenter: data['costCenter'],
            fair: data['fair'],
            items: data['items'],
            calculations: data['calculations'],
            metadata: data['metadata'],
          );
        } else {
          quote = await QuoteService.createQuote(
            customerData: data['customer'],
            costCenter: data['costCenter'],
            fair: data['fair'],
            items: data['items'],
            calculations: data['calculations'],
            metadata: data['metadata'],
            createReservations: true,
          );
        }
        await _clearTemporaryData();

        if (mounted) {
          Navigator.pop(context);
          _showSuccessDialog(
            widget.editingQuoteId != null ? 'Angebot aktualisiert' : 'Angebot erstellt',
            widget.editingQuoteId != null
                ? 'Angebotsnummer: ${quote.quoteNumber}\n\nDas Angebot wurde erfolgreich aktualisiert und das PDF neu generiert.'
                : 'Angebotsnummer: ${quote.quoteNumber}\n\nDie Produkte wurden reserviert.',
            quote.id,
          );
        }
      } else {
        // 1. Erstelle oder aktualisiere Angebot
        print('🔧 FLOW-DEBUG: _isQuoteOnly=false');
        print('🔧 FLOW-DEBUG: editingQuoteId=${widget.editingQuoteId}');
        print('🔧 FLOW-DEBUG: editingQuoteNumber=${widget.editingQuoteNumber}');

        Quote quote;
        if (widget.editingQuoteId != null && widget.editingQuoteNumber != null) {
          // EDIT-MODUS: Bestehendes Angebot aktualisieren (behält Nummer + Reservierungen)
          print('🔧 FLOW-DEBUG: → updateQuote wird aufgerufen für ${widget.editingQuoteId}');
          quote = await QuoteService.updateQuote(
            widget.editingQuoteId!,
            widget.editingQuoteNumber!,
            customerData: data['customer'],
            costCenter: data['costCenter'],
            fair: data['fair'],
            items: data['items'],
            calculations: data['calculations'],
            metadata: data['metadata'],
          );
          print('🔧 FLOW-DEBUG: → updateQuote fertig, quoteId=${quote.id}');
        } else {
          // NEU-MODUS: Neues Angebot erstellen (ohne Reservierungen, da sofort Auftrag folgt)
          print('🔧 FLOW-DEBUG: → createQuote wird aufgerufen (NEU)');
          quote = await QuoteService.createQuote(
            customerData: data['customer'],
            costCenter: data['costCenter'],
            fair: data['fair'],
            items: data['items'],
            calculations: data['calculations'],
            metadata: data['metadata'],
            createReservations: false,
          );
          print('🔧 FLOW-DEBUG: → createQuote fertig, quoteId=${quote.id}');
        }

        // 2. Konvertiere zu Auftrag
        print('🔧 FLOW-DEBUG: → createOrderFromQuote wird aufgerufen für ${quote.id}');
        final order = await OrderService.createOrderFromQuote(quote.id);
        final documentSelection = Map<String, bool>.from(_documentSelection);
        documentSelection.remove('Offerte'); // Bereits erstellt

        // 🚀 BUGFIX START: EINZELVERSAND WEICHE
        // Sicheres Casten mit Map.from() um "Map<dynamic, dynamic>" Errors zu verhindern!
        final metadata = Map<String, dynamic>.from(data['metadata'] as Map? ?? {});
        final packingListSettings = Map<String, dynamic>.from(metadata['packingListSettings'] as Map? ?? {});
        final shipmentMode = packingListSettings['shipment_mode'] as String? ?? 'total';

        final rawPackages = packingListSettings['packages'] as List<dynamic>? ?? [];
        final packages = rawPackages.map((p) => Map<String, dynamic>.from(p as Map)).toList();

        for (int i = 0; i < packages.length; i++) {
          if (packages[i]['shipment_group'] == null) {
            packages[i]['shipment_group'] = i + 1;
          }
        }

        if (documentSelection['Packliste'] == true || shipmentMode == 'per_shipment') {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .collection('packing_list')
              .doc('settings')
              .set({
            'packages': packages,
            'shipment_mode': shipmentMode,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (shipmentMode == 'per_shipment' &&
            (documentSelection['Handelsrechnung'] == true || documentSelection['Lieferschein'] == true)) {

          // 🛠 FIX: Auch hier sicheres Casten für alle Settings-Maps
          final rawTara = Map<String, dynamic>.from(metadata['taraSettings'] as Map? ?? {});
          final dnSettings = Map<String, dynamic>.from(metadata['deliveryNoteSettings'] as Map? ?? {});
          final safeShippingCosts = Map<String, dynamic>.from(metadata['shippingCosts'] as Map? ?? {});
          final safeAdditionalTexts = Map<String, dynamic>.from(metadata['additionalTexts'] as Map? ?? {});

          // Timestamp-Sicherheit für Datumsfelder
          dynamic hrDate = rawTara['commercial_invoice_date'];
          if (hrDate is Timestamp) hrDate = hrDate.toDate();

          dynamic delDate = rawTara['commercial_invoice_delivery_date_value'] ?? rawTara['delivery_date_value'];
          if (delDate is Timestamp) delDate = delDate.toDate();

          final mappedCommercialInvoiceSettings = {
            'number_of_packages': rawTara['number_of_packages'] ?? 1,
            'commercial_invoice_date': hrDate,
            'use_as_delivery_date': rawTara['use_as_delivery_date'] ?? true,
            'origin_declaration': rawTara['commercial_invoice_origin_declaration'] ?? rawTara['origin_declaration'] ?? false,
            'cites': rawTara['commercial_invoice_cites'] ?? rawTara['cites'] ?? false,
            'export_reason': rawTara['commercial_invoice_export_reason'] ?? rawTara['export_reason'] ?? false,
            'export_reason_text': rawTara['commercial_invoice_export_reason_text'] ?? rawTara['export_reason_text'] ?? 'Ware',
            'incoterms': rawTara['commercial_invoice_incoterms'] ?? rawTara['incoterms'] ?? false,
            'selected_incoterms': List<String>.from(rawTara['commercial_invoice_selected_incoterms'] ?? rawTara['selected_incoterms'] ?? []),
            'incoterms_freetexts': Map<String, String>.from(rawTara['commercial_invoice_incoterms_freetexts'] ?? rawTara['incoterms_freetexts'] ?? {}),
            'delivery_date': rawTara['commercial_invoice_delivery_date'] ?? rawTara['delivery_date'] ?? false,
            'delivery_date_value': delDate,
            'delivery_date_month_only': rawTara['commercial_invoice_delivery_date_month_only'] ?? rawTara['delivery_date_month_only'] ?? false,
            'carrier': rawTara['commercial_invoice_carrier'] ?? rawTara['carrier'] ?? false,
            'carrier_text': rawTara['commercial_invoice_carrier_text'] ?? rawTara['carrier_text'] ?? 'Swiss Post',
            'signature': rawTara['commercial_invoice_signature'] ?? rawTara['signature'] ?? false,
            'selected_signature': rawTara['commercial_invoice_selected_signature'] ?? rawTara['selected_signature'],
            'currency': rawTara['commercial_invoice_currency'] ?? rawTara['currency'],
          };

          final settingsMap = {
            'packing_list': {'packages': packages, 'shipment_mode': shipmentMode},
            'commercial_invoice': mappedCommercialInvoiceSettings,
            'delivery_note': dnSettings,
          };

          final rawExchangeRates = metadata['exchangeRates'] as Map<dynamic, dynamic>? ?? {};
          final exchangeRates = <String, double>{'CHF': 1.0};
          rawExchangeRates.forEach((key, value) {
            if (value != null) exchangeRates[key.toString()] = (value as num).toDouble();
          });

          final lang = metadata['language'] ?? 'DE';

          final orderDataMap = {
            'order': order,
            'items': data['items'],
            'customer': data['customer'],
            'calculations': data['calculations'],
            'settings': settingsMap,
            'shippingCosts': safeShippingCosts,
            'currency': metadata['currency'] ?? 'CHF',
            'exchangeRates': exchangeRates,
            'costCenterCode': data['costCenter']?['code'] ?? '00000',
            'fair': data['fair'],
            'taxOption': metadata['taxOption'] ?? 0,
            'vatRate': (metadata['vatRate'] as num?)?.toDouble() ?? 8.1,
            'language': lang,
            'documentLanguages': {
              'Rechnung': lang,
              'Lieferschein': lang,
              'Handelsrechnung': lang,
              'Packliste': lang,
            },
          };

          await PostalDocumentService.createShipmentDocuments(
            order: order,
            orderData: orderDataMap,
            settings: settingsMap,
            additionalTextsConfig: safeAdditionalTexts,
            createCommercialInvoices: documentSelection['Handelsrechnung'] == true,
            createDeliveryNotes: documentSelection['Lieferschein'] == true,
          );

          // Verhindere Standard-Generierung für HR und LS
          documentSelection.remove('Handelsrechnung');
          documentSelection.remove('Lieferschein');
        }
        // 🚀 BUGFIX ENDE

        // 3. Erstelle restliche Standard-Dokumente (z.B. Rechnung)
        if (documentSelection.values.any((v) => v == true)) {
          await OrderService.createOrderDocuments(
            orderId: order.id,
            orderNumber: order.orderNumber,
            documentTypes: documentSelection,
            orderData: {
              'orderId': order.id,
              'quoteId': quote.id,
              'customer': data['customer'],
              'costCenter': data['costCenter'],
              'fair': data['fair'],
              'items': data['items'],
              'calculations': data['calculations'],
              // Sichere auch hier das Metadata-Objekt ab:
              'metadata': Map<String, dynamic>.from(data['metadata'] as Map? ?? {}),
            },
            language: metadata['language'] ?? 'DE',
          );
        }

        await _clearTemporaryData();

        if (mounted) {
          Navigator.pop(context);
          _showSuccessDialog(
            'Auftrag erfolgreich erstellt',
            'Auftragsnummer: ${order.orderNumber}\n'
                'Angebotsnummer: ${quote.quoteNumber}\n\n'
                'Dokumente wurden erstellt.',
            order.id,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  Future<Map<String, dynamic>?> _loadTransactionData() async {
    try {
      // Kunde
      final customerSnapshot = await UserBasketService.temporaryCustomer.limit(1).get();
      if (customerSnapshot.docs.isEmpty) throw Exception('Kein Kunde ausgewählt');

      // Kostenstelle
      final costCenterSnapshot = await UserBasketService.temporaryCostCenter.limit(1).get();

      // Warenkorb
      final basketSnapshot = await UserBasketService.temporaryBasket.get();
      if (basketSnapshot.docs.isEmpty) throw Exception('Warenkorb ist leer');

      // Messe (optional)
      final fairSnapshot = await UserBasketService.temporaryFair.limit(1).get();

      // Settings laden
      final taxDoc = await UserBasketService.temporaryTax.doc('current_tax').get();
      final currencyDoc = await FirebaseFirestore.instance.collection('general_data').doc('currency_settings').get();
      final taraSettingsDoc = await UserBasketService.temporaryDocumentSettings.doc('tara_settings').get();

      // NEU: Diese beiden brauchte der Erstellungsprozess noch!
      final packingListSettings = await DocumentSelectionManager.loadPackingListSettings();
      final deliveryNoteSettings = await DocumentSelectionManager.loadDeliveryNoteSettings();

      final shippingCosts = await ShippingCostsManager.loadShippingCosts();
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();
      final calculations = await _calculateTotals(basketSnapshot.docs);
      final invoiceSettings = await DocumentSelectionManager.loadInvoiceSettings();
      final quoteSettings = await DocumentSelectionManager.loadQuoteSettings();

      final items = basketSnapshot.docs.map((doc) => {
        ...doc.data(),
        'basket_doc_id': doc.id,
      }).toList();

      return {
        'customer': customerSnapshot.docs.first.data(),
        'costCenter': costCenterSnapshot.docs.isNotEmpty ? costCenterSnapshot.docs.first.data() : null,
        'fair': fairSnapshot.docs.isNotEmpty ? fairSnapshot.docs.first.data() : null,
        'items': items,
        'calculations': calculations,
        'metadata': {
          'taxOption': taxDoc.exists ? (taxDoc.data()?['tax_option'] ?? 1) : 1,
          'vatRate': taxDoc.exists ? (taxDoc.data()?['vat_rate'] ?? 8.1) : 8.1,
          'currency': currencyDoc.exists ? (currencyDoc.data()?['selected_currency'] ?? 'CHF') : 'CHF',
          'exchangeRates': currencyDoc.exists ? (currencyDoc.data()?['exchange_rates'] ?? {'CHF': 1.0}) : {'CHF': 1.0},
          'language': await _getDocumentLanguage() ?? customerSnapshot.docs.first.data()['language'] ?? 'DE',
          'taraSettings': taraSettingsDoc.exists ? taraSettingsDoc.data() : {},
          'packingListSettings': packingListSettings, // NEU
          'deliveryNoteSettings': deliveryNoteSettings, // NEU
          'shippingCosts': shippingCosts,
          'additionalTexts': additionalTexts,
          'invoiceSettings': invoiceSettings,
          'distributionChannel': _selectedDistributionChannel,
          'quoteSettings': quoteSettings,
        },
      };
    } catch (e) {
      print('Fehler beim Laden der Transaktionsdaten: $e');
      rethrow;
    }
  }
// Und füge diese Hilfsmethode hinzu:
  Future<String?> _getDocumentLanguage() async {
    try {
      final doc = await
      UserBasketService.temporaryDocumentSettings
          .doc('language_settings')
          .get();

      if (doc.exists) {
        return doc.data()?['document_language'];
      }
    } catch (e) {
      print('Fehler beim Laden der Dokumentensprache: $e');
    }
    return null;
  }
  Future<Map<String, dynamic>> _calculateTotals(List<QueryDocumentSnapshot> basketItems) async {
    double subtotal = 0.0;
    double itemDiscounts = 0.0;

    for (final doc in basketItems) {
      final data = doc.data() as Map<String, dynamic>;

      // NEU: Check für Gratisartikel
      final isGratisartikel = data['is_gratisartikel'] == true;

      final customPriceValue = data['custom_price_per_unit'];
      final pricePerUnit = isGratisartikel
          ? 0.0  // Gratisartikel haben Preis 0
          : customPriceValue != null
          ? (customPriceValue as num).toDouble()
          : (data['price_per_unit'] as num).toDouble();

      final quantity = data['quantity'];
      final quantityDouble = quantity is int ? quantity.toDouble() : quantity as double;
      final itemSubtotal = quantityDouble * pricePerUnit;
      subtotal += itemSubtotal;

      // Rabatte nur auf nicht-Gratisartikel
      if (!isGratisartikel) {
        final discount = data['discount'] as Map<String, dynamic>?;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();
          itemDiscounts += (itemSubtotal * (percentage / 100)) + absolute;
        }
      }
    }

    // Gesamtrabatt
    double totalDiscountAmount = 0.0;
    final totalDiscountDoc = await
    UserBasketService.temporaryDiscounts
        .doc('total_discount')
        .get();

    if (totalDiscountDoc.exists) {
      final discountData = totalDiscountDoc.data()!;
      final percentage = (discountData['percentage'] as num? ?? 0).toDouble();
      final absolute = (discountData['absolute'] as num? ?? 0).toDouble();

      // NEU: Berechne Subtotal nur für nicht-Gratisartikel für Gesamtrabatt
      double subtotalForTotalDiscount = 0.0;
      for (final doc in basketItems) {
        final data = doc.data() as Map<String, dynamic>;
        final isGratisartikel = data['is_gratisartikel'] == true;

        if (!isGratisartikel) {
          final customPriceValue = data['custom_price_per_unit'];
          final pricePerUnit = customPriceValue != null
              ? (customPriceValue as num).toDouble()
              : (data['price_per_unit'] as num).toDouble();

          final quantity = data['quantity'];
          final quantityDouble = quantity is int ? quantity.toDouble() : quantity as double;
          subtotalForTotalDiscount += quantityDouble * pricePerUnit;
        }
      }

      final afterItemDiscounts = subtotalForTotalDiscount - itemDiscounts;
      totalDiscountAmount = (afterItemDiscounts * (percentage / 100)) + absolute;
    }

    final netAmount = subtotal - itemDiscounts - totalDiscountAmount;

    // Steuern
    final taxDoc = await
    UserBasketService.temporaryTax
        .doc('current_tax')
        .get();

    final taxOption = taxDoc.exists ? (taxDoc.data()?['tax_option'] ?? 0) : 0;
    final vatRate = taxDoc.exists ? (taxDoc.data()?['vat_rate'] ?? 8.1).toDouble() : 8.1;

    double vatAmount = 0.0;
    double total = netAmount;

    if (taxOption == 0) { // Standard
      // NEU: Erst Nettobetrag auf 2 Nachkommastellen runden
      final netAmountRounded = double.parse(netAmount.toStringAsFixed(2));

      // NEU: MwSt berechnen und auf 2 Nachkommastellen runden
      vatAmount = double.parse((netAmountRounded * (vatRate / 100)).toStringAsFixed(2));

      // NEU: Total ist Summe der gerundeten Beträge
      total = netAmountRounded + vatAmount;
    } else {
      // Bei anderen Steueroptionen auch auf 2 Nachkommastellen runden
      total = double.parse(netAmount.toStringAsFixed(2));
    }

    return {
      'subtotal': subtotal,
      'item_discounts': itemDiscounts,
      'total_discount': totalDiscountDoc.exists ? totalDiscountDoc.data() : {'percentage': 0.0, 'absolute': 0.0},
      'total_discount_amount': totalDiscountAmount,
      'net_amount': netAmount,
      'vat_rate': vatRate,
      'vat_amount': vatAmount,
      'total': total,
    };
  }

  Future<void> _clearTemporaryData() async {
    final batch = FirebaseFirestore.instance.batch();

    // Lösche Warenkorb
    final basketDocs = await
    UserBasketService.temporaryBasket
        .get();
    for (final doc in basketDocs.docs) {


      final data = doc.data();

      // NEU: Wenn es ein Online-Shop-Item ist, setze in_cart zurück
      if (data['is_online_shop_item'] == true && data['online_shop_barcode'] != null) {
        final onlineShopBarcode = data['online_shop_barcode'] as String;
        try {
          await FirebaseFirestore.instance
              .collection('onlineshop')
              .doc(onlineShopBarcode)
              .update({
            'in_cart': false,
            'cart_timestamp': FieldValue.delete(),
            'cart_user_id': FieldValue.delete(),
            'cart_user_name': FieldValue.delete(),
          });
        } catch (e) {
          print('Fehler beim Zurücksetzen von in_cart für $onlineShopBarcode: $e');
        }
      }



      batch.delete(doc.reference);
    }

    // Lösche Kunde
    final customerDocs = await
    UserBasketService.temporaryCustomer
        .get();
    for (final doc in customerDocs.docs) {
      batch.delete(doc.reference);
    }

    // Lösche weitere temporäre Daten...
    final costCenterDocs = await
    UserBasketService.temporaryCostCenter
        .get();
    for (final doc in costCenterDocs.docs) {
      batch.delete(doc.reference);
    }

    final fairDocs = await
    UserBasketService.temporaryFair
        .get();
    for (final doc in fairDocs.docs) {
      batch.delete(doc.reference);
    }

    final taxDocs = await
    UserBasketService.temporaryTax
        .get();
    for (final doc in taxDocs.docs) {
      batch.delete(doc.reference);
    }

    final discountDocs = await
    UserBasketService.temporaryDiscounts
        .get();
    for (final doc in discountDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    // Lösche auch die anderen Manager-Daten
    await DocumentSelectionManager.clearSelection();
    await AdditionalTextsManager.clearAdditionalTexts();
    await ShippingCostsManager.clearShippingCosts();
  }

  void _showSuccessDialog(String title, String message, String documentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: getAdaptiveIcon(
                  iconName: 'check_circle',
                  defaultIcon: Icons.check_circle,
                  color: Colors.green,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Single Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Schließt den Dialog

                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Verstanden'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: getAdaptiveIcon(
                  iconName: 'error',
                  defaultIcon: Icons.error,
                  color: Colors.red,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Fehler',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),

              // Error Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  error,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // OK Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}