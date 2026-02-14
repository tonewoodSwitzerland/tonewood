// File: services/package_product_picker.dart
//
// Professioneller Dialog zum Zuweisen von Produkten zu Paketen.
// - Mobile: BottomSheet
// - Web/Desktop: Großer Dialog
// - Inline +/- Steuerung pro Produkt
// - "Alle hinzufügen" / "Alle entfernen" pro Produkt
// - "Alle verfügbaren → Paket" Bulk-Action
// - Live-Gewichtsanzeige

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/icon_helper.dart';

class PackageProductPicker {
  /// Öffnet den Produkt-Zuweisungs-Dialog.
  ///
  /// Auf Mobile als BottomSheet, auf Web/Desktop als großen Dialog.
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> targetPackage,
    required List<Map<String, dynamic>> orderItems,
    required List<Map<String, dynamic>> allPackages,
    required StateSetter parentSetState,
    required String Function(Map<String, dynamic>) getItemKey,
    required double Function(Map<String, dynamic>, List<Map<String, dynamic>>) getAssignedQuantity,
  }) async {
    final isWideScreen = kIsWeb || MediaQuery.of(context).size.width > 700;

    if (isWideScreen) {
      await showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
            child: _ProductPickerContent(
              targetPackage: targetPackage,
              orderItems: orderItems,
              allPackages: allPackages,
              parentSetState: parentSetState,
              getItemKey: getItemKey,
              getAssignedQuantity: getAssignedQuantity,
              onClose: () => Navigator.pop(dialogContext),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _ProductPickerContent(
              targetPackage: targetPackage,
              orderItems: orderItems,
              allPackages: allPackages,
              parentSetState: parentSetState,
              getItemKey: getItemKey,
              getAssignedQuantity: getAssignedQuantity,
              onClose: () => Navigator.pop(sheetContext),
              scrollController: scrollController,
            ),
          ),
        ),
      );
    }
  }
}

class _ProductPickerContent extends StatefulWidget {
  final Map<String, dynamic> targetPackage;
  final List<Map<String, dynamic>> orderItems;
  final List<Map<String, dynamic>> allPackages;
  final StateSetter parentSetState;
  final String Function(Map<String, dynamic>) getItemKey;
  final double Function(Map<String, dynamic>, List<Map<String, dynamic>>) getAssignedQuantity;
  final VoidCallback onClose;
  final ScrollController? scrollController;

  const _ProductPickerContent({
    required this.targetPackage,
    required this.orderItems,
    required this.allPackages,
    required this.parentSetState,
    required this.getItemKey,
    required this.getAssignedQuantity,
    required this.onClose,
    this.scrollController,
  });

  @override
  State<_ProductPickerContent> createState() => _ProductPickerContentState();
}

class _ProductPickerContentState extends State<_ProductPickerContent> {
  late List<Map<String, dynamic>> _packageItems;

