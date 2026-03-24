import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Zentraler Service für alle user-spezifischen temporary Collections.
///
/// VORHER (global, alle User teilen sich einen Warenkorb):
///   FirebaseFirestore.instance.collection('temporary_basket')
///
/// NACHHER (pro User isoliert):
///   UserBasketService.temporaryBasket
///
/// Verwendung / Migration:
///   Suche in allen .dart Dateien nach:
///     FirebaseFirestore.instance.collection('temporary_basket')
///   Ersetze durch:
///     UserBasketService.temporaryBasket
///
///   Wiederhole für alle 9 Collections unten.
///
/// Benötigter Import in jeder Datei:
///   import 'package:tonewood/services/user_basket_service.dart';
///
class UserBasketService {
  UserBasketService._(); // Verhindert Instanziierung

  /// Aktueller User-ID – wirft Exception wenn nicht eingeloggt
  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(
        'UserBasketService: Kein User eingeloggt. '
            'Stelle sicher, dass FirebaseAuth.instance.currentUser != null ist.',
      );
    }
    return user.uid;
  }

  /// Basis-Referenz: /users/{uid}
  static DocumentReference get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  // ─── Temporary Collections (pro User) ───────────────────────────

  /// Cache für den Anzeigenamen
  static String? _cachedDisplayName;

  /// Öffentlicher Zugriff auf die aktuelle User-ID
  static String get uid => _uid;

  /// Anzeigename aus der users-Collection (mit Cache)
  static String get displayName => _cachedDisplayName ?? _uid;

  /// Muss einmal beim App-Start oder Login aufgerufen werden
  static Future<void> loadDisplayName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      _cachedDisplayName = doc.data()?['name'] as String? ?? _uid;
    } catch (e) {
      print('Fehler beim Laden des Anzeigenamens: $e');
    }
  }

  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_additional_texts')
  static CollectionReference<Map<String, dynamic>> get temporaryAdditionalTexts =>
      _userDoc.collection('temporary_additional_texts');

  /// Warenkorb-Positionen
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_basket')
  static CollectionReference<Map<String, dynamic>> get temporaryBasket =>
      _userDoc.collection('temporary_basket');

  /// Ausgewählter Kunde
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_customer')
  static CollectionReference<Map<String, dynamic>> get temporaryCustomer =>
      _userDoc.collection('temporary_customer');

  /// Ausgewählte Kostenstelle
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_cost_center')
  static CollectionReference<Map<String, dynamic>> get temporaryCostCenter =>
      _userDoc.collection('temporary_cost_center');

  /// Ausgewählte Messe
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_fair')
  static CollectionReference<Map<String, dynamic>> get temporaryFair =>
      _userDoc.collection('temporary_fair');

  /// Gesamtrabatt-Einstellungen
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_discounts')
  static CollectionReference<Map<String, dynamic>> get temporaryDiscounts =>
      _userDoc.collection('temporary_discounts');

  /// Steuer-Einstellungen (MwSt etc.)
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_tax')
  static CollectionReference<Map<String, dynamic>> get temporaryTax =>
      _userDoc.collection('temporary_tax');

  /// Dokument-Einstellungen (Packliste, Sprache etc.)
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_document_settings')
  static CollectionReference<Map<String, dynamic>> get temporaryDocumentSettings =>
      _userDoc.collection('temporary_document_settings');

  /// Versandkosten-Konfiguration
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_shipping_costs')
  static CollectionReference<Map<String, dynamic>> get temporaryShippingCosts =>
      _userDoc.collection('temporary_shipping_costs');

  /// Dokumentenauswahl (Offerte, Rechnung etc.)
  /// Ersetzt: FirebaseFirestore.instance.collection('temporary_document_selection')
  static CollectionReference<Map<String, dynamic>> get temporaryDocumentSelection =>
      _userDoc.collection('temporary_document_selection');

  // ─── Cross-User Queries (alle Warenkörbe) ─────────────────────

  /// Holt die Warenkorb-Menge eines Produkts über ALLE User hinweg.
  /// Wird für Verfügbarkeitsberechnung benötigt.
  static Future<double> getTotalCartQuantity(String productId) async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collectionGroup('temporary_basket')
          .where('product_id', isEqualTo: productId)
          .get();

      return usersSnapshot.docs.fold<double>(
        0,
            (sum, doc) => sum + ((doc.data()['quantity'] as num?)?.toDouble() ?? 0.0),
      );
    } catch (e) {
      print('Fehler beim Abrufen der Gesamt-Warenkorb-Menge: $e');
      return 0;
    }
  }

  /// Stream der Warenkorb-Menge eines Produkts über ALLE User.
  /// Wird für die UI-Anzeige im Warehouse-Screen benötigt.
  static Stream<double> totalCartQuantityStream(String productId) {
    return FirebaseFirestore.instance
        .collectionGroup('temporary_basket')
        .where('product_id', isEqualTo: productId)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(
      0,
          (sum, doc) => sum + ((doc.data()['quantity'] as num?)?.toDouble() ?? 0.0),
    ));
  }



  // ─── Hilfsmethoden ──────────────────────────────────────────────

  /// Löscht ALLE temporary Collections des aktuellen Users.
  /// Nützlich z.B. nach Auftragsabschluss oder beim "Warenkorb leeren".
  static Future<void> clearAll() async {
    final collections = [
      temporaryBasket,
      temporaryCustomer,
      temporaryCostCenter,
      temporaryFair,
      temporaryDiscounts,
      temporaryTax,
      temporaryDocumentSettings,
      temporaryShippingCosts,
      temporaryDocumentSelection,
    ];

    final batch = FirebaseFirestore.instance.batch();
    int operationCount = 0;

    for (final collection in collections) {
      final docs = await collection.get();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
        operationCount++;

        // Firestore Batch-Limit: max 500 Operationen pro Batch
        if (operationCount >= 490) {
          await batch.commit();
          operationCount = 0;
        }
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }
  }

  /// Löscht nur den Warenkorb (temporary_basket) des aktuellen Users.
  static Future<void> clearBasket() async {
    final docs = await temporaryBasket.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Prüft ob der aktuelle User einen nicht-leeren Warenkorb hat.
  static Future<bool> hasItems() async {
    final snapshot = await temporaryBasket.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// Gibt die Anzahl der Artikel im Warenkorb zurück.
  static Future<int> itemCount() async {
    final snapshot = await temporaryBasket.get();
    return snapshot.docs.length;
  }
}