// swiss_rounding.dart
// Utility-Klasse für die Schweizer Rappenrundung und Formatierung

import 'package:cloud_firestore/cloud_firestore.dart';

class SwissRounding {
  /// Wendet die Schweizer Rappenrundung auf einen Betrag an
  ///
  /// Die Rundung erfolgt nach den offiziellen Schweizer Regeln:
  /// - .01, .02 → .00 (abrunden)
  /// - .03, .04 → .05 (aufrunden)
  /// - .06, .07 → .05 (abrunden)
  /// - .08, .09 → .10 (aufrunden)
  ///
  /// [amount] Der zu rundende Betrag
  /// [currency] Die Währung (Rundung nur bei CHF)
  /// [roundingSettings] Map mit Rundungseinstellungen pro Währung (optional)
  /// [forceRounding] Erzwingt Rundung auch bei anderen Währungen (default: false)
  ///
  /// Gibt den gerundeten Betrag zurück
  ///
  ///
  static Future<Map<String, bool>> loadRoundingSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('currency_settings')
          .get();

      if (doc.exists && doc.data()!.containsKey('rounding_settings')) {
        final settings = doc.data()!['rounding_settings'] as Map<String, dynamic>;
        return {
          'CHF': settings['CHF'] ?? true,
          'EUR': settings['EUR'] ?? false,
          'USD': settings['USD'] ?? false,
        };
      }

