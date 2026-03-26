import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../fairs/fair_management_screen.dart';
import '../fairs/fairs.dart';
import '../services/icon_helper.dart';
import '../services/user_basket_service.dart';


/// Ergebnis des Fair-Selection-Dialogs
class FairSelectionResult {
  final Fair? fair;
  final bool cleared; // true = "Keine Messe" gewählt

  const FairSelectionResult({this.fair, this.cleared = false});
}

/// Zeigt den Messe-Auswahl-Dialog und gibt das Ergebnis zurück.
///
/// Verwendung im SalesScreen:
/// ```dart
/// final result = await showFairSelectionDialog(
///   context: context,
///   currentFairStream: _temporaryFairStream,
/// );
/// if (result != null) {
///   if (result.cleared) {
///     await _clearTemporaryFair();
///   } else if (result.fair != null) {
///     await _saveTemporaryFair(result.fair!);
///   }
/// }
/// ```
Future<FairSelectionResult?> showFairSelectionDialog({
  required BuildContext context,
  required Stream<Fair?> currentFairStream,
}) {
  return showDialog<FairSelectionResult>(
    context: context,
    builder: (dialogContext) => _FairSelectionDialog(
      currentFairStream: currentFairStream,
    ),
  );
}

class _FairSelectionDialog extends StatefulWidget {
  final Stream<Fair?> currentFairStream;

  const _FairSelectionDialog({
    required this.currentFairStream,
  });

  @override
  State<_FairSelectionDialog> createState() => _FairSelectionDialogState();
}

