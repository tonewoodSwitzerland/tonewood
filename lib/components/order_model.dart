import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  processing,
  shipped,
  delivered,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Ausstehend';
      case OrderStatus.processing:
        return 'In Bearbeitung';
      case OrderStatus.shipped:
        return 'Versendet';
      case OrderStatus.delivered:
        return 'Geliefert';
      case OrderStatus.cancelled:
        return 'Storniert';
    }
  }
}

enum PaymentStatus {
  pending,
  partial,
  paid;

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Ausstehend';
      case PaymentStatus.partial:
        return 'Teilzahlung';
      case PaymentStatus.paid:
        return 'Bezahlt';
    }
  }
}

class OrderX {
  final String id;
  final String orderNumber;
  final String? quoteNumber; // GEÄNDERT: Jetzt optional
  final OrderStatus status;
  final String? quoteId; // GEÄNDERT: Auch optional für Robustheit
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> calculations;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final PaymentStatus paymentStatus;
  final Map<String, String> documents;
  final Map<String, dynamic> metadata;

  OrderX({
    required this.id,
    this.quoteNumber, // GEÄNDERT: Nicht mehr required
    required this.orderNumber,
    required this.status,
    this.quoteId, // GEÄNDERT: Nicht mehr required
    required this.customer,
    required this.items,
    required this.calculations,
    required this.orderDate,
    this.deliveryDate,
    required this.paymentStatus,
    required this.documents,
    required this.metadata,
  });

  factory OrderX.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OrderX(
      id: doc.id,
      quoteNumber: data['quoteNumber'] as String?, // GEÄNDERT: Sichere Null-Behandlung
      orderNumber: data['orderNumber'] ?? '', // GEÄNDERT: Fallback auf leeren String
      status: OrderStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      quoteId: data['quoteId'] as String?, // GEÄNDERT: Kann null sein
      customer: Map<String, dynamic>.from(data['customer'] ?? {}), // GEÄNDERT: Sichere Map-Konvertierung
      items: List<Map<String, dynamic>>.from(
          (data['items'] ?? []).map((item) {
            final itemMap = Map<String, dynamic>.from(item);
            // Konvertiere alle numerischen Werte zu double

            print("yuuuuuuuuuu");

            return {
              ...itemMap,
              'quantity': (itemMap['quantity'] as num?)?.toDouble() ?? 0.0,
              'price_per_unit': (itemMap['price_per_unit'] as num?)?.toDouble() ?? 0.0,
              'volume_per_unit': (itemMap['volume_per_unit'] as num?)?.toDouble() ?? 0.0,
              'density': (itemMap['density'] as num?)?.toDouble() ??0.0,
              'weight': (itemMap['weight'] as num?)?.toDouble() ?? 0.0,
              'custom_length': (itemMap['custom_length'] as num?)?.toDouble() ?? 0.0,
              'custom_width': (itemMap['custom_width'] as num?)?.toDouble() ?? 0.0,
              'custom_thickness': (itemMap['custom_thickness'] as num?)?.toDouble() ?? 0.0,
              // Discount handling
              'discount': itemMap['discount'] != null ? {
                'percentage': ((itemMap['discount']['percentage'] ?? 0) as num).toDouble(),
                'absolute': ((itemMap['discount']['absolute'] ?? 0) as num).toDouble(),
              } : {'percentage': 0.0, 'absolute': 0.0},
            };
          })
      ),
      calculations: Map<String, dynamic>.from(data['calculations'] ?? {}),
      orderDate: (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(), // GEÄNDERT: Fallback auf jetzt
      deliveryDate: data['deliveryDate'] != null
          ? (data['deliveryDate'] as Timestamp).toDate()
          : null,
      paymentStatus: PaymentStatus.values.firstWhere(
            (e) => e.name == data['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
      documents: Map<String, String>.from(data['documents'] ?? {}),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'status': status.name,
      if (quoteId != null) 'quoteId': quoteId, // GEÄNDERT: Nur hinzufügen wenn nicht null
      if (quoteNumber != null) 'quoteNumber': quoteNumber, // GEÄNDERT: Nur hinzufügen wenn nicht null
      'customer': customer,
      'items': items,
      'calculations': calculations,
      'orderDate': Timestamp.fromDate(orderDate),
      'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
      'paymentStatus': paymentStatus.name,
      'documents': documents,
      'metadata': metadata,
    };
  }
}