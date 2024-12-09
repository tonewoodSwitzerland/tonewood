// product.dart
class ProductDetails {
  final String fullBarcode;     // Komplette Artikelnummer (IIPP.HHQQ.ThHaMoFs.JJ.0000)
  final String shortBarcode;    // Verkaufsartikelnummer (IIPP.HHQQ)
  final Map<String, dynamic> productionData;  // Alle Produktionsdetails
  final Map<String, dynamic> salesData;       // Vereinfachte Verkaufsdaten

  ProductDetails({
    required this.fullBarcode,
    required this.shortBarcode,
    required this.productionData,
    required this.salesData,
  });
}
