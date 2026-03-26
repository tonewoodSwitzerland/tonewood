import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/icon_helper.dart';
import '../services/user_basket_service.dart';
import 'fairs.dart';

class FairManagementScreen extends StatefulWidget {
  const FairManagementScreen({Key? key}) : super(key: key);

  @override
  FairManagementScreenState createState() => FairManagementScreenState();
}

class FairManagementScreenState extends State<FairManagementScreen> {
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messeverwaltung'),
        actions: [
          IconButton(
            icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
            tooltip: 'Neue Messe',
            onPressed: () => _showFairSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned Fair Banner
          _buildPinnedFairBanner(),

          // Suchleiste
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Messe suchen...',
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
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'clear',
                    defaultIcon: Icons.clear,
                    size: 20,
                  ),
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          // Messe-Liste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fairs')
                  .orderBy('startDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Fehler: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final fairs = snapshot.data?.docs ?? [];
                final searchTerm = searchController.text.toLowerCase();

                final filteredFairs = fairs.where((doc) {
                  final fair = Fair.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                  return fair.name.toLowerCase().contains(searchTerm) ||
                      fair.location.toLowerCase().contains(searchTerm) ||
                      fair.city.toLowerCase().contains(searchTerm);
                }).toList();

                if (filteredFairs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        getAdaptiveIcon(
                          iconName: 'event_busy',
                          defaultIcon: Icons.event_busy,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Keine Messen gefunden',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Aufteilen in aktive und vergangene Messen
                final now = DateTime.now();
                final activeFairs = <QueryDocumentSnapshot>[];
                final pastFairs = <QueryDocumentSnapshot>[];

                for (final doc in filteredFairs) {
                  final fair = Fair.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                  if (fair.endDate.isAfter(now) ||
                      fair.endDate.isAtSameMomentAs(now)) {
                    activeFairs.add(doc);
                  } else {
                    pastFairs.add(doc);
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream:
                  UserBasketService.pinnedFair.limit(1).snapshots(),
                  builder: (context, pinnedSnapshot) {
                    final pinnedFairId =
                    pinnedSnapshot.hasData &&
                        pinnedSnapshot.data!.docs.isNotEmpty
                        ? pinnedSnapshot.data!.docs.first.id
                        : null;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      children: [
                        // Aktive Messen
                        if (activeFairs.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Aktive & kommende Messen',
                            Icons.event_available,
                            count: activeFairs.length,
                          ),
                          const SizedBox(height: 8),
                          ...activeFairs.map((doc) {
                            final fair = Fair.fromMap(
                              doc.data() as Map<String, dynamic>,
                              doc.id,
                            );
                            return _buildFairCard(
                              context,
                              fair,
                              isActive: true,
                              isPinned: pinnedFairId == fair.id,
                            );
                          }),
                          const SizedBox(height: 24),
                        ],

                        // Vergangene Messen
                        if (pastFairs.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Vergangene Messen',
                            Icons.history,
                            count: pastFairs.length,
                          ),
                          const SizedBox(height: 8),
                          ...pastFairs.map((doc) {
                            final fair = Fair.fromMap(
                              doc.data() as Map<String, dynamic>,
                              doc.id,
                            );
                            return _buildFairCard(
                              context,
                              fair,
                              isActive: false,
                              isPinned: pinnedFairId == fair.id,
                            );
                          }),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFairSheet(context),
        icon: getAdaptiveIcon(
          iconName: 'add',
          defaultIcon: Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        label: const Text('Neue Messe'),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Pinned Fair Banner
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPinnedFairBanner() {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'push_pin',
                defaultIcon: Icons.push_pin,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Angepinnt: $fairName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _unpinFair(),
                icon: getAdaptiveIcon(
                  iconName: 'close',
                  defaultIcon: Icons.close,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  'Lösen',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Section Header
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(
      BuildContext context,
      String title,
      IconData icon, {
        int? count,
      }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Row(
        children: [
          getAdaptiveIcon(
            iconName: icon.toString().split('.').last,
            defaultIcon: icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Fair Card
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFairCard(
      BuildContext context,
      Fair fair, {
        required bool isActive,
        required bool isPinned,
      }) {
    final now = DateTime.now();
    final isOngoing =
        fair.startDate.isBefore(now) && fair.endDate.isAfter(now);
    final daysUntilStart = fair.startDate.difference(now).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isPinned ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isPinned
              ? BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          )
              : BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          ),
        ),
        color: isPinned
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : isActive
            ? null
            : Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showFairDetailsSheet(context, fair),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Name + Status + Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1)
                            : Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: getAdaptiveIcon(
                          iconName: 'event',
                          defaultIcon: Icons.event,
                          size: 22,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + Ort
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fair.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        : Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPinned)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: getAdaptiveIcon(
                                    iconName: 'push_pin',
                                    defaultIcon: Icons.push_pin,
                                    size: 16,
                                    color:
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${fair.city}, ${fair.country}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    _buildCardActions(context, fair, isPinned, isActive),
                  ],
                ),

                const SizedBox(height: 10),

                // Bottom Row: Datum + Status-Chips
                Row(
                  children: [
                    // Datum
                    getAdaptiveIcon(
                      iconName: 'date_range',
                      defaultIcon: Icons.date_range,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('dd.MM.yyyy').format(fair.startDate)} – ${DateFormat('dd.MM.yyyy').format(fair.endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const Spacer(),

                    // Kostenstelle
                    if (fair.costCenterCode.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'KST ${fair.costCenterCode}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Status Chip
                    if (isOngoing)
                      _buildStatusChip(context, 'Läuft', Colors.green)
                    else if (isActive && daysUntilStart > 0)
                      _buildStatusChip(
                        context,
                        'In $daysUntilStart ${daysUntilStart == 1 ? 'Tag' : 'Tagen'}',
                        Theme.of(context).colorScheme.primary,
                      )
                    else if (!isActive)
                        _buildStatusChip(
                          context,
                          'Beendet',
                          Theme.of(context).colorScheme.outline,
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCardActions(
      BuildContext context,
      Fair fair,
      bool isPinned,
      bool isActive,
      ) {
    return PopupMenuButton<String>(
      icon: getAdaptiveIcon(
        iconName: 'more_vert',
        defaultIcon: Icons.more_vert,
        size: 20,
        color: Theme.of(context).colorScheme.outline,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'pin':
            await _togglePin(fair, isPinned);
            break;
          case 'edit':
            _showFairSheet(context, fair: fair);
            break;
          case 'delete':
            _showDeleteFairDialog(fair);
            break;
        }
      },
      itemBuilder: (context) => [
        if (isActive)
          PopupMenuItem(
            value: 'pin',
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'push_pin',
                  defaultIcon:
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 20,
                  color: isPinned
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 12),
                Text(isPinned ? 'Messe lösen' : 'Messe anpinnen'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'edit',
                defaultIcon: Icons.edit,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Bearbeiten'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'delete',
                defaultIcon: Icons.delete,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Text(
                'Löschen',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Pin / Unpin Logic
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
                  ? '${fair.name} losgelöst'
                  : '${fair.name} angepinnt – wird automatisch im Warenkorb gesetzt',
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

  Future<void> _unpinFair() async {
    try {
      final docs = await UserBasketService.pinnedFair.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Messe losgelöst'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Lösen: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Navigation Helpers
  // ═══════════════════════════════════════════════════════════════════
  void _showFairSheet(BuildContext context, {Fair? fair}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FairFormSheet(fair: fair),
    );
  }

  void _showFairDetailsSheet(BuildContext context, Fair fair) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FairDetailsSheet(
        fair: fair,
        onEdit: () {
          Navigator.pop(context);
          _showFairSheet(context, fair: fair);
        },
        onPin: () async {
          final pinnedSnapshot =
          await UserBasketService.pinnedFair.limit(1).get();
          final isPinned = pinnedSnapshot.docs.isNotEmpty &&
              pinnedSnapshot.docs.first.id == fair.id;
          await _togglePin(fair, isPinned);
        },
      ),
    );
  }

  void _showDeleteFairDialog(Fair fair) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'warning',
              defaultIcon: Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Text('Messe löschen'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Möchtest du die folgende Messe wirklich löschen?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fair.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${fair.city}, ${fair.country}'),
                  Text(
                    '${DateFormat('dd.MM.yyyy').format(fair.startDate)} – '
                        '${DateFormat('dd.MM.yyyy').format(fair.endDate)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                // Falls diese Messe gepinnt ist, auch den Pin löschen
                final pinnedDocs =
                await UserBasketService.pinnedFair.limit(1).get();
                if (pinnedDocs.docs.isNotEmpty &&
                    pinnedDocs.docs.first.id == fair.id) {
                  await pinnedDocs.docs.first.reference.delete();
                }

                await FirebaseFirestore.instance
                    .collection('fairs')
                    .doc(fair.id)
                    .delete();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Messe erfolgreich gelöscht'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Löschen: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon:
            getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
            label: const Text('Löschen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FairFormSheet (Neu/Bearbeiten)
// ═══════════════════════════════════════════════════════════════════════════
class FairFormSheet extends StatefulWidget {
  final Fair? fair;

  const FairFormSheet({Key? key, this.fair}) : super(key: key);

  @override
  State<FairFormSheet> createState() => _FairFormSheetState();
}

class _FairFormSheetState extends State<FairFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController locationController;
  late final TextEditingController costCenterController;
  late final TextEditingController startDateController;
  late final TextEditingController endDateController;
  late final TextEditingController countryController;
  late final TextEditingController cityController;
  late final TextEditingController addressController;
  late final TextEditingController notesController;

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.fair?.name ?? '');
    locationController =
        TextEditingController(text: widget.fair?.location ?? '');
    costCenterController =
        TextEditingController(text: widget.fair?.costCenterCode ?? '');
    startDateController = TextEditingController(
      text: widget.fair != null
          ? DateFormat('dd.MM.yyyy').format(widget.fair!.startDate)
          : '',
    );
    endDateController = TextEditingController(
      text: widget.fair != null
          ? DateFormat('dd.MM.yyyy').format(widget.fair!.endDate)
          : '',
    );
    countryController =
        TextEditingController(text: widget.fair?.country ?? 'Schweiz');
    cityController = TextEditingController(text: widget.fair?.city ?? '');
    addressController = TextEditingController(text: widget.fair?.address ?? '');
    notesController = TextEditingController(text: widget.fair?.notes ?? '');

    selectedStartDate = widget.fair?.startDate;
    selectedEndDate = widget.fair?.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.fair != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: isEdit ? 'edit' : 'add_circle',
                  defaultIcon: isEdit ? Icons.edit : Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  isEdit ? 'Messe bearbeiten' : 'Neue Messe',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: getAdaptiveIcon(
                      iconName: 'close', defaultIcon: Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollbarer Inhalt
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Allgemeine Informationen', Icons.info),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Messebezeichnung *',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                            iconName: 'event',
                            defaultIcon: Icons.event,
                          ),
                        ),
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Bitte Bezeichnung eingeben'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: costCenterController,
                      decoration: InputDecoration(
                        labelText:
                        isEdit ? 'Kostenstelle' : 'Kostenstelle *',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                            iconName: 'account_balance_wallet',
                            defaultIcon: Icons.account_balance_wallet,
                          ),
                        ),
                      ),
                      validator: isEdit
                          ? null
                          : (value) => value?.isEmpty == true
                          ? 'Bitte Kostenstelle eingeben'
                          : null,
                    ),

                    const SizedBox(height: 24),

                    _buildSectionTitle('Zeitraum', Icons.date_range),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startDateController,
                            decoration: InputDecoration(
                              labelText: 'Startdatum *',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor:
                              Theme.of(context).colorScheme.surface,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(
                                  iconName: 'calendar_today',
                                  defaultIcon: Icons.calendar_today,
                                ),
                              ),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate:
                                selectedStartDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedStartDate = date;
                                  startDateController.text =
                                      DateFormat('dd.MM.yyyy').format(date);
                                });
                              }
                            },
                            validator: (value) => value?.isEmpty == true
                                ? 'Bitte Startdatum wählen'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endDateController,
                            decoration: InputDecoration(
                              labelText: 'Enddatum *',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor:
                              Theme.of(context).colorScheme.surface,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(
                                  iconName: 'calendar_today',
                                  defaultIcon: Icons.calendar_today,
                                ),
                              ),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedEndDate ??
                                    selectedStartDate ??
                                    DateTime.now(),
                                firstDate:
                                selectedStartDate ?? DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedEndDate = date;
                                  endDateController.text =
                                      DateFormat('dd.MM.yyyy').format(date);
                                });
                              }
                            },
                            validator: (value) => value?.isEmpty == true
                                ? 'Bitte Enddatum wählen'
                                : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSectionTitle('Veranstaltungsort', Icons.location_on),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Adresse',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                            iconName: 'home',
                            defaultIcon: Icons.home,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityController,
                            decoration: InputDecoration(
                              labelText: 'Stadt',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor:
                              Theme.of(context).colorScheme.surface,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(
                                  iconName: 'location_city',
                                  defaultIcon: Icons.location_city,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: countryController,
                            decoration: InputDecoration(
                              labelText: 'Land',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor:
                              Theme.of(context).colorScheme.surface,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: getAdaptiveIcon(
                                  iconName: 'public',
                                  defaultIcon: Icons.public,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSectionTitle(
                        'Zusätzliche Informationen', Icons.notes),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notizen',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getAdaptiveIcon(
                            iconName: 'note',
                            defaultIcon: Icons.note,
                          ),
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      '* Pflichtfelder',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer mit Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveFair,
                      icon: getAdaptiveIcon(
                        iconName: 'save',
                        defaultIcon: Icons.save,
                        color: Colors.white,
                      ),
                      label: const Text('Speichern'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor:
                        Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        getAdaptiveIcon(
          iconName: icon.toString().split('.').last,
          defaultIcon: icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  void _saveFair() async {
    if (_formKey.currentState?.validate() == true &&
        selectedStartDate != null &&
        selectedEndDate != null) {
      final fair = Fair(
        id: widget.fair?.id ?? '',
        name: nameController.text,
        location: locationController.text,
        costCenterCode: costCenterController.text,
        startDate: selectedStartDate!,
        endDate: selectedEndDate!,
        country: countryController.text,
        city: cityController.text,
        address: addressController.text,
        notes: notesController.text,
      );

      try {
        if (widget.fair == null) {
          await FirebaseFirestore.instance
              .collection('fairs')
              .add(fair.toMap());
        } else {
          await FirebaseFirestore.instance
              .collection('fairs')
              .doc(fair.id)
              .update(fair.toMap());
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.fair == null
                  ? 'Messe erfolgreich angelegt'
                  : 'Messe erfolgreich aktualisiert'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    costCenterController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    countryController.dispose();
    cityController.dispose();
    addressController.dispose();
    notesController.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FairDetailsSheet
// ═══════════════════════════════════════════════════════════════════════════
class FairDetailsSheet extends StatelessWidget {
  final Fair fair;
  final VoidCallback onEdit;
  final VoidCallback? onPin;

  const FairDetailsSheet({
    Key? key,
    required this.fair,
    required this.onEdit,
    this.onPin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive = fair.endDate.isAfter(now);
    final isOngoing = fair.startDate.isBefore(now) && fair.endDate.isAfter(now);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.1)
                        : Theme.of(context)
                        .colorScheme
                        .outline
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: getAdaptiveIcon(
                      iconName: 'event',
                      defaultIcon: Icons.event,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fair.name,
                        style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isOngoing)
                        Text(
                          'Läuft gerade',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: getAdaptiveIcon(
                      iconName: 'close', defaultIcon: Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollbarer Inhalt
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zeitraum
                  _buildInfoCard(
                    context,
                    icon: Icons.date_range,
                    title: 'Zeitraum',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('dd.MM.yyyy').format(fair.startDate)} – '
                              '${DateFormat('dd.MM.yyyy').format(fair.endDate)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${fair.endDate.difference(fair.startDate).inDays + 1} Tage',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Kostenstelle
                  _buildInfoCard(
                    context,
                    icon: Icons.account_balance_wallet,
                    title: 'Kostenstelle',
                    content: Text(
                      fair.costCenterCode.isNotEmpty
                          ? fair.costCenterCode
                          : 'Keine Kostenstelle',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Veranstaltungsort
                  _buildInfoCard(
                    context,
                    icon: Icons.location_on,
                    title: 'Veranstaltungsort',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fair.address.isNotEmpty)
                          Text(fair.address,
                              style: const TextStyle(fontSize: 16)),
                        Text(
                          '${fair.city}, ${fair.country}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (fair.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    _buildInfoCard(
                      context,
                      icon: Icons.notes,
                      title: 'Notizen',
                      content: Text(
                        fair.notes!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer mit Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Pin Button
                  if (isActive && onPin != null)
                    StreamBuilder<QuerySnapshot>(
                      stream:
                      UserBasketService.pinnedFair.limit(1).snapshots(),
                      builder: (context, snapshot) {
                        final isPinned = snapshot.hasData &&
                            snapshot.data!.docs.isNotEmpty &&
                            snapshot.data!.docs.first.id == fair.id;

                        return OutlinedButton.icon(
                          onPressed: () {
                            onPin!();
                            Navigator.pop(context);
                          },
                          icon: getAdaptiveIcon(
                            iconName: 'push_pin',
                            defaultIcon: isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                          ),
                          label: Text(isPinned ? 'Lösen' : 'Anpinnen'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            side: isPinned
                                ? BorderSide(
                                color:
                                Theme.of(context).colorScheme.primary)
                                : null,
                          ),
                        );
                      },
                    ),
                  if (isActive && onPin != null) const SizedBox(width: 12),

                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Schließen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEdit,
                      icon: getAdaptiveIcon(
                        iconName: 'edit',
                        defaultIcon: Icons.edit,
                        color: Colors.white,
                      ),
                      label: const Text('Bearbeiten'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor:
                        Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
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

  Widget _buildInfoCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Widget content,
      }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: icon.toString().split('.').last,
                  defaultIcon: icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            content,
          ],
        ),
      ),
    );
  }
}