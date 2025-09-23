// File: services/pdf_generators/quote_generator.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../document_selection_manager.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';
import '../swiss_rounding.dart';
class InvoiceGenerator extends BasePdfGenerator {
  // Erstelle eine neue Rechnungs-Nummer
  static Future<String> getNextInvoiceNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('invoice_counters');

      return await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        Map<String, dynamic> counters = {};
        if (counterDoc.exists) {
          counters = counterDoc.data() ?? {};
        }

        int currentNumber = counters[year.toString()] ?? 999; // Start bei 1000
        currentNumber++;

        transaction.set(counterRef, {
          year.toString(): currentNumber,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return '$year-$currentNumber';
      });
    } catch (e) {
      print('Fehler beim Erstellen der Rechnungs-Nummer: $e');
      return '${DateTime.now().year}-1000';
    }
  }

  static Future<Uint8List> generateInvoicePdf({
    required Map<String, bool> roundingSettings,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, dynamic>? fairData,
    required String costCenterCode,
    required String currency,
    required Map<String, double> exchangeRates,
    String? invoiceNumber,
    String? quoteNumber, // NEU
    required String language,
    Map<String, dynamic>? shippingCosts,
    Map<String, dynamic>? calculations,
    required int paymentTermDays,
    required int taxOption,
    required double vatRate,
    Map<String, dynamic>? downPaymentSettings,
    Map<String, dynamic>? additionalTexts,
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    print("paymentTermDayas:$paymentTermDays");
    // Generiere Rechnungs-Nummer falls nicht übergeben
    final invoiceNum = invoiceNumber ?? await getNextInvoiceNumber();
    final paymentDue = DateTime.now().add(Duration(days: paymentTermDays));

    // NEU: Lade Invoice-Einstellungen für showDimensions


    final invoiceSettings = downPaymentSettings ?? await DocumentSelectionManager.loadInvoiceSettings();


    final showDimensions = invoiceSettings['show_dimensions'] ?? false;
    // NEU: Prüfe ob 100% Vorkasse und hole Zahlungsmethode
    final isFullPayment = invoiceSettings['is_full_payment'] ?? false;
    final paymentMethod = invoiceSettings['payment_method'] ?? 'BAR';
    final customPaymentMethod = invoiceSettings['custom_payment_method'] ?? '';

    // NEU: Hole das Zahlungsziel aus den Settings (überschreibt den Default)
    if (invoiceSettings['payment_term_days'] != null) {
      paymentTermDays = invoiceSettings['payment_term_days'];
    }

    // Gruppiere Items nach Holzart
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final serviceItems = items.where((item) => item['is_service'] == true).toList();

// Nur Produkte gruppieren (Dienstleistungen haben keine Holzart)
    final groupedProductItems = await _groupItemsByWoodType(productItems, language);


    final additionalTextsWidget = await _addInlineAdditionalTexts(language,additionalTexts);

    // Übersetzungsfunktion
    // In der getTranslation Funktion, ändere diese Zeilen:
    String getTranslation(String key) {
      // Sichere den Exchange Rate ab
      final exchangeRate = exchangeRates[currency] ?? 1.0;

      final translations = {
        'DE': {
          'invoice': 'RECHNUNG',
          'quote_reference': quoteNumber != null ? 'Angebotsnummer: $quoteNumber' : '',
          'currency_note': 'Alle Preise in $currency (Umrechnungskurs: 1 CHF = ${exchangeRate.toStringAsFixed(4)} $currency)',
          'payment_note': 'Zahlbar innerhalb von $paymentTermDays Tagen bis ${DateFormat('dd. MMMM yyyy', 'de_DE').format(paymentDue)}.',
        },
        'EN': {
          'invoice': 'INVOICE',
          'quote_reference': quoteNumber != null ? 'Quote Number: $quoteNumber' : '',
          'currency_note': 'All prices in $currency (Exchange rate: 1 CHF = ${exchangeRate.toStringAsFixed(4)} $currency)',
          'payment_note': 'Payment due within $paymentTermDays days until ${DateFormat('MMMM dd, yyyy', 'en_US').format(paymentDue)}.',
        }
      };

      // NEU: Bei 100% Vorkasse andere Zahlungsnotiz
      if (isFullPayment) {
        final paymentMethodText = paymentMethod == 'BAR'
            ? 'BAR'
            : customPaymentMethod;

        translations['DE']!['payment_note'] = 'Vollständig bezahlt';
        translations['EN']!['payment_note'] = 'Fully paid';
      }

      return translations[language]?[key] ?? translations['DE']?[key] ?? '';
    }
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              BasePdfGenerator.buildHeader(
                documentTitle: getTranslation('invoice'),
                documentNumber: invoiceNum,
                date: DateTime.now(),
                logo: logo,
                costCenter: costCenterCode,
                language: language,
                additionalReference: quoteNumber != null && quoteNumber.isNotEmpty
                    ? getTranslation('quote_reference')
                    : null, // GEÄNDERT
              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
              BasePdfGenerator.buildCustomerAddress(customerData,'invoice', language: language),

              pw.SizedBox(height: 15),

              // Währungshinweis (falls nicht CHF)
              if (currency != 'CHF')
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
                  ),
                  child: pw.Text(
                    getTranslation('currency_note'),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.amber900),
                  ),
                ),

              pw.SizedBox(height: 15),

              // Produkttabelle mit Holzart-Gruppierung
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Column(
                      children: [
                        // Produkttabelle nur wenn Produkte vorhanden
                        if (productItems.isNotEmpty)
                          _buildProductTable(groupedProductItems, currency, exchangeRates, language, showDimensions),

                        // Dienstleistungstabelle nur wenn Dienstleistungen vorhanden
                        if (serviceItems.isNotEmpty)
                          _buildServiceTable(serviceItems, currency, exchangeRates, language),
                      ],
                    ),  pw.SizedBox(height: 10),
                    // Summen-Bereich
                    _buildTotalsSection(items, currency, exchangeRates, language, shippingCosts, calculations, taxOption, vatRate, downPaymentSettings, // NEU
                      paymentDue,roundingSettings),

                    pw.SizedBox(height: 10),
                    // Zahlungshinweis - ANGEPASST
                    if (!isFullPayment) ...[
                      // Nur bei offener Zahlung anzeigen
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                        ),
                        child: pw.Text(
                          getTranslation('payment_note'),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue900),
                        ),
                      ),
                    ] else ...[
                      // Bei 100% Vorkasse - Zahlungsbestätigung
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: PdfColors.green200, width: 0.5),
                        ),
                        child: pw.Text(
                          getTranslation('payment_note'), // Nutzt die angepasste Übersetzung
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.green900),
                        ),
                      ),
                    ],

                    pw.SizedBox(height: 10),
                    additionalTextsWidget,
                  ],
                ),
              ),

              // Footer
              BasePdfGenerator.buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Gruppiere Items nach Holzart