class _FairSelectionDialogState extends State<_FairSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context),

            // Pinned Banner
            _buildPinnedBanner(context),

            // Suchfeld
            _buildSearchField(context),

            // Liste
            Expanded(child: _buildFairList(context)),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Header
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: getAdaptiveIcon(
                iconName: 'event',
                defaultIcon: Icons.event,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Messe auswählen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: getAdaptiveIcon(
              iconName: 'close',
              defaultIcon: Icons.close,
              size: 20,
            ),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Pinned Banner
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPinnedBanner(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: UserBasketService.pinnedFair.limit(1).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final fairName = data['name'] ?? '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
          child: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'push_pin',
                defaultIcon: Icons.push_pin,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Angepinnt: $fairName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Suchfeld
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Suchen...',
          prefixIcon: getAdaptiveIcon(
            iconName: 'search',
            defaultIcon: Icons.search,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.4),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          isDense: true,
          suffixIcon: _searchTerm.isNotEmpty
              ? IconButton(
            icon: getAdaptiveIcon(
              iconName: 'clear',
              defaultIcon: Icons.clear,
              size: 18,
            ),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchTerm = '');
            },
          )
              : null,
        ),
        onChanged: (value) => setState(() => _searchTerm = value.toLowerCase()),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Messe-Liste
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFairList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fairs')
          .where('endDate',
          isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
          .orderBy('endDate')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(
                  iconName: 'error',
                  defaultIcon: Icons.error,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Fehler beim Laden',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final fairs = snapshot.data?.docs
            .map((doc) =>
            Fair.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList() ??
            [];

        final filteredFairs = fairs.where((fair) {
          if (_searchTerm.isEmpty) return true;
          return fair.name.toLowerCase().contains(_searchTerm) ||
              fair.city.toLowerCase().contains(_searchTerm) ||
              fair.country.toLowerCase().contains(_searchTerm);
        }).toList();

        if (filteredFairs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(
                  iconName: 'event_busy',
                  defaultIcon: Icons.event_busy,
                  size: 40,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Keine aktiven Messen gefunden',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<Fair?>(
          stream: widget.currentFairStream,
          builder: (context, selectedSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: UserBasketService.pinnedFair.limit(1).snapshots(),
              builder: (context, pinnedSnapshot) {
                final pinnedFairId = pinnedSnapshot.hasData &&
                    pinnedSnapshot.data!.docs.isNotEmpty
                    ? pinnedSnapshot.data!.docs.first.id
                    : null;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredFairs.length,
                  itemBuilder: (context, index) {
                    final fair = filteredFairs[index];
                    final isSelected = selectedSnapshot.data?.id == fair.id;
                    final isPinned = pinnedFairId == fair.id;
                    final now = DateTime.now();
                    final isOngoing =
                        fair.startDate.isBefore(now) && fair.endDate.isAfter(now);
                    final daysUntilStart =
                        fair.startDate.difference(now).inDays;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Card(
                        elevation: isSelected ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected
                              ? BorderSide(
                            color:
                            Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          )
                              : isPinned
                              ? BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.4),
                          )
                              : BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.1),
                          ),
                        ),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(
                              context,
                              FairSelectionResult(fair: fair),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.2)
                                        : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: getAdaptiveIcon(
                                      iconName: 'event',
                                      defaultIcon: Icons.event,
                                      size: 20,
                                      color: isSelected
                                          ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          : Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Inhalt
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              fair.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow:
                                              TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isPinned)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 4),
                                              child: getAdaptiveIcon(
                                                iconName: 'push_pin',
                                                defaultIcon: Icons.push_pin,
                                                size: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${fair.city}, ${fair.country}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '${DateFormat('dd.MM.yyyy').format(fair.startDate)} – '
                                                '${DateFormat('dd.MM.yyyy').format(fair.endDate)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (isOngoing)
                                            _buildChip(
                                                context, 'Läuft', Colors.green)
                                          else if (daysUntilStart > 0)
                                            _buildChip(
                                              context,
                                              'In $daysUntilStart ${daysUntilStart == 1 ? 'Tag' : 'Tagen'}',
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Check wenn ausgewählt
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: getAdaptiveIcon(
                                      iconName: 'check_circle',
                                      defaultIcon: Icons.check_circle,
                                      size: 22,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Footer
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pin-Button (nur wenn eine Messe ausgewählt ist)
          StreamBuilder<Fair?>(
            stream: widget.currentFairStream,
            builder: (context, fairSnapshot) {
              if (fairSnapshot.data == null) return const SizedBox.shrink();

              return StreamBuilder<QuerySnapshot>(
                stream: UserBasketService.pinnedFair.limit(1).snapshots(),
                builder: (context, pinnedSnapshot) {
                  final isPinned = pinnedSnapshot.hasData &&
                      pinnedSnapshot.data!.docs.isNotEmpty &&
                      pinnedSnapshot.data!.docs.first.id ==
                          fairSnapshot.data!.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _togglePin(
                          fairSnapshot.data!,
                          isPinned,
                        ),
                        icon: getAdaptiveIcon(
                          iconName: 'push_pin',
                          defaultIcon: isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 18,
                          color: isPinned
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        label: Text(
                          isPinned
                              ? 'Messe losgelöst'
                              : 'Aktuelle Messe anpinnen',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: isPinned
                              ? BorderSide(
                              color:
                              Theme.of(context).colorScheme.primary)
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Action-Buttons
          Row(
            children: [
              // Keine Messe
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      const FairSelectionResult(cleared: true),
                    );
                  },
                  child: Text(
                    'Keine Messe',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Messen verwalten
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FairManagementScreen(),
                      ),
                    );
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'settings',
                    defaultIcon: Icons.settings,
                    size: 18,
                  ),
                  label: const Text(
                    'Verwalten',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Pin Logic
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _togglePin(Fair fair, bool currentlyPinned) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final docs = await UserBasketService.pinnedFair.get();
      for (var doc in docs.docs) {
        batch.delete(doc.reference);
      }

      if (!currentlyPinned) {
        batch.set(
          UserBasketService.pinnedFair.doc(fair.id),
          {
            ...fair.toMap(),
            'pinned_at': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyPinned
                  ? 'Messe losgelöst'
                  : '${fair.name} angepinnt – bleibt nach Warenkorb leeren',
            ),
            backgroundColor: currentlyPinned ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Pinnen: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}