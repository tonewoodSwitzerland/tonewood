// lib/analytics/sales/helpers/tax_helper.dart

/// Hilfsfunktionen für die steuerliche Behandlung in der Analyse.
///
/// TaxOption-Werte aus metadata.taxOption:
///   0 = standard  → Netto + MwSt separat → Brutto (vat_amount ist korrekt)
///   1 = noTax     → Kein MwSt (vat_amount = 0, total = netto)
///   2 = totalOnly → Brutto inkl. MwSt (vat_amount in Firestore = 0,
///                    muss rückgerechnet werden)
class TaxHelper {
  /// Liest die TaxOption aus den Order-Metadaten.
  static int getTaxOption(Map<String, dynamic> data) {
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    return (metadata['taxOption'] as num?)?.toInt() ?? 0;
  }

  /// Liest den MwSt-Satz aus den Order-Metadaten.
  static double getVatRate(Map<String, dynamic> data) {
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    return (metadata['vatRate'] as num?)?.toDouble() ?? 8.1;
  }

  /// Berechnet den effektiven MwSt-Betrag einer Order.
  ///
  /// - taxOption 0 (standard): vat_amount aus calculations wird verwendet
  /// - taxOption 1 (noTax):    0.0 (keine MwSt)
  /// - taxOption 2 (totalOnly): MwSt aus total rückgerechnet
  static double getEffectiveVat({
    required Map<String, dynamic> data,
    required double orderTotal,
  }) {
    final taxOption = getTaxOption(data);
    final vatRate = getVatRate(data);

    switch (taxOption) {
      case 1: // noTax
        return 0.0;
      case 2: // totalOnly — MwSt ist im Total enthalten
        if (vatRate <= 0) return 0.0;
        // Formel: impliedVat = total * vatRate / (100 + vatRate)
        return orderTotal * vatRate / (100 + vatRate);
      default: // 0 = standard — aus calculations lesen
        final calculations = data['calculations'] as Map<String, dynamic>? ?? {};
        return (calculations['vat_amount'] as num?)?.toDouble() ?? 0;
    }
  }


  /// Rechnet einen Brutto-Betrag in Netto um (für taxOption 2).
  /// Bei vatRate <= 0 wird der Betrag unverändert zurückgegeben.
  static double netFromGross(double gross, double vatRate) {
    if (vatRate <= 0) return gross;
    return gross / (1 + vatRate / 100);
  }

  /// Gibt den Anzeige-String für die Steuerart zurück.
  static String getTaxOptionLabel(int taxOption) {
    switch (taxOption) {
      case 1:
        return 'Ohne MwSt';
      case 2:
        return 'Inkl. MwSt';
      default:
        return 'Exkl. MwSt';
    }
  }

  /// Kurzer Code für CSV-/PDF-Export.
  static String getTaxOptionCode(int taxOption) {
    switch (taxOption) {
      case 1:
        return 'Ohne';
      case 2:
        return 'Inkl.';
      default:
        return 'Exkl.';
    }
  }
}