// Gruppiere Items nach Holzart
  static Future<Map<String, List<Map<String, dynamic>>>> _groupItemsByWoodType(
      List<Map<String, dynamic>> items,
      String language  // Füge language Parameter hinzu
      ) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    for (final item in items) {
      final woodCode = item['wood_code'] as String;

      // Lade Holzart-Info (mit Cache)
      if (!woodTypeCache.containsKey(woodCode)) {
        woodTypeCache[woodCode] = await BasePdfGenerator.getWoodTypeInfo(woodCode) ?? {};
      }

      final woodInfo = woodTypeCache[woodCode]!;

      // Verwende name_english wenn Sprache EN ist
      final woodName = language == 'EN'
          ? (woodInfo['name_english'] ?? woodInfo['name'] ?? item['wood_name'] ?? 'Unknown wood type')
          : (woodInfo['name'] ?? item['wood_name'] ?? 'Unbekannte Holzart');

      final woodNameLatin = woodInfo['name_latin'] ?? '';

      final groupKey = '$woodName ($woodNameLatin)';

      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }

      // Füge Holzart-Info zum Item hinzu
      final enhancedItem = Map<String, dynamic>.from(item);
      enhancedItem['wood_display_name'] = groupKey;
      enhancedItem['wood_name_latin'] = woodNameLatin;

      grouped[groupKey]!.add(enhancedItem);
    }

    return grouped;
  }
