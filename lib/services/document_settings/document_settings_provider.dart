// File: services/document_settings/document_settings_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstraktion für den Datenzugriff der Dokument-Einstellungen.
/// 
/// Ermöglicht es, die gleichen Einstellungs-Dialoge (Lieferschein, 
/// Handelsrechnung, Packliste, Rechnung, Zusatztexte) sowohl im 
/// Auftrags- als auch im Angebotsbereich zu verwenden.
/// 
/// Konkrete Implementierungen:
/// - [OrderSettingsProvider] für Aufträge (Firestore: orders/{id}/settings/...)
/// - [QuoteSettingsProvider] für Angebote (Firestore: UserBasketService.temporaryDocumentSettings/...)
abstract class DocumentSettingsProvider {
  
  // ═══════════════════════════════════════════════════════════════════
  // Kontext-Informationen
  // ═══════════════════════════════════════════════════════════════════
  
  /// Label für den Header z.B. "Auftrag 2024-001" oder "Angebot"
  String get contextLabel;
  
  /// Typ: 'order' oder 'quote' – für bedingte UI-Elemente
  String get contextType;
  
  // ═══════════════════════════════════════════════════════════════════
  // Daten lesen
  // ═══════════════════════════════════════════════════════════════════
  
  /// Lieferschein-Einstellungen laden.
  /// Gibt zurück: { 'delivery_date': DateTime?, 'payment_date': DateTime? }
  Future<Map<String, dynamic>> loadDeliveryNoteSettings();
  
  /// Handelsrechnung/Tara-Einstellungen laden.
  /// Gibt zurück: { 'number_of_packages': int, 'packaging_weight': double, 
  ///   'commercial_invoice_date': DateTime?, 'origin_declaration': bool, ... }
  Future<Map<String, dynamic>> loadCommercialInvoiceSettings();
  
  /// Packlisten-Einstellungen laden.
  /// Gibt zurück: { 'packages': List<Map<String, dynamic>> }
  Future<Map<String, dynamic>> loadPackingListSettings();
  
  /// Rechnungs-Einstellungen laden.
  /// Gibt zurück: { 'down_payment_amount': double, 'invoice_date': DateTime?, ... }
  Future<Map<String, dynamic>> loadInvoiceSettings();
  
  /// Zusatztexte-Konfiguration laden.
  /// Gibt zurück: { 'legend_origin': {...}, 'fsc': {...}, ... }
  Future<Map<String, dynamic>> loadAdditionalTexts();
  
  // ═══════════════════════════════════════════════════════════════════
  // Daten speichern
  // ═══════════════════════════════════════════════════════════════════
  
  /// Lieferschein-Einstellungen speichern.
  Future<void> saveDeliveryNoteSettings(Map<String, dynamic> settings);
  
  /// Handelsrechnung/Tara-Einstellungen speichern.
  Future<void> saveCommercialInvoiceSettings(Map<String, dynamic> settings);
  
  /// Packlisten-Einstellungen speichern.
  Future<void> savePackingListSettings(Map<String, dynamic> settings);
  
  /// Rechnungs-Einstellungen speichern.
  Future<void> saveInvoiceSettings(Map<String, dynamic> settings);
  
  /// Zusatztexte-Konfiguration speichern.
  Future<void> saveAdditionalTexts(Map<String, dynamic> config);
  
  // ═══════════════════════════════════════════════════════════════════
  // Prüf-Methoden (für die Vorbelegung im Lieferschein-Dialog)
  // ═══════════════════════════════════════════════════════════════════
  
  /// Prüft ob Lieferschein-Settings schon einmal manuell gespeichert wurden.
  /// Wird benötigt, um zu entscheiden ob das Datum aus der HR vorbelegt werden soll.
  Future<bool> hasExistingDeliveryNoteSettings();
  
  /// Lädt das aktuelle Handelsrechnungsdatum (für Vorbelegung/Vergleich).
  /// Gibt null zurück wenn keins gesetzt ist.
  Future<DateTime?> loadCommercialInvoiceDate();
  
  // ═══════════════════════════════════════════════════════════════════
  // Feature-Flags
  // ═══════════════════════════════════════════════════════════════════
  
  /// Ob der Kundenadress-Vergleich verfügbar ist (nur bei Orders).
  bool get supportsCustomerAddressCompare => false;
  
  /// Ob Versandmodus (Einzel-/Gesamtversand) unterstützt wird.
  bool get supportsShipmentMode => true;
  
  /// Callback für den Kundenadress-Vergleich.
  /// Wird nur aufgerufen wenn [supportsCustomerAddressCompare] true ist.
  /// Muss vom Aufrufer gesetzt werden.
  Future<void> Function()? onCompareCustomerAddress;
}
