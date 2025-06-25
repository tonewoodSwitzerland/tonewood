// lib/screens/analytics/sales/widgets/sales_list_item.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/icon_helper.dart';
import '../models/sales_models.dart';

class SalesListItem extends StatelessWidget {
  final SaleItem sale;
  final VoidCallback onTap;

  const SalesListItem({
    Key? key,
    required this.sale,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child:
              getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon: Icons.shopping_cart,  color: theme.colorScheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(sale.customer['company'] as String),
            ),
            Text(
              NumberFormat.currency(
                locale: 'de_CH',
                symbol: 'CHF',
              ).format(sale.calculations['total']),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${sale.quantity}x ${sale.productName}'),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(sale.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}