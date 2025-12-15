// File: lib/home/pdf_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';

class PdfSettingsScreen extends StatefulWidget {
  const PdfSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PdfSettingsScreen> createState() => _PdfSettingsScreenState();
}

class _PdfSettingsScreenState extends State<PdfSettingsScreen> {
  bool _isLoading = true;

  // Lieferschein Einstellungen
  double _deliveryNoteAddressEmailSpacing = 6.0; // Standard: 6 Pixel

  // Weitere Einstellungen können hier ergänzt werden

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
        setState(() {
          _deliveryNoteAddressEmailSpacing =
              (data['delivery_note_address_email_spacing'] as num?)?.toDouble() ?? 6.0;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der PDF-Einstellungen: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_settings')
          .set({
        'delivery_note_address_email_spacing': _deliveryNoteAddressEmailSpacing,
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
      print('Fehler beim Speichern der PDF-Einstellungen: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Einstellungen'),
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
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                      'Hier kannst du die Abstände und Positionierungen in den PDF-Dokumenten anpassen, um sie an deine Vordrucke anzupassen.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Lieferschein Sektion
            _buildSectionHeader(
              context,
              'Lieferschein',
              Icons.local_shipping,
            ),

            const SizedBox(height: 16),

            // Abstand Adresse - Email
            _buildSpacingControl(
              context,
              title: 'Abstand: Land → E-Mail',
              subtitle: 'Abstand zwischen Länderzeile und Kontaktdaten',
              value: _deliveryNoteAddressEmailSpacing,
              min: 0,
              max: 100,
              onChanged: (value) {
                setState(() {
                  _deliveryNoteAddressEmailSpacing = value;
                });
              },
            ),

            const SizedBox(height: 32),

            // Vorschau-Bereich
            _buildPreviewSection(context),

            const SizedBox(height: 32),

            // Weitere Sektionen können hier ergänzt werden
            // z.B. Rechnung, Handelsrechnung, Packliste, etc.
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: getAdaptiveIcon(
            iconName: title.toLowerCase().replaceAll(' ', '_'),
            defaultIcon: icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSpacingControl(
      BuildContext context, {
        required String title,
        required String subtitle,
        required double value,
        required double min,
        required double max,
        required ValueChanged<double> onChanged,
      }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Minus Button (groß)
                _buildStepButton(
                  context,
                  icon: Icons.remove,
                  onPressed: value > min
                      ? () => onChanged((value - 5).clamp(min, max))
                      : null,
                  label: '-5',
                ),
                const SizedBox(width: 8),
                // Minus Button (klein)
                _buildStepButton(
                  context,
                  icon: Icons.remove,
                  onPressed: value > min
                      ? () => onChanged((value - 1).clamp(min, max))
                      : null,
                  label: '-1',
                  isSmall: true,
                ),

                // Wert-Anzeige
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'px',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Plus Button (klein)
                _buildStepButton(
                  context,
                  icon: Icons.add,
                  onPressed: value < max
                      ? () => onChanged((value + 1).clamp(min, max))
                      : null,
                  label: '+1',
                  isSmall: true,
                ),
                const SizedBox(width: 8),
                // Plus Button (groß)
                _buildStepButton(
                  context,
                  icon: Icons.add,
                  onPressed: value < max
                      ? () => onChanged((value + 5).clamp(min, max))
                      : null,
                  label: '+5',
                ),
              ],
            ),

            // Slider für feinere Kontrolle
            const SizedBox(height: 12),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              label: '${value.toStringAsFixed(0)} px',
              onChanged: onChanged,
            ),

            // Reset Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onChanged(6.0), // Standard-Wert
                icon: getAdaptiveIcon(
                  iconName: 'refresh',
                  defaultIcon: Icons.refresh,
                  size: 16,
                ),
                label: const Text('Zurücksetzen (6 px)'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton(
      BuildContext context, {
        required IconData icon,
        required VoidCallback? onPressed,
        required String label,
        bool isSmall = false,
      }) {
    return Column(
      children: [
        SizedBox(
          width: isSmall ? 40 : 48,
          height: isSmall ? 40 : 48,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: isSmall
                  ? Theme.of(context).colorScheme.surfaceVariant
                  : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: isSmall
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onPrimaryContainer,
              elevation: isSmall ? 0 : 1,
            ),
            child: Icon(icon, size: isSmall ? 18 : 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'preview',
                  defaultIcon: Icons.preview,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Vorschau',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Simulated Address Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Musterfirma GmbH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF37474F),
                    ),
                  ),
                  const Text(
                    'Max Mustermann',
                    style: TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                  ),
                  const Text(
                    'Musterstraße 123',
                    style: TextStyle(fontSize: 11, color: Color(0xFF607D8B)),
                  ),
                  const Text(
                    '12345 Musterstadt',
                    style: TextStyle(fontSize: 11, color: Color(0xFF607D8B)),
                  ),
                  const Text(
                    'Deutschland',
                    style: TextStyle(fontSize: 11, color: Color(0xFF607D8B)),
                  ),

                  // Dynamischer Abstand
                  SizedBox(height: _deliveryNoteAddressEmailSpacing),

                  // Kontaktdaten
                  Row(
                    children: [
                      Text(
                        'E-Mail:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'info@musterfirma.de',
                        style: TextStyle(fontSize: 10, color: Color(0xFF607D8B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Tel.:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '+49 123 456789',
                        style: TextStyle(fontSize: 10, color: Color(0xFF607D8B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Abstandsanzeige
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  getAdaptiveIcon(
                    iconName: 'straighten',
                    defaultIcon: Icons.straighten,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Aktueller Abstand: ${_deliveryNoteAddressEmailSpacing.toStringAsFixed(0)} px',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
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

// Hilfsfunktion zum Laden der Einstellung (für andere Dateien)
class PdfSettingsHelper {
  static Future<Map<String, dynamic>> loadPdfSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_settings')
          .get();

      if (doc.exists) {
        return doc.data() ?? {};
      }
    } catch (e) {
      print('Fehler beim Laden der PDF-Einstellungen: $e');
    }

    // Standard-Werte
    return {
      'delivery_note_address_email_spacing': 6.0,
    };
  }

  static Future<double> getDeliveryNoteAddressEmailSpacing() async {
    final settings = await loadPdfSettings();
    return (settings['delivery_note_address_email_spacing'] as num?)?.toDouble() ?? 6.0;
  }
}