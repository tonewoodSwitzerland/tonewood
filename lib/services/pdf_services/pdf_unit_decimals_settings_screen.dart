// File: lib/services/pdf_services/pdf_unit_decimals_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../icon_helper.dart';

/// Globale Einstellungen für Nachkommastellen pro Einheit in allen PDFs.
/// Speichert nach Firestore unter general_data/pdf_settings.unit_decimals
class PdfUnitDecimalsSettingsScreen extends StatefulWidget {
  const PdfUnitDecimalsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PdfUnitDecimalsSettingsScreen> createState() =>
      _PdfUnitDecimalsSettingsScreenState();
}

class _PdfUnitDecimalsSettingsScreenState
    extends State<PdfUnitDecimalsSettingsScreen> {
  bool _isLoading = true;

  // Defaults entsprechen Wunsch des Users:
  // Stk = 0, m² = 2, m³ = 3, kg = 3
  int _piecesDecimals = 0;
  int _areaDecimals = 2;
  int _volumeDecimals = 3;
  int _weightDecimals = 3;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final unitDecimals = data['unit_decimals'] as Map<String, dynamic>?;
        if (unitDecimals != null) {
          setState(() {
            _piecesDecimals =
                (unitDecimals['pieces'] as num?)?.toInt() ?? 0;
            _areaDecimals = (unitDecimals['area'] as num?)?.toInt() ?? 2;
            _volumeDecimals =
                (unitDecimals['volume'] as num?)?.toInt() ?? 3;
            _weightDecimals =
                (unitDecimals['weight'] as num?)?.toInt() ?? 3;
          });
        }
      }
    } catch (e) {
      print('Fehler beim Laden der Nachkommastellen-Einstellungen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_settings')
          .set({
        'unit_decimals': {
          'pieces': _piecesDecimals,
          'area': _areaDecimals,
          'volume': _volumeDecimals,
          'weight': _weightDecimals,
        },
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Einstellungen gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Speichern der Nachkommastellen-Einstellungen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatExample(double value, int decimals, String unit) {
    return '${value.toStringAsFixed(decimals)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nachkommastellen'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: getAdaptiveIcon(
                iconName: 'save',
                defaultIcon: Icons.save,
                size: 18,
              ),
              label: const Text('Speichern'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info-Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'info',
                    defaultIcon: Icons.info,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lege fest, mit wie vielen Nachkommastellen die Mengen pro Einheit in allen PDF-Dokumenten dargestellt werden.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stück
            _buildDecimalCard(
              icon: Icons.format_list_numbered,
              iconName: 'format_list_numbered',
              title: 'Stück (Stk / pcs)',
              description: 'Anzahl ganzer Stücke',
              decimals: _piecesDecimals,
              onChanged: (v) =>
                  setState(() => _piecesDecimals = v),
              exampleValue: 5,
              exampleUnit: 'Stk',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),

            // m²
            _buildDecimalCard(
              icon: Icons.crop_square,
              iconName: 'crop_square',
              title: 'Fläche (m²)',
              description: 'Quadratmeter',
              decimals: _areaDecimals,
              onChanged: (v) =>
                  setState(() => _areaDecimals = v),
              exampleValue: 2.55,
              exampleUnit: 'm²',
              color: Colors.green,
            ),
            const SizedBox(height: 12),

            // m³
            _buildDecimalCard(
              icon: Icons.view_in_ar,
              iconName: 'view_in_ar',
              title: 'Volumen (m³)',
              description: 'Kubikmeter',
              decimals: _volumeDecimals,
              onChanged: (v) =>
                  setState(() => _volumeDecimals = v),
              exampleValue: 7.554,
              exampleUnit: 'm³',
              color: Colors.purple,
            ),
            const SizedBox(height: 12),

            // kg
            _buildDecimalCard(
              icon: Icons.scale,
              iconName: 'scale',
              title: 'Gewicht (kg)',
              description: 'Kilogramm',
              decimals: _weightDecimals,
              onChanged: (v) =>
                  setState(() => _weightDecimals = v),
              exampleValue: 4.456,
              exampleUnit: 'kg',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecimalCard({
    required IconData icon,
    required String iconName,
    required String title,
    required String description,
    required int decimals,
    required ValueChanged<int> onChanged,
    required double exampleValue,
    required String exampleUnit,
    required Color color,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: getAdaptiveIcon(
                      iconName: iconName,
                      defaultIcon: icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Auswahl der Nachkommastellen
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [

                Wrap(
                  spacing: 9,
                  children: List.generate(7, (i) {
                    final selected = decimals == i;
                    return ChoiceChip(
                      label: Text(i.toString()),
                      selected: selected,
                      onSelected: (s) {
                        if (s) onChanged(i);
                      },
                      selectedColor: color.withOpacity(0.2),
                      labelStyle: TextStyle(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: selected ? color : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live-Vorschau
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'visibility',
                    defaultIcon: Icons.visibility,
                    color: color,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Vorschau: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    _formatExample(exampleValue, decimals, exampleUnit),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}