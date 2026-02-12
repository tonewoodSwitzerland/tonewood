// lib/home/orders/order_details_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/icon_helper.dart';
import '../../services/swiss_rounding.dart';
import '../services/price_formatter.dart';
import 'order_model.dart';

class OrderColors {
  static const pending = Color(0xFFEF9A3C);
  static const processing = Color(0xFF2196F3);
  static const shipped = Color(0xFF7C4DFF);
  static const delivered = Color(0xFF4CAF50);
  static const cancelled = Color(0xFF757575);
  static const paymentPending = Color(0xFFFF7043);
  static const paymentPartial = Color(0xFFFFA726);
  static const paymentPaid = Color(0xFF66BB6A);
}

class OrderDetailsSheet extends StatelessWidget {
  final OrderX order;
  final Function(OrderX) onStatusChange;
  final Function(OrderX) onViewDocuments;
  final Function(OrderX) onShowHistory;
  final Function(OrderX) onShare;
  final Function(OrderX) onCancel;
  final Function(OrderX, Map<String, dynamic>, int) onEditItemMeasurements;
  final Function(OrderX)? onVeranlagung;

  const OrderDetailsSheet({
    Key? key,
    required this.order,
    required this.onStatusChange,
    required this.onViewDocuments,
    required this.onShowHistory,
    required this.onShare,
    required this.onCancel,
    required this.onEditItemMeasurements,
    this.onVeranlagung,
  }) : super(key: key);

  static void show(
      BuildContext context, {
        required OrderX order,
        required Function(OrderX) onStatusChange,
        required Function(OrderX) onViewDocuments,
        required Function(OrderX) onShowHistory,
        required Function(OrderX) onShare,
        required Function(OrderX) onCancel,
        required Function(OrderX, Map<String, dynamic>, int) onEditItemMeasurements,
        Function(OrderX)? onVeranlagung,
      }) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 900,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _OrderDetailsContent(
              order: order,
              onStatusChange: onStatusChange,
              onViewDocuments: onViewDocuments,
              onShowHistory: onShowHistory,
              onShare: onShare,
              onCancel: onCancel,
              onEditItemMeasurements: onEditItemMeasurements,
              onVeranlagung: onVeranlagung,
              isDesktop: true,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _OrderDetailsContent(
            order: order,
            onStatusChange: onStatusChange,
            onViewDocuments: onViewDocuments,
            onShowHistory: onShowHistory,
            onShare: onShare,
            onCancel: onCancel,
            onEditItemMeasurements: onEditItemMeasurements,
            onVeranlagung: onVeranlagung,
            isDesktop: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OrderDetailsContent(
      order: order,
      onStatusChange: onStatusChange,
      onViewDocuments: onViewDocuments,
      onShowHistory: onShowHistory,
      onShare: onShare,
      onCancel: onCancel,
      onEditItemMeasurements: onEditItemMeasurements,
      onVeranlagung: onVeranlagung,
      isDesktop: MediaQuery.of(context).size.width > 800,
    );
  }
}

class _OrderDetailsContent extends StatefulWidget {
  final OrderX order;
  final Function(OrderX) onStatusChange;
  final Function(OrderX) onViewDocuments;
  final Function(OrderX) onShowHistory;
  final Function(OrderX) onShare;
  final Function(OrderX) onCancel;
  final Function(OrderX, Map<String, dynamic>, int) onEditItemMeasurements;
  final Function(OrderX)? onVeranlagung;
  final bool isDesktop;

  const _OrderDetailsContent({
    required this.order,
    required this.onStatusChange,
    required this.onViewDocuments,
    required this.onShowHistory,
    required this.onShare,
    required this.onCancel,
    required this.onEditItemMeasurements,
    this.onVeranlagung,
    required this.isDesktop,
  });

  @override
  State<_OrderDetailsContent> createState() => _OrderDetailsContentState();
}

class _OrderDetailsContentState extends State<_OrderDetailsContent> {
  Map<String, bool> _roundingSettings = {'CHF': true, 'EUR': false, 'USD': false};

  @override
  void initState() {
    super.initState();
    _loadRoundingSettings();
  }

  Future<void> _loadRoundingSettings() async {
    final settings = await SwissRounding.loadRoundingSettings();
    if (mounted) {
      setState(() {
        _roundingSettings = settings;
      });
    }
  }

