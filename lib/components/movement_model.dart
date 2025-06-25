import 'package:cloud_firestore/cloud_firestore.dart';

enum StockMovementType {
  reservation,
  sale,
  returnX;

  String get displayName {
  switch (this) {
  case StockMovementType.reservation:
  return 'Reservierung';
  case StockMovementType.sale:
  return 'Verkauf';
  case StockMovementType.returnX:
  return 'Rückgabe';
  }
  }
}

enum StockMovementStatus {
  reserved,
  confirmed,
  cancelled;

  String get displayName {
    switch (this) {
      case StockMovementStatus.reserved:
        return 'Reserviert';
      case StockMovementStatus.confirmed:
        return 'Bestätigt';
      case StockMovementStatus.cancelled:
        return 'Storniert';
    }
  }
}

class StockMovement {
  final String id;
  final StockMovementType type;
  final String? quoteId;
  final String? orderId;
  final String? documentId;
  final String productId;
  final int quantity;
  final StockMovementStatus status;
  final DateTime timestamp;

  StockMovement({
    required this.id,
    required this.type,
    this.quoteId,
    this.orderId,
    this.documentId,
    required this.productId,
    required this.quantity,
    required this.status,
    required this.timestamp,
  });

  factory StockMovement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockMovement(
      id: doc.id,
      type: StockMovementType.values.firstWhere(
            (e) => e.name == data['type'],
      ),
      quoteId: data['quoteId'],
      orderId: data['orderId'],
      documentId: data['documentId'],
      productId: data['productId'],
      quantity: data['quantity'],
      status: StockMovementStatus.values.firstWhere(
            (e) => e.name == data['status'],
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'quoteId': quoteId,
      'orderId': orderId,
      'documentId': documentId,
      'productId': productId,
      'quantity': quantity,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}