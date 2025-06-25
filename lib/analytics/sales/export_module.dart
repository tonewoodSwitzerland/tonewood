import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:intl/intl.dart';

import 'export_document_screen.dart';
import 'export_document_service.dart';
import 'export_documents_integration.dart';

/// Central module for export document generation functionality
/// This class coordinates all export document related functions
class ExportModule {
  /// Generate and save export documents for a receipt
  /// Generate and save export documents for a receipt
  static Future<Map<String, String>> generateAndSaveExportDocuments({
    required String receiptId,
    required Map<String, dynamic> exportInfo,
    bool saveToDrive = true,
  }) async {
    try {
      // Überprüfe, ob der Beleg existiert
      final receiptDoc = await FirebaseFirestore.instance
          .collection('sales_receipts')
          .doc(receiptId)
          .get();

      if (!receiptDoc.exists) {
        return {
          'status': 'error',
          'error': 'Beleg nicht gefunden',
        };
      }

      // Generiere die Dokumente
      final invoiceBytes = await ExportDocumentsService.generateCommercialInvoice(receiptId);

      // Container-Info für die Packliste, falls vorhanden
      final containerInfo = exportInfo['containerNumber'] != null && exportInfo['sealNumber'] != null
          ? '${exportInfo['containerNumber']}, seal ${exportInfo['sealNumber']}'
          : null;

      final packingListBytes = await ExportDocumentsService.generatePackingList(
        receiptId,
        containerInfo: containerInfo,
      );

      Map<String, String> documentUrls = {};

      // Speichere die Dokumente in Firebase Storage, wenn angefordert
      if (saveToDrive) {
        final storage = FirebaseStorage.instance;

        // Bereite einen eindeutigen Dateinamen vor (mit Zeitstempel)
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        // Speichere die Handelsrechnung
        final invoiceRef = storage.ref().child('export_documents/invoice_${receiptId}_$timestamp.pdf');
        await invoiceRef.putData(invoiceBytes);
        documentUrls['invoiceUrl'] = await invoiceRef.getDownloadURL();

        // Speichere die Packliste
        final packingListRef = storage.ref().child('export_documents/packing_list_${receiptId}_$timestamp.pdf');
        await packingListRef.putData(packingListBytes);
        documentUrls['packingListUrl'] = await packingListRef.getDownloadURL();

        // Konvertiere das Datum in ein Timestamp-Format für Firestore
        Timestamp? deliveryDateTimestamp;
        if (exportInfo['deliveryDate'] != null && exportInfo['deliveryDate'].isNotEmpty) {
          try {
            final dateFormat = DateFormat('dd.MM.yyyy');
            final deliveryDate = dateFormat.parse(exportInfo['deliveryDate']);
            deliveryDateTimestamp = Timestamp.fromDate(deliveryDate);
          } catch (e) {
            print('Fehler beim Parsen des Lieferdatums: $e');
            // Verwende das aktuelle Datum + 14 Tage als Fallback
            deliveryDateTimestamp = Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 14)),
            );
          }
        }

        // Aktualisiere den Beleg in Firestore mit den Export-Dokumenten-URLs und Metadaten
        await FirebaseFirestore.instance
            .collection('sales_receipts')
            .doc(receiptId)
            .update({
          'export_documents': {
            'invoice_url': documentUrls['invoiceUrl'],
            'packing_list_url': documentUrls['packingListUrl'],
            'container_number': exportInfo['containerNumber'],
            'seal_number': exportInfo['sealNumber'],
            'customer_vat': exportInfo['customerVat'],
            'delivery_date': deliveryDateTimestamp,
            'transport_type': exportInfo['transportType'],
            'transporter': exportInfo['transporter'],
            'incoterm': exportInfo['incoterm'],
            'export_purpose': exportInfo['exportPurpose'],
            'invoice_number': exportInfo['invoiceNumber'],
            'generated_at': FieldValue.serverTimestamp(),
          }
        });

        // Log zur Bestätigung
        print('Exportdokumente wurden erfolgreich in Firebase gespeichert');
      }

      return {
        'status': 'success',
        ...documentUrls,
      };
    } catch (e) {
      print('Fehler beim Generieren der Exportdokumente: $e');
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  /// Show export documents screen to configure and generate export documents
  static Future<bool> showExportDocumentsScreen(BuildContext context, String receiptId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExportDocumentsScreen(receiptId: receiptId),
      ),
    );

    return result == true;
  }

  /// Add export documents button to an existing widget
  static Widget addExportDocumentsButton(
      BuildContext context,
      String receiptId,
      {bool isLoading = false}
      ) {
    return ExportDocumentsIntegration.buildExportDocumentsButton(
      context,
      receiptId,
      isLoading: isLoading,
    );
  }

  /// Check if export documents already exist for a receipt
  static Future<bool> checkExportDocumentsExist(String receiptId) async {
    try {
      final receiptDoc = await FirebaseFirestore.instance
          .collection('sales_receipts')
          .doc(receiptId)
          .get();

      if (!receiptDoc.exists) return false;

      final data = receiptDoc.data();
      if (data == null) return false;

      final exportDocs = data['export_documents'];
      if (exportDocs == null) return false;

      return exportDocs['invoice_url'] != null && exportDocs['packing_list_url'] != null;
    } catch (e) {
      print('Error checking export documents: $e');
      return false;
    }
  }

  /// Get URLs of existing export documents
  static Future<Map<String, String>?> getExportDocumentUrls(String receiptId) async {
    try {
      final receiptDoc = await FirebaseFirestore.instance
          .collection('sales_receipts')
          .doc(receiptId)
          .get();

      if (!receiptDoc.exists) return null;

      final data = receiptDoc.data();
      if (data == null) return null;

      final exportDocs = data['export_documents'];
      if (exportDocs == null) return null;

      return {
        'invoiceUrl': exportDocs['invoice_url'],
        'packingListUrl': exportDocs['packing_list_url'],
      };
    } catch (e) {
      print('Error getting export document URLs: $e');
      return null;
    }
  }

  /// Send export documents via email (placeholder - would need proper email integration)
  static Future<bool> sendExportDocumentsViaEmail(
      String receiptId,
      String recipientEmail,
      {String? ccEmail}
      ) async {
    try {
      // Check if documents exist
      final urls = await getExportDocumentUrls(receiptId);
      if (urls == null) return false;

      // This is a placeholder - would need to implement proper email sending
      // Could use Firebase Functions or a direct SMTP client

      // For example, using a Cloud Function:
      // final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      // final callable = functions.httpsCallable('sendExportDocumentsEmail');
      // final result = await callable.call({
      //   'receiptId': receiptId,
      //   'recipientEmail': recipientEmail,
      //   'ccEmail': ccEmail,
      //   'invoiceUrl': urls['invoiceUrl'],
      //   'packingListUrl': urls['packingListUrl'],
      // });

      // return result.data['success'] == true;

      // Simulating success for this placeholder
      return true;
    } catch (e) {
      print('Error sending export documents via email: $e');
      return false;
    }
  }
}