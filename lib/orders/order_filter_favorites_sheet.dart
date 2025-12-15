import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/icon_helper.dart';
import 'order_filter_service.dart';
import '../orders/order_model.dart';

class OrderFilterFavoritesSheet {
  static void show(
      BuildContext context, {
        required Function(Map<String, dynamic>) onFavoriteSelected,
        required VoidCallback onCreateNew,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderFilterFavoritesBottomSheet(
        onFavoriteSelected: onFavoriteSelected,
        onCreateNew: onCreateNew,
      ),
    );
  }
}

class _OrderFilterFavoritesBottomSheet extends StatelessWidget {
  final Function(Map<String, dynamic>) onFavoriteSelected;
  final VoidCallback onCreateNew;

  const _OrderFilterFavoritesBottomSheet({
    Key? key,
    required this.onFavoriteSelected,
    required this.onCreateNew,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'star',
                  defaultIcon: Icons.star,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filter-Favoriten',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'close',
                    defaultIcon: Icons.close,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: OrderFilterService.getFavorites(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final favorites = snapshot.data?.docs ?? [];

                if (favorites.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        getAdaptiveIcon(iconName: 'star', defaultIcon:
                          Icons.star,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Noch keine Favoriten vorhanden',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onCreateNew();
                          },
                          icon:  getAdaptiveIcon(iconName: 'add', defaultIcon:Icons.add),
                          label: const Text('Ersten Favoriten erstellen'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    // Aktuellen Filter als Favorit speichern
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onCreateNew();
                        },
                        icon:  getAdaptiveIcon(iconName: 'add', defaultIcon:Icons.add),
                        label: const Text('Aktuellen Filter als Favorit speichern'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const Divider(),

                    // Favoriten Liste
                    ...favorites.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final filters = data['filters'] as Map<String, dynamic>;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child:  getAdaptiveIcon(iconName: 'filter_alt', defaultIcon:
                            Icons.filter_alt,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          data['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _getFilterDescription(filters),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon:  getAdaptiveIcon(iconName: 'delete', defaultIcon:
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _deleteFavorite(context, doc.id, data['name']),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onFavoriteSelected(data);
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterDescription(Map<String, dynamic> filters) {
    final parts = <String>[];

    // Suche
    if (filters['searchText']?.toString().isNotEmpty ?? false) {
      parts.add('Suche: "${filters['searchText']}"');
    }

    // Auftragsstatus
    final orderStatus = (filters['orderStatus'] as List?)?.cast<String>() ?? [];
    if (orderStatus.isNotEmpty) {
      final statusNames = orderStatus.map((s) {
        try {
          return OrderStatus.values.firstWhere((e) => e.name == s).displayName;
        } catch (_) {
          return s;
        }
      }).join(', ');
      parts.add('Status: $statusNames');
    }

    // Zahlungsstatus
    final paymentStatus = (filters['paymentStatus'] as List?)?.cast<String>() ?? [];
    if (paymentStatus.isNotEmpty) {
      final statusNames = paymentStatus.map((s) {
        try {
          return PaymentStatus.values.firstWhere((e) => e.name == s).displayName;
        } catch (_) {
          return s;
        }
      }).join(', ');
      parts.add('Zahlung: $statusNames');
    }

    // Betrag
    if (filters['minAmount'] != null || filters['maxAmount'] != null) {
      final min = filters['minAmount']?.toString() ?? '';
      final max = filters['maxAmount']?.toString() ?? '';
      parts.add('Betrag: ${min.isEmpty ? '' : 'ab CHF $min'}${min.isNotEmpty && max.isNotEmpty ? ' - ' : ''}${max.isEmpty ? '' : 'bis CHF $max'}');
    }

    // Veranlagung
    if (filters['veranlagungStatus'] == 'required') {
      parts.add('Veranlagung fehlt');
    } else if (filters['veranlagungStatus'] == 'completed') {
      parts.add('Veranlagung vorhanden');
    }

    return parts.isEmpty ? 'Keine Filter aktiv' : parts.join(' • ');
  }

  Future<void> _deleteFavorite(BuildContext context, String favoriteId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Favorit löschen'),
        content: Text('Möchten Sie den Favoriten "$name" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await OrderFilterService.deleteFavorite(favoriteId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Favorit wurde gelöscht'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}