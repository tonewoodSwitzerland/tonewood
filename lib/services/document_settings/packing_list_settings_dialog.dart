// File: services/document_settings/packing_list_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/icon_helper.dart';
import '../../services/package_card_widget.dart';
import 'document_settings_provider.dart';

/// Gemeinsamer Packliste-Einstellungen Dialog.
///
/// Wird sowohl im Auftrags- als auch im Angebotsbereich verwendet.
/// Der [DocumentSettingsProvider] bestimmt, wohin die Daten gespeichert werden.
///
/// Basiert auf der Order-Implementierung (führend) mit:
/// - PackageCardWidget für Paket-Karten
/// - Versandmodus (Gesamtversand / Einzelversand)
/// - Standardpaket-Vorlagen aus Firestore
/// - Produkt-Zuweisung zu Paketen
class PackingListSettingsDialog extends StatefulWidget {
  final DocumentSettingsProvider provider;

  /// Die Produkt-Items die auf Pakete verteilt werden können.
  /// Bei Orders: order.items (gefiltert ohne Services)
  /// Bei Quotes: basket items (gefiltert ohne Services)
  final List<Map<String, dynamic>> items;

  /// Bestehende Pakete (aus vorherigem Speichern)
  final List<Map<String, dynamic>> initialPackages;

  /// Versandmodus: 'total' oder 'per_shipment' (nur bei Orders relevant)
  final String initialShipmentMode;

  /// Ob der Versandmodus-Toggle angezeigt werden soll
  final bool showShipmentModeToggle;

  /// Callback wenn gespeichert wurde
  final void Function(List<Map<String, dynamic>> packages, String shipmentMode)? onSaved;

  const PackingListSettingsDialog({
    super.key,
    required this.provider,
    required this.items,
    this.initialPackages = const [],
    this.initialShipmentMode = 'total',
    this.showShipmentModeToggle = true,
    this.onSaved,
  });

  /// Convenience-Methode: Lädt Daten und zeigt den Dialog.
  static Future<void> show(
    BuildContext context, {
    required DocumentSettingsProvider provider,
    required List<Map<String, dynamic>> items,
    String initialShipmentMode = 'total',
    bool showShipmentModeToggle = true,
    void Function(List<Map<String, dynamic>> packages, String shipmentMode)? onSaved,
  }) async {
    // Lade bestehende Packlisten-Settings
    final settings = await provider.loadPackingListSettings();
    final rawPackages = settings['packages'] as List<dynamic>? ?? [];
    final packages = rawPackages
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    final shipmentMode = settings['shipment_mode'] as String? ?? initialShipmentMode;

    // Aktualisiere Maße in bestehenden Paketen mit aktuellen Item-Werten
    _updatePackageItemDimensions(packages, items);

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => PackingListSettingsDialog(
        provider: provider,
        items: items,
        initialPackages: packages,
        initialShipmentMode: shipmentMode,
        showShipmentModeToggle: showShipmentModeToggle,
        onSaved: onSaved,
      ),
    );
  }

  /// Aktualisiert die Maße in bestehenden Paketen mit den aktuellen Werten
  static void _updatePackageItemDimensions(
    List<Map<String, dynamic>> packages,
    List<Map<String, dynamic>> currentItems,
  ) {
    for (final package in packages) {
      final packageItems = package['items'] as List<dynamic>? ?? [];
      for (int i = 0; i < packageItems.length; i++) {
        final assignedItem = packageItems[i] as Map<String, dynamic>;
        final productId = assignedItem['product_id'];

        final currentItem = currentItems.firstWhere(
          (item) => item['product_id'] == productId,
          orElse: () => <String, dynamic>{},
        );

        if (currentItem.isNotEmpty) {
          packageItems[i] = {
            ...assignedItem,
            'custom_length': (currentItem['custom_length'] as num?)?.toDouble() ?? 0.0,
            'custom_width': (currentItem['custom_width'] as num?)?.toDouble() ?? 0.0,
            'custom_thickness': (currentItem['custom_thickness'] as num?)?.toDouble() ?? 0.0,
            'density': (currentItem['density'] as num?)?.toDouble() ?? 0.0,
            'custom_density': (currentItem['custom_density'] as num?)?.toDouble(),
            'volume_per_unit': (currentItem['volume_per_unit'] as num?)?.toDouble() ?? 0.0,
            'weight_per_unit': (currentItem['weight'] as num?)?.toDouble() ?? 0.0,
            'product_name': currentItem['product_name'] ?? assignedItem['product_name'],
            'product_name_en': currentItem['product_name_en'] ?? assignedItem['product_name_en'],
            'wood_code': currentItem['wood_code'] ?? assignedItem['wood_code'],
            'wood_name': currentItem['wood_name'] ?? assignedItem['wood_name'],
            'unit': currentItem['unit'] ?? assignedItem['unit'],
            'instrument_code': currentItem['instrument_code'] ?? assignedItem['instrument_code'],
            'instrument_name': currentItem['instrument_name'] ?? assignedItem['instrument_name'],
            'part_code': currentItem['part_code'] ?? assignedItem['part_code'],
            'part_name': currentItem['part_name'] ?? assignedItem['part_name'],
            'quality_code': currentItem['quality_code'] ?? assignedItem['quality_code'],
            'quality_name': currentItem['quality_name'] ?? assignedItem['quality_name'],
          };
        }
      }
    }
  }

  @override
  State<PackingListSettingsDialog> createState() =>
      _PackingListSettingsDialogState();
}

