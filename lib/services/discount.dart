// Neue Klasse für die Rabattberechnung
class Discount {
  final double percentage;  // Prozentualer Rabatt
  final double absolute;    // Absoluter Rabatt in CHF

  const Discount({
    this.percentage = 0.0,
    this.absolute = 0.0,
  });

  // Berechnet den Rabattbetrag basierend auf einem Grundbetrag
  double calculateDiscount(double amount) {
    return (amount * (percentage / 100)) + absolute;
  }

  Map<String, dynamic> toMap() => {
    'percentage': percentage,
    'absolute': absolute,
  };

  factory Discount.fromMap(Map<String, dynamic> map) => Discount(
    percentage: map['percentage'] ?? 0.0,
    absolute: map['absolute'] ?? 0.0,
  );

  bool get hasDiscount => percentage > 0 || absolute > 0;
}
// Erweiterte Klasse für Warenkorb-Positionen
class BasketItem {
  final String productId;
  final String productName;
  final int quantity;
  final double pricePerUnit;
  final Discount itemDiscount;
  final String unit;
  // ... andere Produktdetails

  const BasketItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
    this.itemDiscount = const Discount(),
    required this.unit,
  });

  double get subtotal => quantity * pricePerUnit;
  double get discount => itemDiscount.calculateDiscount(subtotal);
  double get total => subtotal - discount;

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'price_per_unit': pricePerUnit,
    'discount': itemDiscount.toMap(),
    'unit': unit,
    'subtotal': subtotal,
    'discount_amount': discount,
    'total': total,
  };
}

// Klasse für die Gesamtberechnung
class SalesCalculation {
  final List<BasketItem> items;
  final Discount totalDiscount;
  final double vatRate;

  const SalesCalculation({
    required this.items,
    this.totalDiscount = const Discount(),
    this.vatRate = 8.1,  // Standard Schweizer MwSt
  });

  double get subtotal => items.fold(
    0.0,
        (sum, item) => sum + item.subtotal,
  );

  double get itemDiscounts => items.fold(
    0.0,
        (sum, item) => sum + item.discount,
  );

  double get additionalDiscount => totalDiscount.calculateDiscount(
    subtotal - itemDiscounts,
  );

  // Umbenennung zu totalDiscountAmount um Namenskonflikt zu vermeiden
  double get totalDiscountAmount => itemDiscounts + additionalDiscount;

  double get netAmount => subtotal - totalDiscountAmount;

  double get vatAmount => netAmount * (vatRate / 100);

  double get total => netAmount + vatAmount;

  Map<String, dynamic> toMap() => {
    'items': items.map((item) => item.toMap()).toList(),
    'subtotal': subtotal,
    'item_discounts': itemDiscounts,
    'additional_discount': totalDiscount.toMap(),
    'total_discount_amount': totalDiscountAmount,
    'net_amount': netAmount,
    'vat_rate': vatRate,
    'vat_amount': vatAmount,
    'total': total,
  };
}