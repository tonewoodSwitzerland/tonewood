// lib/analytics/sales/widgets/order_summary_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/icon_helper.dart';
import '../models/sales_analytics_models.dart';

class OrderSummarySheet {
  static void show(BuildContext context, OrderSummary order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderSummarySheetContent(order: order),
    );
  }
}

class _OrderSummarySheetContent extends StatelessWidget {
  final OrderSummary order;

  const _OrderSummarySheetContent({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'de_DE', symbol: order.currency, decimalDigits: 2);
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'receipt',
                    defaultIcon: Icons.receipt_long,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auftrag ${order.orderNumber}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.customerName,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Datum
                  _buildRow(
                    context,
                    icon: Icons.calendar_today,
                    iconName: 'calendar_today',
                    label: 'Versanddatum',
                    value: DateFormat('dd. MMMM yyyy', 'de').format(order.relevantDate),
                  ),
                  const SizedBox(height: 12),

                  // Positionen
                  _buildRow(
                    context,
                    icon: Icons.inventory_2,
                    iconName: 'inventory_2',
                    label: 'Positionen',
                    value: '${order.itemCount} Artikel',
                  ),
                  const SizedBox(height: 20),

                  // Betragsblock
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      children: [
                        _buildAmountRow(context, 'Warenwert (netto)', fmt.format(order.subtotal), isMain: false),
                        if (order.discount > 0) ...[
                          const SizedBox(height: 8),
                          _buildAmountRow(
                            context,
                            'Rabatt gewährt',
                            '− ${fmt.format(order.discount)}',
                            valueColor: Colors.orange.shade700,
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        _buildAmountRow(
                          context,
                          'Gesamtbetrag (brutto)',
                          fmt.format(order.total),
                          isMain: true,
                          valueColor: theme.colorScheme.primary,
                        ),
                      ],
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

  Widget _buildRow(
    BuildContext context, {
    required IconData icon,
    required String iconName,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        getAdaptiveIcon(
          iconName: iconName,
          defaultIcon: icon,
          size: 18,
          color: theme.colorScheme.onSurface.withOpacity(0.45),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAmountRow(
    BuildContext context,
    String label,
    String value, {
    bool isMain = false,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMain ? 14 : 13,
            fontWeight: isMain ? FontWeight.w600 : FontWeight.normal,
            color: isMain ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isMain ? 16 : 13,
            fontWeight: isMain ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? (isMain ? theme.colorScheme.onSurface : null),
          ),
        ),
      ],
    );
  }
}
