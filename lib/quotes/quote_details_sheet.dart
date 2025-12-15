// lib/home/quotes/quote_details_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/quotes/quote_model.dart';
import 'package:url_launcher/url_launcher.dart';


import '../../services/icon_helper.dart';
import '../../constants.dart';

// Farben und Status aus der Hauptdatei importieren oder hier definieren
class QuoteColors {
  static const open = Color(0xFF2196F3);
  static const accepted = Color(0xFF4CAF50);
  static const rejected = Color(0xFFF44336);
  static const expired = Color(0xFF9E9E9E);
}

enum QuoteViewStatus { open, accepted, rejected, expired }

extension QuoteViewStatusX on QuoteViewStatus {
  String get displayName => ['Offen', 'Angenommen', 'Abgelehnt', 'Abgelaufen'][index];
  Color get color => [QuoteColors.open, QuoteColors.accepted, QuoteColors.rejected, QuoteColors.expired][index];
}

class QuoteDetailsSheet extends StatelessWidget {
  final Quote quote;
  final Function(Quote) onConvertToOrder;
  final Function(Quote) onReject;
  final Function(Quote) onEdit;
  final Function(Quote) onCopy;
  final Function(Quote) onViewPdf;
  final Function(Quote) onShare;
  final Function(Quote) onShowHistory;

  const QuoteDetailsSheet({
    Key? key,
    required this.quote,
    required this.onConvertToOrder,
    required this.onReject,
    required this.onEdit,
    required this.onCopy,
    required this.onViewPdf,
    required this.onShare,
    required this.onShowHistory,
  }) : super(key: key);

