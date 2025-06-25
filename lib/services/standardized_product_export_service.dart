import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tonewood/services/standardized_products.dart';
import 'dart:convert';


// Conditional imports für Web
import 'standardized_product_export_stub.dart'
if (dart.library.html) 'standardized_product_export_web.dart';

class StandardizedProductExportService {
  static Future<void> exportProductsCsv(BuildContext context) async {
    try {
      // Zeige Ladeindikator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Lade alle Standardprodukte aus Firebase
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('standardized_products')
          .orderBy('articleNumber')
          .get();

      if (snapshot.docs.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Standardprodukte zum Exportieren gefunden'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Erstelle CSV-Inhalt
      final csvContent = _generateCsvContent(snapshot.docs);

      // Dateiname mit Zeitstempel
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileName = 'standardprodukte_export_$timestamp.csv';

      // Export je nach Plattform
      if (kIsWeb) {
        // Web: Download im Browser
        _downloadFileWeb(csvContent, fileName);
      } else {
        // Mobile: Speichern und teilen
        await _saveAndShareFile(csvContent, fileName);
      }

      // Schließe Ladeindikator
      Navigator.pop(context);

      // Erfolgsmeldung
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${snapshot.docs.length} Standardprodukte exportiert'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      // Schließe Ladeindikator falls noch offen
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Fehlermeldung
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static String _generateCsvContent(List<QueryDocumentSnapshot> docs) {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln(StandardizedProduct.getCsvHeader());

    // Daten
    for (var doc in docs) {
      try {
        final product = StandardizedProduct.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id
        );
        buffer.writeln(product.toCsvRow());
      } catch (e) {
        print('Fehler beim Verarbeiten von Dokument ${doc.id}: $e');
      }
    }

    return buffer.toString();
  }

  static void _downloadFileWeb(String content, String fileName) {
    if (!kIsWeb) return;

    // Delegiere an die plattformspezifische Implementierung
    downloadFileForWeb(content, fileName);
  }

  static Future<void> _saveAndShareFile(String content, String fileName) async {
    // Hole temporäres Verzeichnis
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');

    // Schreibe Datei mit UTF-8 BOM für Excel-Kompatibilität
    await file.writeAsString('\uFEFF$content', encoding: utf8);

    // Teile Datei
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Standardprodukte Export',
    );
  }
}