  OrderX get order => widget.order;
  bool get isDesktop => widget.isDesktop;

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing: return OrderColors.processing;
      case OrderStatus.shipped: return OrderColors.shipped;
      case OrderStatus.cancelled: return OrderColors.cancelled;
    }
  }


  String _getCurrencySymbol(OrderX currentOrder) => currentOrder.metadata?['currency'] ?? 'CHF';

  bool _needsVeranlagung(OrderX currentOrder) {
    final total = (currentOrder.calculations['total'] as num? ?? 0).toDouble();
    return total > 1000.0;
  }

  bool _hasVeranlagung(OrderX currentOrder) {
    return currentOrder.metadata?['veranlagungsnummer'] != null &&
        currentOrder.metadata!['veranlagungsnummer'].toString().isNotEmpty;
  }

  String _getCustomerName(OrderX currentOrder) {
    final c = currentOrder.customer;
    if (c['company']?.toString().trim().isNotEmpty == true) return c['company'];
    if (c['fullName']?.toString().trim().isNotEmpty == true) return c['fullName'];
    return '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .snapshots(),
      builder: (context, snapshot) {
        final currentOrder = snapshot.hasData && snapshot.data!.exists
            ? OrderX.fromFirestore(snapshot.data!)
            : order;

        return Column(
          children: [
            _buildHeader(context, currentOrder),
            Expanded(
              child: isDesktop
                  ? _buildDesktopLayout(context, currentOrder)
                  : _buildMobileLayout(context, currentOrder),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, OrderX currentOrder) {
    return Container(
      padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, isDesktop ? 16 : 12, isDesktop ? 24 : 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          if (!isDesktop)
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Auftrag ${currentOrder.orderNumber}',
                          style: TextStyle(
                            fontSize: isDesktop ? 22 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          DateFormat('dd.MM.yyyy').format(currentOrder.orderDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        if (currentOrder.quoteNumber != null && currentOrder.quoteNumber!.isNotEmpty) ...[
                          Text(' • ', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                          getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description, size: 12, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            'Angebot ${currentOrder.quoteNumber}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              //   _buildQuickActions(context, currentOrder),
              // const SizedBox(width: 8),
              IconButton(
                icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, OrderStatus status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status.displayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, OrderX currentOrder) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconAction(context, Icons.history, 'history', 'Verlauf', () {
          //  Navigator.pop(context);
          widget.onShowHistory(currentOrder);
        }),
        _buildIconAction(context, Icons.folder, 'folder', 'Dokumente', () {
          //Navigator.pop(context);
          widget.onViewDocuments(currentOrder);
        }),
        _buildIconAction(context, Icons.share, 'share', 'Teilen', () => widget.onShare(currentOrder)),
      ],
    );
  }

  Widget _buildIconAction(BuildContext context, IconData icon, String iconName, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, OrderX currentOrder) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildStatusSection(context, currentOrder),
                const SizedBox(height: 20),
                _buildInfoCards(context, currentOrder, isDesktop: true),
                const SizedBox(height: 20),
                _buildAddressSection(context, currentOrder),
                const SizedBox(height: 20),
                _buildActionButtons(context, currentOrder),
                if (_needsVeranlagung(currentOrder)) ...[
                  const SizedBox(height: 20),
                  _buildVeranlagungCard(context, currentOrder),
                ],
              ],
            ),
          ),
        ),
        Container(width: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildItemsList(context, currentOrder, isDesktop: true),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, OrderX currentOrder) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSection(context, currentOrder),
          const SizedBox(height: 16),
          _buildInfoCards(context, currentOrder, isDesktop: false),
          const SizedBox(height: 16),
          _buildAddressSection(context, currentOrder),
          const SizedBox(height: 16),
          _buildActionButtons(context, currentOrder),
          if (_needsVeranlagung(currentOrder)) ...[
            const SizedBox(height: 16),
            _buildVeranlagungCard(context, currentOrder),
          ],
          const SizedBox(height: 20),
          _buildItemsAccordion(context, currentOrder),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context, OrderX currentOrder) {
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
              Text('Status', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              const Spacer(),
              _buildStatusChip(context, currentOrder.status),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: currentOrder.status != OrderStatus.cancelled ? () {
                Navigator.pop(context);
                widget.onStatusChange(currentOrder);
              } : null,
              icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit, size: 18),
              label: const Text('Status ändern'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(BuildContext context, OrderX currentOrder, {required bool isDesktop}) {
    final total = PriceFormatter.convertPrice(
      priceInCHF: (currentOrder.calculations['total'] as num).toDouble(),
      currency: currentOrder.metadata['currency'] ?? 'CHF',
      exchangeRates: currentOrder.metadata['exchangeRates'] as Map<String, dynamic>?,
      roundingSettings: _roundingSettings,
    );
    final currencySymbol = _getCurrencySymbol(currentOrder);

    if (isDesktop) {
      return Column(
        children: [
          _buildInfoCard(context, 'business', Icons.business, 'Kunde', _getCustomerName(currentOrder), null),
          const SizedBox(height: 10),
          _buildInfoCard(context, 'payments', Icons.payments, 'Betrag', PriceFormatter.formatAmount(
            amount: total,
            currency: currentOrder.metadata['currency'] ?? 'CHF',
            roundingSettings: _roundingSettings,
          ), OrderColors.delivered), const SizedBox(height: 10),
          _buildInfoCard(context, 'email', Icons.email, 'E-Mail', currentOrder.customer['email'] ?? '-', null),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCompactInfoCard(context, 'payments', Icons.payments, '$currencySymbol ${total.toStringAsFixed(2)}', OrderColors.delivered)),
            const SizedBox(width: 8),
            Expanded(child: _buildCompactInfoCard(context, 'translate', Icons.translate, currentOrder.metadata?['language'] ?? 'DE', null)),
          ],
        ),
        const SizedBox(height: 8),
        _buildInfoCard(context, 'business', Icons.business, 'Kunde', _getCustomerName(currentOrder), null),
      ],
    );
  }

  // ============================================================================
  // NEU: Adress-Sektion
  // ============================================================================
  Widget _buildAddressSection(BuildContext context, OrderX currentOrder) {
    final customer = currentOrder.customer;

    // Prüfe beide möglichen Strukturen:
    // 1. Verschachtelt: customer['shipping_address']['street']
    // 2. Flach: customer['hasDifferentShippingAddress'] + customer['shippingStreet']
    final hasShippingAddressNested = customer['shipping_address'] != null &&
        (customer['shipping_address'] is Map) &&
        (customer['shipping_address'] as Map).isNotEmpty &&
        customer['shipping_address']['street']?.toString().isNotEmpty == true;

    final hasShippingAddressFlat = customer['hasDifferentShippingAddress'] == true &&
        customer['shippingStreet']?.toString().isNotEmpty == true;

    final hasShippingAddress = hasShippingAddressNested || hasShippingAddressFlat;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header mit Abgleich-Button
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'location_on',
                  defaultIcon: Icons.location_on,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Adressen',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showSyncAddressDialog(context, currentOrder),
                  icon: getAdaptiveIcon(
                    iconName: 'sync',
                    defaultIcon: Icons.sync,
                    size: 16,
                  ),
                  label: const Text('Abgleichen', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Rechnungsadresse
          _buildAddressCard(
            context: context,
            title: 'Rechnungsadresse',
            iconName: 'receipt',
            icon: Icons.receipt,
            address: _formatBillingAddress(customer),
            onEdit: () => _showEditAddressDialog(context, currentOrder, 'billing'),
          ),

          const Divider(height: 1),

          // Lieferadresse
          _buildAddressCard(
            context: context,
            title: 'Lieferadresse',
            iconName: 'local_shipping',
            icon: Icons.local_shipping,
            address: hasShippingAddress
                ? _formatShippingAddressAuto(customer)
                : 'Identisch mit Rechnungsadresse',
            isIdentical: !hasShippingAddress,
            onEdit: () => _showEditAddressDialog(context, currentOrder, 'shipping'),
          ),
        ],
      ),
    );
  }
  /// Formatiert Lieferadresse - erkennt automatisch ob flach oder verschachtelt
  String _formatShippingAddressAuto(Map<String, dynamic> customer) {
    // Prüfe ob verschachtelte Struktur mit Daten vorhanden
    if (customer['shipping_address'] != null &&
        customer['shipping_address'] is Map &&
        (customer['shipping_address'] as Map).isNotEmpty &&
        customer['shipping_address']['street']?.toString().isNotEmpty == true) {
      return _formatShippingAddress(customer['shipping_address']);
    }

    // Flache Struktur (wie im Customer Model)
    final parts = <String>[];

    if (customer['shippingCompany']?.toString().isNotEmpty == true) {
      parts.add(customer['shippingCompany']);
    }

    final firstName = customer['shippingFirstName']?.toString() ?? '';
    final lastName = customer['shippingLastName']?.toString() ?? '';
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      parts.add('$firstName $lastName'.trim());
    }

    if (customer['shippingStreet']?.toString().isNotEmpty == true) {
      final houseNumber = customer['shippingHouseNumber']?.toString() ?? '';
      parts.add('${customer['shippingStreet']} $houseNumber'.trim());
    }

    // NEU: Zusätzliche Lieferadresszeilen
    if (customer['shippingAdditionalAddressLines'] != null) {
      final lines = customer['shippingAdditionalAddressLines'] as List<dynamic>;
      for (final line in lines) {
        if (line.toString().isNotEmpty) {
          parts.add(line.toString());
        }
      }
    }

    final zip = customer['shippingZipCode']?.toString() ?? '';
    final city = customer['shippingCity']?.toString() ?? '';
    if (zip.isNotEmpty || city.isNotEmpty) {
      parts.add('$zip $city'.trim());
    }

    if (customer['shippingProvince']?.toString().isNotEmpty == true) {
      parts.add(customer['shippingProvince']);
    }

    if (customer['shippingCountry']?.toString().isNotEmpty == true) {
      parts.add(customer['shippingCountry']);
    }

    return parts.isNotEmpty ? parts.join('\n') : 'Keine Lieferadresse';
  }


  Widget _buildAddressCard({
    required BuildContext context,
    required String title,
    required String iconName,
    required IconData icon,
    required String address,
    required VoidCallback onEdit,
    bool isIdentical = false,
  }) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            getAdaptiveIcon(
              iconName: iconName,
              defaultIcon: icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isIdentical)
                    Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'check_circle',
                          defaultIcon: Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          address,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      address,
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
            getAdaptiveIcon(
              iconName: 'edit',
              defaultIcon: Icons.edit,
              size: 16,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBillingAddress(Map<String, dynamic> customer) {
    final parts = <String>[];

    if (customer['company']?.toString().isNotEmpty == true) {
      parts.add(customer['company']);
    }

    final firstName = customer['firstName']?.toString() ?? '';
    final lastName = customer['lastName']?.toString() ?? '';
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      parts.add('$firstName $lastName'.trim());
    }

    final street = customer['street']?.toString() ?? '';
    final houseNumber = customer['houseNumber']?.toString() ?? '';
    if (street.isNotEmpty || houseNumber.isNotEmpty) {
      parts.add('$street $houseNumber'.trim());
    }

    // NEU: Zusätzliche Adresszeilen
    if (customer['additionalAddressLines'] != null) {
      final lines = customer['additionalAddressLines'] as List<dynamic>;
      for (final line in lines) {
        if (line.toString().isNotEmpty) {
          parts.add(line.toString());
        }
      }
    }

    final zip = customer['zipCode']?.toString() ?? '';
    final city = customer['city']?.toString() ?? '';
    if (zip.isNotEmpty || city.isNotEmpty) {
      parts.add('$zip $city'.trim());
    }

    if (customer['province']?.toString().isNotEmpty == true) {
      parts.add(customer['province']);
    }

    if (customer['country']?.toString().isNotEmpty == true) {
      parts.add(customer['country']);
    }

    return parts.join('\n');
  }
  String _formatShippingAddress(Map<String, dynamic> shipping) {
    final parts = <String>[];

    if (shipping['company']?.toString().isNotEmpty == true) {
      parts.add(shipping['company']);
    }

    if (shipping['name']?.toString().isNotEmpty == true) {
      parts.add(shipping['name']);
    }

    if (shipping['street']?.toString().isNotEmpty == true) {
      parts.add(shipping['street']);
    }

    final zip = shipping['zip']?.toString() ?? '';
    final city = shipping['city']?.toString() ?? '';
    if (zip.isNotEmpty || city.isNotEmpty) {
      parts.add('$zip $city'.trim());
    }

    if (shipping['country']?.toString().isNotEmpty == true) {
      parts.add(shipping['country']);
    }

    return parts.join('\n');
  }

  // ============================================================================
  // Adresse bearbeiten Dialog
  // ============================================================================
  Future<void> _showEditAddressDialog(BuildContext context, OrderX currentOrder, String type) async {
    final isBilling = type == 'billing';
    final customer = currentOrder.customer;

    // Controller initialisieren
    final companyController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final streetController = TextEditingController();
    final houseNumberController = TextEditingController();
    final zipController = TextEditingController();
    final cityController = TextEditingController();
    final provinceController = TextEditingController();
    final countryController = TextEditingController();
    final additionalLinesController = TextEditingController();
    bool useIdenticalAddress = false;

    if (isBilling) {
      // Rechnungsadresse - flache Struktur
      companyController.text = customer['company']?.toString() ?? '';
      firstNameController.text = customer['firstName']?.toString() ?? '';
      lastNameController.text = customer['lastName']?.toString() ?? '';
      streetController.text = customer['street']?.toString() ?? '';
      houseNumberController.text = customer['houseNumber']?.toString() ?? '';
      zipController.text = customer['zipCode']?.toString() ?? '';  // KORRIGIERT: war 'zip'
      cityController.text = customer['city']?.toString() ?? '';
      provinceController.text = customer['province']?.toString() ?? '';
      countryController.text = customer['country']?.toString() ?? '';
      if (customer['additionalAddressLines'] != null) {
        final lines = customer['additionalAddressLines'] as List<dynamic>;
        additionalLinesController.text = lines.join('\n');
      }

    } else {
      // Lieferadresse - prüfe ob flache oder verschachtelte Struktur
      final hasShippingNested = customer['shipping_address'] != null &&
          (customer['shipping_address'] is Map) &&
          customer['shipping_address']['street']?.toString().isNotEmpty == true;

      final hasShippingFlat = customer['hasDifferentShippingAddress'] == true &&
          customer['shippingStreet']?.toString().isNotEmpty == true;

      useIdenticalAddress = !hasShippingNested && !hasShippingFlat;

      if (hasShippingFlat) {
        // Flache Struktur (vom Customer Model)
        companyController.text = customer['shippingCompany']?.toString() ?? '';
        firstNameController.text = customer['shippingFirstName']?.toString() ?? '';
        lastNameController.text = customer['shippingLastName']?.toString() ?? '';
        streetController.text = customer['shippingStreet']?.toString() ?? '';
        houseNumberController.text = customer['shippingHouseNumber']?.toString() ?? '';
        zipController.text = customer['shippingZipCode']?.toString() ?? '';
        cityController.text = customer['shippingCity']?.toString() ?? '';
        provinceController.text = customer['shippingProvince']?.toString() ?? '';
        countryController.text = customer['shippingCountry']?.toString() ?? '';
        if (customer['shippingAdditionalAddressLines'] != null) {
          final lines = customer['shippingAdditionalAddressLines'] as List<dynamic>;
          additionalLinesController.text = lines.join('\n');
        }
      } else if (hasShippingNested) {
        // Verschachtelte Struktur
        final shipping = customer['shipping_address'] as Map<String, dynamic>;
        companyController.text = shipping['company']?.toString() ?? '';
        firstNameController.text = shipping['firstName']?.toString() ?? '';
        lastNameController.text = shipping['lastName']?.toString() ?? shipping['name']?.toString() ?? '';
        streetController.text = shipping['street']?.toString() ?? '';
        houseNumberController.text = shipping['houseNumber']?.toString() ?? '';
        zipController.text = shipping['zipCode']?.toString() ?? shipping['zip']?.toString() ?? '';
        cityController.text = shipping['city']?.toString() ?? '';
        provinceController.text = shipping['province']?.toString() ?? '';
        countryController.text = shipping['country']?.toString() ?? '';
        if (customer['shipping_address']['additionalAddressLines'] != null) {
          final lines = customer['shipping_address']['additionalAddressLines'] as List<dynamic>;
          additionalLinesController.text = lines.join('\n');
        }
      }
    }

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: isBilling ? 'receipt' : 'local_shipping',
                        defaultIcon: isBilling ? Icons.receipt : Icons.local_shipping,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isBilling ? 'Rechnungsadresse bearbeiten' : 'Lieferadresse bearbeiten',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Toggle für Lieferadresse
                        if (!isBilling) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: useIdenticalAddress
                                  ? Colors.green.withOpacity(0.1)
                                  : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: useIdenticalAddress
                                    ? Colors.green.withOpacity(0.3)
                                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: SwitchListTile(
                              title: const Text('Identisch mit Rechnungsadresse'),
                              subtitle: Text(
                                useIdenticalAddress
                                    ? 'Lieferung an Rechnungsadresse'
                                    : 'Abweichende Lieferadresse',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: useIdenticalAddress ? Colors.green[700] : null,
                                ),
                              ),
                              value: useIdenticalAddress,
                              onChanged: (value) {
                                setDialogState(() {
                                  useIdenticalAddress = value;
                                });
                              },
                              secondary: getAdaptiveIcon(
                                iconName: useIdenticalAddress ? 'check_circle' : 'edit_location',
                                defaultIcon: useIdenticalAddress ? Icons.check_circle : Icons.edit_location,
                                color: useIdenticalAddress ? Colors.green : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Adressfelder (ausgeblendet wenn identisch)
                        if (isBilling || !useIdenticalAddress) ...[
                          // Firma
                          TextField(
                            controller: companyController,
                            decoration: InputDecoration(
                              labelText: 'Firma',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: getAdaptiveIcon(iconName: 'business', defaultIcon: Icons.business),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Vorname + Nachname
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: firstNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Vorname',
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: getAdaptiveIcon(iconName: 'person', defaultIcon: Icons.person),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: lastNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nachname',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Straße + Hausnummer
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: streetController,
                                  decoration: InputDecoration(
                                    labelText: 'Straße',
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: getAdaptiveIcon(iconName: 'home', defaultIcon: Icons.home),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: houseNumberController,
                                  decoration: InputDecoration(
                                    labelText: 'Nr.',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
// NEU: Zusätzliche Adresszeilen
                          TextField(
                            controller: additionalLinesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Zusätzliche Adresszeilen',
                              hintText: 'z.B. Gebäude, Etage, Abteilung...',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: getAdaptiveIcon(iconName: 'notes', defaultIcon: Icons.notes),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // PLZ + Ort
                          Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: zipController,
                                  decoration: InputDecoration(
                                    labelText: 'PLZ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: cityController,
                                  decoration: InputDecoration(
                                    labelText: 'Ort',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Provinz
                          TextField(
                            controller: provinceController,
                            decoration: InputDecoration(
                              labelText: 'Provinz / Bundesland',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: getAdaptiveIcon(iconName: 'map', defaultIcon: Icons.map),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Land
                          TextField(
                            controller: countryController,
                            decoration: InputDecoration(
                              labelText: 'Land',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: getAdaptiveIcon(iconName: 'flag', defaultIcon: Icons.flag),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
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
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Abbrechen'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              'type': type,
                              'useIdentical': useIdenticalAddress,
                              'company': companyController.text,
                              'firstName': firstNameController.text,
                              'lastName': lastNameController.text,
                              'street': streetController.text,
                              'houseNumber': houseNumberController.text,
                              'additionalAddressLines': additionalLinesController.text,  // NEU
                              'zipCode': zipController.text,
                              'city': cityController.text,
                              'province': provinceController.text,
                              'country': countryController.text,
                            });
                          },
                          child: const Text('Speichern'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Ergebnis verarbeiten
    if (result != null) {
      await _saveAddressChanges(currentOrder, result);
    }

    // Controller aufräumen
    companyController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    streetController.dispose();
    houseNumberController.dispose();
    zipController.dispose();
    cityController.dispose();
    provinceController.dispose();
    countryController.dispose();
    additionalLinesController.dispose();
  }
  Future<void> _saveAddressChanges(OrderX currentOrder, Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String;
      final useIdentical = data['useIdentical'] as bool? ?? false;

      final updateData = <String, dynamic>{};

      if (type == 'billing') {
        // Rechnungsadresse aktualisieren (flache Struktur)
        updateData['customer.company'] = data['company'];
        updateData['customer.firstName'] = data['firstName'];
        updateData['customer.lastName'] = data['lastName'];
        updateData['customer.street'] = data['street'];
        updateData['customer.houseNumber'] = data['houseNumber'];
        updateData['customer.zipCode'] = data['zipCode'];
        updateData['customer.city'] = data['city'];
        updateData['customer.province'] = data['province'];
        updateData['customer.country'] = data['country'];
        final additionalLines = (data['additionalAddressLines'] as String?)
            ?.split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList() ?? [];
        updateData['customer.additionalAddressLines'] = additionalLines;

      } else {
        // Lieferadresse aktualisieren
        if (useIdentical) {
          // Lieferadresse entfernen (= identisch mit Rechnungsadresse)
          updateData['customer.hasDifferentShippingAddress'] = false;
          updateData['customer.shippingCompany'] = '';
          updateData['customer.shippingFirstName'] = '';
          updateData['customer.shippingLastName'] = '';
          updateData['customer.shippingStreet'] = '';
          updateData['customer.shippingHouseNumber'] = '';
          updateData['customer.shippingZipCode'] = '';
          updateData['customer.shippingCity'] = '';
          updateData['customer.shippingProvince'] = '';
          updateData['customer.shippingCountry'] = '';
          // Auch verschachtelte Struktur leeren falls vorhanden
          updateData['customer.shipping_address'] = {};
        } else {
          // Abweichende Lieferadresse setzen (flache Struktur)
          updateData['customer.hasDifferentShippingAddress'] = true;
          updateData['customer.shippingCompany'] = data['company'];
          updateData['customer.shippingFirstName'] = data['firstName'];
          updateData['customer.shippingLastName'] = data['lastName'];
          updateData['customer.shippingStreet'] = data['street'];
          updateData['customer.shippingHouseNumber'] = data['houseNumber'];
          updateData['customer.shippingZipCode'] = data['zipCode'];
          updateData['customer.shippingCity'] = data['city'];
          updateData['customer.shippingProvince'] = data['province'];
          updateData['customer.shippingCountry'] = data['country'];

          final additionalLines = (data['additionalAddressLines'] as String?)
              ?.split('\n')
              .where((line) => line.trim().isNotEmpty)
              .toList() ?? [];
          updateData['customer.shippingAdditionalAddressLines'] = additionalLines;

        }
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(currentOrder.id)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'billing'
                ? 'Rechnungsadresse aktualisiert'
                : 'Lieferadresse aktualisiert'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  // ============================================================================
  // Adresse mit Kundenstamm abgleichen
  // ============================================================================
  Future<void> _showSyncAddressDialog(BuildContext context, OrderX currentOrder) async {
    final customerId = currentOrder.customer['customerId'] ?? currentOrder.customer['id'];

    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Kunden-ID gefunden'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Kundenstammdaten laden
    final customerDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .get();

    if (!customerDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde nicht im Kundenstamm gefunden'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final masterData = customerDoc.data()!;
    final orderData = currentOrder.customer;

    // Unterschiede finden
    final differences = <String, Map<String, String>>{};

    void compare(String field, String? orderValue, String? masterValue, String label) {
      final oVal = orderValue?.trim() ?? '';
      final mVal = masterValue?.trim() ?? '';
      if (oVal != mVal) {
        differences[field] = {
          'label': label,
          'order': oVal.isEmpty ? '(leer)' : oVal,
          'master': mVal.isEmpty ? '(leer)' : mVal,
        };
      }
    }

    void compareList(String field, List<dynamic>? orderValue, List<dynamic>? masterValue, String label) {
      final oVal = (orderValue ?? []).where((e) => e.toString().trim().isNotEmpty).map((e) => e.toString().trim()).toList();
      final mVal = (masterValue ?? []).where((e) => e.toString().trim().isNotEmpty).map((e) => e.toString().trim()).toList();
      final oStr = oVal.join(', ');
      final mStr = mVal.join(', ');
      if (oStr != mStr) {
        differences[field] = {
          'label': label,
          'order': oStr.isEmpty ? '(leer)' : oStr,
          'master': mStr.isEmpty ? '(leer)' : mStr,
        };
      }
    }

    // === Rechnungsadresse ===
    compare('company', orderData['company'], masterData['company'], 'Firma');
    compare('firstName', orderData['firstName'], masterData['firstName'], 'Vorname');
    compare('lastName', orderData['lastName'], masterData['lastName'], 'Nachname');
    compare('street', orderData['street'], masterData['street'], 'Straße');
    compare('houseNumber', orderData['houseNumber'], masterData['houseNumber'], 'Hausnummer');
    compare('addressSupplement', orderData['addressSupplement'], masterData['addressSupplement'], 'Adresszusatz');
    compareList('additionalAddressLines',
        orderData['additionalAddressLines'] as List<dynamic>?,
        masterData['additionalAddressLines'] as List<dynamic>?,
        'Zusätzliche Adresszeilen');
    compare('zipCode', orderData['zipCode'], masterData['zipCode'], 'PLZ');
    compare('city', orderData['city'], masterData['city'], 'Ort');
    compare('province', orderData['province'], masterData['province'], 'Provinz');
    compare('country', orderData['country'], masterData['country'], 'Land');
    compare('email', orderData['email'], masterData['email'], 'E-Mail');
    compare('phone1', orderData['phone1'], masterData['phone1'], 'Telefon 1');
    compare('phone2', orderData['phone2'], masterData['phone2'], 'Telefon 2');
    compare('vatNumber', orderData['vatNumber'], masterData['vatNumber'], 'MwSt-Nummer');
    compare('eoriNumber', orderData['eoriNumber'], masterData['eoriNumber'], 'EORI-Nummer');

    // === Lieferadresse ===
    // Prüfe ob Kundenstamm eine abweichende Lieferadresse hat
    final masterHasShipping = masterData['hasDifferentShippingAddress'] == true;
    final orderHasShippingFlat = orderData['hasDifferentShippingAddress'] == true;
    final orderHasShippingNested = orderData['shipping_address'] != null &&
        (orderData['shipping_address'] is Map) &&
        (orderData['shipping_address'] as Map).isNotEmpty;

    if (masterHasShipping || orderHasShippingFlat || orderHasShippingNested) {
      // Hole Order-Lieferadresse (flach oder verschachtelt)
      String? getOrderShipping(String flatKey, String nestedKey) {
        if (orderHasShippingFlat) return orderData[flatKey]?.toString();
        if (orderHasShippingNested) return (orderData['shipping_address'] as Map)[nestedKey]?.toString();
        return null;
      }

      compare('shippingCompany', getOrderShipping('shippingCompany', 'company'), masterData['shippingCompany'], 'Lieferadresse: Firma');
      compare('shippingFirstName', getOrderShipping('shippingFirstName', 'firstName'), masterData['shippingFirstName'], 'Lieferadresse: Vorname');
      compare('shippingLastName', getOrderShipping('shippingLastName', 'lastName'), masterData['shippingLastName'], 'Lieferadresse: Nachname');
      compare('shippingStreet', getOrderShipping('shippingStreet', 'street'), masterData['shippingStreet'], 'Lieferadresse: Straße');
      compare('shippingHouseNumber', getOrderShipping('shippingHouseNumber', 'houseNumber'), masterData['shippingHouseNumber'], 'Lieferadresse: Hausnummer');
      compare('shippingZipCode', getOrderShipping('shippingZipCode', 'zipCode'), masterData['shippingZipCode'], 'Lieferadresse: PLZ');
      compare('shippingCity', getOrderShipping('shippingCity', 'city'), masterData['shippingCity'], 'Lieferadresse: Ort');
      compare('shippingProvince', getOrderShipping('shippingProvince', 'province'), masterData['shippingProvince'], 'Lieferadresse: Provinz');
      compare('shippingCountry', getOrderShipping('shippingCountry', 'country'), masterData['shippingCountry'], 'Lieferadresse: Land');
      compare('shippingPhone', getOrderShipping('shippingPhone', 'phone'), masterData['shippingPhone'], 'Lieferadresse: Telefon');
      compare('shippingEmail', getOrderShipping('shippingEmail', 'email'), masterData['shippingEmail'], 'Lieferadresse: E-Mail');

      // Zusätzliche Lieferadresszeilen
      List<dynamic>? orderShippingLines;
      if (orderHasShippingFlat) {
        orderShippingLines = orderData['shippingAdditionalAddressLines'] as List<dynamic>?;
      } else if (orderHasShippingNested) {
        orderShippingLines = (orderData['shipping_address'] as Map)['additionalAddressLines'] as List<dynamic>?;
      }
      compareList('shippingAdditionalAddressLines',
          orderShippingLines,
          masterData['shippingAdditionalAddressLines'] as List<dynamic>?,
          'Lieferadresse: Zusätzliche Zeilen');

      // hasDifferentShippingAddress Flag
      if ((orderHasShippingFlat || orderHasShippingNested) != masterHasShipping) {
        differences['hasDifferentShippingAddress'] = {
          'label': 'Abweichende Lieferadresse',
          'order': (orderHasShippingFlat || orderHasShippingNested) ? 'Ja' : 'Nein',
          'master': masterHasShipping ? 'Ja' : 'Nein',
        };
      }
    }

    if (!mounted) return;

    if (differences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'check_circle',
                defaultIcon: Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text('Adressdaten sind bereits identisch'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // Dialog mit Unterschieden anzeigen
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'sync',
              defaultIcon: Icons.sync,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Adressdaten abgleichen'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Folgende Unterschiede wurden gefunden:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: differences.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.value['label']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Auftrag:',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                      Text(
                                        entry.value['order']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                getAdaptiveIcon(
                                  iconName: 'arrow_forward',
                                  defaultIcon: Icons.arrow_forward,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Kundenstamm:',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                      Text(
                                        entry.value['master']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Die Auftragsdaten werden mit den aktuellen Kundenstammdaten überschrieben.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: getAdaptiveIcon(iconName: 'sync', defaultIcon: Icons.sync),
            label: const Text('Abgleichen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Auftragsdaten mit Kundenstamm aktualisieren
        final updateData = <String, dynamic>{};

        for (final field in differences.keys) {
          final masterValue = masterData[field];

          // Für Lieferadresse: Wenn die Order verschachtelte Struktur hatte,
          // auf flache Struktur umstellen
          if (field == 'hasDifferentShippingAddress') {
            updateData['customer.$field'] = masterData['hasDifferentShippingAddress'] ?? false;
            // Verschachtelte shipping_address leeren falls vorhanden
            updateData['customer.shipping_address'] = {};
          } else {
            updateData['customer.$field'] = masterValue ?? '';
          }
        }

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(currentOrder.id)
            .update(updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'check_circle',
                    defaultIcon: Icons.check_circle,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text('${differences.length} Feld(er) aktualisiert'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Abgleichen: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildInfoCard(BuildContext context, String iconName, IconData icon, String label, String value, Color? color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: 20, color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoCard(BuildContext context, String iconName, IconData icon, String value, Color? color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: 18, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color ?? Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, OrderX currentOrder) {
    final canCancel = currentOrder.status == OrderStatus.processing;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSecondaryButton(context, 'folder', Icons.folder, 'Dokumente', Theme.of(context).colorScheme.primary, () {
                //  Navigator.pop(context);
                widget.onViewDocuments(currentOrder);
              })),
              const SizedBox(width: 8),
              Expanded(child: _buildSecondaryButton(context, 'history', Icons.history, 'Verlauf', Theme.of(context).colorScheme.primary, () {
                //  Navigator.pop(context);
                widget.onShowHistory(currentOrder);
              })),
            ],
          ),
          if (canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onCancel(currentOrder);
                },
                icon: getAdaptiveIcon(iconName: 'cancel', defaultIcon: Icons.cancel, color: Colors.red, size: 18),
                label: const Text('Auftrag stornieren', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, String iconName, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildVeranlagungCard(BuildContext context, OrderX currentOrder) {
    final hasVeranlagung = currentOrder.metadata?['veranlagungsnummer'] != null &&
        currentOrder.metadata!['veranlagungsnummer'].toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasVeranlagung ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasVeranlagung ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: widget.onVeranlagung != null ? () {
          Navigator.pop(context);
          widget.onVeranlagung!(currentOrder);
        } : null,
        child: Row(
          children: [
            getAdaptiveIcon(
              iconName: hasVeranlagung ? 'assignment_turned_in' : 'assignment_late',
              defaultIcon: hasVeranlagung ? Icons.assignment_turned_in : Icons.assignment_late,
              color: hasVeranlagung ? Colors.green : Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Veranlagungsverfügung',
                    style: TextStyle(fontWeight: FontWeight.w600, color: hasVeranlagung ? Colors.green[700] : Colors.orange[700]),
                  ),
                  Text(
                    hasVeranlagung
                        ? currentOrder.metadata!['veranlagungsnummer'].toString()
                        : 'Noch nicht erfasst',
                    style: TextStyle(fontSize: 12, color: hasVeranlagung ? Colors.green[600] : Colors.orange[600]),
                  ),
                ],
              ),
            ),
            getAdaptiveIcon(iconName: 'chevron_right', defaultIcon: Icons.chevron_right, color: hasVeranlagung ? Colors.green : Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsAccordion(BuildContext context, OrderX currentOrder) {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
      collapsedBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
      title: Row(
        children: [
          getAdaptiveIcon(iconName: 'inventory_2', defaultIcon: Icons.inventory_2, size: 18),
          const SizedBox(width: 10),
          Text('Artikel (${currentOrder.items.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _buildItemsList(context, currentOrder, isDesktop: false),
        ),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context, OrderX currentOrder, {required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop) ...[
          Text('Artikel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
        ],
        ...currentOrder.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildItemCard(context, currentOrder, item, index, isDesktop);
        }).toList(),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, OrderX currentOrder, Map<String, dynamic> item, int index, bool isDesktop) {
    final qty = (item['quantity'] as num? ?? 0).toDouble();
    final isGratis = item['is_gratisartikel'] == true;
    final isService = item['is_service'] == true;
    final customPrice = item['custom_price_per_unit'];
    final price = isGratis ? 0.0 : (customPrice != null ? (customPrice as num).toDouble() : (item['price_per_unit'] as num?)?.toDouble() ?? 0.0);
    final total = (item['total'] as num?)?.toDouble() ?? (qty * price);
    final hasCustomMeasurements = (item['custom_length'] != null && item['custom_length'] > 0) ||
        (item['custom_width'] != null && item['custom_width'] > 0) ||
        (item['custom_thickness'] != null && item['custom_thickness'] > 0);

    final currencySymbol = _getCurrencySymbol(currentOrder);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: () => widget.onEditItemMeasurements(currentOrder, item, index),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isService ? (item['name'] ?? 'Dienstleistung') : (item['product_name'] ?? 'Produkt'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${qty.toStringAsFixed(0)} × ${PriceFormatter.format(
                            priceInCHF: price,
                            currency: currentOrder.metadata['currency'] ?? 'CHF',
                            exchangeRates: currentOrder.metadata['exchangeRates'] as Map<String, dynamic>?,
                            roundingSettings: _roundingSettings,
                          )}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isGratis ? Colors.green.withOpacity(0.1) : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isGratis ? 'GRATIS' : PriceFormatter.format(
                        priceInCHF: total,
                        currency: currentOrder.metadata['currency'] ?? 'CHF',
                        exchangeRates: currentOrder.metadata['exchangeRates'] as Map<String, dynamic>?,
                        roundingSettings: _roundingSettings,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isGratis ? Colors.green[700] : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasCustomMeasurements) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    getAdaptiveIcon(iconName: 'straighten', defaultIcon: Icons.straighten, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 6),
                    Text(
                      '${item['custom_length'] ?? 0} × ${item['custom_width'] ?? 0} × ${item['custom_thickness'] ?? 0} mm',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    const Spacer(),
                    getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit, size: 14, color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
                  ],
                ),
              ],
              if (!hasCustomMeasurements) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add, size: 14, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      'Maße hinzufügen',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}