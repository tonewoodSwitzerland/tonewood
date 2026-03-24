// lib/screens/orders/edit_item_measurements_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/icon_helper.dart';
import 'order_model.dart';

class EditItemMeasurementsDialog {
  // Komma → Punkt ersetzen + nur gültige Dezimalzahlen erlauben
  static final List<TextInputFormatter> _decimalFormatters = [
    _CommaToPointFormatter(),
    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
  ];

  // Nur ganze Zahlen
  static final List<TextInputFormatter> _integerFormatters = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  static void show(
      BuildContext context,
      OrderX order,
      Map<String, dynamic> item,
      int itemIndex,
      ) {
    // Prüfe ob parts in der Datenbank fehlt
    final bool partsIsMissing = item['parts'] == null;

    // Controller für die Eingabefelder
    final lengthController = TextEditingController(
      text: item['custom_length']?.toString() ?? '',
    );
    final widthController = TextEditingController(
      text: item['custom_width']?.toString() ?? '',
    );
    final thicknessController = TextEditingController(
      text: item['custom_thickness']?.toString() ?? '',
    );
    final partsController = TextEditingController(
      text: item['parts']?.toString() ?? '1', // Standard: 1 wenn fehlt
    );
// NEU: Controller für direktes Volumen (volume_per_unit in m³)
    final existingVolumePerUnit = (item['volume_per_unit'] as num?)?.toDouble() ?? 0.0;
    final volumeDirectController = TextEditingController(
      text: existingVolumePerUnit > 0 ? existingVolumePerUnit.toString() : '',
    );

    // Bestimme initialen Modus: Wenn Einzelmaße vorhanden → berechnet, sonst direkt
    final hasExistingDimensions = (item['custom_length'] as num?)?.toDouble() != null &&
        (item['custom_length'] as num?)?.toDouble() != 0 &&
        (item['custom_width'] as num?)?.toDouble() != null &&
        (item['custom_width'] as num?)?.toDouble() != 0 &&
        (item['custom_thickness'] as num?)?.toDouble() != null &&
        (item['custom_thickness'] as num?)?.toDouble() != 0;

    // Modus: 'calculated' = aus Einzelmaßen, 'direct' = manuell als m³
    String volumeMode;
    final savedMode = item['volume_mode'] as String?;
    if (savedMode == 'calculated' || savedMode == 'direct') {
      volumeMode = savedMode!;
    } else {
      volumeMode = hasExistingDimensions ? 'calculated' : (existingVolumePerUnit > 0 ? 'direct' : 'calculated');
    }

// NEU: Controller für Zolltarifnummer und Hinweise
    final customTariffController = TextEditingController(
      text: item['custom_tariff_number']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: item['notes']?.toString() ?? '',
    );
    final existingCustomDensity = (item['custom_density'] as num?)?.toDouble() ?? 0;
    final customDensityController = TextEditingController(
      text: existingCustomDensity > 0 ? existingCustomDensity.toStringAsFixed(0) : '',
    );
    // Anzahl (quantity) - nicht editierbar, nur zur Anzeige
    final quantity = (item['quantity'] as num?)?.toDouble() ?? 1;
    bool densityEditMode = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Werte auslesen
          final length = double.tryParse(lengthController.text) ?? 0;
          final width = double.tryParse(widthController.text) ?? 0;
          final thickness = double.tryParse(thicknessController.text) ?? 0;
          final parts = double.tryParse(partsController.text) ?? 1;

          // Volumen-Berechnung
          final hasValidDimensions = length > 0 && width > 0 && thickness > 0;

          // Volumen pro Stück (L × B × D × Teile) in mm³
          final volumePerPieceMm3 =
          hasValidDimensions ? length * width * thickness * parts : 0.0;

          // Gesamtvolumen (Volumen pro Stück × Anzahl) in mm³
          final totalVolumeMm3 = volumePerPieceMm3 * quantity;

          // Umrechnungen
          final volumePerPieceDm3 = volumePerPieceMm3 / 1000000;
          final volumePerPieceM3 = volumePerPieceMm3 / 1000000000;
          final totalVolumeDm3 = totalVolumeMm3 / 1000000;
          final totalVolumeM3 = totalVolumeMm3 / 1000000000;
// Gewichtsberechnung
          final density = (item['density'] as num?)?.toDouble() ?? 0;
          final weightPerPiece = volumePerPieceM3 * density; // kg pro Stück
          final totalWeight = weightPerPiece * quantity;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          getAdaptiveIcon(
                            iconName: 'straighten',
                            defaultIcon: Icons.straighten,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Artikel bearbeiten',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['product_name']?.toString() ?? 'Produkt',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Anzahl-Badge (nicht editierbar)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                getAdaptiveIcon(
                                  iconName: 'shopping_cart',
                                  defaultIcon: Icons.shopping_cart,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} Stk',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: getAdaptiveIcon(
                                iconName: 'close', defaultIcon: Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // WARNUNG: Parts fehlt in Datenbank
                          if (partsIsMissing) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  getAdaptiveIcon(
                                    iconName: 'warning',
                                    defaultIcon: Icons.warning_amber_rounded,
                                    size: 24,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Anzahl Teile fehlt in Datenbank',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bitte manuell korrigieren (Standardwert: 1)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Maße Eingabefelder - Responsive Layout
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Mobile: 2x2 Grid, Desktop: eine Zeile
                              final isMobile = constraints.maxWidth < 500;

                              if (isMobile) {
                                return Column(
                                  children: [
                                    // Erste Zeile: Länge + Breite
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDimensionField(
                                            context: context,
                                            label: 'Länge (mm)',
                                            controller: lengthController,
                                            iconName: 'arrow_right_alt',
                                            icon: Icons.arrow_right_alt,
                                            onChanged: () => setModalState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildDimensionField(
                                            context: context,
                                            label: 'Breite (mm)',
                                            controller: widthController,
                                            iconName: 'swap_horiz',
                                            icon: Icons.swap_horiz,
                                            onChanged: () => setModalState(() {}),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Zweite Zeile: Dicke + Teile
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDimensionField(
                                            context: context,
                                            label: 'Dicke (mm)',
                                            controller: thicknessController,
                                            iconName: 'height',
                                            icon: Icons.height,
                                            onChanged: () => setModalState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildPartsField(
                                            context: context,
                                            controller: partsController,
                                            isMissing: partsIsMissing,
                                            onChanged: () => setModalState(() {}),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              } else {
                                // Desktop: Original-Layout (eine Zeile)
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _buildDimensionField(
                                        context: context,
                                        label: 'Länge (mm)',
                                        controller: lengthController,
                                        iconName: 'arrow_right_alt',
                                        icon: Icons.arrow_right_alt,
                                        onChanged: () => setModalState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildDimensionField(
                                        context: context,
                                        label: 'Breite (mm)',
                                        controller: widthController,
                                        iconName: 'swap_horiz',
                                        icon: Icons.swap_horiz,
                                        onChanged: () => setModalState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildDimensionField(
                                        context: context,
                                        label: 'Dicke (mm)',
                                        controller: thicknessController,
                                        iconName: 'height',
                                        icon: Icons.height,
                                        onChanged: () => setModalState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 80,
                                      child: _buildPartsField(
                                        context: context,
                                        controller: partsController,
                                        isMissing: partsIsMissing,
                                        onChanged: () => setModalState(() {}),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),

                          const SizedBox(height: 20),

                          // === VOLUMEN MODUS TOGGLE ===
                          _buildVolumeModeToggle(
                            context: context,
                            volumeMode: volumeMode,
                            onModeChanged: (newMode) {
                              setModalState(() {
                                volumeMode = newMode;
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          // Volumen-Anzeige je nach Modus
                          if (volumeMode == 'calculated') ...[
                            // Berechnetes Volumen aus Einzelmaßen
                            _buildVolumeSection(
                              context: context,
                              hasValidDimensions: hasValidDimensions,
                              length: length,
                              width: width,
                              thickness: thickness,
                              parts: parts,
                              quantity: quantity,
                              volumePerPieceMm3: volumePerPieceMm3,
                              volumePerPieceDm3: volumePerPieceDm3,
                              volumePerPieceM3: volumePerPieceM3,
                              totalVolumeMm3: totalVolumeMm3,
                              totalVolumeDm3: totalVolumeDm3,
                              totalVolumeM3: totalVolumeM3,
                              isActive: true,
                            ),
                            // Nur Hinweis wenn BEIDE Seiten Werte haben → echter Konflikt
                            if (existingVolumePerUnit > 0 && hasValidDimensions) ...[
                              const SizedBox(height: 8),
                              _buildInactiveVolumeHint(
                                context: context,
                                label: 'Gespeichertes Direktvolumen',
                                valueM3: existingVolumePerUnit,
                                quantity: quantity,
                                hint: 'Wird ignoriert – Einzelmaße werden verwendet',
                              ),
                            ],
                          ] else ...[
                            // Direktes Volumen Eingabefeld
                            _buildDirectVolumeSection(
                              context: context,
                              volumeDirectController: volumeDirectController,
                              quantity: quantity,
                              onChanged: () => setModalState(() {}),
                            ),
                            // Nur Hinweis wenn BEIDE Seiten Werte haben → echter Konflikt
                            if (hasValidDimensions && (double.tryParse(volumeDirectController.text) ?? 0) > 0) ...[
                              const SizedBox(height: 8),
                              _buildInactiveVolumeHint(
                                context: context,
                                label: 'Berechnetes Volumen (L×B×D)',
                                valueM3: volumePerPieceM3,
                                quantity: quantity,
                                hint: 'Wird ignoriert – Direkteingabe wird verwendet',
                              ),
                            ],
                          ],
                          const SizedBox(height: 20),
                          Builder(
                            builder: (context) {
                              // Gewicht basierend auf aktivem Volumen-Modus
                              double effectiveVolumePerPieceM3;
                              bool effectiveHasVolume;

                              if (volumeMode == 'calculated') {
                                effectiveVolumePerPieceM3 = volumePerPieceM3;
                                effectiveHasVolume = hasValidDimensions;
                              } else {
                                final directVal = double.tryParse(volumeDirectController.text) ?? 0;
                                effectiveVolumePerPieceM3 = directVal;
                                effectiveHasVolume = directVal > 0;
                              }
// NEU: Custom-Dichte hat Vorrang
                              final customDensityVal = double.tryParse(customDensityController.text);
                              final effectiveDensity = (customDensityVal != null && customDensityVal > 0)
                                  ? customDensityVal
                                  : density; // density = 0 in deinem Fall

                              final effectiveWeightPerPiece = effectiveVolumePerPieceM3 * effectiveDensity;
                              final effectiveTotalWeight = effectiveWeightPerPiece * quantity;
                              return _buildWeightSection(
                                context: context,
                                hasValidDimensions: effectiveHasVolume,
                                density: density,                        // Original-Dichte (für helperText)
                                effectiveDensity: effectiveDensity,      // Wird tatsächlich gerechnet
                                weightPerPiece: effectiveWeightPerPiece,
                                totalWeight: effectiveTotalWeight,
                                quantity: quantity,
                                volumePerPieceM3: effectiveVolumePerPieceM3,
                                unit: item['unit']?.toString() ?? 'Stück',
                                densityEditMode: densityEditMode,
                                customDensityController: customDensityController,
                                onToggleDensityEdit: () => setModalState(() {
                                  densityEditMode = !densityEditMode;
                                }),
                                onDensityChanged: () => setModalState(() {}),
                              );
                            },
                          ),
// NEU: Zolltarifnummer
                          // NEU: Zolltarifnummer (berechnet aus Holzart + Dicke)
                          const SizedBox(height: 20),
                          FutureBuilder<String?>(
                            future: _calculateTariffNumber(item, thickness),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                item['_calculated_tariff'] = snapshot.data;
                              }
                              return _buildTariffSection(
                                context: context,
                                item: item,
                                customTariffController: customTariffController,
                                onChanged: () => setModalState(() {}),
                              );
                            },
                          ),
// NEU: Hinweise
                          const SizedBox(height: 20),
                          _buildNotesSection(
                            context: context,
                            notesController: notesController,
                          ),
                          const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Abbrechen'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _saveChanges(
                                    context: context,
                                    order: order,
                                    item: item,
                                    itemIndex: itemIndex,
                                    lengthController: lengthController,
                                    widthController: widthController,
                                    thicknessController: thicknessController,
                                    partsController: partsController,
                                    customTariffController: customTariffController,
                                    notesController: notesController,
                                    quantity: quantity,
                                    volumeMode: volumeMode,
                                    volumeDirectController: volumeDirectController,
                                    customDensityController: customDensityController,
                                  ),
                                  icon: getAdaptiveIcon(
                                    iconName: 'save',
                                    defaultIcon: Icons.save,
                                  ),
                                  label: const Text('Speichern'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================

  static Widget _buildDimensionField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required String iconName,
    required IconData icon,
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _decimalFormatters,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: getAdaptiveIcon(
              iconName: iconName,
              defaultIcon: icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor:
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }

  static Widget _buildPartsField({
    required BuildContext context,
    required TextEditingController controller,
    required bool isMissing,
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Teile',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isMissing
                    ? Colors.orange.shade700
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
            if (isMissing) ...[
              const SizedBox(width: 4),
              getAdaptiveIcon(
                iconName: 'warning',
                defaultIcon: Icons.warning_amber,
                size: 12,
                color: Colors.orange.shade700,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: _integerFormatters,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '1',
            prefixIcon: getAdaptiveIcon(
              iconName: 'layers',
              defaultIcon: Icons.layers,
              color: isMissing
                  ? Colors.orange.shade700
                  : Theme.of(context).colorScheme.secondary,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isMissing
                    ? Colors.orange
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isMissing
                    ? Colors.orange.withOpacity(0.7)
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                width: isMissing ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isMissing
                    ? Colors.orange
                    : Theme.of(context).colorScheme.secondary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isMissing
                ? Colors.orange.withOpacity(0.1)
                : Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withOpacity(0.3),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
  static Widget _buildTariffSection({
    required BuildContext context,
    required Map<String, dynamic> item,
    required TextEditingController customTariffController,
    required VoidCallback onChanged,
  }) {
    // Standard-Zolltarifnummer aus dem Item (falls vorhanden)
    // Standard-Zolltarifnummer berechnen aus Holzart + Dicke
    String? standardTariff = item['_calculated_tariff']?.toString() ??
        item['tariff_number']?.toString() ??
        item['standard_tariff_number']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Zolltarifnummer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),

          // Standard-Zolltarifnummer anzeigen (falls vorhanden)
          if (standardTariff != null && standardTariff.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'info',
                    defaultIcon: Icons.info,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Standard-Zolltarifnummer',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          standardTariff,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          TextField(
            controller: customTariffController,
            decoration: InputDecoration(
              labelText: 'Individuelle Zolltarifnummer',
              hintText: 'z.B. 4407.1200',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: getAdaptiveIcon(
                  iconName: 'edit',
                  defaultIcon: Icons.edit,
                  size: 20,
                ),
              ),
              helperText: standardTariff != null
                  ? 'Überschreibt die Standard-Zolltarifnummer'
                  : 'Zolltarifnummer für Handelsrechnungen',
              suffixIcon: customTariffController.text.isNotEmpty
                  ? IconButton(
                icon: getAdaptiveIcon(
                  iconName: 'clear',
                  defaultIcon: Icons.clear,
                  size: 18,
                ),
                onPressed: () {
                  customTariffController.clear();
                  onChanged();
                },
              )
                  : null,
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }

  static Widget _buildNotesSection({
    required BuildContext context,
    required TextEditingController notesController,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'note',
                defaultIcon: Icons.note_alt,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Hinweise',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: 'Spezielle Hinweise (optional)',
              hintText: 'z.B. besondere Qualitätsmerkmale, Lagerort, etc.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            minLines: 2,
          ),
        ],
      ),
    );
  }
  static Future<String?> _calculateTariffNumber(Map<String, dynamic> item, double thickness) async {
    // DEBUG
    print('🔍 _calculateTariffNumber called');
    print('   thickness: $thickness');
    print('   wood_code: ${item['wood_code']}');
    print('   item keys: ${item.keys.toList()}');

    if (thickness <= 0) {
      print('   ❌ thickness <= 0, returning null');
      return null;
    }

    final woodCode = item['wood_code'] as String? ?? '';
    if (woodCode.isEmpty) {
      print('   ❌ woodCode is empty, returning null');
      return null;
    }

    try {
      final woodTypeDoc = await FirebaseFirestore.instance
          .collection('wood_types')
          .doc(woodCode)
          .get();

      print('   Firestore doc exists: ${woodTypeDoc.exists}');

      if (!woodTypeDoc.exists) {
        print('   ❌ wood_types/$woodCode does not exist');
        return null;
      }

      final woodInfo = woodTypeDoc.data()!;
      print('   woodInfo keys: ${woodInfo.keys.toList()}');
      print('   z_tares_1: ${woodInfo['z_tares_1']}');
      print('   z_tares_2: ${woodInfo['z_tares_2']}');

      if (thickness <= 6.0) {
        final result = woodInfo['z_tares_1']?.toString() ?? '4408.1000';
        print('   ✅ thickness <= 6mm → $result');
        return result;
      } else {
        final result = woodInfo['z_tares_2']?.toString() ?? '4407.1200';
        print('   ✅ thickness > 6mm → $result');
        return result;
      }
    } catch (e) {
      print('   ❌ Error: $e');
      return null;
    }
  }
  static Widget _buildWeightSection({
    required BuildContext context,
    required bool hasValidDimensions,
    required double density,           // Original (nur für helperText)
    required double effectiveDensity,  // NEU: wird tatsächlich verwendet
    required double weightPerPiece,
    required double totalWeight,
    required double quantity,
    required double volumePerPieceM3,
    required String unit,
    required bool densityEditMode,
    required TextEditingController customDensityController,
    required VoidCallback onToggleDensityEdit,
    required VoidCallback onDensityChanged,
  }){
    final hasWeight = hasValidDimensions && effectiveDensity > 0;
// Effektive Dichte für Anzeige
    final effectiveDensityDisplay = (double.tryParse(customDensityController.text) ?? 0) > 0
        ? double.parse(customDensityController.text)
        : density;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasWeight
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWeight
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'scale',
                defaultIcon: Icons.scale,
                size: 20,
                color: hasWeight
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                'Gewichtsberechnung',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasWeight
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              if (hasWeight) ...[
                // Dichte-Badge mit Stift
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: customDensityController.text.isNotEmpty
                            ? Colors.orange.withOpacity(0.15)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${effectiveDensity.toStringAsFixed(0)} kg/m³',  style: TextStyle(
                          fontSize: 11,
                          color: customDensityController.text.isNotEmpty
                              ? Colors.orange.shade700
                              : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onToggleDensityEdit,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: densityEditMode
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 14,
                          color: densityEditMode
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
// Manuelle Dichte-Eingabe (nur wenn Edit-Mode aktiv)
          if (densityEditMode) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customDensityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalFormatters,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Manuelle Dichte',
                      suffixText: 'kg/m³',
                      hintText: density > 0 ? density.toStringAsFixed(0) : '600',
                      helperText: density > 0
                          ? 'Überschreibt die hinterlegte Dichte (${density.toStringAsFixed(0)} kg/m³)'
                          : 'Keine Dichte hinterlegt',  border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      prefixIcon: Icon(
                        Icons.scale,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onChanged: (_) => onDensityChanged(),
                  ),
                ),
                if (customDensityController.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      customDensityController.clear();
                      onDensityChanged();
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Zurücksetzen',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (hasWeight) ...[
            const SizedBox(height: 16),

            // Formel
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${volumePerPieceM3.toStringAsFixed(7)} m³ × ${effectiveDensityDisplay.toStringAsFixed(0)} kg/m³',  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gewicht pro $unit:',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '${weightPerPiece.toStringAsFixed(3)} kg',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (quantity > 1) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gesamtgewicht (${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} Stk):',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${totalWeight.toStringAsFixed(2)} kg',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                effectiveDensity <= 0
                    ? 'Keine Dichte hinterlegt – Gewicht kann nicht berechnet werden'
                    : 'Gib alle Maße ein, um das Gewicht zu berechnen',   style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
  static Widget _buildVolumeSection({
    required BuildContext context,
    required bool hasValidDimensions,
    required double length,
    required double width,
    required double thickness,
    required double parts,
    required double quantity,
    required double volumePerPieceMm3,
    required double volumePerPieceDm3,
    required double volumePerPieceM3,
    required double totalVolumeMm3,
    required double totalVolumeDm3,
    required double totalVolumeM3,
    bool isActive = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasValidDimensions
            ? Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValidDimensions
              ? Theme.of(context).colorScheme.tertiary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'view_in_ar',
                defaultIcon: Icons.view_in_ar,
                size: 20,
                color: hasValidDimensions
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                'Berechnetes Volumen',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasValidDimensions
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              if (hasValidDimensions)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'check',
                        defaultIcon: Icons.check,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Gültig',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (hasValidDimensions) ...[
            const SizedBox(height: 16),

            // Formel-Anzeige: Volumen pro Stück
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'functions',
                        defaultIcon: Icons.functions,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Volumen pro Stück',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${length.toStringAsFixed(1)} × ${width.toStringAsFixed(1)} × ${thickness.toStringAsFixed(1)} × ${parts.toStringAsFixed(0)} Teile',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '= ${_formatVolumeNumber(volumePerPieceMm3, 0)} mm³',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Formel-Anzeige: Gesamtvolumen
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
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
                        iconName: 'calculate',
                        defaultIcon: Icons.calculate,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Gesamtvolumen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '× ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} Stk',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatVolumeNumber(volumePerPieceMm3, 0)} mm³ × ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '= ${_formatVolumeNumber(totalVolumeMm3, 0)} mm³',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Volumen-Tabelle
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.5),
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 50),
                        Expanded(
                          child: Text(
                            'Pro Stück',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gesamt',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rows
                  // _buildVolumeTableRow(
                  //     context, 'mm³', volumePerPieceMm3, totalVolumeMm3, 0),
                  // _buildVolumeTableRow(
                  //     context, 'dm³', volumePerPieceDm3, totalVolumeDm3, 4),
                  _buildVolumeTableRow(
                      context, 'm³', volumePerPieceM3, totalVolumeM3, 6),
                ],
              ),
            ),
          ] else ...[
            // Placeholder wenn keine gültigen Werte
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  getAdaptiveIcon(
                    iconName: 'calculate',
                    defaultIcon: Icons.calculate,
                    size: 32,
                    color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gib alle Maße ein, um das Volumen zu berechnen',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],


        ],
      ),
    );
  }

  // ============================================================
  // VOLUME MODE TOGGLE & DIRECT VOLUME INPUT
  // ============================================================

  static Widget _buildVolumeModeToggle({
    required BuildContext context,
    required String volumeMode,
    required Function(String) onModeChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged('calculated'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: volumeMode == 'calculated'
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: volumeMode == 'calculated'
                      ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 16,
                      color: volumeMode == 'calculated'
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Einzelmaße (L×B×D)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: volumeMode == 'calculated'
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged('direct'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: volumeMode == 'direct'
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: volumeMode == 'direct'
                      ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.view_in_ar,
                      size: 16,
                      color: volumeMode == 'direct'
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Volumen direkt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: volumeMode == 'direct'
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDirectVolumeSection({
    required BuildContext context,
    required TextEditingController volumeDirectController,
    required double quantity,
    required VoidCallback onChanged,
  }) {
    final directVal = double.tryParse(volumeDirectController.text) ?? 0;
    final hasValue = directVal > 0;
    final totalVolumeM3 = directVal * quantity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasValue
            ? Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue
              ? Theme.of(context).colorScheme.tertiary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'view_in_ar',
                defaultIcon: Icons.view_in_ar,
                size: 20,
                color: hasValue
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                'Volumen pro Einheit (direkt)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasValue
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              if (hasValue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      getAdaptiveIcon(
                        iconName: 'check',
                        defaultIcon: Icons.check,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Aktiv',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Eingabefeld für Volumen in m³
          TextField(
            controller: volumeDirectController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _decimalFormatters,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Volumen pro Einheit',
              suffixText: 'm³',
              hintText: 'z.B. 0.000125',
              prefixIcon: getAdaptiveIcon(
                iconName: 'view_in_ar',
                defaultIcon: Icons.view_in_ar,
                color: Theme.of(context).colorScheme.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              helperText: 'Volumen pro Stück in Kubikmetern (m³)',
            ),
            onChanged: (_) => onChanged(),
          ),

          if (hasValue) ...[
            const SizedBox(height: 16),

            // Gesamtvolumen
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
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
                        iconName: 'calculate',
                        defaultIcon: Icons.calculate,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Gesamtvolumen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '× ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} Stk',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${directVal.toStringAsFixed(7)} m³ × ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '= ${totalVolumeM3.toStringAsFixed(7)} m³',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildInactiveVolumeHint({
    required BuildContext context,
    required String label,
    required double valueM3,
    required double quantity,
    required String hint,
  }) {
    final totalM3 = valueM3 * quantity;
    final showTotal = quantity > 1;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showTotal
                      ? '$label: ${valueM3.toStringAsFixed(7)} m³/Stk × ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} = ${totalM3.toStringAsFixed(7)} m³'
                      : '$label: ${valueM3.toStringAsFixed(7)} m³',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildVolumeTableRow(
      BuildContext context,
      String unit,
      double perPiece,
      double total,
      int decimals,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              unit,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              decimals == 0
                  ? _formatVolumeNumber(perPiece, 0)
                  : perPiece.toStringAsFixed(decimals),
              style: TextStyle(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              decimals == 0
                  ? _formatVolumeNumber(total, 0)
                  : total.toStringAsFixed(decimals),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatVolumeNumber(double value, int decimals) {
    if (decimals == 0) {
      return value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
      );
    }
    return value.toStringAsFixed(decimals);
  }

  static Future<void> _saveChanges({
    required BuildContext context,
    required OrderX order,
    required Map<String, dynamic> item,
    required int itemIndex,
    required TextEditingController lengthController,
    required TextEditingController widthController,
    required TextEditingController thicknessController,
    required TextEditingController partsController,
    required TextEditingController customTariffController,
    required TextEditingController notesController,
    required double quantity,
    required String volumeMode,
    required TextEditingController volumeDirectController,
    required TextEditingController customDensityController,
  }) async {
    // Validiere und parse die Eingaben
    final lengthVal = double.tryParse(lengthController.text);
    final widthVal = double.tryParse(widthController.text);
    final thicknessVal = double.tryParse(thicknessController.text);
    final partsVal = int.tryParse(partsController.text) ?? 1;

    try {
      // Update das Item in der Liste
      final updatedItems = List<Map<String, dynamic>>.from(order.items);

      // Volumen je nach Modus berechnen
      double? volPerPiece;       // in mm³ (für berechneten Modus)
      double? volTotal;          // in mm³
      double? volumePerUnitM3;   // in m³ (für beide Modi, als Endwert)

      if (volumeMode == 'calculated') {
        // Berechne Volumen aus Einzelmaßen
        if (lengthVal != null &&
            widthVal != null &&
            thicknessVal != null &&
            lengthVal > 0 &&
            widthVal > 0 &&
            thicknessVal > 0) {
          volPerPiece = lengthVal * widthVal * thicknessVal * partsVal;
          volTotal = volPerPiece * quantity;
          volumePerUnitM3 = volPerPiece / 1000000000;
        }
      } else {
        // Direktes Volumen in m³
        final directVal = double.tryParse(volumeDirectController.text);
        if (directVal != null && directVal > 0) {
          volumePerUnitM3 = directVal;
          volPerPiece = directVal * 1000000000; // zurück zu mm³
          volTotal = volPerPiece * quantity;
        }
      }

      // Update direkt am korrekten Index
      updatedItems[itemIndex] = {
        ...updatedItems[itemIndex],
        'custom_length': lengthVal,
        'custom_width': widthVal,
        'custom_thickness': thicknessVal,
        'parts': partsVal,
        'volume_mode': volumeMode, // Speichere welcher Modus aktiv war

        // Volumen pro Stück
        'volume_per_unit_mm3': volPerPiece,
        'volume_per_unit_dm3': volPerPiece != null ? volPerPiece / 1000000 : null,
        'volume_per_unit_m3': volumePerUnitM3,
        'volume_per_unit': volumePerUnitM3,

        // Gesamtvolumen
        'total_volume_mm3': volTotal,
        'total_volume_dm3': volTotal != null ? volTotal / 1000000 : null,
        'total_volume_m3': volTotal != null ? volTotal / 1000000000 : null,
        'custom_density': (double.tryParse(customDensityController.text) ?? 0) > 0
            ? double.tryParse(customDensityController.text)
            : null,
        'custom_tariff_number': customTariffController.text.trim().isNotEmpty
            ? customTariffController.text.trim()
            : null,
        'notes': notesController.text.trim().isNotEmpty
            ? notesController.text.trim()
            : null,
      };

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
        'items': updatedItems,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Erstelle History-Eintrag
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .collection('history')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': user?.uid ?? 'unknown',
        'user_email': user?.email ?? 'Unknown User',
        'user_name': user?.email ?? 'Unknown',
        'action': 'measurements_updated',
        'product_name': item['product_name'],
        'item_index': itemIndex,
        'measurements': {
          'length': lengthVal,
          'width': widthVal,
          'thickness': thicknessVal,
          'parts': partsVal,
          'quantity': quantity,
          'volume_mode': volumeMode,
          'volume_per_unit_m3': volumePerUnitM3,
          'volume_per_unit_mm3': volPerPiece,
          'total_volume_mm3': volTotal,
        },
      });

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maße für ${item['product_name']} wurden aktualisiert'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Aktualisieren: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}

/// Ersetzt Kommas durch Punkte bei der Eingabe, damit deutsche Tastatur
/// kein falsches Format erzeugt (z.B. "0,5" → "0.5")
class _CommaToPointFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.replaceAll(',', '.'),
    );
  }
}