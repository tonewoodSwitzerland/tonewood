import 'package:cloud_firestore/cloud_firestore.dart';

// VEREINFACHT: Nur noch 3 Status statt 5
enum OrderStatus {
  processing,  // "In Bearbeitung" - ersetzt auch "pending"
  shipped,     // "Versendet" - ersetzt auch "delivered"
  cancelled;   // "Storniert"

  String get displayName {
    switch (this) {
      case OrderStatus.processing:
        return 'In Bearbeitung';
      case OrderStatus.shipped:
        return 'Versendet';
      case OrderStatus.cancelled:
        return 'Storniert';
    }
  }
}

class OrderX {
  final String id;
  final String orderNumber;
  final String? quoteNumber;
  final OrderStatus status;
  final String? quoteId;
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> calculations;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final Map<String, String> documents;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? costCenter;  // NEU

  OrderX({
    required this.id,
    this.quoteNumber,
    required this.orderNumber,
    required this.status,
    this.quoteId,
    required this.customer,
    required this.items,
    required this.calculations,
    required this.orderDate,
    this.deliveryDate,
    required this.documents,
    required this.metadata,
    this.costCenter,  // NEU
  });

  factory OrderX.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // DEBUG
    //print('=== OrderX.fromFirestore DEBUG ===');
    //print('Doc ID: ${doc.id}');
    //print('Raw costCenter in data: ${data['costCenter']}');
    //print('Raw costCenter type: ${data['costCenter']?.runtimeType}');
    //print('==================================');
    // Status-Migration: Alte Status auf neue mappen
    OrderStatus parseStatus(String? statusName) {
      switch (statusName) {
        case 'pending':
          return OrderStatus.processing;
        case 'processing':
          return OrderStatus.processing;
        case 'shipped':
          return OrderStatus.shipped;
        case 'delivered':
          return OrderStatus.shipped;
        case 'cancelled':
          return OrderStatus.cancelled;
        default:
          return OrderStatus.processing;
      }
    }

    return OrderX(
      id: doc.id,
      quoteNumber: data['quoteNumber'] as String?,
      orderNumber: data['orderNumber'] ?? '',
      status: parseStatus(data['status'] as String?),
      quoteId: data['quoteId'] as String?,
      customer: Map<String, dynamic>.from(data['customer'] ?? {}),
      items: List<Map<String, dynamic>>.from(
          (data['items'] ?? []).map((item) {
            final itemMap = Map<String, dynamic>.from(item);
            return {
              ...itemMap,
              'quantity': (itemMap['quantity'] as num?)?.toDouble() ?? 0.0,
              'price_per_unit': (itemMap['price_per_unit'] as num?)?.toDouble() ?? 0.0,
              'custom_price_per_unit': (itemMap['custom_price_per_unit'] as num?)?.toDouble(),
              'volume_per_unit': (itemMap['volume_per_unit'] as num?)?.toDouble() ?? 0.0,
              'density': (itemMap['density'] as num?)?.toDouble() ?? 0.0,
              'weight': (itemMap['weight'] as num?)?.toDouble() ?? 0.0,
              'custom_length': (itemMap['custom_length'] as num?)?.toDouble() ?? 0.0,
              'custom_width': (itemMap['custom_width'] as num?)?.toDouble() ?? 0.0,
              'custom_thickness': (itemMap['custom_thickness'] as num?)?.toDouble() ?? 0.0,
              'discount': itemMap['discount'] != null ? {
                'percentage': ((itemMap['discount']['percentage'] ?? 0) as num).toDouble(),
                'absolute': ((itemMap['discount']['absolute'] ?? 0) as num).toDouble(),
              } : {'percentage': 0.0, 'absolute': 0.0},
            };
          })
      ),
      calculations: Map<String, dynamic>.from(data['calculations'] ?? {}),
      orderDate: (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveryDate: data['deliveryDate'] != null
          ? (data['deliveryDate'] as Timestamp).toDate()
          : null,
      documents: Map<String, String>.from(data['documents'] ?? {}),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      costCenter: data['costCenter'] != null
          ? Map<String, dynamic>.from(data['costCenter'])
          : null,  // NEU
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'status': status.name,
      if (quoteId != null) 'quoteId': quoteId,
      if (quoteNumber != null) 'quoteNumber': quoteNumber,
      'customer': customer,
      'items': items,
      'calculations': calculations,
      'orderDate': Timestamp.fromDate(orderDate),
      'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
      'documents': documents,
      'metadata': metadata,
      if (costCenter != null) 'costCenter': costCenter,  // NEU
    };
  }

  OrderX copyWith({
    String? id,
    String? orderNumber,
    String? quoteNumber,
    OrderStatus? status,
    String? quoteId,
    Map<String, dynamic>? customer,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? calculations,
    DateTime? orderDate,
    DateTime? deliveryDate,
    Map<String, String>? documents,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? costCenter,
  }) {
    return OrderX(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      status: status ?? this.status,
      quoteId: quoteId ?? this.quoteId,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      calculations: calculations ?? this.calculations,
      orderDate: orderDate ?? this.orderDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      documents: documents ?? this.documents,
      metadata: metadata ?? this.metadata,
      costCenter: costCenter ?? this.costCenter,
    );
  }
}