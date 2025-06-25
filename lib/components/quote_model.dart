import 'package:cloud_firestore/cloud_firestore.dart';

enum QuoteStatus {
  draft,
  sent,
  accepted,
  rejected,
  expired;

  String get displayName {
    switch (this) {
      case QuoteStatus.draft:
        return 'Entwurf';
      case QuoteStatus.sent:
        return 'Versendet';
      case QuoteStatus.accepted:
        return 'Angenommen';
      case QuoteStatus.rejected:
        return 'Abgelehnt';
      case QuoteStatus.expired:
        return 'Abgelaufen';
    }
  }
}

class Quote {
  final String id;
  final String quoteNumber;
  final QuoteStatus status;
  final Map<String, dynamic> customer;
  final Map<String, dynamic>? costCenter;
  final Map<String, dynamic>? fair;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> calculations;
  final DateTime createdAt;
  final DateTime validUntil;
  final DateTime? sentAt;
  final String? orderId;
  final Map<String, String> documents;
  final Map<String, dynamic> metadata;

  Quote({
    required this.id,
    required this.quoteNumber,
    required this.status,
    required this.customer,
    this.costCenter,
    this.fair,
    required this.items,
    required this.calculations,
    required this.createdAt,
    required this.validUntil,
    this.sentAt,
    this.orderId,
    required this.documents,
    required this.metadata,
  });

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Quote(
      id: doc.id,
      quoteNumber: data['quoteNumber'],
      status: QuoteStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => QuoteStatus.draft,
      ),
      customer: data['customer'],
      costCenter: data['costCenter'],
      fair: data['fair'],
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      calculations: data['calculations'] ?? {},
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      validUntil: (data['validUntil'] as Timestamp).toDate(),
      sentAt: data['sentAt'] != null ? (data['sentAt'] as Timestamp).toDate() : null,
      orderId: data['orderId'],
      documents: Map<String, String>.from(data['documents'] ?? {}),
      metadata: data['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quoteNumber': quoteNumber,
      'status': status.name,
      'customer': customer,
      'costCenter': costCenter,
      'fair': fair,
      'items': items,
      'calculations': calculations,
      'createdAt': Timestamp.fromDate(createdAt),
      'validUntil': Timestamp.fromDate(validUntil),
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'orderId': orderId,
      'documents': documents,
      'metadata': metadata,
    };
  }
}