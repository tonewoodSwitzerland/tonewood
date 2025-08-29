import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/icon_helper.dart';
import 'customer_filter_service.dart';

class CustomerFilterFavoritesSheet {
  static void show(
      BuildContext context, {
        required Function(Map<String, dynamic>) onFavoriteSelected,
        required VoidCallback onCreateNew,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerFilterFavoritesBottomSheet(
        onFavoriteSelected: onFavoriteSelected,
        onCreateNew: onCreateNew,
      ),
    );
  }
}

class _CustomerFilterFavoritesBottomSheet extends StatelessWidget {
  final Function(Map<String, dynamic>) onFavoriteSelected;
  final VoidCallback onCreateNew;

  const _CustomerFilterFavoritesBottomSheet({
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
                Icon(
                  Icons.star,
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
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: CustomerFilterService.getFavorites(),
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
                        Icon(
                          Icons.star_border,
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
                          icon: const Icon(Icons.add),
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
                        icon: const Icon(Icons.add),
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

                      // Konvertiere Timestamps zurück zu DateTime
                      if (filters['revenueStartDate'] != null && filters['revenueStartDate'] is Timestamp) {
                        filters['revenueStartDate'] = (filters['revenueStartDate'] as Timestamp).toDate();
                      }
                      if (filters['revenueEndDate'] != null && filters['revenueEndDate'] is Timestamp) {
                        filters['revenueEndDate'] = (filters['revenueEndDate'] as Timestamp).toDate();
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(
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
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _deleteFavorite(context, doc.id, data['name']),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onFavoriteSelected({
                            'name': data['name'],
                            'filters': filters,
                          });
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

    // Umsatz
    if (filters['minRevenue'] != null || filters['maxRevenue'] != null) {
      final min = filters['minRevenue']?.toString() ?? '';
      final max = filters['maxRevenue']?.toString() ?? '';
      parts.add('Umsatz: ${min.isEmpty ? '' : 'ab CHF $min'}${min.isNotEmpty && max.isNotEmpty ? ' - ' : ''}${max.isEmpty ? '' : 'bis CHF $max'}');
    }

    // Zeitraum
    if (filters['revenueStartDate'] != null || filters['revenueEndDate'] != null) {
      final start = filters['revenueStartDate'] != null
          ? DateFormat('dd.MM.yy').format(filters['revenueStartDate'] as DateTime)
          : '';
      final end = filters['revenueEndDate'] != null
          ? DateFormat('dd.MM.yy').format(filters['revenueEndDate'] as DateTime)
          : '';
      parts.add('Zeitraum: ${start.isEmpty ? '' : 'ab $start'}${start.isNotEmpty && end.isNotEmpty ? ' - ' : ''}${end.isEmpty ? '' : 'bis $end'}');
    }

    // Aufträge
    if (filters['minOrderCount'] != null || filters['maxOrderCount'] != null) {
      final min = filters['minOrderCount']?.toString() ?? '';
      final max = filters['maxOrderCount']?.toString() ?? '';
      parts.add('Aufträge: ${min.isEmpty ? '' : 'ab $min'}${min.isNotEmpty && max.isNotEmpty ? ' - ' : ''}${max.isEmpty ? '' : 'bis $max'}');
    }

    // Weihnachtskarte
    if (filters['wantsChristmasCard'] != null) {
      parts.add('Weihnachtskarte: ${filters['wantsChristmasCard'] ? 'JA' : 'NEIN'}');
    }

    // Länder
    final countries = filters['countries'] as List? ?? [];
    if (countries.isNotEmpty) {
      parts.add('${countries.length} Länder');
    }

    // Sprachen
    final languages = filters['languages'] as List? ?? [];
    if (languages.isNotEmpty) {
      parts.add('${languages.length} Sprachen');
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
      await CustomerFilterService.deleteFavorite(favoriteId);

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