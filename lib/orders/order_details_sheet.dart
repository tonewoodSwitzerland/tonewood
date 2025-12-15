// lib/home/orders/order_details_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/icon_helper.dart';
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

class _OrderDetailsContent extends StatelessWidget {
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

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return OrderColors.pending;
      case OrderStatus.processing: return OrderColors.processing;
      case OrderStatus.shipped: return OrderColors.shipped;
      case OrderStatus.delivered: return OrderColors.delivered;
      case OrderStatus.cancelled: return OrderColors.cancelled;
    }
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending: return OrderColors.paymentPending;
      case PaymentStatus.partial: return OrderColors.paymentPartial;
      case PaymentStatus.paid: return OrderColors.paymentPaid;
    }
  }

  double _convertPrice(double priceInCHF) {
    final currency = order.metadata?['currency'] ?? 'CHF';
    if (currency == 'CHF') return priceInCHF;
    final rates = order.metadata?['exchangeRates'] as Map<String, dynamic>? ?? {};
    final rate = (rates[currency] as num?)?.toDouble() ?? 1.0;
    return priceInCHF * rate;
  }

  String get _currencySymbol => order.metadata?['currency'] ?? 'CHF';

  bool get _needsVeranlagung {
    final total = (order.calculations['total'] as num? ?? 0).toDouble();
    return total > 1000.0;
  }

  bool get _hasVeranlagung {
    return order.metadata?['veranlagungsnummer'] != null &&
        order.metadata!['veranlagungsnummer'].toString().isNotEmpty;
  }

  String _getCustomerName() {
    final c = order.customer;
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
                        // const SizedBox(width: 8),
                        // _buildStatusChip(context, currentOrder.status),
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
              _buildQuickActions(context, currentOrder),
              const SizedBox(width: 8),
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

  Widget _buildPaymentChip(BuildContext context, PaymentStatus status) {
    final color = _getPaymentStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          getAdaptiveIcon(iconName: 'payments', defaultIcon: Icons.payments, size: 14, color: color),
          const SizedBox(width: 4),
          Text(status.displayName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, OrderX currentOrder) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconAction(context, Icons.history, 'history', 'Verlauf', () {
          Navigator.pop(context);
          onShowHistory(currentOrder);
        }),
        _buildIconAction(context, Icons.folder, 'folder', 'Dokumente', () {
          Navigator.pop(context);
          onViewDocuments(currentOrder);
        }),
        _buildIconAction(context, Icons.share, 'share', 'Teilen', () => onShare(currentOrder)),
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
                _buildActionButtons(context, currentOrder),
                if (_needsVeranlagung) ...[
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
          _buildActionButtons(context, currentOrder),
          if (_needsVeranlagung) ...[
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
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auftragsstatus', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    const SizedBox(height: 4),
                    _buildStatusChip(context, currentOrder.status),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zahlung', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    const SizedBox(height: 4),
                    _buildPaymentChip(context, currentOrder.paymentStatus),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: currentOrder.status != OrderStatus.cancelled ? () {
                Navigator.pop(context);
                onStatusChange(currentOrder);
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
    final total = _convertPrice((currentOrder.calculations['total'] as num).toDouble());

    if (isDesktop) {
      return Column(
        children: [
          _buildInfoCard(context, 'business', Icons.business, 'Kunde', _getCustomerName(), null),
          const SizedBox(height: 10),
          _buildInfoCard(context, 'payments', Icons.payments, 'Betrag', '$_currencySymbol ${total.toStringAsFixed(2)}', OrderColors.delivered),
          const SizedBox(height: 10),
          _buildInfoCard(context, 'email', Icons.email, 'E-Mail', currentOrder.customer['email'] ?? '-', null),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCompactInfoCard(context, 'payments', Icons.payments, '$_currencySymbol ${total.toStringAsFixed(2)}', OrderColors.delivered)),
            const SizedBox(width: 8),
            Expanded(child: _buildCompactInfoCard(context, 'translate', Icons.translate, currentOrder.metadata?['language'] ?? 'DE', null)),
          ],
        ),
        const SizedBox(height: 8),
        _buildInfoCard(context, 'business', Icons.business, 'Kunde', _getCustomerName(), null),
      ],
    );
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
    final canCancel = currentOrder.status == OrderStatus.pending || currentOrder.status == OrderStatus.processing;

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
                Navigator.pop(context);
                onViewDocuments(currentOrder);
              })),
              const SizedBox(width: 8),
              Expanded(child: _buildSecondaryButton(context, 'history', Icons.history, 'Verlauf', Theme.of(context).colorScheme.primary, () {
                Navigator.pop(context);
                onShowHistory(currentOrder);
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
                  onCancel(currentOrder);
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
        onTap: onVeranlagung != null ? () {
          Navigator.pop(context);
          onVeranlagung!(currentOrder);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: () => onEditItemMeasurements(currentOrder, item, index),
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
                          '${qty.toStringAsFixed(0)} × $_currencySymbol ${_convertPrice(price).toStringAsFixed(2)}',
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
                      isGratis ? 'GRATIS' : '$_currencySymbol ${_convertPrice(total).toStringAsFixed(2)}',
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