// Nach der _buildProductTable Methode hinzufügen:
  static pw.Widget _buildServiceTable(
      List<Map<String, dynamic>> serviceItems,
      String currency,
      Map<String, double> exchangeRates,
      String language) {

    if (serviceItems.isEmpty) return pw.SizedBox.shrink();

    final List<pw.TableRow> rows = [];

    // Header für Dienstleistungen
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Service' : 'Dienstleistung', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Description' : 'Beschreibung', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Anz.', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Total' : 'Gesamt', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Disc.' : 'Rab.', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right),
        ],
      ),
    );

    // Dienstleistungen hinzufügen
    for (final service in serviceItems) {
      final quantity = (service['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = (service['price_per_unit'] as num? ?? 0).toDouble();
      // Nachher:
// Rabatt-Berechnung
      final discount = service['discount'] as Map<String, dynamic>?;
      final totalBeforeDiscount = quantity * pricePerUnit;

      double discountAmount = 0.0;
      if (discount != null) {
        final percentage = (discount['percentage'] as num? ?? 0).toDouble();
        final absolute = (discount['absolute'] as num? ?? 0).toDouble();

        if (percentage > 0) {
          discountAmount = totalBeforeDiscount * (percentage / 100);
        } else if (absolute > 0) {
          discountAmount = absolute;
        }
      }

      final total = totalBeforeDiscount - discountAmount;

      rows.add(
        pw.TableRow(
          children: [
            BasePdfGenerator.buildContentCell(
              pw.Text(
                service['name'] ?? 'Unbenannte Dienstleistung',
                style: const pw.TextStyle(fontSize: 6),
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                service['description'] ?? '',
                style: const pw.TextStyle(fontSize: 6),
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                quantity.toStringAsFixed(0),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatCurrency(pricePerUnit, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatCurrency(totalBeforeDiscount, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
// NEU: Rabatt-Spalte
            BasePdfGenerator.buildContentCell(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (discount != null && (discount['percentage'] as num? ?? 0) > 0)
                    pw.Text(
                      '${discount['percentage'].toStringAsFixed(2)}%',
                      style: const pw.TextStyle(fontSize: 6),
                      textAlign: pw.TextAlign.right,
                    ),
                  if (discount != null && (discount['absolute'] as num? ?? 0) > 0)
                    pw.Text(
                      BasePdfGenerator.formatCurrency(
                          (discount['absolute'] as num).toDouble(),
                          currency,
                          exchangeRates
                      ),
                      style: const pw.TextStyle(fontSize: 6),
                      textAlign: pw.TextAlign.right,
                    ),
                ],
              ),
            ),
// NEU: Netto Gesamtpreis
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatCurrency(total, currency, exchangeRates),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: discountAmount > 0 ? pw.FontWeight.bold : null,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [

        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),    // Dienstleistung
            1: const pw.FlexColumnWidth(4),    // Beschreibung
            2: const pw.FlexColumnWidth(1),    // Anzahl
            3: const pw.FlexColumnWidth(2),    // Preis/E
            4: const pw.FlexColumnWidth(2),    // Gesamt
            5: const pw.FlexColumnWidth(1.5),  // Rabatt (NEU)
            6: const pw.FlexColumnWidth(2),    // Netto Gesamt (NEU)
          },
          children: rows,
        ),
      ],
    );
  }
  // Erstelle Produkttabelle mit Gruppierung
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      bool showDimensions) {

    final List<pw.TableRow> rows = [];

    // Header-Zeile anpassen basierend auf showDimensions
    final headerCells = <pw.Widget>[
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Product' : 'Produkt', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Instr.' : 'Instr.', 8),
      // BasePdfGenerator.buildHeaderCell(
      //     language == 'EN' ? 'Type' : 'Typ', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Qual.' : 'Qual.', 8),
      BasePdfGenerator.buildHeaderCell('FSC®', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Orig' : 'Urs', 8),
      BasePdfGenerator.buildHeaderCell('°C', 8),
    ];

    // NEU: Nur wenn showDimensions true ist
    if (showDimensions) {
      headerCells.add(BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Dimensions' : 'Masse', 8));
    }

    headerCells.addAll([
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Qty' : 'Anz.', 8, align: pw.TextAlign.right),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Unit' : 'Einh', 8),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: pw.TextAlign.right),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Total' : 'Gesamt', 8, align: pw.TextAlign.right),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Disc.' : 'Rab.', 8, align: pw.TextAlign.right),
      BasePdfGenerator.buildHeaderCell(
          language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right),
    ]);

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: headerCells,
      ),
    );

    double totalAmount = 0.0;
    // Für jede Holzart-Gruppe
    groupedItems.forEach((woodGroup, items) {
      // Holzart-Header - Kompakte Zeile mit kleinem Padding
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            // Erste Zelle mit kompaktem Padding
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4), // Weniger Padding!
              child: pw.Text(
                woodGroup,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7, // Kleinere Schrift
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            // Alle anderen 12 Zellen minimal
            ...List.generate(13, (index) => pw.SizedBox(height: 16)), // Niedrige fixe Höhe
          ],
        ),
      );

      // Items der Holzart
      // Items der Holzart
      for (final item in items) {
        // NEU: Gratisartikel-Check hinzufügen
        final isGratisartikel = item['is_gratisartikel'] == true;

        final quantity = (item['quantity'] as num? ?? 0).toDouble();

        // ÄNDERUNG: Preis bei Gratisartikeln auf 0 setzen
        final pricePerUnit = isGratisartikel
            ? 0.0  // Gratisartikel haben Preis 0
            : (item['price_per_unit'] as num? ?? 0).toDouble();

        final discount = item['discount'] as Map<String, dynamic>?;

        // Gesamtbetrag vor Rabatt
        final totalBeforeDiscount = quantity * pricePerUnit;

        // Rabattbetrag berechnen (nicht aus discount_amount lesen!)
        double discountAmount = 0.0;
        if (discount != null) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();

          if (percentage > 0) {
            discountAmount = totalBeforeDiscount * (percentage / 100);
          } else if (absolute > 0) {
            discountAmount = absolute;
          }
        }

        // Gesamtbetrag nach Rabatt
        final itemTotal = totalBeforeDiscount - discountAmount;

        // Maße zusammenstellen
        String dimensions = '';
        final customLength = (item['custom_length'] as num?) ?? 0;
        final customWidth = (item['custom_width'] as num?) ?? 0;
        final customThickness = (item['custom_thickness'] as num?) ?? 0;

