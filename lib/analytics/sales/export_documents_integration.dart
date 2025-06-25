import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/icon_helper.dart';
import 'export_document_screen.dart';
import 'export_module.dart';

/// Diese Klasse bietet Methoden zur Integration der Exportdokumente-Funktionalität
/// in bestehende Bildschirme der Anwendung.
class ExportDocumentsIntegration {
  /// Liefert einen Button, der dem Verkaufsbildschirm hinzugefügt werden kann
  static Widget buildExportDocumentsButton(
      BuildContext context,
      String receiptId,
      {bool isLoading = false}
      ) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : () => _showExportDocumentsScreen(context, receiptId),
      icon: isLoading
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
      label: const Text('Exportdokumente'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Zeigt den Bildschirm für Exportdokumente an
  static Future<bool> _showExportDocumentsScreen(BuildContext context, String receiptId) async {
    // Prüfe vorher, ob bereits Exportdokumente existieren
    final hasExistingDocs = await ExportModule.checkExportDocumentsExist(receiptId);

    if (hasExistingDocs) {
      // Zeige Dialog mit Option zum Anzeigen oder Ersetzen der Dokumente
      final shouldRegenerate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exportdokumente existieren bereits'),
          content: const Text(
              'Für diesen Beleg wurden bereits Exportdokumente erstellt. '
                  'Möchten Sie neue Dokumente erstellen oder die bestehenden anzeigen?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bestehende anzeigen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Neue erstellen'),
            ),
          ],
        ),
      );

      if (shouldRegenerate == false) {
        // Zeige die bestehenden Dokumente an
        _showExistingDocuments(context, receiptId);
        return true;
      } else if (shouldRegenerate == null) {
        // Abgebrochen
        return false;
      }
      // Wenn true, fahre mit der Erstellung neuer Dokumente fort
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExportDocumentsScreen(receiptId: receiptId),
      ),
    );

    // Behandle das Ergebnis (z.B. Anzeige einer Erfolgsmeldung)
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exportdokumente wurden erstellt'),
          backgroundColor: Colors.green,
        ),
      );
    }

    return result == true;
  }

  /// Zeigt bestehende Dokumente an
  static Future<void> _showExistingDocuments(BuildContext context, String receiptId) async {
    try {
      // Laden der URLs der bestehenden Dokumente
      final urls = await ExportModule.getExportDocumentUrls(receiptId);
      if (urls == null) {
        throw Exception('Dokumente nicht gefunden');
      }

      // Anzeigen der Dokument-URLs in einem Dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exportdokumente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Die folgenden Exportdokumente sind verfügbar:'),
              const SizedBox(height: 16),
              ListTile(
                leading: getAdaptiveIcon(iconName: 'receipt', defaultIcon: Icons.receipt),
                title: const Text('Handelsrechnung'),
                subtitle: const Text('Öffnen oder herunterladen'),
                onTap: () async {
                  final url = urls['invoiceUrl'];
                  if (url != null && url.isNotEmpty) {
                    // Öffne URL im Browser
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                },
              ),
              ListTile(
                leading: getAdaptiveIcon(iconName: 'inventory', defaultIcon: Icons.inventory),
                title: const Text('Packliste'),
                subtitle: const Text('Öffnen oder herunterladen'),
                onTap: () async {
                  final url = urls['packingListUrl'];
                  if (url != null && url.isNotEmpty) {
                    // Öffne URL im Browser
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
            TextButton(
              onPressed: () => _showExportDocumentsScreen(context, receiptId),
              child: const Text('Neue Dokumente erstellen'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Fehlerbehandlung
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Anzeigen der Dokumente: $e'),
            backgroundColor: Colors.red,
          ),
        );

        // Öffne den Export-Dokumente-Screen, da die bestehenden nicht gefunden wurden
        await _showExportDocumentsScreen(context, receiptId);
      }
    }
  }

  /// Fügt einen Button zu den App-Bar-Aktionen hinzu
  static List<Widget> addExportButtonToAppBar(
      List<Widget> existingActions,
      BuildContext context,
      String? receiptId,
      ) {
    if (receiptId == null) return existingActions;

    return [
      ...existingActions,
      IconButton(
        icon: getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
        tooltip: 'Exportdokumente',
        onPressed: () => _showExportDocumentsScreen(context, receiptId),
      ),
    ];
  }
}