// price_formatter.dart
// Globale Utility-Klasse für konsistente Preisformatierung in der gesamten App

import 'swiss_rounding.dart';

class PriceFormatter {
  /// Formatiert einen Preis mit Währungsumrechnung, Rundung und Tausendertrennzeichen
  ///
  /// [priceInCHF] Der Preis in CHF (Basiswährung)
  /// [currency] Die Zielwährung
  /// [exchangeRates] Map mit Wechselkursen {'EUR': 0.96, 'USD': 1.08, etc.}
  /// [roundingSettings] Map mit Rundungseinstellungen pro Währung
  /// [showCurrency] Ob die Währung angezeigt werden soll (default: true)
  /// [showThousandsSeparator] Ob Tausendertrennzeichen verwendet werden sollen (default: true)
  ///
  /// Returns: Formatierter Preis String z.B. "CHF 12'345.70"
  static String format({
    required double priceInCHF,
    required String currency,
    Map<String, dynamic>? exchangeRates,
    Map<String, bool>? roundingSettings,
    bool showCurrency = true,
    bool showThousandsSeparator = true,
  }) {
    // 1. Währungsumrechnung
    double convertedPrice = priceInCHF;
    if (currency != 'CHF' && exchangeRates != null) {
      final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;
      convertedPrice = priceInCHF * rate;
    }

    // 2. Formatierung (inkl. Rundung)
    return SwissRounding.format(
      convertedPrice,
      currency: currency,
      roundingSettings: roundingSettings,
      showCurrency: showCurrency,
      showThousandsSeparator: showThousandsSeparator,
    );
  }

  /// Formatiert einen Preis aus einem Quote-Objekt
  ///
  /// Convenience-Methode für Angebote
  static String fromQuote({
    required double price,
    required Map<String, dynamic> metadata,
    Map<String, bool>? roundingSettings,
    bool showCurrency = true,
    bool showThousandsSeparator = true,
  }) {
    final currency = metadata['currency'] as String? ?? 'CHF';
    final exchangeRates = metadata['exchangeRates'] as Map<String, dynamic>?;

    return format(
      priceInCHF: price,
      currency: currency,
      exchangeRates: exchangeRates,
      roundingSettings: roundingSettings,
      showCurrency: showCurrency,
      showThousandsSeparator: showThousandsSeparator,
    );
  }

  /// Formatiert einen Preis aus einem Order-Objekt
  ///
  /// Convenience-Methode für Aufträge
  static String fromOrder({
    required double price,
    required Map<String, dynamic> metadata,
    Map<String, bool>? roundingSettings,
    bool showCurrency = true,
    bool showThousandsSeparator = true,
  }) {
    // Gleiche Logik wie fromQuote, aber explizit für Orders benannt
    return fromQuote(
      price: price,
      metadata: metadata,
      roundingSettings: roundingSettings,
      showCurrency: showCurrency,
      showThousandsSeparator: showThousandsSeparator,
    );
  }

  /// Formatiert einen Preis aus einem Invoice-Objekt
  ///
  /// Convenience-Methode für Rechnungen
  static String fromInvoice({
    required double price,
    required Map<String, dynamic> metadata,
    Map<String, bool>? roundingSettings,
    bool showCurrency = true,
    bool showThousandsSeparator = true,
  }) {
    return fromQuote(
      price: price,
      metadata: metadata,
      roundingSettings: roundingSettings,
      showCurrency: showCurrency,
      showThousandsSeparator: showThousandsSeparator,
    );
  }

  /// Formatiert nur den Betrag ohne Währungsumrechnung
  ///
  /// Nützlich wenn der Preis bereits in der richtigen Währung ist
  static String formatAmount({
    required double amount,
    required String currency,
    Map<String, bool>? roundingSettings,
    bool showCurrency = true,
    bool showThousandsSeparator = true,
  }) {
    return SwissRounding.format(
      amount,
      currency: currency,
      roundingSettings: roundingSettings,
      showCurrency: showCurrency,
      showThousandsSeparator: showThousandsSeparator,
    );
  }

  /// Berechnet den konvertierten Preis ohne Formatierung
  ///
  /// Nützlich wenn man den numerischen Wert für Berechnungen braucht
  static double convertPrice({
    required double priceInCHF,
    required String currency,
    Map<String, dynamic>? exchangeRates,
    Map<String, bool>? roundingSettings,
  }) {
    // 1. Währungsumrechnung
    double convertedPrice = priceInCHF;
    if (currency != 'CHF' && exchangeRates != null) {
      final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;
      convertedPrice = priceInCHF * rate;
    }

    // 2. Rundung anwenden wenn aktiviert
    if (roundingSettings != null && roundingSettings[currency] == true) {
      convertedPrice = SwissRounding.round(
        convertedPrice,
        currency: currency,
        roundingSettings: roundingSettings,
      );
    }

    return convertedPrice;
  }
}