// Nur anzeigen wenn mindestens ein Maß größer als 0 ist
        if (customLength > 0 || customWidth > 0 || customThickness > 0) {
          dimensions = '${customLength}×${customWidth}×${customThickness}';
        }

        // Einheit korrigieren: "Stück" zu "Stk"
        String unit = item['unit'] ?? '';
        if (unit.toLowerCase() == 'stück') {
          unit = 'Stk';
        }


        rows.add(
          pw.TableRow(
            children: [
              // ÄNDERUNG: Produktname mit Gratisartikel-Badge
              BasePdfGenerator.buildContentCell(
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          pw.Text(
                              language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 6)
                          ),
                          // NEU: Hinweise in Klammern hinzufügen
                          if (item['notes'] != null && item['notes'].toString().isNotEmpty)
                            pw.Text(
                              ' (${item['notes']})',
                              style: pw.TextStyle(
                                fontSize: 6,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.grey700,
                              ),
                            ),
                          // Gratisartikel-Badge
                          if (isGratisartikel)
                            pw.Container(
                              margin: const pw.EdgeInsets.only(left: 4),
                              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.green,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Text(
                                language == 'EN' ? 'FREE' : 'GRATIS',
                                style: const pw.TextStyle(
                                  fontSize: 5,
                                  color: PdfColors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(  language == 'EN' ?item['instrument_name_en']:item['instrument_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              // BasePdfGenerator.buildContentCell(
              //   pw.Text(  language == 'EN' ?item['part_name_en']:item['part_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              // ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['fsc_status'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text('CH', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text('', style: const pw.TextStyle(fontSize: 6)),
              ),
              if (showDimensions) BasePdfGenerator.buildContentCell(pw.Text(dimensions, style: const pw.TextStyle(fontSize: 6)),),

              BasePdfGenerator.buildContentCell(
                pw.Text(
                  unit != "Stk"
                      ? quantity.toStringAsFixed(3)
                      : quantity.toStringAsFixed(quantity == quantity.round() ? 0 : 3),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(unit, style: const pw.TextStyle(fontSize: 6)),
              ),

              // Originalpreis pro Einheit
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
                ),
              ),

// NEU: Gesamtpreis (Menge × Einzelpreis, unrabattiert)
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(quantity * pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
                ),
              ),

// NEU: Rabatt-Spalte (jetzt an 3. Stelle)
              BasePdfGenerator.buildContentCell(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (discount != null && (discount['percentage'] as num? ?? 0) > 0)
                      pw.Text(
                        '${discount['percentage'].toStringAsFixed(2)}%',
                        style: const pw.TextStyle(fontSize: 6, ),
                        textAlign: pw.TextAlign.right,
                      ),
                    if (discount != null && (discount['absolute'] as num? ?? 0) > 0)
                      pw.Text(
                        BasePdfGenerator.formatCurrency(
                            (discount['absolute'] as num).toDouble(),
                            currency,
                            exchangeRates
                        ),
                        style: const pw.TextStyle(fontSize: 6),
                        textAlign: pw.TextAlign.right,
                      ),
                  ],
                ),
              ),

// NEU: Netto Gesamtpreis - Rabattierter Gesamtbetrag (jetzt an 4. Stelle)
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(itemTotal, currency, exchangeRates),
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: discountAmount > 0 ? pw.FontWeight.bold : null,

                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }
    });

    // NEU: Spaltenbreiten anpassen basierend auf showDimensions
    final columnWidths = showDimensions ? {
      0: const pw.FlexColumnWidth(4),      // Produkt
      1: const pw.FlexColumnWidth(2.0),    // Instr.
    //  2: const pw.FlexColumnWidth(1.5),    // Typ
      2: const pw.FlexColumnWidth(1.5),    // Qual.
      3: const pw.FlexColumnWidth(1.5),    // FSC
      4: const pw.FlexColumnWidth(1.2),    // Urs
      5: const pw.FlexColumnWidth(1.0),    // °C
      6: const pw.FlexColumnWidth(2.5),    // Masse
      7: const pw.FlexColumnWidth(1.5),    // Anz.
      8: const pw.FlexColumnWidth(1.2),    // Einh
      9: const pw.FlexColumnWidth(2.0),   // Preis/E
      10: const pw.FlexColumnWidth(2.0),   // Gesamt
      11: const pw.FlexColumnWidth(1.5),   // Rabatt
      12: const pw.FlexColumnWidth(2.0),   // Netto Gesamt
    } : {
      0: const pw.FlexColumnWidth(4.5),    // Produkt (mehr Platz ohne Masse)
      1: const pw.FlexColumnWidth(2.2),    // Instr.
      //2: const pw.FlexColumnWidth(1.8),    // Typ
      2: const pw.FlexColumnWidth(1.8),    // Qual.
      3: const pw.FlexColumnWidth(1.8),    // FSC
      4: const pw.FlexColumnWidth(1.5),    // Urs
      5: const pw.FlexColumnWidth(1.0),    // °C
      6: const pw.FlexColumnWidth(1.8),    // Anz.
      7: const pw.FlexColumnWidth(1.5),    // Einh
      8: const pw.FlexColumnWidth(2.2),    // Preis/E
      9: const pw.FlexColumnWidth(2.2),   // Gesamt
      10: const pw.FlexColumnWidth(1.8),   // Rabatt
      11: const pw.FlexColumnWidth(2.3),   // Netto Gesamt
    };

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }
// Hilfsmethode für die Referenz-Formatierung
  static String _buildDownPaymentReference(String reference, DateTime? date, String language) {
    final List<String> parts = [];

    if (reference.isNotEmpty) {
      // Bei Zahlungsmethoden direkt anzeigen
      if (reference == 'Barzahlung' || reference == 'Cash payment') {
        return ' (${reference})';
      }
      // Bei anderen Referenzen
      parts.add(reference);
    }

    if (date != null) {
      parts.add(DateFormat('dd.MM.yyyy').format(date));
    }

    if (parts.isEmpty) {
      return '';
    }

    // Keine "Referenz:" Prefix bei Zahlungsmethoden
    if (reference == 'Barzahlung' || reference == 'Cash payment' ||
        reference.toLowerCase().contains('paypal') ||
        reference.toLowerCase().contains('überweisung')) {
      return ' (${parts.join(', ')})';
    }

    final referenceText = language == 'EN' ? 'Reference' : 'Referenz';
    return ' ($referenceText: ${parts.join(', ')})';
  }
  // Erstelle Summen-Bereich
  static pw.Widget _buildTotalsSection(
      List<Map<String, dynamic>> items,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      Map<String, dynamic>? shippingCosts,
      Map<String, dynamic>? calculations,
      int taxOption,
      double vatRate,
      Map<String, dynamic>? downPaymentSettings, // NEU: Parameter hinzufügen
      DateTime? paymentDue,
      Map<String, bool> roundingSettings,
      )
  {
    double subtotal = 0.0;
    double actualItemDiscounts = 0.0;

    // Am Anfang von _buildTotalsSection:
    print('Debug _buildTotalsSection:');
    print('currency: $currency');
    print('exchangeRates: $exchangeRates');
    print('exchangeRates type: ${exchangeRates.runtimeType}');
    exchangeRates.forEach((key, value) {
      print('exchangeRates[$key] = $value (type: ${value.runtimeType})');
    });

    for (final item in items) {
      // NEU: Gratisartikel-Check
      final isGratisartikel = item['is_gratisartikel'] == true;

      final quantity = (item['quantity'] as num? ?? 0).toDouble();

      // ÄNDERUNG: Preis bei Gratisartikeln
      final pricePerUnit = isGratisartikel
          ? 0.0
          : (item['price_per_unit'] as num? ?? 0).toDouble();

      subtotal += quantity * pricePerUnit;

      // NEU: Rabatte nur auf nicht-Gratisartikel berechnen
      if (!isGratisartikel) {
        final itemDiscountAmount = (item['discount_amount'] as num? ?? 0).toDouble();
        actualItemDiscounts += itemDiscountAmount;
      }

    }
    final itemDiscounts = actualItemDiscounts > 0 ? actualItemDiscounts : (calculations?['item_discounts'] ?? 0.0);
    final totalDiscountAmount = calculations?['total_discount_amount'] ?? 0.0;
    final afterDiscounts = subtotal - itemDiscounts - totalDiscountAmount;

    // Versandkosten
    final plantCertificate = shippingCosts?['plant_certificate_enabled'] == true
        ? ((shippingCosts?['plant_certificate_cost'] as num?) ?? 0).toDouble()
        : 0.0;
    final packagingCost = ((shippingCosts?['packaging_cost'] as num?) ?? 0).toDouble();
    final freightCost = ((shippingCosts?['freight_cost'] as num?) ?? 0).toDouble();
    final shippingCombined = shippingCosts?['shipping_combined'] ?? true;
    final carrier = (shippingCosts?['carrier'] == 'Persönlich abgeholt' && language == 'EN')
        ? 'Collected in person'
        : (shippingCosts?['carrier'] ?? 'Swiss Post');

    // Abschläge und Zuschläge
    final totalDeductions = ((shippingCosts?['totalDeductions'] as num?) ?? 0).toDouble();
    final totalSurcharges = ((shippingCosts?['totalSurcharges'] as num?) ?? 0).toDouble();

    final netAmount = afterDiscounts + plantCertificate + packagingCost + freightCost + totalSurcharges - totalDeductions;



    print("test");
    print("$taxOption");

    // MwSt-Berechnung basierend auf taxOption
    double vatAmount = 0.0;
    double totalWithTax = netAmount;

    if (taxOption == 0) { // TaxOption.standard
      // NEU: Erst Nettobetrag auf 2 Nachkommastellen runden
      final netAmountRounded = double.parse(netAmount.toStringAsFixed(2));

      // NEU: MwSt berechnen und auf 2 Nachkommastellen runden
      vatAmount = double.parse((netAmountRounded * (vatRate / 100)).toStringAsFixed(2));

      // NEU: Total ist Summe der gerundeten Beträge
      totalWithTax = netAmountRounded + vatAmount;
    } else {
      // Bei anderen Steueroptionen auch auf 2 Nachkommastellen runden
      totalWithTax = double.parse(netAmount.toStringAsFixed(2));
    }

    // NEU: Rundung anwenden
    double displayTotal = totalWithTax;
    double roundingDifference = 0.0;

    // Prüfe ob Rundung für diese Währung aktiviert ist
    if (roundingSettings[currency] == true) {
      // Konvertiere in Anzeigewährung
      if (currency != 'CHF') {
        displayTotal = totalWithTax * (exchangeRates[currency] ?? 1.0);
      }

      // Wende Rundung an
      final roundedDisplayTotal = SwissRounding.round(
        displayTotal,
        currency: currency,
        roundingSettings: roundingSettings,
      );

      roundingDifference = roundedDisplayTotal - displayTotal;

      // Setze den gerundeten Wert
      displayTotal = roundedDisplayTotal;

      // Konvertiere zurück in CHF falls nötig
      if (currency != 'CHF') {
        totalWithTax = displayTotal / (exchangeRates[currency] ?? 1.0);
      } else {
        totalWithTax = displayTotal;
      }
    }

    double totalInTargetCurrency = totalWithTax;
    if (currency != 'CHF') {
      totalInTargetCurrency = totalWithTax * (exchangeRates[currency] ?? 1.0);
    }

    // JETZT ERST die Anzahlung berechnen (NACH MwSt, Rundung und Währungsumrechnung!)
    final isFullPayment = downPaymentSettings?['is_full_payment'] ?? false;

    double downPaymentAmount = 0.0;
    String downPaymentReference = '';
    DateTime? downPaymentDate;

    if (isFullPayment) {
      // Bei 100% Vorkasse ist die "Anzahlung" = finaler Bruttobetrag in Zielwährung
      downPaymentAmount = totalInTargetCurrency;

      // Hole Zahlungsmethode
      final paymentMethod = downPaymentSettings?['payment_method'] ?? 'BAR';
      if (paymentMethod == 'BAR') {
        downPaymentReference = language == 'EN' ? 'Cash payment' : 'Barzahlung';
      } else {
        downPaymentReference = downPaymentSettings?['custom_payment_method'] ?? '';
      }
      downPaymentDate = DateTime.now();
    } else {
      // Normale Anzahlung
      downPaymentAmount = downPaymentSettings != null
          ? ((downPaymentSettings['down_payment_amount'] as num?) ?? 0.0).toDouble()
          : 0.0;
      downPaymentReference = downPaymentSettings?['down_payment_reference'] ?? '';
      downPaymentDate = downPaymentSettings?['down_payment_date'];
    }



    if (currency != 'CHF') {
      totalInTargetCurrency = totalWithTax * (exchangeRates[currency] ?? 1.0);
    }
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 400,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Subtotal (bereits reduziert um Positionsrabatte)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(language == 'EN' ? 'Subtotal' : 'Subtotal', style: const pw.TextStyle(fontSize: 9)),
                pw.Text(BasePdfGenerator.formatCurrency(subtotal - itemDiscounts, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
              ],
            ),

            // Gesamtrabatt
            if (totalDiscountAmount > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(

                    children: [

                      pw.Text(language == 'EN' ? 'Total discount' : 'Gesamtrabatt', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(' (${(totalDiscountAmount/subtotal*100).toStringAsFixed(2)}%)', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),

                  pw.Text('- ${BasePdfGenerator.formatCurrency(totalDiscountAmount, currency, exchangeRates)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],

            // Pflanzenschutzzeugniss
            if (plantCertificate > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'Phytosanitary certificate' : 'Pflanzenschutzzeugniss', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(BasePdfGenerator.formatCurrency(plantCertificate, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
// Verpackung & Fracht
            if (shippingCombined) ...[
              // NEU: Prüfe ob persönlich abgeholt
              // Statt nur zu prüfen ob "Persönlich abgeholt"
              if (carrier == 'Persönlich abgeholt' || carrier == 'Collected in person') ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Collected in person' : 'Persönlich abgeholt',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    // NEU: Nur wenn Kosten 0 sind, nichts anzeigen, sonst Preis zeigen
                    if (packagingCost + freightCost > 0)
                      pw.Text(BasePdfGenerator.formatCurrency(packagingCost + freightCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9))
                    else
                      pw.SizedBox(),
                  ],
                ),
              ] else if (packagingCost + freightCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN'
                          ? 'Packing & Freight costs ($carrier)'
                          : 'Verpackungs- & Frachtkosten ($carrier)',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(BasePdfGenerator.formatCurrency(packagingCost + freightCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ] else ...[
              // Getrennt
              if (packagingCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(language == 'EN' ? 'Packing costs' : 'Verpackungskosten', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(BasePdfGenerator.formatCurrency(packagingCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
              // NEU: Bei getrennter Anzeige auch prüfen ob persönlich abgeholt
              if (carrier == 'Persönlich abgeholt' || carrier == 'Collected in person') ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Collected in person' : 'Persönlich abgeholt',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    // NEU: Nur wenn Frachtkosten 0 sind, nichts anzeigen, sonst Preis zeigen
                    if (freightCost > 0)
                      pw.Text(BasePdfGenerator.formatCurrency(freightCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9))
                    else
                      pw.SizedBox(),
                  ],
                ),
              ] else if (freightCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN'
                          ? 'Freight costs ($carrier)'
                          : 'Frachtkosten ($carrier)',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(BasePdfGenerator.formatCurrency(freightCost, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ],

            // Abschläge und Zuschläge
            if (shippingCosts != null) ...[
              // Abschlag 1
              if ((shippingCosts['deduction_1_text'] ?? '').isNotEmpty && ((shippingCosts['deduction_1_amount'] as num?) ?? 0).toDouble()> 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_1_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_1_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
                    ),
                  ],
                ),
              ],

              // Abschlag 2
              if ((shippingCosts['deduction_2_text'] ?? '').isNotEmpty && (shippingCosts['deduction_2_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_2_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_2_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
                    ),
                  ],
                ),
              ],

              // Abschlag 3
              if ((shippingCosts['deduction_3_text'] ?? '').isNotEmpty && (shippingCosts['deduction_3_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['deduction_3_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(shippingCosts['deduction_3_amount'], currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
                    ),
                  ],
                ),
              ],

              // Zuschlag 1
              if ((shippingCosts['surcharge_1_text'] ?? '').isNotEmpty && (shippingCosts['surcharge_1_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['surcharge_1_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      BasePdfGenerator.formatCurrency(shippingCosts['surcharge_1_amount'], currency, exchangeRates),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],

              // Zuschlag 2
              if ((shippingCosts['surcharge_2_text'] ?? '').isNotEmpty && (shippingCosts['surcharge_2_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['surcharge_2_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      BasePdfGenerator.formatCurrency(shippingCosts['surcharge_2_amount'], currency, exchangeRates),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],

              // Zuschlag 3
              if ((shippingCosts['surcharge_3_text'] ?? '').isNotEmpty && (shippingCosts['surcharge_3_amount'] ?? 0.0) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(shippingCosts['surcharge_3_text'], style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      BasePdfGenerator.formatCurrency(shippingCosts['surcharge_3_amount'], currency, exchangeRates),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ],

            // MwSt-Bereich je nach Option
            if (taxOption == 0) ...[  // TaxOption.standard
              pw.Divider(color: PdfColors.blueGrey300),

              // Nettobetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(language == 'EN' ? 'Net amount' : 'Nettobetrag', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.SizedBox(height: 4),

              // MwSt
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN'
                        ? 'VAT (${vatRate.toStringAsFixed(1)}%)'
                        : 'MwSt (${vatRate.toStringAsFixed(1)}%)',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(BasePdfGenerator.formatCurrency(vatAmount, currency, exchangeRates), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.SizedBox(height: 4),
              // Rundungsdifferenz anzeigen (falls vorhanden)
              if (roundingSettings[currency] == true && roundingDifference != 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Rounding' : 'Rundung',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      roundingDifference > 0
                          ? '+${BasePdfGenerator.formatCurrency(roundingDifference.abs() / exchangeRates[currency]!, currency, exchangeRates)}'
                          : '-${BasePdfGenerator.formatCurrency(roundingDifference.abs() / exchangeRates[currency]!, currency, exchangeRates)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: roundingDifference > 0 ? PdfColors.green700 : PdfColors.orange800,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],


              pw.Divider(color: PdfColors.blueGrey300),

              // Gesamtbetrag
    // Bruttobetrag
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Text(
    language == 'EN' ? 'Gross amount' : 'Bruttobetrag',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    pw.Text(
    BasePdfGenerator.formatCurrency(totalWithTax, currency, exchangeRates),
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    ],
    ),

    // NEU: Anzahlung abziehen falls vorhanden
              // NEU: Anzahlung/Vollzahlung abziehen falls vorhanden
              if (downPaymentAmount > 0) ...[
                pw.SizedBox(height: 8),

                // Anzahlungszeile
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isFullPayment
                          ? (language == 'EN'
                          ? './ Payment received${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
                          : './ Zahlung erhalten${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}')
                          : (language == 'EN'
                          ? './ Down payment${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
                          : './ Anzahlung${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      '$currency ${downPaymentAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),

                pw.SizedBox(height: 4),

                // Restbetrag
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN'
                          ? 'Balance due'
                          : 'Restbetrag',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(
                      '$currency ${(totalInTargetCurrency - downPaymentAmount).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ],
                ),
              ],

    ] else if (taxOption == 1) ...[  // TaxOption.noTax
    pw.Divider(color: PdfColors.blueGrey300),

    // Nettobetrag
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Text(
    language == 'EN' ? 'Net amount' : 'Nettobetrag',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    pw.Text(
    BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates),
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    ],
    ),

    pw.SizedBox(height: 4),
    pw.Text(
    language == 'EN'
    ? 'No VAT will be charged.'
        : 'Es wird keine Mehrwertsteuer berechnet.',
    style: pw.TextStyle(
    fontSize: 9,
    fontStyle: pw.FontStyle.italic,
    color: PdfColors.grey700,
    ),
    ),

    // NEU: Anzahlung auch bei noTax abziehen
    if (downPaymentAmount > 0) ...[
    pw.SizedBox(height: 8),

    // Anzahlungszeile
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Text(
    language == 'EN'
    ? './ Down payment${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
        : './ Anzahlung${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}',
    style: const pw.TextStyle(fontSize: 9),
    ),
    pw.Text(
    '$currency ${downPaymentAmount.toStringAsFixed(2)}',
    style: const pw.TextStyle(fontSize: 9),
    ),
    ],
    ),

    pw.SizedBox(height: 4),

    // Restbetrag
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Text(
    language == 'EN'
    ? 'Balance due'
        : 'Restbetrag',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    pw.Text(
    BasePdfGenerator.formatCurrency(netAmount - downPaymentAmount, currency, exchangeRates),
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
    ],
    ),
    ],

    ] else ...[  // TaxOption.totalOnly
              pw.Divider(color: PdfColors.blueGrey300),

              // Gesamtbetrag
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN'
                        ? 'Total incl. ${vatRate.toStringAsFixed(1)}% VAT'
                        : 'Gesamtbetrag inkl. ${vatRate.toStringAsFixed(1)}% MwSt',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                  pw.Text(
                    BasePdfGenerator.formatCurrency(netAmount, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                ],
              ),

              // Anzahlung falls vorhanden
              if (downPaymentAmount > 0) ...[
                pw.SizedBox(height: 8),

                // Anzahlungszeile
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN'
                          ? './ Down payment${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}'
                          : './ Anzahlung${_buildDownPaymentReference(downPaymentReference, downPaymentDate, language)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      '$currency ${downPaymentAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),

                pw.SizedBox(height: 4),

                // Restbetrag
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Balance due' : 'Restbetrag',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(
                      BasePdfGenerator.formatCurrency(netAmount - downPaymentAmount, currency, exchangeRates),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ],
                ),
              ],

            ],
          ],
        ),
      ),
    );
  }

  // Formatiere Betrag ohne Währungszeichen
  static String _formatAmountOnly(double amount, String currency, Map<String, double> exchangeRates) {
    double convertedAmount = amount;
    if (currency != 'CHF') {
      convertedAmount = amount * exchangeRates[currency]!;
    }
    return convertedAmount.toStringAsFixed(2);
  }
  // Ändere die _addInlineAdditionalTexts Methode:
  static Future<pw.Widget> _addInlineAdditionalTexts(
      String language,
      Map<String, dynamic>? additionalTexts, // NEU: Additional Texts als Parameter
      ) async {
    try {
      // NEU: Verwende die übergebenen Additional Texts oder lade Default-Werte
      final textsToUse = additionalTexts ?? {
        'legend': {
          'type': 'standard',
          'custom_text': '',
          'selected': true,
        },
        'fsc': {
          'type': 'standard',
          'custom_text': '',
          'selected': false,
        },
        'natural_product': {
          'type': 'standard',
          'custom_text': '',
          'selected': true,
        },
        'bank_info': {
          'type': 'standard',
          'custom_text': '',
          'selected': true,
        },
        'free_text': {
          'type': 'custom',
          'custom_text': '',
          'selected': false,
        },
      };

      final List<pw.Widget> textWidgets = [];

      // Sammle alle ausgewählten Texte
      if (textsToUse['legend']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['legend'],
                  'legend',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textsToUse['fsc']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['fsc'],
                  'fsc',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textsToUse['natural_product']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['natural_product'],
                  'natural_product',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textsToUse['bank_info']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['bank_info'],
                  'bank_info',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      // Neues Freitextfeld
      if (textsToUse['free_text']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  textsToUse['free_text'],
                  'free_text',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (textWidgets.isEmpty) {
        return pw.SizedBox.shrink();
      }

      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: textWidgets,
        ),
      );
    } catch (e) {
      print('Fehler beim Laden der Zusatztexte: $e');
      return pw.SizedBox.shrink();
    }
  }



  // Füge Zusatztexte-Seite hinzu
  static Future<void> _addAdditionalTextsPage(pw.Document pdf, pw.MemoryImage logo) async {
    try {
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();

      final List<String> textsToShow = [];

      // Legende
      if (additionalTexts['legend']?['selected'] == true) {
        textsToShow.add(AdditionalTextsManager.getTextContent(additionalTexts['legend'], 'legend'));
      }

      // FSC
      if (additionalTexts['fsc']?['selected'] == true) {
        textsToShow.add(AdditionalTextsManager.getTextContent(additionalTexts['fsc'], 'fsc'));
      }

      // Naturprodukt
      if (additionalTexts['natural_product']?['selected'] == true) {
        textsToShow.add(AdditionalTextsManager.getTextContent(additionalTexts['natural_product'], 'natural_product'));
      }

      if (textsToShow.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(10),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Zusätzliche Informationen',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  ...textsToShow.map((text) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
                  )),

                  pw.Expanded(child: pw.SizedBox()),
                  BasePdfGenerator.buildFooter(),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Hinzufügen der Zusatztexte-Seite: $e');
    }
  }
}