// File: services/package_card_widget.dart
//
// Ausgelagertes Widget für die Paket-Karte in der Packlisten-Konfiguration.
// Zeigt Paketdaten (Vorlage, Maße, Gewichte) und zugewiesene Produkte.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';
import 'package:tonewood/services/package_product_picker.dart';

class PackageCardWidget extends StatelessWidget {
  final BuildContext parentContext;
  final Map<String, dynamic> package;
  final int index;
  final List<Map<String, dynamic>> orderItems;
  final List<Map<String, dynamic>> allPackages;
  final StateSetter setModalState;
  final Map<String, Map<String, TextEditingController>> packageControllers;
  final String shipmentMode;
  final String Function(Map<String, dynamic>) getItemKey;
  final double Function(Map<String, dynamic>, List<Map<String, dynamic>>) getAssignedQuantity;

  const PackageCardWidget({
    super.key,
    required this.parentContext,
    required this.package,
    required this.index,
    required this.orderItems,
    required this.allPackages,
    required this.setModalState,
    required this.packageControllers,
    required this.shipmentMode,
    required this.getItemKey,
    required this.getAssignedQuantity,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Gewichtsberechnungen
  // ═══════════════════════════════════════════════════════════════════════════

  double _calculateNetWeight() {
    double netWeight = 0.0;
    final packageItems = package['items'] as List<dynamic>? ?? [];

    for (final item in packageItems) {
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final unit = item['unit'] ?? 'Stk';

      if (unit.toLowerCase() == 'kg') {
        netWeight += quantity;
      } else {
        double volumePerPiece = 0.0;
        final volumeField = (item['volume_per_unit'] as num?)?.toDouble() ?? 0.0;

        if (volumeField > 0) {
          volumePerPiece = volumeField;
        } else {
          final length = (item['custom_length'] as num?)?.toDouble() ?? 0.0;
          final width = (item['custom_width'] as num?)?.toDouble() ?? 0.0;
          final thickness = (item['custom_thickness'] as num?)?.toDouble() ?? 0.0;
          if (length > 0 && width > 0 && thickness > 0) {
            volumePerPiece = (length / 1000) * (width / 1000) * (thickness / 1000);
          }
        }

        final density = (item['custom_density'] as num?)?.toDouble()
            ?? (item['density'] as num?)?.toDouble()
            ?? 0.0;
        final weightPerPiece = volumePerPiece * density;
        netWeight += weightPerPiece * quantity;
      }
    }
    return netWeight;
  }

  double _calculateGrossWeight() {
    final netWeight = _calculateNetWeight();
    final tareWeight = (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
    return netWeight + tareWeight;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Farbkodierung für Versandgruppen
  // ═══════════════════════════════════════════════════════════════════════════

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? selectedStandardPackageId = package['standard_package_id'];

    final controllers = packageControllers[package['id']]!;
    final lengthController = controllers['length']!;
    final widthController = controllers['width']!;
    final heightController = controllers['height']!;
    final weightController = controllers['weight']!;
    final customNameController = controllers['custom_name']!;

    if (!controllers.containsKey('gross_weight')) {
      controllers['gross_weight'] = TextEditingController(
        text: package['gross_weight']?.toString() ?? '',
      );
    }
    final grossWeightController = controllers['gross_weight']!;

    final packageItems = package['items'] as List<dynamic>? ?? [];
    final itemCount = packageItems.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Package Header ──
            _buildHeader(context, theme),

            const SizedBox(height: 12),

            // ── Verpackungsvorlage Dropdown ──
            _buildPackageTemplateDropdown(
              context, theme, selectedStandardPackageId,
              lengthController, widthController, heightController,
              weightController, customNameController, grossWeightController,
            ),

            // ── Versandgruppe (nur bei Einzelversand) ──
            if (shipmentMode == 'per_shipment') ...[
              const SizedBox(height: 12),
              _buildShipmentGroupDropdown(context, theme),
            ],

            const SizedBox(height: 12),

            // ── Freitextfeld für benutzerdefinierten Namen ──
            if (selectedStandardPackageId == 'custom') ...[
              TextFormField(
                controller: customNameController,
                decoration: InputDecoration(
                  labelText: 'Verpackungsbezeichnung',
                  hintText: 'z.B. Spezialverpackung',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                onChanged: (value) => package['packaging_type'] = value,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            // ── Abmessungen ──
            _buildDimensionsRow(context, lengthController, widthController, heightController),

            const SizedBox(height: 16),

            // ── Tara-Gewicht ──
            _buildTareWeightField(context, weightController, grossWeightController),
            const SizedBox(height: 12),
            // ── Gewichtsübersicht ──
            if (packageItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildWeightSummary(context, theme, grossWeightController, weightController, selectedStandardPackageId),
            ],

            const SizedBox(height: 12),

            // ── Zugewiesene Produkte ──
            _buildAssignedProductsSection(context, theme),

            const SizedBox(height: 10),

            // ── Produkte verwalten Button ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => PackageProductPicker.show(
                  context: context,
                  targetPackage: package,
                  orderItems: orderItems,
                  allPackages: allPackages,
                  parentSetState: setModalState,
                  getItemKey: getItemKey,
                  getAssignedQuantity: getAssignedQuantity,
                ),
                icon: getAdaptiveIcon(
                  iconName: itemCount > 0 ? 'edit' : 'add',
                  defaultIcon: itemCount > 0 ? Icons.edit : Icons.add,
                  size: 16,
                ),
                label: Text(itemCount > 0
                    ? 'Produkte verwalten ($itemCount)'
                    : 'Produkte hinzufügen'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Header
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              package['name'] ?? '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paket ${package['name'] ?? index + 1}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (package['packaging_type'] != null && (package['packaging_type'] as String).isNotEmpty)
                Text(
                  package['packaging_type'],
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
            ],
          ),
        ),
        if (allPackages.length > 1)
          IconButton(
            onPressed: () {
              setModalState(() {
                final packageId = package['id'] as String;
                packageControllers[packageId]?.forEach((key, controller) {
                  controller.dispose();
                });
                packageControllers.remove(packageId);
                allPackages.removeAt(index);
              });
            },
            icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete, color: Colors.red[400]),
            iconSize: 20,
            tooltip: 'Paket löschen',
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Verpackungsvorlage
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPackageTemplateDropdown(
      BuildContext context,
      ThemeData theme,
      String? selectedStandardPackageId,
      TextEditingController lengthCtrl,
      TextEditingController widthCtrl,
      TextEditingController heightCtrl,
      TextEditingController weightCtrl,
      TextEditingController customNameCtrl,
      TextEditingController grossWeightCtrl,
      ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('standardized_packages')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();

        final standardPackages = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Verpackungsvorlage',
                hintText: 'Bitte auswählen',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: getAdaptiveIcon(iconName: 'inventory', defaultIcon: Icons.inventory),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              value: selectedStandardPackageId,
              items: [
                const DropdownMenuItem<String>(value: 'custom', child: Text('Benutzerdefiniert')),
                ...standardPackages.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(value: doc.id, child: Text(data['name'] ?? 'Unbenannt'));
                }),
              ],
              onChanged: (value) {
                setModalState(() {
                  package['standard_package_id'] = value;
                  package['manual_gross_weight_mode'] = false;
                  package['gross_weight'] = null;
                  grossWeightCtrl.clear();

                  if (value != null && value != 'custom') {
                    final selectedPackage = standardPackages.firstWhere((doc) => doc.id == value);
                    final packageData = selectedPackage.data() as Map<String, dynamic>;
                    package['packaging_type'] = packageData['name'] ?? 'Standardpaket';
                    package['packaging_type_en'] = packageData['nameEn'] ?? packageData['name'] ?? 'Standard package';
                    package['length'] = packageData['length'] ?? 0.0;
                    package['width'] = packageData['width'] ?? 0.0;
                    package['height'] = packageData['height'] ?? 0.0;
                    package['tare_weight'] = packageData['weight'] ?? 0.0;
                    lengthCtrl.text = package['length'].toString();
                    widthCtrl.text = package['width'].toString();
                    heightCtrl.text = package['height'].toString();
                    weightCtrl.text = package['tare_weight'].toString();
                  } else if (value == 'custom') {
                    package['packaging_type'] = '';
                    package['length'] = 0.0;
                    package['width'] = 0.0;
                    package['height'] = 0.0;
                    package['tare_weight'] = 0.0;
                    lengthCtrl.text = '0.0';
                    widthCtrl.text = '0.0';
                    heightCtrl.text = '0.0';
                    weightCtrl.text = '0.0';
                    customNameCtrl.text = '';
                  }
                });
              },
            ),
            if (selectedStandardPackageId != null && selectedStandardPackageId != 'custom')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Werte aus Vorlage übernommen – können angepasst werden.',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Versandgruppe
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildShipmentGroupDropdown(BuildContext context, ThemeData theme) {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        labelText: 'Sendung',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(8.0),
          child: getAdaptiveIcon(iconName: 'mail', defaultIcon: Icons.mail, size: 20),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        filled: true,
        fillColor: _getShipmentGroupColor(
          (package['shipment_group'] as num?)?.toInt() ?? 1,
        ).withOpacity(0.08),
      ),
      value: (package['shipment_group'] as num?)?.toInt() ?? (index + 1),
      items: List.generate(
        allPackages.length,
            (i) => DropdownMenuItem<int>(
          value: i + 1,
          child: Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: _getShipmentGroupColor(i + 1), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Sendung ${i + 1}'),
            ],
          ),
        ),
      ),
      onChanged: (value) => setModalState(() => package['shipment_group'] = value),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Abmessungen
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDimensionsRow(
      BuildContext context,
      TextEditingController lengthCtrl,
      TextEditingController widthCtrl,
      TextEditingController heightCtrl,
      ) {
    return Row(
      children: [
        Expanded(child: _dimensionField('Länge (cm)', lengthCtrl, (v) => package['length'] = double.tryParse(v) ?? 0.0)),
        const SizedBox(width: 8),
        Text('×', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        const SizedBox(width: 8),
        Expanded(child: _dimensionField('Breite (cm)', widthCtrl, (v) => package['width'] = double.tryParse(v) ?? 0.0)),
        const SizedBox(width: 8),
        Text('×', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        const SizedBox(width: 8),
        Expanded(child: _dimensionField('Höhe (cm)', heightCtrl, (v) => package['height'] = double.tryParse(v) ?? 0.0)),
      ],
    );
  }

  Widget _dimensionField(String label, TextEditingController controller, ValueChanged<String> onChanged) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tara-Gewicht
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTareWeightField(
      BuildContext context,
      TextEditingController weightCtrl,
      TextEditingController grossWeightCtrl,
      ) {
    return TextFormField(
      controller: weightCtrl,
      decoration: InputDecoration(
        labelText: 'Verpackungsgewicht / Tara (kg)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          return newValue.copyWith(text: newValue.text.replaceAll(',', '.'));
        }),
      ],
      onChanged: (value) {
        setModalState(() {
          package['tare_weight'] = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
          if (package['manual_gross_weight_mode'] != true) {
            package['gross_weight'] = null;
          }
        });
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Gewichtsübersicht
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWeightSummary(
      BuildContext context,
      ThemeData theme,
      TextEditingController grossWeightCtrl,
      TextEditingController weightCtrl,
      String? selectedStandardPackageId,
      ) {
    final netWeight = _calculateNetWeight();
    final grossWeight = _calculateGrossWeight();
    final tareWeight = (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
    final hasManualGross = package['gross_weight'] != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _weightRow('Nettogewicht (Produkte):', '${netWeight.toStringAsFixed(2)} kg', false),
          const SizedBox(height: 4),
          _weightRow('+ Tara (Verpackung):', '${tareWeight.toStringAsFixed(2)} kg', false),
          const Divider(height: 12),

          // Bruttogewicht Label
          Row(
            children: [
              const Text('= Bruttogewicht:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasManualGross ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasManualGross ? 'gemessen' : 'berechnet',
                  style: TextStyle(fontSize: 9, color: hasManualGross ? Colors.orange[700] : Colors.green[700]),
                ),
              ),
              const Spacer(),
              if (!hasManualGross)
                Text(
                  '${grossWeight.toStringAsFixed(2)} kg',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Bruttogewicht Eingabefeld
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextFormField(
                    controller: grossWeightCtrl,
                    decoration: InputDecoration(
                      hintText: 'Gewogenes Bruttogewicht',
                      suffixText: 'kg',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        return newValue.copyWith(text: newValue.text.replaceAll(',', '.'));
                      }),
                    ],
                    onChanged: (value) {
                      final gw = double.tryParse(value.replaceAll(',', '.'));
                      if (gw != null && gw > 0) {
                        setModalState(() {
                          package['gross_weight'] = gw;
                          final nw = _calculateNetWeight();
                          final calculatedTara = double.parse((gw - nw > 0 ? gw - nw : 0.0).toStringAsFixed(3));
                          package['tare_weight'] = calculatedTara;
                          weightCtrl.text = calculatedTara.toStringAsFixed(2);
                        });
                      } else if (value.isEmpty) {
                        setModalState(() {
                          package['gross_weight'] = null;
                          if (selectedStandardPackageId != null && selectedStandardPackageId != 'custom') {
                            FirebaseFirestore.instance
                                .collection('standardized_packages')
                                .doc(selectedStandardPackageId)
                                .get()
                                .then((doc) {
                              if (doc.exists) {
                                final data = doc.data() as Map<String, dynamic>;
                                setModalState(() {
                                  package['tare_weight'] = data['weight'] ?? 0.0;
                                  weightCtrl.text = package['tare_weight'].toString();
                                });
                              }
                            });
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              if (hasManualGross) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setModalState(() {
                      package['gross_weight'] = null;
                      grossWeightCtrl.clear();
                      if (selectedStandardPackageId != null && selectedStandardPackageId != 'custom') {
                        FirebaseFirestore.instance
                            .collection('standardized_packages')
                            .doc(selectedStandardPackageId)
                            .get()
                            .then((doc) {
                          if (doc.exists) {
                            final data = doc.data() as Map<String, dynamic>;
                            setModalState(() {
                              package['tare_weight'] = data['weight'] ?? 0.0;
                              weightCtrl.text = package['tare_weight'].toString();
                            });
                          }
                        });
                      }
                    });
                  },
                  icon: getAdaptiveIcon(iconName: 'autorenew', defaultIcon: Icons.autorenew, size: 18),
                  tooltip: 'Zurück zu automatischer Berechnung',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),

          if (hasManualGross)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tara auf ${(package['tare_weight'] as num?)?.toStringAsFixed(2) ?? '0.00'} kg angepasst '
                    '(berechnet: ${grossWeight.toStringAsFixed(2)} kg)',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _weightRow(String label, String value, bool bold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Zugewiesene Produkte – professionelle Anzeige
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAssignedProductsSection(BuildContext context, ThemeData theme) {
    final items = package['items'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            getAdaptiveIcon(
              iconName: 'list_alt',
              defaultIcon: Icons.list_alt,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Zugewiesene Produkte',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                getAdaptiveIcon(
                  iconName: 'inbox',
                  defaultIcon: Icons.inbox,
                  size: 28,
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                ),
                const SizedBox(height: 6),
                Text(
                  'Noch keine Produkte zugewiesen',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          )
        else
          ...items.map<Widget>((assignedItem) {
            return _AssignedProductTile(
              item: Map<String, dynamic>.from(assignedItem as Map),
              theme: theme,
              onRemove: () {
                setModalState(() {
                  (package['items'] as List).remove(assignedItem);
                });
              },
            );
          }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Einzelne Produkt-Kachel in der Zuweisungsliste
// ═══════════════════════════════════════════════════════════════════════════════

class _AssignedProductTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final ThemeData theme;
  final VoidCallback onRemove;

  const _AssignedProductTile({
    required this.item,
    required this.theme,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final productName = item['product_name'] ?? '';
    final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    final unit = item['unit'] ?? 'Stk';
    final woodName = item['wood_name'] ?? '';
    final qualityName = item['quality_name'] ?? '';
    final instrumentName = item['instrument_name'] ?? '';
    final partName = item['part_name'] ?? '';
    final length = (item['custom_length'] as num?)?.toDouble() ?? 0.0;
    final width = (item['custom_width'] as num?)?.toDouble() ?? 0.0;
    final thickness = (item['custom_thickness'] as num?)?.toDouble() ?? 0.0;
    final density = (item['density'] as num?)?.toInt();
    final hasThermal = item['has_thermal_treatment'] == true;
    final thermalTemp = (item['thermal_treatment_temperature'] as num?)?.toInt();

    // Details zusammenbauen
    final details = <String>[
      if (woodName.isNotEmpty) woodName,
      if (qualityName.isNotEmpty) qualityName,
      if (length > 0 && width > 0 && thickness > 0)
        '${length.toStringAsFixed(0)}×${width.toStringAsFixed(0)}×${thickness.toStringAsFixed(0)}mm',
      if (density != null && density > 0) '$density kg/m³',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          // Menge-Badge
          Container(
            width: 38,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(
                  '${quantity % 1 == 0 ? quantity.toInt() : quantity}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 8,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Produkt-Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details.isNotEmpty || hasThermal) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
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
                      if (hasThermal && thermalTemp != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '🔥 $thermalTemp°C',
                            style: TextStyle(fontSize: 9, color: Colors.deepOrange[700]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Entfernen-Button
          IconButton(
            onPressed: onRemove,
            icon: getAdaptiveIcon(
              iconName: 'close',
              defaultIcon: Icons.close,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            iconSize: 16,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: 'Entfernen',
          ),
        ],
      ),
    );
  }
}