  @override
  void initState() {
    super.initState();


    _packageItems = (widget.targetPackage['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  // Wie viel von diesem Item ist in DIESEM Paket?
  double _getQuantityInThisPackage(Map<String, dynamic> orderItem) {
    final itemKey = widget.getItemKey(orderItem);
    for (final assigned in _packageItems) {
      if (widget.getItemKey(Map<String, dynamic>.from(assigned)) == itemKey) {
        return (assigned['quantity'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return 0.0;
  }

  // Wie viel ist in ALLEN Paketen zugewiesen?
  double _getTotalAssigned(Map<String, dynamic> orderItem) {
    return widget.getAssignedQuantity(orderItem, widget.allPackages);
  }

  // Verfügbare Menge (nicht in irgendeinem Paket)
  double _getAvailable(Map<String, dynamic> orderItem) {
    final total = (orderItem['quantity'] as num?)?.toDouble() ?? 0.0;
    final assigned = _getTotalAssigned(orderItem);
    return (total - assigned).clamp(0.0, total);
  }

  // Menge in diesem Paket ändern
  void _setQuantityInPackage(Map<String, dynamic> orderItem, double newQuantity) {
    final itemKey = widget.getItemKey(orderItem);
    final currentInPackage = _getQuantityInThisPackage(orderItem);

    widget.parentSetState(() {
      setState(() {
        if (newQuantity <= 0) {
          // Entferne aus Paket
          _packageItems.removeWhere(
                (item) => widget.getItemKey(Map<String, dynamic>.from(item)) == itemKey,
          );
        } else if (currentInPackage > 0) {
          // Update existierenden Eintrag
          for (final assigned in _packageItems) {
            if (widget.getItemKey(Map<String, dynamic>.from(assigned)) == itemKey) {
              assigned['quantity'] = newQuantity;
              break;
            }
          }
        } else {
          // Neu hinzufügen
          _packageItems.add(_createPackageItem(orderItem, newQuantity));
        }
      });
    });
  }

  // +1
  void _increment(Map<String, dynamic> orderItem) {
    final currentInPackage = _getQuantityInThisPackage(orderItem);
    final available = _getAvailable(orderItem);
    if (available > 0 || currentInPackage > 0) {
      final maxAdd = available;
      if (maxAdd >= 1) {
        _setQuantityInPackage(orderItem, currentInPackage + 1);
      }
    }
  }

  // -1
  void _decrement(Map<String, dynamic> orderItem) {
    final currentInPackage = _getQuantityInThisPackage(orderItem);
    if (currentInPackage > 0) {
      _setQuantityInPackage(orderItem, currentInPackage - 1);
    }
  }

  // Alle verfügbaren dieses Produkts hinzufügen
  void _addAll(Map<String, dynamic> orderItem) {
    final currentInPackage = _getQuantityInThisPackage(orderItem);
    final available = _getAvailable(orderItem);
    if (available > 0) {
      _setQuantityInPackage(orderItem, currentInPackage + available);
    }
  }

  // Alle dieses Produkts aus diesem Paket entfernen
  void _removeAll(Map<String, dynamic> orderItem) {
    _setQuantityInPackage(orderItem, 0);
  }

  // Alle verfügbaren Produkte dem Paket zuweisen
  void _addAllProducts() {
    for (final item in widget.orderItems) {
      final currentInPackage = _getQuantityInThisPackage(item);
      final available = _getAvailable(item);
      if (available > 0) {
        _setQuantityInPackage(item, currentInPackage + available);
      }
    }
  }

  // Paket komplett leeren
  void _clearPackage() {
    widget.parentSetState(() {
      setState(() {
        _packageItems.clear();
      });
    });
  }

  Map<String, dynamic> _createPackageItem(Map<String, dynamic> item, double quantity) {
    return {
      'basket_doc_id': item['basket_doc_id'],
      'product_id': item['product_id'],
      'product_name': item['product_name'],
      'product_name_en': item['product_name_en'],
      'quantity': quantity,
      'weight_per_unit': (item['weight'] as num?)?.toDouble() ?? 0.0,
      'volume_per_unit': (item['volume_per_unit'] as num?)?.toDouble() ?? 0.0,
      'density': (item['density'] as num?)?.toDouble() ?? 0.0,
      'custom_density': (item['custom_density'] as num?)?.toDouble(),
      'custom_length': (item['custom_length'] as num?)?.toDouble() ?? 0.0,
      'custom_width': (item['custom_width'] as num?)?.toDouble() ?? 0.0,
      'custom_thickness': (item['custom_thickness'] as num?)?.toDouble() ?? 0.0,
      'wood_code': item['wood_code'] ?? '',
      'wood_name': item['wood_name'] ?? '',
      'unit': item['unit'] ?? 'Stk',
      'instrument_code': item['instrument_code'] ?? '',
      'instrument_name': item['instrument_name'] ?? '',
      'part_code': item['part_code'] ?? '',
      'part_name': item['part_name'] ?? '',
      'quality_code': item['quality_code'] ?? '',
      'quality_name': item['quality_name'] ?? '',
    };
  }

  // Statistiken berechnen
  int get _assignedCount {
    int count = 0;
    for (final item in widget.orderItems) {
      if (_getQuantityInThisPackage(item) > 0) count++;
    }
    return count;
  }

  int get _totalProducts => widget.orderItems.length;

  bool get _hasAvailableProducts {
    for (final item in widget.orderItems) {
      if (_getAvailable(item) > 0) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packageName = widget.targetPackage['name'] ?? 'Paket';

    return Column(
      children: [
        // ── Drag Handle (nur Mobile) ──
        if (widget.scrollController != null)
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: getAdaptiveIcon(
                  iconName: 'inventory_2',
                  defaultIcon: Icons.inventory_2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paket $packageName befüllen',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_assignedCount / $_totalProducts Produkte zugewiesen',
                      style: TextStyle(
                        fontSize: 12,
                        color: _assignedCount == _totalProducts
                            ? Colors.green[700]
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: _assignedCount == _totalProducts
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
              ),
            ],
          ),
        ),

        // ── Bulk Actions ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              // Alle hinzufügen
              Expanded(
                child: _BulkActionButton(
                  icon: Icons.playlist_add,
                  iconName: 'playlist_add',
                  label: 'Alle verfügbaren',
                  color: theme.colorScheme.primary,
                  onPressed: _hasAvailableProducts ? _addAllProducts : null,
                ),
              ),
              const SizedBox(width: 8),
              // Paket leeren
              Expanded(
                child: _BulkActionButton(
                  icon: Icons.playlist_remove,
                  iconName: 'playlist_remove',
                  label: 'Paket leeren',
                  color: Colors.red,
                  onPressed: _packageItems.isNotEmpty ? _clearPackage : null,
                ),
              ),
            ],
          ),
        ),

        // ── Progress Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _totalProducts > 0 ? _assignedCount / _totalProducts : 0,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: _assignedCount == _totalProducts
                  ? Colors.green
                  : theme.colorScheme.primary,
              minHeight: 4,
            ),
          ),
        ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // ── Produktliste ──
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: widget.orderItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = widget.orderItems[index];
              return _ProductRow(
                item: item,
                quantityInPackage: _getQuantityInThisPackage(item),
                totalQuantity: (item['quantity'] as num?)?.toDouble() ?? 0.0,
                available: _getAvailable(item),
                onIncrement: () => _increment(item),
                onDecrement: () => _decrement(item),
                onAddAll: () => _addAll(item),
                onRemoveAll: () => _removeAll(item),
              );
            },
          ),
        ),

        // ── Footer ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onClose,
                icon: getAdaptiveIcon(
                  iconName: 'check',
                  defaultIcon: Icons.check,
                ),
                label: Text(
                  _packageItems.isNotEmpty
                      ? 'Fertig • ${_packageItems.length} Produkt${_packageItems.length != 1 ? 'e' : ''} im Paket'
                      : 'Fertig',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Bulk Action Button
// ═══════════════════════════════════════════════════════════════════════════════

class _BulkActionButton extends StatelessWidget {
  final IconData icon;
  final String iconName;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _BulkActionButton({
    required this.icon,
    required this.iconName,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final effectiveColor = isEnabled ? color : Colors.grey;

    return Material(
      color: effectiveColor.withOpacity(isEnabled ? 0.08 : 0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              getAdaptiveIcon(
                iconName: iconName,
                defaultIcon: icon,
                size: 18,
                color: effectiveColor.withOpacity(isEnabled ? 1.0 : 0.4),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: effectiveColor.withOpacity(isEnabled ? 1.0 : 0.4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Einzelne Produktzeile
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final double quantityInPackage;
  final double totalQuantity;
  final double available;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onAddAll;
  final VoidCallback onRemoveAll;

  const _ProductRow({
    required this.item,
    required this.quantityInPackage,
    required this.totalQuantity,
    required this.available,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddAll,
    required this.onRemoveAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAssigned = quantityInPackage > 0;
    final isFullyAssigned = available <= 0 && quantityInPackage >= totalQuantity;

    // Detail-Infos
    final qualityName = item['quality_name'] ?? '';
    final instrumentName = item['instrument_name'] ?? '';
    final partName = item['part_name'] ?? '';
    final length = (item['custom_length'] as num?)?.toDouble() ?? 0.0;
    final width = (item['custom_width'] as num?)?.toDouble() ?? 0.0;
    final thickness = (item['custom_thickness'] as num?)?.toDouble() ?? 0.0;
    final unit = item['unit'] ?? 'Stk';

    final  woodName = item['wood_name'] ?? '';
    final hasThermal = item['has_thermal_treatment'] == true;
    final thermalTemp = (item['thermal_treatment_temperature'] as num?)?.toInt();
    final density = (item['density'] as num?)?.toInt();

    final details = <String>[

      if (qualityName.isNotEmpty) qualityName,
      if (length > 0 && width > 0 && thickness > 0)
        '${length.toStringAsFixed(0)}×${width.toStringAsFixed(0)}×${thickness.toStringAsFixed(0)}mm',
      if (density != null && density > 0) '${density} kg/m³',
      if (hasThermal && thermalTemp != null) '🔥 ${thermalTemp}°C',
    ];

    return Container(
      decoration: BoxDecoration(
        color: isAssigned
            ? theme.colorScheme.primaryContainer.withOpacity(0.12)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFullyAssigned
              ? Colors.green.withOpacity(0.4)
              : isAssigned
              ? theme.colorScheme.primary.withOpacity(0.25)
              : theme.colorScheme.outline.withOpacity(0.12),
          width: isAssigned ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            // ── Status-Indikator ──
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isFullyAssigned
                    ? Colors.green.withOpacity(0.15)
                    : isAssigned
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isFullyAssigned
                    ? getAdaptiveIcon(
                  iconName: 'check',
                  defaultIcon: Icons.check,
                  size: 16,
                  color: Colors.green[700],
                )
                    : Text(
                  '${quantityInPackage.toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isAssigned
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ── Produkt-Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['product_name'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isAssigned ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (details.isNotEmpty)
                        Flexible(
                          child: Text(
                            details.join(' • '),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (details.isNotEmpty) const SizedBox(width: 6),
                      // Verfügbarkeits-Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: available > 0
                              ? Colors.orange.withOpacity(0.15)
                              : Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isFullyAssigned
                              ? '✓ alle im Paket'
                              : '${available.toStringAsFixed(available == available.roundToDouble() ? 0 : 1)}/${totalQuantity.toStringAsFixed(totalQuantity == totalQuantity.roundToDouble() ? 0 : 1)} frei',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: available > 0 ? Colors.orange[800] : Colors.green[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Steuerung ──
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Alle entfernen (nur sichtbar wenn etwas zugewiesen)
                if (isAssigned)
                  _TinyIconButton(
                    icon: Icons.remove_circle_outline,
                    iconName: 'remove_circle_outline',
                    tooltip: 'Alle entfernen',
                    color: Colors.red,
                    onPressed: onRemoveAll,
                  ),

                // Minus
                _TinyIconButton(
                  icon: Icons.remove,
                  iconName: 'remove',
                  tooltip: '-1',
                  color: theme.colorScheme.onSurface,
                  onPressed: quantityInPackage > 0 ? onDecrement : null,
                ),

                // Menge
                Container(
                  width: 36,
                  alignment: Alignment.center,
                  child: Text(
                    '${quantityInPackage.toInt()}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isAssigned
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                ),

                // Plus
                _TinyIconButton(
                  icon: Icons.add,
                  iconName: 'add',
                  tooltip: '+1',
                  color: theme.colorScheme.primary,
                  onPressed: available > 0 ? onIncrement : null,
                ),

                // Alle hinzufügen (nur sichtbar wenn noch etwas verfügbar)
                if (available > 0)
                  _TinyIconButton(
                    icon: Icons.add_circle_outline,
                    iconName: 'add_circle_outline',
                    tooltip: 'Alle hinzufügen (${available.toInt()})',
                    color: theme.colorScheme.primary,
                    onPressed: onAddAll,
                  ),

                // Platzhalter wenn keine Action
                if (available <= 0 && !isAssigned)
                  const SizedBox(width: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tiny Icon Button (kompakt für die Zeile)
// ═══════════════════════════════════════════════════════════════════════════════

class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final String iconName;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _TinyIconButton({
    required this.icon,
    required this.iconName,
    required this.tooltip,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            size: 20,
            color: isEnabled ? color : color.withOpacity(0.2),
          ),
        ),
      ),
    );
  }
}