  static void show(
      BuildContext context, {
        required Quote quote,
        required Function(Quote) onConvertToOrder,
        required Function(Quote) onReject,
        required Function(Quote) onEdit,
        required Function(Quote) onCopy,
        required Function(Quote) onViewPdf,
        required Function(Quote) onShare,
        required Function(Quote) onShowHistory,
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
            child: QuoteDetailsSheet(
              quote: quote,
              onConvertToOrder: onConvertToOrder,
              onReject: onReject,
              onEdit: onEdit,
              onCopy: onCopy,
              onViewPdf: onViewPdf,
              onShare: onShare,
              onShowHistory: onShowHistory,
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
          child: QuoteDetailsSheet(
            quote: quote,
            onConvertToOrder: onConvertToOrder,
            onReject: onReject,
            onEdit: onEdit,
            onCopy: onCopy,
            onViewPdf: onViewPdf,
            onShare: onShare,
            onShowHistory: onShowHistory,
          ),
        ),
      );
    }
  }

  QuoteViewStatus get viewStatus {
    if (quote.status == QuoteStatus.accepted) return QuoteViewStatus.accepted;
    if (quote.status == QuoteStatus.rejected) return QuoteViewStatus.rejected;
    if (quote.validUntil.isBefore(DateTime.now())) return QuoteViewStatus.expired;
    return QuoteViewStatus.open;
  }

  bool get isOpen => viewStatus == QuoteViewStatus.open;

  double _convertPrice(double priceInCHF) {
    final currency = quote.metadata['currency'] ?? 'CHF';
    if (currency == 'CHF') return priceInCHF;
    final rates = quote.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
    final rate = (rates[currency] as num?)?.toDouble() ?? 1.0;
    return priceInCHF * rate;
  }

  String get _currencySymbol => quote.metadata['currency'] ?? 'CHF';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Column(
      children: [
        _buildHeader(context, isDesktop),
        Expanded(
          child: isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context),
        ),
      ],
    );
  }

  // ===== HEADER =====
  Widget _buildHeader(BuildContext context, bool isDesktop) {
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
                          'Angebot ${quote.quoteNumber}',
                          style: TextStyle(
                            fontSize: isDesktop ? 22 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // const SizedBox(width: 12),
                        // _buildStatusChip(context),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Erstellt am ${DateFormat('dd.MM.yyyy').format(quote.createdAt)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Quick Actions im Header
              _buildQuickActions(context),
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

  Widget _buildStatusChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: viewStatus.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: viewStatus.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            viewStatus.displayName,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: viewStatus.color),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconAction(context, Icons.history, 'history', 'Verlauf', () {
          Navigator.pop(context);
          onShowHistory(quote);
        }),
        _buildIconAction(context, Icons.picture_as_pdf, 'picture_as_pdf', 'PDF', () => onViewPdf(quote)),
        _buildIconAction(context, Icons.share, 'share', 'Teilen', () => onShare(quote)),
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
          child: getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  // ===== DESKTOP LAYOUT =====
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linke Spalte: Infos + Aktionen
        SizedBox(
          width: 320,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildPrimaryActions(context),
                const SizedBox(height: 20),
                _buildInfoCards(context, isDesktop: true),
                const SizedBox(height: 20),
                _buildSecondaryActions(context),
                if (quote.isOrderCancelled) ...[
                  const SizedBox(height: 20),
                  _buildCancellationWarning(context),
                ],
              ],
            ),
          ),
        ),
        // Vertikale Trennlinie
        Container(width: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
        // Rechte Spalte: Artikel
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildItemsList(context, isDesktop: true),
          ),
        ),
      ],
    );
  }

  // ===== MOBILE LAYOUT =====
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote.isOrderCancelled) ...[
            _buildCancellationWarning(context),
            const SizedBox(height: 16),
          ],
          _buildPrimaryActions(context),
          const SizedBox(height: 16),
          _buildInfoCards(context, isDesktop: false),
          const SizedBox(height: 16),
          _buildSecondaryActions(context),
          const SizedBox(height: 20),
          _buildItemsAccordion(context),
        ],
      ),
    );
  }

  // ===== PRIMARY ACTIONS (Beauftragen / Ablehnen) =====
  Widget _buildPrimaryActions(BuildContext context) {
    if (!isOpen) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: viewStatus.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: viewStatus.color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            getAdaptiveIcon(
              iconName: viewStatus == QuoteViewStatus.accepted ? 'check_circle' : 'info',
              defaultIcon: viewStatus == QuoteViewStatus.accepted ? Icons.check_circle : Icons.info,
              color: viewStatus.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                viewStatus == QuoteViewStatus.accepted
                    ? 'Dieses Angebot wurde angenommen'
                    : viewStatus == QuoteViewStatus.rejected
                    ? 'Dieses Angebot wurde abgelehnt'
                    : 'Dieses Angebot ist abgelaufen',
                style: TextStyle(color: viewStatus.color, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onConvertToOrder(quote);
            },
            icon: getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon: Icons.shopping_cart, color: Colors.white),
            label: const Text('Auftrag erstellen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuoteColors.accepted,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onReject(quote);
            },
            icon: getAdaptiveIcon(iconName: 'cancel', defaultIcon: Icons.cancel, color: QuoteColors.rejected),
            label: Text('Ablehnen', style: TextStyle(color: QuoteColors.rejected)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: QuoteColors.rejected.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ===== INFO CARDS =====
  Widget _buildInfoCards(BuildContext context, {required bool isDesktop}) {
    final total = _convertPrice((quote.calculations['total'] as num).toDouble());

    if (isDesktop) {
      return Column(
        children: [
          _buildInfoCard(context, 'business', Icons.business, 'Kunde', _getCustomerName(), null),
          const SizedBox(height: 10),
          _buildInfoCard(context, 'payments', Icons.payments, 'Betrag', '$_currencySymbol ${total.toStringAsFixed(2)}', QuoteColors.accepted),
          const SizedBox(height: 10),
          _buildInfoCard(
            context, 'timer', Icons.timer, 'Gültig bis',
            DateFormat('dd.MM.yyyy').format(quote.validUntil),
            viewStatus == QuoteViewStatus.expired ? QuoteColors.expired : null,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildCompactInfoCard(context, 'payments', Icons.payments, '$_currencySymbol ${total.toStringAsFixed(2)}', QuoteColors.accepted)),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactInfoCard(
            context, 'timer', Icons.timer,
            DateFormat('dd.MM').format(quote.validUntil),
            viewStatus == QuoteViewStatus.expired ? QuoteColors.expired : null,
          ),
        ),
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

  // ===== SECONDARY ACTIONS =====
  Widget _buildSecondaryActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (isOpen) ...[
            Expanded(child: _buildSecondaryButton(context, 'edit', Icons.edit, 'Bearbeiten', goldenColour, () {
              Navigator.pop(context);
              onEdit(quote);
            })),
            const SizedBox(width: 8),
          ],
          Expanded(child: _buildSecondaryButton(context, 'content_copy', Icons.content_copy, 'Kopieren', Theme.of(context).colorScheme.primary, () {
            Navigator.pop(context);
            onCopy(quote);
          })),
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

  // ===== CANCELLATION WARNING =====
  Widget _buildCancellationWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(iconName: 'warning', defaultIcon: Icons.warning, color: Colors.red[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auftrag storniert', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700])),
                if (quote.orderCancelledAt != null)
                  Text(
                    'am ${DateFormat('dd.MM.yyyy').format(quote.orderCancelledAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.red[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== ITEMS ACCORDION (Mobile) =====
  Widget _buildItemsAccordion(BuildContext context) {
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
          Text('Artikel (${quote.items.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _buildItemsList(context, isDesktop: false),
        ),
      ],
    );
  }

  // ===== ITEMS LIST =====
  Widget _buildItemsList(BuildContext context, {required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop) ...[
          Text('Artikel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
        ],
        ...quote.items.map((item) => _buildItemCard(context, item, isDesktop)).toList(),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item, bool isDesktop) {
    final qty = (item['quantity'] as num? ?? 0).toDouble();
    final price = (item['price_per_unit'] as num?)?.toDouble() ?? 0.0;
    final total = (item['total'] as num?)?.toDouble() ?? (qty * price);
    final isGratis = item['is_gratisartikel'] == true;
    final isService = item['is_service'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
      ),
      child: Row(
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
    );
  }

  String _getCustomerName() {
    final c = quote.customer;
    if (c['company']?.toString().trim().isNotEmpty == true) return c['company'];
    if (c['fullName']?.toString().trim().isNotEmpty == true) return c['fullName'];
    return '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
  }
}