      // Fallback zu Standard-Einstellungen
      //print('Keine Rundungseinstellungen in Firebase gefunden, verwende Standard-Werte');
      return {
        'CHF': true,  // Standard: CHF wird gerundet
        'EUR': false,
        'USD': false,
      };
    } catch (e) {
      //print('Fehler beim Laden der Rundungseinstellungen: $e');
      // Fallback zu Standard-Einstellungen
      return {
        'CHF': true,
        'EUR': false,
        'USD': false,
      };
    }
  }

  ///
  ///
  static double round(double amount, {
    String currency = 'CHF',
    Map<String, bool>? roundingSettings,
    bool forceRounding = false
  }) {
    // Debug-Ausgabe
    //print('=== Swiss Rounding Debug ===');
    //print('Original amount: $amount');
    //print('Amount * 100: ${amount * 100}');
    //print('Amount * 100 rounded: ${(amount * 100).round()}');

    // Prüfe ob Rundung für diese Währung aktiviert ist
    if (roundingSettings != null) {
      final isEnabled = roundingSettings[currency] ?? false;
      if (!isEnabled && !forceRounding) {
        return amount;
      }
    } else {
      // Fallback: Nur bei CHF runden, außer forceRounding ist true
      if (currency != 'CHF' && !forceRounding) {
        return amount;
      }
    }

    // Extrahiere die Rappen (letzte Stelle nach dem Komma)
    int totalRappen = (amount * 100).round();
    int lastDigit = totalRappen % 10;

    //print('Total Rappen: $totalRappen');
    //print('Last digit: $lastDigit');

    // Berechne die Anpassung basierend auf der letzten Ziffer
    int adjustedRappen;
    switch (lastDigit) {
      case 1:
      case 2:
      // Abrunden auf .00
        adjustedRappen = totalRappen - lastDigit;
        //print('Case 1,2: Abrunden auf .00');
        break;
      case 3:
      case 4:
      // Aufrunden auf .05
        adjustedRappen = totalRappen - lastDigit + 5;
        //print('Case 3,4: Aufrunden auf .05');
        break;
      case 6:
      case 7:
      // Abrunden auf .05
        adjustedRappen = totalRappen - lastDigit + 5;
        //print('Case 6,7: Abrunden auf .05');
        break;
      case 8:
      case 9:
      // Aufrunden auf .10
        adjustedRappen = totalRappen - lastDigit + 10;
        //print('Case 8,9: Aufrunden auf .10');
        break;
      default:
      // 0 und 5 bleiben unverändert
        adjustedRappen = totalRappen;
        //print('Case 0,5: Keine Änderung');
    }

    double result = adjustedRappen / 100.0;
    //print('Result: $result');
    //print('=== End Debug ===');

    return result;
  }

  /// Berechnet die Differenz zwischen Original- und gerundetem Betrag
  ///
  /// [amount] Der Originalbetrag
  /// [currency] Die Währung (Rundung nur bei CHF)
  ///
  /// Gibt die Rundungsdifferenz zurück (positiv = aufgerundet, negativ = abgerundet)
  static double getRoundingDifference(double amount, {
    String currency = 'CHF',
    Map<String, bool>? roundingSettings,
  }) {
    // Prüfe ob Rundung für diese Währung aktiviert ist
    if (roundingSettings != null) {
      final isEnabled = roundingSettings[currency] ?? false;
      if (!isEnabled) {
        return 0.0;
      }
    } else if (currency != 'CHF') {
      return 0.0;
    }

    double rounded = round(amount, currency: currency, roundingSettings: roundingSettings);
    return rounded - amount;
  }

  /// Prüft ob eine Rundung stattfinden würde
  ///
  /// [amount] Der zu prüfende Betrag
  /// [currency] Die Währung (Rundung nur bei CHF)
  ///
  /// Gibt true zurück wenn gerundet werden würde
  static bool wouldRound(double amount, {
    String currency = 'CHF',
    Map<String, bool>? roundingSettings,
  }) {
    // Prüfe ob Rundung für diese Währung aktiviert ist
    if (roundingSettings != null) {
      final isEnabled = roundingSettings[currency] ?? false;
      if (!isEnabled) {
        return false;
      }
    } else if (currency != 'CHF') {
      return false;
    }

    int lastDigit = (amount * 100).round() % 10;
    return lastDigit != 0 && lastDigit != 5;
  }

  /// Formatiert einen Betrag mit Rappenrundung für die Anzeige
  ///
  /// [amount] Der Betrag
  /// [currency] Die Währung
  /// [showDifference] Zeigt die Rundungsdifferenz an (default: false)
  ///
  /// Gibt einen formatierten String zurück
  static String formatWithRounding(double amount, {
    String currency = 'CHF',
    bool showDifference = false,
  }) {
    if (currency != 'CHF') {
      return amount.toStringAsFixed(2);
    }

    double rounded = round(amount, currency: currency);
    double difference = getRoundingDifference(amount, currency: currency);

    if (showDifference && difference != 0) {
      String sign = difference > 0 ? '+' : '';
      return '${rounded.toStringAsFixed(2)} ($sign${difference.toStringAsFixed(2)})';
    }

    return rounded.toStringAsFixed(2);
  }

  /// Formatiert einen Betrag mit Tausendertrennzeichen
  ///
  /// Beispiele:
  /// - 1234.56 → "1'234.56"
  /// - 1234567.89 → "1'234'567.89"
  /// - 12.34 → "12.34"
  ///
  /// [amount] Der zu formatierende Betrag
  /// [decimals] Anzahl der Dezimalstellen (default: 2)
  /// [separator] Das Tausendertrennzeichen (default: ')
  /// [decimalSeparator] Das Dezimaltrennzeichen (default: .)
  ///
  /// Gibt den formatierten String zurück
  static String formatWithThousandsSeparator(
      double amount, {
        int decimals = 2,
        String separator = "'",
        String decimalSeparator = '.',
      }) {
    // Runde auf die gewünschte Anzahl Dezimalstellen
    final roundedAmount = double.parse(amount.toStringAsFixed(decimals));

    // Trenne Ganzzahl und Dezimalteil
    final parts = roundedAmount.toStringAsFixed(decimals).split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';

    // Füge Tausendertrennzeichen ein
    String formattedInteger = '';
    int count = 0;

    // Von rechts nach links durch die Ganzzahl gehen
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formattedInteger = separator + formattedInteger;
      }
      formattedInteger = integerPart[i] + formattedInteger;
      count++;
    }

    // Füge Dezimalteil hinzu wenn vorhanden
    if (decimalPart.isNotEmpty) {
      return formattedInteger + decimalSeparator + decimalPart;
    }

    return formattedInteger;
  }

  /// Formatiert einen Betrag mit Währung und Tausendertrennzeichen
  ///
  /// [amount] Der Betrag
  /// [currency] Die Währung (CHF, EUR, USD, etc.)
  /// [roundingSettings] Rundungseinstellungen (optional)
  /// [showCurrency] Ob die Währung angezeigt werden soll (default: true)
  /// [currencyPosition] Position der Währung: 'before' oder 'after' (default: 'before')
  /// [separator] Das Tausendertrennzeichen (default: ')
  ///
  /// Gibt den formatierten String zurück
  ///
  /// Beispiele:
  /// - formatCurrency(1234.56, 'CHF') → "CHF 1'234.56"
  /// - formatCurrency(1234.56, 'EUR', currencyPosition: 'after') → "1'234.56 EUR"
  static String formatCurrency(
      double amount, {
        required String currency,
        Map<String, bool>? roundingSettings,
        bool showCurrency = true,
        String currencyPosition = 'before',
        String separator = "'",
      }) {
    // Wende Rundung an wenn aktiviert
    double finalAmount = amount;
    if (roundingSettings != null) {
      final isRoundingEnabled = roundingSettings[currency] ?? false;
      if (isRoundingEnabled) {
        finalAmount = round(amount, currency: currency, roundingSettings: roundingSettings);
      }
    } else if (currency == 'CHF') {
      finalAmount = round(amount, currency: currency);
    }

    // Formatiere mit Tausendertrennzeichen
    final formattedAmount = formatWithThousandsSeparator(
      finalAmount,
      separator: separator,
    );

    // Füge Währung hinzu
    if (showCurrency) {
      if (currencyPosition == 'after') {
        return '$formattedAmount $currency';
      } else {
        return '$currency $formattedAmount';
      }
    }

    return formattedAmount;
  }

  /// Formatiert einen Betrag komplett (mit Rundung, Währung und Tausendertrennzeichen)
  ///
  /// Dies ist eine Convenience-Methode die alle Formatierungen kombiniert
  ///
  /// [amount] Der Betrag
  /// [currency] Die Währung
  /// [roundingSettings] Rundungseinstellungen (optional)
  /// [showCurrency] Währung anzeigen (default: true)
  /// [showThousandsSeparator] Tausendertrennzeichen verwenden (default: true)
  ///
  /// Gibt den vollständig formatierten String zurück
  static String format(
      double amount, {
        required String currency,
        Map<String, bool>? roundingSettings,
        bool showCurrency = true,
        bool showThousandsSeparator = true,
      }) {
    if (showThousandsSeparator) {
      return formatCurrency(
        amount,
        currency: currency,
        roundingSettings: roundingSettings,
        showCurrency: showCurrency,
      );
    } else {
      // Ohne Tausendertrennzeichen
      double finalAmount = amount;
      if (roundingSettings != null) {
        final isRoundingEnabled = roundingSettings[currency] ?? false;
        if (isRoundingEnabled) {
          finalAmount = round(amount, currency: currency, roundingSettings: roundingSettings);
        }
      } else if (currency == 'CHF') {
        finalAmount = round(amount, currency: currency);
      }

      if (showCurrency) {
        return '$currency ${finalAmount.toStringAsFixed(2)}';
      } else {
        return finalAmount.toStringAsFixed(2);
      }
    }
  }

  /// Hilfsmethode zum Testen: Gibt detaillierte Rundungsinformationen zurück
  static Map<String, dynamic> getRoundingDetails(double amount, {String currency = 'CHF'}) {
    if (currency != 'CHF') {
      return {
        'original': amount,
        'rounded': amount,
        'difference': 0.0,
        'wouldRound': false,
        'lastDigit': null,
        'rule': 'Keine Rundung (nicht CHF)',
      };
    }

    int lastDigit = (amount * 100).round() % 10;
    double rounded = round(amount, currency: currency);
    double difference = rounded - amount;

    String rule;
    switch (lastDigit) {
      case 1:
      case 2:
        rule = 'Abrunden auf .00';
        break;
      case 3:
      case 4:
        rule = 'Aufrunden auf .05';
        break;
      case 6:
      case 7:
        rule = 'Abrunden auf .05';
        break;
      case 8:
      case 9:
        rule = 'Aufrunden auf .10';
        break;
      default:
        rule = 'Keine Rundung (endet auf 0 oder 5)';
    }

    return {
      'original': amount,
      'rounded': rounded,
      'difference': difference,
      'wouldRound': wouldRound(amount, currency: currency),
      'lastDigit': lastDigit,
      'rule': rule,
    };
  }

  /// Formatierungs-Demo für Tests und Beispiele
  ///
  /// Gibt verschiedene Formatierungen eines Betrags zurück
  static Map<String, String> getFormattingExamples(double amount, String currency) {
    return {
      'plain': amount.toStringAsFixed(2),
      'withThousands': formatWithThousandsSeparator(amount),
      'withCurrency': formatCurrency(amount, currency: currency),
      'withRounding': format(amount, currency: currency),
      'currencyAfter': formatCurrency(
        amount,
        currency: currency,
        currencyPosition: 'after',
      ),
    };
  }
}