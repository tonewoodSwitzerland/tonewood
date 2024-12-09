import 'package:cloud_firestore/cloud_firestore.dart';

class ProductManagement {
  // Konvertiert eine vollständige Artikelnummer in eine Verkaufsartikelnummer
  static String getShortBarcode(String fullBarcode) {
    // Extrahiert nur IIPP.HHQQ
    final parts = fullBarcode.split('.');
    if (parts.length >= 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return fullBarcode;
  }

  // Erstellt einen neuen Produktionseintrag
  static Future<void> createProductionEntry({
    required String barcode,
    required Map<String, dynamic> productionData,
    required FirebaseFirestore db,
  }) async {
    final shortBarcode = getShortBarcode(barcode);

    // Erstelle Produktionseintrag
    await db.collection('production').doc(barcode).set({
      ...productionData,
      'full_barcode': barcode,
      'short_barcode': shortBarcode,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Aktualisiere oder erstelle Lagereintrag
    final inventoryRef = db.collection('inventory').doc(shortBarcode);
    final inventoryDoc = await inventoryRef.get();

    if (inventoryDoc.exists) {
      // Addiere zur bestehenden Menge
      await inventoryRef.update({
        'quantity': FieldValue.increment(productionData['quantity'] ?? 0),
        'last_modified': FieldValue.serverTimestamp(),
      });
    } else {
      // Erstelle neuen Lagereintrag mit Basisdaten
      await inventoryRef.set({
        'short_barcode': shortBarcode,
        'product_name': productionData['product_name'],
        'instrument_code': productionData['instrument_code'],
        'instrument_name': productionData['instrument_name'],
        'part_code': productionData['part_code'],
        'part_name': productionData['part_name'],
        'wood_code': productionData['wood_code'],
        'wood_name': productionData['wood_name'],
        'quality_code': productionData['quality_code'],
        'quality_name': productionData['quality_name'],
        'unit': productionData['unit'],
        'quantity': productionData['quantity'],
        'price_CHF': productionData['price_CHF'],
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }
}