class _PackingListSettingsDialogState
    extends State<PackingListSettingsDialog> {
  late List<Map<String, dynamic>> packages;
  late String shipmentMode;
  final Map<String, Map<String, TextEditingController>> packageControllers = {};

  @override
  void initState() {
    super.initState();
    packages = widget.initialPackages.isNotEmpty
        ? List<Map<String, dynamic>>.from(widget.initialPackages)
        : [];
    shipmentMode = widget.initialShipmentMode;

    if (packages.isEmpty) {
      _createFirstPackage();
    } else {
      _initControllersForExistingPackages();
    }
  }

  @override
  void dispose() {
    packageControllers.forEach((key, controllers) {
      controllers.forEach((_, controller) {
        try {
          controller.dispose();
        } catch (e) {
          // Controller war bereits disposed
        }
      });
    });
    packageControllers.clear();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Init-Helpers
  // ─────────────────────────────────────────────────────────────────

  Future<void> _createFirstPackage() async {
    final firstPackageId = DateTime.now().millisecondsSinceEpoch.toString();

    String? defaultPackageId;
    String defaultPackagingType = '';
    String defaultPackagingTypeEn = '';
    double defaultLength = 0.0;
    double defaultWidth = 0.0;
    double defaultHeight = 0.0;
    double defaultWeight = 0.0;

    try {
      var defaultPackageQuery = await FirebaseFirestore.instance
          .collection('standardized_packages')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (defaultPackageQuery.docs.isEmpty) {
        defaultPackageQuery = await FirebaseFirestore.instance
            .collection('standardized_packages')
            .where('name', isEqualTo: 'Karton')
            .limit(1)
            .get();
      }

      if (defaultPackageQuery.docs.isNotEmpty) {
        final defaultDoc = defaultPackageQuery.docs.first;
        final defaultData = defaultDoc.data();
        defaultPackageId = defaultDoc.id;
        defaultPackagingType = defaultData['name'] ?? '';
        defaultPackagingTypeEn = defaultData['nameEn'] ?? '';
        defaultLength = (defaultData['length'] as num?)?.toDouble() ?? 0.0;
        defaultWidth = (defaultData['width'] as num?)?.toDouble() ?? 0.0;
        defaultHeight = (defaultData['height'] as num?)?.toDouble() ?? 0.0;
        defaultWeight = (defaultData['weight'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('Fehler beim Laden des Standardpakets: $e');
    }

    setState(() {
      packages.add({
        'id': firstPackageId,
        'name': 'Packung 1',
        'packaging_type': defaultPackagingType,
        'packaging_type_en': defaultPackagingTypeEn,
        'length': defaultLength,
        'width': defaultWidth,
        'height': defaultHeight,
        'tare_weight': defaultWeight,
        'items': <Map<String, dynamic>>[],
        'standard_package_id': defaultPackageId,
      });

      packageControllers[firstPackageId] = {
        'length': TextEditingController(text: defaultLength.toString()),
        'width': TextEditingController(text: defaultWidth.toString()),
        'height': TextEditingController(text: defaultHeight.toString()),
        'weight': TextEditingController(text: defaultWeight.toStringAsFixed(2)),
        'custom_name': TextEditingController(text: ''),
      };
    });
  }

  void _initControllersForExistingPackages() {
    for (final package in packages) {
      final packageId = package['id'] as String;
      packageControllers[packageId] = {
        'length': TextEditingController(text: package['length'].toString()),
        'width': TextEditingController(text: package['width'].toString()),
        'height': TextEditingController(text: package['height'].toString()),
        'weight': TextEditingController(text: package['tare_weight'].toString()),
        'custom_name': TextEditingController(text: package['packaging_type'] ?? ''),
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Item-Zuweisungs-Logik
  // ─────────────────────────────────────────────────────────────────

  String _getItemKey(Map<String, dynamic> item) {
    return item['basket_doc_id']?.toString() ?? '';
  }

  double _getAssignedQuantity(
      Map<String, dynamic> item, List<Map<String, dynamic>> pkgs) {
    double totalAssigned = 0;
    final itemKey = _getItemKey(item);

    for (final package in pkgs) {
      final packageItems = package['items'] as List<dynamic>? ?? [];
      for (final assignedItem in packageItems) {
        if (_getItemKey(Map<String, dynamic>.from(assignedItem as Map)) ==
            itemKey) {
          totalAssigned +=
              ((assignedItem['quantity'] as num?)?.toDouble() ?? 0);
        }
      }
    }
    return totalAssigned;
  }

  void _assignAllItemsToPackage(
    Map<String, dynamic> targetPackage,
    StateSetter setDialogState,
  ) {
    setDialogState(() {
      targetPackage['items'].clear();

      for (final item in widget.items) {
        final totalQuantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final itemKey = _getItemKey(item);

        for (final package in packages) {
          if (package['id'] != targetPackage['id']) {
            (package['items'] as List).removeWhere((assignedItem) =>
                _getItemKey(
                        Map<String, dynamic>.from(assignedItem as Map)) ==
                    itemKey);
          }
        }

        targetPackage['items'].add({
          'basket_doc_id': item['basket_doc_id'],
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'product_name_en': item['product_name_en'],
          'quantity': totalQuantity,
          'weight_per_unit': (item['weight'] as num?)?.toDouble() ?? 0.0,
          'volume_per_unit':
              (item['volume_per_unit'] as num?)?.toDouble() ?? 0.0,
          'density': (item['density'] as num?)?.toDouble() ?? 0.0,
          'custom_density': (item['custom_density'] as num?)?.toDouble(),
          'custom_length':
              (item['custom_length'] as num?)?.toDouble() ?? 0.0,
          'custom_width':
              (item['custom_width'] as num?)?.toDouble() ?? 0.0,
          'custom_thickness':
              (item['custom_thickness'] as num?)?.toDouble() ?? 0.0,
          'wood_code': item['wood_code'] ?? '',
          'wood_name': item['wood_name'] ?? '',
          'unit': item['unit'] ?? 'Stk',
          'instrument_code': item['instrument_code'] ?? '',
          'instrument_name': item['instrument_name'] ?? '',
          'part_code': item['part_code'] ?? '',
          'part_name': item['part_name'] ?? '',
          'quality_code': item['quality_code'] ?? '',
          'quality_name': item['quality_name'] ?? '',
        });
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // Speichern
  // ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    await widget.provider.savePackingListSettings({
      'packages': packages,
      'shipment_mode': shipmentMode,
    });

    widget.onSaved?.call(packages, shipmentMode);
    if (mounted) Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'view_list',
                    defaultIcon: Icons.view_list,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text('Packliste Einstellungen',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: getAdaptiveIcon(
                        iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Content
            Expanded(
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Produkt-Übersicht ──
                        _buildProductOverview(context, setModalState),

                        const SizedBox(height: 16),

                        // ── Versandmodus (optional) ──
                        if (widget.showShipmentModeToggle)
                          _buildShipmentModeToggle(context, setModalState),

                        const SizedBox(height: 24),

                        // ── Pakete Header + Hinzufügen-Button ──
                        _buildPackagesHeader(context, setModalState),

                        const SizedBox(height: 16),

                        // ── Paket-Karten ──
                        ...packages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final package = entry.value;
                          package['name'] = '${index + 1}';

                          return PackageCardWidget(
                            parentContext: context,
                            package: package,
                            index: index,
                            orderItems: widget.items,
                            allPackages: packages,
                            setModalState: setModalState,
                            packageControllers: packageControllers,
                            shipmentMode: shipmentMode,
                            getItemKey: _getItemKey,
                            getAssignedQuantity: _getAssignedQuantity,
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                        // ── Paket hinzufügen (unten) ──
                        _buildAddPackageButton(setModalState),


                        const SizedBox(height: 24),

                        // ── Actions ──
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Abbrechen'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _save,
                                icon: getAdaptiveIcon(
                                    iconName: 'save',
                                    defaultIcon: Icons.save),
                                label: const Text('Speichern'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // UI-Bausteine
  // ─────────────────────────────────────────────────────────────────

  Widget _buildProductOverview(
      BuildContext context, StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Produkte',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (packages.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _assignAllItemsToPackage(packages.first, setModalState);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Alle Produkte wurden Paket 1 zugewiesen'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'inbox',
                    defaultIcon: Icons.inbox,
                    size: 16,
                  ),
                  label: const Text('Alle → Paket 1',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.items.map((item) {
            final assignedQuantity = _getAssignedQuantity(item, packages);
            final totalQuantity = (item['quantity'] as num).toDouble();
            final remainingQuantity = totalQuantity - assignedQuantity;

            final qualityName = item['quality_name'] ?? '';
            final instrumentName = item['instrument_name'] ?? '';
            final partName = item['part_name'] ?? '';
            final length =
                (item['custom_length'] as num?)?.toDouble() ?? 0.0;
            final width =
                (item['custom_width'] as num?)?.toDouble() ?? 0.0;
            final thickness =
                (item['custom_thickness'] as num?)?.toDouble() ?? 0.0;

            final details = <String>[
              if (qualityName.isNotEmpty) qualityName,
              if (instrumentName.isNotEmpty) instrumentName,
              if (partName.isNotEmpty) partName,
              if (length > 0 && width > 0 && thickness > 0)
                '${length.toStringAsFixed(0)}×${width.toStringAsFixed(0)}×${thickness.toStringAsFixed(0)}mm',
            ];
            final detailText =
                details.isNotEmpty ? details.join(' • ') : '';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['product_name'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        if (detailText.isNotEmpty)
                          Text(
                            detailText,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: remainingQuantity > 0
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$remainingQuantity/$totalQuantity verbleibend',
                      style: TextStyle(
                        fontSize: 10,
                        color: remainingQuantity > 0
                            ? Colors.orange[700]
                            : Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildShipmentModeToggle(
      BuildContext context, StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'local_shipping',
                defaultIcon: Icons.local_shipping,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Versandmodus',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'total',
                  label: const Text('Gesamtversand',
                      style: TextStyle(fontSize: 12)),
                  icon: getAdaptiveIcon(
                    iconName: 'flight',
                    defaultIcon: Icons.flight,
                    size: 16,
                  ),
                ),
                ButtonSegment<String>(
                  value: 'per_shipment',
                  label: const Text('Einzelversand',
                      style: TextStyle(fontSize: 12)),
                  icon: getAdaptiveIcon(
                    iconName: 'mail',
                    defaultIcon: Icons.mail,
                    size: 16,
                  ),
                ),
              ],
              selected: {shipmentMode},
              onSelectionChanged: (Set<String> selection) {
                setModalState(() {
                  shipmentMode = selection.first;
                  if (shipmentMode == 'per_shipment') {
                    for (int i = 0; i < packages.length; i++) {
                      packages[i]['shipment_group'] ??= i + 1;
                    }
                  }
                });
              },
              style: SegmentedButton.styleFrom(
                selectedForegroundColor:
                    Theme.of(context).colorScheme.onPrimary,
                selectedBackgroundColor:
                    Theme.of(context).colorScheme.primary,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            shipmentMode == 'total'
                ? 'Alle Pakete werden als eine Sendung behandelt → 1 HR + 1 Lieferschein'
                : 'Pro Sendung wird eine eigene HR + Lieferschein erstellt. '
                    'Weise jedem Paket eine Sendungsnummer zu.',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.6),
            ),
          ),
          if (shipmentMode == 'per_shipment') ...[
            const SizedBox(height: 8),
            _buildShipmentGroupSummary(context),
          ],
        ],
      ),
    );
  }

  Widget _buildPackagesHeader(
      BuildContext context, StateSetter setModalState)
  {
    return Row(
      children: [
        Text(
          'Pakete',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () async {
            final newPackageId =
                DateTime.now().millisecondsSinceEpoch.toString();

            String? defaultPackageId;
            String defaultPackagingType = '';
            String defaultPackagingTypeEn = '';
            double defaultLength = 0.0;
            double defaultWidth = 0.0;
            double defaultHeight = 0.0;
            double defaultWeight = 0.0;

            try {
              var query = await FirebaseFirestore.instance
                  .collection('standardized_packages')
                  .where('isDefault', isEqualTo: true)
                  .limit(1)
                  .get();

              if (query.docs.isEmpty) {
                query = await FirebaseFirestore.instance
                    .collection('standardized_packages')
                    .where('name', isEqualTo: 'Karton')
                    .limit(1)
                    .get();
              }

              if (query.docs.isNotEmpty) {
                final doc = query.docs.first;
                final data = doc.data();
                defaultPackageId = doc.id;
                defaultPackagingType = data['name'] ?? '';
                defaultPackagingTypeEn = data['nameEn'] ?? '';
                defaultLength =
                    (data['length'] as num?)?.toDouble() ?? 0.0;
                defaultWidth =
                    (data['width'] as num?)?.toDouble() ?? 0.0;
                defaultHeight =
                    (data['height'] as num?)?.toDouble() ?? 0.0;
                defaultWeight =
                    (data['weight'] as num?)?.toDouble() ?? 0.0;
              }
            } catch (e) {
              print('Fehler beim Laden des Standardpakets: $e');
            }

            setModalState(() {
              packageControllers[newPackageId] = {
                'length': TextEditingController(
                    text: defaultLength.toString()),
                'width': TextEditingController(
                    text: defaultWidth.toString()),
                'height': TextEditingController(
                    text: defaultHeight.toString()),
                'weight': TextEditingController(
                    text: defaultWeight.toStringAsFixed(2)),
                'custom_name': TextEditingController(text: ''),
              };

              packages.add({
                'id': newPackageId,
                'name': '${packages.length + 1}',
                'packaging_type': defaultPackagingType,
                'packaging_type_en': defaultPackagingTypeEn,
                'length': defaultLength,
                'width': defaultWidth,
                'height': defaultHeight,
                'tare_weight': defaultWeight,
                'items': <Map<String, dynamic>>[],
                'standard_package_id': defaultPackageId,
              });
            });
          },
          icon: getAdaptiveIcon(
              iconName: 'add', defaultIcon: Icons.add, size: 16),
          label: const Text('Paket hinzufügen'),
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
          ),
        ),
      ],
    );
  }


  Widget _buildAddPackageButton(StateSetter setModalState) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final newPackageId = DateTime.now().millisecondsSinceEpoch.toString();

          String? defaultPackageId;
          String defaultPackagingType = '';
          String defaultPackagingTypeEn = '';
          double defaultLength = 0.0;
          double defaultWidth = 0.0;
          double defaultHeight = 0.0;
          double defaultWeight = 0.0;

          try {
            var query = await FirebaseFirestore.instance
                .collection('standardized_packages')
                .where('isDefault', isEqualTo: true)
                .limit(1)
                .get();

            if (query.docs.isEmpty) {
              query = await FirebaseFirestore.instance
                  .collection('standardized_packages')
                  .where('name', isEqualTo: 'Karton')
                  .limit(1)
                  .get();
            }

            if (query.docs.isNotEmpty) {
              final doc = query.docs.first;
              final data = doc.data();
              defaultPackageId = doc.id;
              defaultPackagingType = data['name'] ?? '';
              defaultPackagingTypeEn = data['nameEn'] ?? '';
              defaultLength = (data['length'] as num?)?.toDouble() ?? 0.0;
              defaultWidth = (data['width'] as num?)?.toDouble() ?? 0.0;
              defaultHeight = (data['height'] as num?)?.toDouble() ?? 0.0;
              defaultWeight = (data['weight'] as num?)?.toDouble() ?? 0.0;
            }
          } catch (e) {
            print('Fehler beim Laden des Standardpakets: $e');
          }

          setModalState(() {
            packageControllers[newPackageId] = {
              'length': TextEditingController(text: defaultLength.toString()),
              'width': TextEditingController(text: defaultWidth.toString()),
              'height': TextEditingController(text: defaultHeight.toString()),
              'weight': TextEditingController(text: defaultWeight.toStringAsFixed(2)),
              'custom_name': TextEditingController(text: ''),
            };

            packages.add({
              'id': newPackageId,
              'name': '${packages.length + 1}',
              'packaging_type': defaultPackagingType,
              'packaging_type_en': defaultPackagingTypeEn,
              'length': defaultLength,
              'width': defaultWidth,
              'height': defaultHeight,
              'tare_weight': defaultWeight,
              'items': <Map<String, dynamic>>[],
              'standard_package_id': defaultPackageId,
            });
          });
        },
        icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add, size: 16),
        label: const Text('Paket hinzufügen'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
  // ── Versandgruppen-Zusammenfassung ──

  static Color _getShipmentGroupColor(int group) {
    const colors = [
      Color(0xFF1976D2),
      Color(0xFF388E3C),
      Color(0xFFF57C00),
      Color(0xFF7B1FA2),
      Color(0xFFD32F2F),
      Color(0xFF00838F),
      Color(0xFF5D4037),
      Color(0xFF455A64),
      Color(0xFFC2185B),
      Color(0xFF689F38),
    ];
    return colors[(group - 1) % colors.length];
  }

  Widget _buildShipmentGroupSummary(BuildContext context) {
    final Map<int, List<String>> groups = {};
    for (int i = 0; i < packages.length; i++) {
      final group =
          (packages[i]['shipment_group'] as num?)?.toInt() ?? (i + 1);
      groups.putIfAbsent(group, () => []);
      groups[group]!.add('Paket ${i + 1}');
    }

    final sortedGroups = groups.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sortedGroups.length} Sendung${sortedGroups.length > 1 ? 'en' : ''} '
            '→ ${sortedGroups.length} HR + ${sortedGroups.length} Lieferschein${sortedGroups.length > 1 ? 'e' : ''}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          ...sortedGroups.map((groupNum) {
            final packageNames = groups[groupNum]!;
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getShipmentGroupColor(groupNum),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sendung $groupNum: ${packageNames.join(', ')}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
