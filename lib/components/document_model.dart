import 'package:cloud_firestore/cloud_firestore.dart';

enum DocumentType {
  quote,
  invoice,
  commercialInvoice,
  deliveryNote,
  packingList;

  String get displayName {
    switch (this) {
      case DocumentType.quote:
        return 'Angebot';
      case DocumentType.invoice:
        return 'Rechnung';
      case DocumentType.commercialInvoice:
        return 'Handelsrechnung';
      case DocumentType.deliveryNote:
        return 'Lieferschein';
      case DocumentType.packingList:
        return 'Packliste';
    }
  }
}

enum DocumentStatus {
  draft,
  finalX,
  sent,
  cancelled;

  String get displayName {
  switch (this) {
  case DocumentStatus.draft:
  return 'Entwurf';
  case DocumentStatus.finalX:
  return 'Finalisiert';
  case DocumentStatus.sent:
  return 'Versendet';
  case DocumentStatus.cancelled:
  return 'Storniert';
  }
  }
}

class Document {
  final String id;
  final DocumentType type;
  final String documentNumber;
  final String? orderId;
  final String? quoteId;
  final Map<String, dynamic> data;
  final DocumentStatus status;
  final String? pdfUrl;
  final DateTime createdAt;
  final DateTime? sentAt;
  final String language;

  Document({
    required this.id,
    required this.type,
    required this.documentNumber,
    this.orderId,
    this.quoteId,
    required this.data,
    required this.status,
    this.pdfUrl,
    required this.createdAt,
    this.sentAt,
    required this.language,
  });

  factory Document.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Document(
      id: doc.id,
      type: DocumentType.values.firstWhere(
            (e) => e.name == data['type'],
      ),
      documentNumber: data['documentNumber'],
      orderId: data['orderId'],
      quoteId: data['quoteId'],
      data: data['data'] ?? {},
      status: DocumentStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => DocumentStatus.draft,
      ),
      pdfUrl: data['pdfUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      sentAt: data['sentAt'] != null ? (data['sentAt'] as Timestamp).toDate() : null,
      language: data['language'] ?? 'DE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'documentNumber': documentNumber,
      'orderId': orderId,
      'quoteId': quoteId,
      'data': data,
      'status': status.name,
      'pdfUrl': pdfUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'language': language,
    };
  }
}