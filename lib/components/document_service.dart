// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
//
// import '../services/pdf_generators/commercial_invoice_generator.dart';
// import '../services/pdf_generators/delivery_note_generator.dart';
// import '../services/pdf_generators/invoice_generator.dart';
// import '../services/pdf_generators/packing_list_generator.dart';
// import 'document_model.dart';
//
// import 'dart:typed_data';
//
// class DocumentService {
//   static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   static final FirebaseStorage _storage = FirebaseStorage.instance;
//
//   // Erstelle Dokument
//   static Future<Document> createDocument({
//     required DocumentType type,
//     required String orderId,
//     String? quoteId,
//     required Map<String, dynamic> data,
//     required String language,
//   }) async {
//     try {
//       // Generiere Dokumentnummer basierend auf Typ
//       final documentNumber = await _getNextDocumentNumber(type);
//       final documentId = _getDocumentId(type, documentNumber);
//
//       final document = Document(
//         id: documentId,
//         type: type,
//         documentNumber: documentNumber,
//         orderId: orderId,
//         quoteId: quoteId,
//         data: data,
//         status: DocumentStatus.draft,
//         createdAt: DateTime.now(),
//         language: language,
//       );
//
//       // Erstelle Dokument in Firestore
//       await _firestore
//           .collection('documents')
//           .doc(documentId)
//           .set(document.toMap());
//
//       // Generiere PDF
//       final pdfBytes = await _generatePdf(document, data);
//
//       // Speichere PDF
//       final pdfUrl = await _savePdf(documentId, pdfBytes);
//
//       // Aktualisiere Dokument mit PDF-URL
//       await _firestore
//           .collection('documents')
//           .doc(documentId)
//           .update({'pdfUrl': pdfUrl});
//
//       // Aktualisiere Auftrag
//       await _firestore
//           .collection('orders')
//           .doc(orderId)
//           .update({
//         'documents.${type.name}': documentId,
//       });
//
//       return document;
//     } catch (e) {
//       print('Fehler beim Erstellen des Dokuments: $e');
//       rethrow;
//     }
//   }
//
//   // Generiere Dokumentnummer
//   static Future<String> _getNextDocumentNumber(DocumentType type) async {
//     final year = DateTime.now().year;
//     final counterKey = '${type.name}_counters';
//
//     final counterRef = _firestore
//         .collection('general_data')
//         .doc(counterKey);
//
//     return await _firestore.runTransaction<String>((transaction) async {
//       final counterDoc = await transaction.get(counterRef);
//
//       Map<String, dynamic> counters = {};
//       if (counterDoc.exists) {
//         counters = counterDoc.data() ?? {};
//       }
//
//       int currentNumber = counters[year.toString()] ?? 999;
//       currentNumber++;
//
//       transaction.set(counterRef, {
//         year.toString(): currentNumber,
//         'lastUpdated': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));
//
//       return '$year-$currentNumber';
//     });
//   }
//
//   // Generiere Dokument-ID
//   static String _getDocumentId(DocumentType type, String number) {
//     switch (type) {
//       case DocumentType.quote:
//         return 'Q-$number';
//       case DocumentType.invoice:
//         return 'INV-$number';
//       case DocumentType.commercialInvoice:
//         return 'CI-$number';
//       case DocumentType.deliveryNote:
//         return 'DN-$number';
//       case DocumentType.packingList:
//         return 'PL-$number';
//     }
//   }
//
//   // Generiere PDF basierend auf Dokumenttyp
//   static Future<Uint8List> _generatePdf(
//       Document document,
//       Map<String, dynamic> orderData,
//       ) async {
//     switch (document.type) {
//       case DocumentType.invoice:
//         return await InvoiceGenerator.generateInvoicePdf(
//           items: orderData['items'],
//           customerData: orderData['customer'],
//           fairData: orderData['fair'],
//           costCenterCode: orderData['costCenterCode'] ?? '00000',
//           currency: orderData['currency'] ?? 'CHF',
//           exchangeRates: Map<String, double>.from(orderData['exchangeRates'] ?? {'CHF': 1.0}),
//           invoiceNumber: document.documentNumber,
//           language: document.language,
//           shippingCosts: orderData['shippingCosts'],
//           calculations: orderData['calculations'],
//           taxOption: orderData['taxOption'] ?? 0,
//           vatRate: (orderData['vatRate'] ?? 8.1).toDouble(),
//         );
//
//       case DocumentType.deliveryNote:
//         return await DeliveryNoteGenerator.generateDeliveryNotePdf(
//           items: orderData['items'],
//           customerData: orderData['customer'],
//           fairData: orderData['fair'],
//           costCenterCode: orderData['costCenterCode'] ?? '00000',
//           currency: orderData['currency'] ?? 'CHF',
//           exchangeRates: Map<String, double>.from(orderData['exchangeRates'] ?? {'CHF': 1.0}),
//           deliveryNoteNumber: document.documentNumber,
//           language: document.language,
//           deliveryDate: document.data['deliveryDate'] != null
//               ? DateTime.parse(document.data['deliveryDate'])
//               : null,
//           paymentDate: document.data['paymentDate'] != null
//               ? DateTime.parse(document.data['paymentDate'])
//               : null,
//         );
//
//       case DocumentType.commercialInvoice:
//         return await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
//           items: orderData['items'],
//           customerData: orderData['customer'],
//           fairData: orderData['fair'],
//           costCenterCode: orderData['costCenterCode'] ?? '00000',
//           currency: orderData['currency'] ?? 'CHF',
//           exchangeRates: Map<String, double>.from(orderData['exchangeRates'] ?? {'CHF': 1.0}),
//           invoiceNumber: document.documentNumber,
//           language: document.language,
//           shippingCosts: orderData['shippingCosts'],
//           calculations: orderData['calculations'],
//           taxOption: orderData['taxOption'] ?? 0,
//           vatRate: (orderData['vatRate'] ?? 8.1).toDouble(),
//           taraSettings: document.data['taraSettings'],
//         );
//
//       case DocumentType.packingList:
//         return await PackingListGenerator.generatePackingListPdf(
//           language: document.language,
//           packingListNumber: document.documentNumber,
//           customerData: orderData['customer'],
//           fairData: orderData['fair'],
//           costCenterCode: orderData['costCenterCode'] ?? '00000',
//         );
//
//       default:
//         throw Exception('Unbekannter Dokumenttyp');
//     }
//   }
//
//
//
//   // Speichere PDF in Storage
//   static Future<String> _savePdf(String documentId, Uint8List pdfBytes) async {
//     final pdfRef = _storage.ref().child('documents/$documentId/document.pdf');
//     await pdfRef.putData(pdfBytes);
//     return await pdfRef.getDownloadURL();
//   }
//
//   // Aktualisiere Dokumentstatus
//   static Future<void> updateDocumentStatus(
//       String documentId,
//       DocumentStatus status,
//       ) async {
//     await _firestore
//         .collection('documents')
//         .doc(documentId)
//         .update({
//       'status': status.name,
//       if (status == DocumentStatus.sent) 'sentAt': FieldValue.serverTimestamp(),
//     });
//   }
//
//   // Lade Dokument
//   static Future<Document?> getDocument(String documentId) async {
//     final doc = await _firestore
//         .collection('documents')
//         .doc(documentId)
//         .get();
//
//     if (!doc.exists) return null;
//
//     return Document.fromFirestore(doc);
//   }
//
//   // Erstelle alle Dokumente für einen Auftrag
//   static Future<Map<String, String>> createOrderDocuments({
//     required String orderId,
//     required Map<String, bool> documentTypes,
//     required Map<String, dynamic> orderData,
//     required String language,
//   }) async {
//     final createdDocuments = <String, String>{};
//
//     for (final entry in documentTypes.entries) {
//       if (!entry.value) continue;
//
//       final type = _getDocumentTypeFromString(entry.key);
//       if (type == null) continue;
//
//       try {
//         final document = await createDocument(
//           type: type,
//           orderId: orderId,
//           data: orderData,
//           language: language,
//         );
//
//         createdDocuments[type.name] = document.id;
//       } catch (e) {
//         print('Fehler beim Erstellen von ${entry.key}: $e');
//       }
//     }
//
//     return createdDocuments;
//   }
//
//   static DocumentType? _getDocumentTypeFromString(String typeString) {
//     switch (typeString) {
//       case 'Rechnung':
//         return DocumentType.invoice;
//       case 'Handelsrechnung':
//         return DocumentType.commercialInvoice;
//       case 'Lieferschein':
//         return DocumentType.deliveryNote;
//       case 'Packliste':
//         return DocumentType.packingList;
//       default:
//         return null;
//     }
//   }
// }