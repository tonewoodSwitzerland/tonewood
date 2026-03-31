// File: lib/services/pdf_settings_overview_screen.dart

import 'package:flutter/material.dart';
import 'package:tonewood/services/pdf_services/pdf_header_footer_settings_screen.dart';
import 'package:tonewood/services/pdf_services/pdf_settings_screen.dart';
import 'package:tonewood/services/product_sorting_manager.dart';
import '../icon_helper.dart';


/// Übersichtsseite für alle PDF-Einstellungen
/// Navigiert zu den einzelnen Unterseiten
class PdfSettingsOverviewScreen extends StatelessWidget {
  const PdfSettingsOverviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Einstellungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                color:
                Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'picture_as_pdf',
                  defaultIcon: Icons.picture_as_pdf,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Verwalte hier alle Einstellungen für deine PDF-Dokumente.',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Kopf- & Fußzeile
          _buildSettingsCard(
            context,
            icon: Icons.vertical_split,
            iconName: 'vertical_split',
            title: 'Kopf- & Fußzeile',
            subtitle:
            'Logo-Größe, Titel-Schriftgröße, Firmenadresse, Kontaktdaten und weitere Inhalte der Kopf- und Fußzeile anpassen.',
            color: Colors.indigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PdfHeaderFooterSettingsScreen(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Tabellen & Layout
          _buildSettingsCard(
            context,
            icon: Icons.table_chart,
            iconName: 'table_chart',
            title: 'Tabellen & Layout',
            subtitle:
            'Spaltenausrichtung, Adressanzeige, Abstände und Positionierungen in den PDF-Dokumenten konfigurieren.',
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PdfSettingsScreen(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Sortierreihenfolge
          _buildSettingsCard(
            context,
            icon: Icons.sort,
            iconName: 'sort',
            title: 'Sortierreihenfolge',
            subtitle:
            'Produkte nach Instrument, Holzart, Qualität etc. sortieren. Gilt für alle Angebote, Aufträge und Dokumente.',
            color: Colors.deepOrange,
            onTap: () => ProductSortingManager.showSortingDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      BuildContext context, {
        required IconData icon,
        required String iconName,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: getAdaptiveIcon(
                    iconName: iconName,
                    defaultIcon: icon,
                    color: color,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}