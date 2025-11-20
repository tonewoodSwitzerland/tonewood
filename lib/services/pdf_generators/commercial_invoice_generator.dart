// File: services/pdf_generators/commercial_invoice_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';

class CommercialInvoiceGenerator extends BasePdfGenerator {

  // Erstelle eine neue Handelsrechnungs-Nummer
  static Future<String> getNextCommercialInvoiceNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('commercial_invoice_counters');

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

        return 'HR-$year-$currentNumber';
      });
    } catch (e) {
      print('Fehler beim Erstellen der Handelsrechnungs-Nummer: $e');
      return 'HR-${DateTime.now().year}-1000';
    }
  }

  static Future<Uint8List> generateCommercialInvoicePdf({
    String? orderId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, dynamic>? fairData,
    required String costCenterCode,
    required String currency,
    required Map<String, double> exchangeRates,
    String? invoiceNumber,
    String? orderNumber, // NEU (ist die Rechnungsnummer)
    String? quoteNumber, // NEU
    required String language,
    Map<String, dynamic>? shippingCosts,
    Map<String, dynamic>? calculations,
    required int taxOption,
    required double vatRate,
    Map<String, dynamic>? taraSettings,
    DateTime? invoiceDate
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    // Generiere Handelsrechnungs-Nummer falls nicht übergeben
    final invoiceNum = invoiceNumber ?? await getNextCommercialInvoiceNumber();

    // Gruppiere Items nach Zolltarifnummer
    // Ersetzen durch:
// Items nach Typ trennen
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final serviceItems = items.where((item) => item['is_service'] == true).toList();

// Nur Produkte gruppieren (Dienstleistungen haben keine Zolltarifnummer)
    final groupedProductItems = await _groupItemsByTariffNumber(productItems, language);

    bool showExchangeRateOnDocument = false;
    try {
      final currencySettings = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('currency_settings')
          .get();

      if (currencySettings.exists) {
        showExchangeRateOnDocument = currencySettings.data()?['show_exchange_rate_on_documents'] ?? false;
      }
    } catch (e) {
      print('Fehler beim Laden der Currency Settings: $e');
    }

    final additionalTextsWidget = await _addInlineAdditionalTexts(language);
    final standardTextsWidget = await _addCommercialInvoiceStandardTexts( language,
        taraSettings: taraSettings,
        orderId: orderId);
    // Übersetzungsfunktion
    String getTranslation(String key) {
      // Sichere den currency Wert
      final safeCurrency = currency ?? 'CHF';
      final exchangeRate = exchangeRates[safeCurrency] ?? 1.0;

      final translations = {
        'DE': {
          'commercial_invoice': 'HANDELSRECHNUNG',
          'currency_note': 'Alle Preise in $safeCurrency (Umrechnungskurs: 1 CHF = ${exchangeRate.toStringAsFixed(4)} $safeCurrency)',
          'tariff_number': 'Zolltarifnummer',
        },
        'EN': {
          'commercial_invoice': 'COMMERCIAL INVOICE',
          'currency_note': 'All prices in $safeCurrency (Exchange rate: 1 CHF = ${exchangeRate.toStringAsFixed(4)} $safeCurrency)',
          'tariff_number': 'Customs Tariff Number',
        }
      };

      // Sichere Rückgabe
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
                documentTitle: getTranslation('commercial_invoice'),
                documentNumber: invoiceNum,
                date: invoiceDate ?? DateTime.now(), // Verwende übergebenes Datum oder aktuelles
                logo: logo,
                costCenter: costCenterCode,
                language: language,
                additionalReference:  invoiceNumber != null ? 'invoice_nr:$invoiceNumber' : null,
                secondaryReference: quoteNumber != null ? 'quote_nr:$quoteNumber' : null,

              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
             BasePdfGenerator.buildCustomerAddress(customerData,'commercial_invoice', language: language),

              pw.SizedBox(height: 15),


              // Währungshinweis (falls nicht CHF UND showExchangeRateOnDocument aktiviert)
              if (currency != 'CHF' && showExchangeRateOnDocument)
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

              // Produkttabelle mit Zolltarifnummer-Gruppierung
              pw.Expanded(
                child: pw.Column(
                  children: [
                    // Produkttabelle nur wenn Produkte vorhanden
                    if (productItems.isNotEmpty)
                      _buildProductTable(groupedProductItems, currency, exchangeRates, language, taraSettings),

                    // Dienstleistungstabelle nur wenn Dienstleistungen vorhanden
                    if (serviceItems.isNotEmpty)
                      _buildServiceTable(serviceItems, currency, exchangeRates, language),

                    _buildTotalsSection(items, currency, exchangeRates, language, calculations),


                  ],
                ),
              ),
              additionalTextsWidget,
              standardTextsWidget,
              // Footer
              BasePdfGenerator.buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }


  static Future<pw.Widget> _addCommercialInvoiceStandardTexts(
      String language,
      {Map<String, dynamic>? taraSettings, String? orderId}  // NEU: Optional orderId
      ) async {
    try {
      // Lade die Standardtexte aus AdditionalTextsManager
      await AdditionalTextsManager.loadDefaultTextsFromFirebase();

      Map<String, dynamic> settings = {};

      // Entscheidungslogik für Datenquelle
      if (taraSettings != null) {
        // 1. Priorität: Übergebene taraSettings (von Order)
        settings = taraSettings;
        print('Verwende übergebene taraSettings');
      } else if (orderId != null && orderId.isNotEmpty) {
        // 2. Priorität: Lade aus Order-spezifischen Einstellungen
        final orderSettingsDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .collection('settings')
            .doc('tara_settings')
            .get();

        if (orderSettingsDoc.exists) {
          settings = orderSettingsDoc.data()!;
          print('Verwende Order-spezifische Einstellungen');
        } else {
          // Fallback zu temporären Einstellungen wenn keine Order-Settings existieren
          final tempSettingsDoc = await FirebaseFirestore.instance
              .collection('temporary_document_settings')
              .doc('tara_settings')
              .get();

          if (tempSettingsDoc.exists) {
            settings = tempSettingsDoc.data()!;
            print('Verwende temporäre Einstellungen (Fallback von Order)');
          } else {
            return pw.SizedBox.shrink();
          }
        }
      } else {
        // 3. Priorität: Angebotsphase - lade aus temporären Einstellungen
        final tempSettingsDoc = await FirebaseFirestore.instance
            .collection('temporary_document_settings')
            .doc('tara_settings')
            .get();

        if (!tempSettingsDoc.exists) return pw.SizedBox.shrink();
        settings = tempSettingsDoc.data()!;
        print('Verwende temporäre Einstellungen (Angebotsphase)');
      }

      final List<pw.Widget> textWidgets = [];



      // CITES
      if (settings['commercial_invoice_cites'] == true ||
          settings['cites'] == true) {  // Unterstütze beide Varianten
        final citesText = AdditionalTextsManager.getTextContent(
            {'selected': true, 'type': 'standard'},
            'cites',
            language: language
        );

        if (citesText.isNotEmpty) {
          textWidgets.add(
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                citesText,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              ),
            ),
          );
        }
      }

      // Grund des Exports - mit Freitext
      // Grund des Exports - mit Freitext
      if (settings['commercial_invoice_export_reason'] == true) {
        final exportReasonText = settings['commercial_invoice_export_reason_text'] as String? ?? 'Ware';

        // Übersetze "Ware" zu "goods" für Englisch
        final displayText = (exportReasonText == 'Ware' && language == 'EN') ? 'goods' : exportReasonText;

        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              language == 'EN' ? 'Export Reason: $displayText' : 'Grund des Exports: $exportReasonText',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
            ),
          ),
        );
      }

      // Incoterms - mehrere aus Datenbank laden mit individuellen Freitexten
      if (settings['commercial_invoice_incoterms'] == true &&
          settings['commercial_invoice_selected_incoterms'] != null) {

        final incotermIds = List<String>.from(settings['commercial_invoice_selected_incoterms']);
        final freeTexts = Map<String, String>.from(settings['commercial_invoice_incoterms_freetexts'] ?? {});

        if (incotermIds.isNotEmpty) {
          List<pw.Widget> incotermWidgets = [];

          // Header
          incotermWidgets.add(
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                'Incoterm 2020:',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              ),
            ),
          );

          // Einzelne Incoterms
          for (String incotermId in incotermIds) {
            final incotermDoc = await FirebaseFirestore.instance
                .collection('incoterms')
                .doc(incotermId)
                .get();

            if (incotermDoc.exists) {
              final incotermData = incotermDoc.data()!;
              final incotermName = incotermData['name'] as String;
              final freeText = freeTexts[incotermId] ?? '';

              String lineText = incotermName;
              if (freeText.isNotEmpty) {
                lineText += ', $freeText';
              }

              incotermWidgets.add(
                pw.Container(
                  alignment: pw.Alignment.centerLeft,
                  margin: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(
                    lineText,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
                  ),
                ),
              );
            }
          }

          textWidgets.addAll(incotermWidgets);
        }
      }

      // Lieferdatum - aus gespeichertem Datum mit Format-Option
      if (settings['commercial_invoice_delivery_date'] == true) {
        String dateText = language == 'EN' ? 'Delivery Date: ' : 'Lieferdatum: ';

        if (settings['commercial_invoice_delivery_date_value'] != null) {
          final timestamp = settings['commercial_invoice_delivery_date_value'];
          final monthOnly = settings['commercial_invoice_delivery_date_month_only'] ?? false;

          if (timestamp is Timestamp) {
            final date = timestamp.toDate();

            if (monthOnly) {
              // Nur Monat und Jahr
              final months = language == 'EN'
                  ? ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
                  : ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];
              dateText += '${months[date.month - 1]} ${date.year}';
            } else {
              // Vollständiges Datum
              dateText += '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
            }
          } else {
            dateText += language == 'EN' ? 'April 2025' : 'April 2025';
          }
        } else {
          dateText += language == 'EN' ? 'April 2025' : 'April 2025';
        }

        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              dateText,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
            ),
          ),
        );
      }

      // Transporteur - aus Freitext
      if (settings['commercial_invoice_carrier'] == true) {
        final carrierText = settings['commercial_invoice_carrier_text'] as String? ?? 'Swiss Post';

        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              language == 'EN' ? 'Carrier: $carrierText' : 'Transporteur: $carrierText',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
            ),
          ),
        );
      }

      // Ursprungserklärung
      if (settings['commercial_invoice_origin_declaration'] == true ||
          settings['origin_declaration'] == true) {  // Unterstütze beide Varianten
        final originText = AdditionalTextsManager.getTextContent(
            {'selected': true, 'type': 'standard'},
            'origin_declaration',
            language: language
        );

        if (originText.isNotEmpty) {
          textWidgets.add(
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2), // Mehr Margin
              padding: const pw.EdgeInsets.all(8), // Zusätzliches Padding
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                originText,
                style: pw.TextStyle(
                  fontSize: 8, // Etwas größer
                  color: PdfColors.blueGrey800, // Dunkler
                  fontWeight: pw.FontWeight.bold, // Fett
                ),
              ),
            ),
          );
        }
      }

      // Signatur - aus Datenbank laden
      if (settings['commercial_invoice_signature'] == true &&
          settings['commercial_invoice_selected_signature'] != null) {

        final signatureId = settings['commercial_invoice_selected_signature'] as String;
        final signatureDoc = await FirebaseFirestore.instance
            .collection('general_data')
            .doc('signatures')
            .collection('users')
            .doc(signatureId)
            .get();

        if (signatureDoc.exists) {
          final signatureData = signatureDoc.data()!;
          final signerName = signatureData['name'] as String;

          textWidgets.add(
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(top: 10, bottom: 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    language == 'EN' ? 'Signature:' : 'Signatur:',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    signerName,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    width: 200,
                    height: 1,
                    color: PdfColors.blueGrey400,
                  ),
                  pw.Text(
                    'Florinett AG, Tonewood Switzerland',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
                  ),
                ],
              ),
            ),
          );
        }
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
      print('Fehler beim Laden der Commercial Invoice Standardtexte: $e');
      return pw.SizedBox.shrink();
    }
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _groupItemsByTariffNumber(
      List<Map<String, dynamic>> items,
      String language
      ) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    for (final item in items) {
      final woodCode = item['wood_code'] as String;

      // Lade Holzart-Info (mit Cache)
      if (!woodTypeCache.containsKey(woodCode)) {
        final woodTypeDoc = await FirebaseFirestore.instance
            .collection('wood_types')
            .doc(woodCode)
            .get();

        if (woodTypeDoc.exists) {
          woodTypeCache[woodCode] = woodTypeDoc.data()!;
        } else {
          woodTypeCache[woodCode] = {};
        }
      }

      final woodInfo = woodTypeCache[woodCode]!;

      // NEU: Hole Dichte aus Datenbank
      final density = (woodInfo['density'] as num?)?.toDouble() ?? 0; // Default 0 kg/m³

      // Bestimme Zolltarifnummer basierend auf der Dicke
      final thickness = (item['custom_thickness'] != null)
          ? (item['custom_thickness'] is int
          ? (item['custom_thickness'] as int).toDouble()
          : item['custom_thickness'] as double)
          : 0.0;
      String tariffNumber = '';

      if (thickness <= 6.0) {
        tariffNumber = woodInfo['z_tares_1'] ?? '4408.1000';
      } else {
        tariffNumber = woodInfo['z_tares_2'] ?? '4407.1200';
      }

      // Berechne m³
      final length = item['custom_length'] != null
          ? (item['custom_length'] is int ? (item['custom_length'] as int).toDouble() : item['custom_length'] as double)
          : 0.0;

      final width = item['custom_width'] != null
          ? (item['custom_width'] is int ? (item['custom_width'] as int).toDouble() : item['custom_width'] as double)
          : 0.0;

      final thicknessValue = item['custom_thickness'] != null
          ? (item['custom_thickness'] is int ? (item['custom_thickness'] as int).toDouble() : item['custom_thickness'] as double)
          : 0.0;

      final quantity = (item['quantity'] as num? ?? 0).toDouble();

      // m³ pro Stück (in Meter umrechnen: mm -> m)
      double totalVolume = 0.0;

// 1. Priorität: Manuell eingegebenes Volumen
      if (item['custom_volume'] != null && (item['custom_volume'] as num) > 0) {
        totalVolume = (item['custom_volume'] as num).toDouble() * quantity;
      }
// 2. Priorität: Berechnetes Volumen aus Maßen
      else if (length > 0 && width > 0 && thicknessValue > 0) {
        final volumePerPiece = (length / 1000) * (width / 1000) * (thicknessValue / 1000);
        totalVolume = volumePerPiece * quantity;
      }
// 3. Priorität: Standardvolumen aus der Datenbank
      else {
        // Hole Standardvolumen aus standardized_products
        final instrumentCode = item['instrument_code'] as String?;
        final partCode = item['part_code'] as String?;

        if (instrumentCode != null && partCode != null) {
          final articleNumber = instrumentCode + partCode;

          try {
            final standardProductQuery = await FirebaseFirestore.instance
                .collection('standardized_products')
                .where('articleNumber', isEqualTo: articleNumber)
                .limit(1)
                .get();

            if (standardProductQuery.docs.isNotEmpty) {
              final standardProduct = standardProductQuery.docs.first.data();
              // Versuche verschiedene Volumen-Felder
              final standardVolume = standardProduct['volume']?['mm3_standard'] ??
                  standardProduct['volume']?['dm3_standard'] ?? 0;

              if (standardVolume > 0) {
                // Konvertiere mm³ zu m³ (falls mm3_standard)
                totalVolume = (standardVolume / 1000000000.0) * quantity;
              }
            }
          } catch (e) {
            print('Fehler beim Laden des Standard-Volumens: $e');
          }
        }
      }

      // Gewicht berechnen
      double weight = 0.0;

// Workaround: Wenn Einheit kg ist, verwende Quantity als Gewicht
      if (item['unit']?.toString().toLowerCase() == 'kg') {
        weight = quantity;
      } else if (totalVolume > 0) {
        // Normale Berechnung über Volumen * Dichte nur wenn Volumen vorhanden
        weight = totalVolume * density;
      } else {
        // Fallback: Versuche manuell eingegebenes Gewicht
        weight = (item['custom_weight'] as num?)?.toDouble() ?? 0.0;
      }

      // Verwende name_english wenn Sprache EN ist
      final woodName = language == 'EN'
          ? (woodInfo['name_english'] ?? woodInfo['name'] ?? item['wood_name'] ?? 'Unknown wood type')
          : (woodInfo['name'] ?? item['wood_name'] ?? 'Unbekannte Holzart');

      final woodNameLatin = woodInfo['name_latin'] ?? '';

      // Gruppiere nach Zolltarifnummer
      final groupKey = '$tariffNumber - $woodName ($woodNameLatin)';

      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }

      // Füge zusätzliche Infos zum Item hinzu
      final enhancedItem = Map<String, dynamic>.from(item);
      enhancedItem['tariff_number'] = tariffNumber;
      enhancedItem['wood_display_name'] = '$woodName ($woodNameLatin)';
      enhancedItem['wood_name_latin'] = woodNameLatin;
      enhancedItem['volume_m3'] = totalVolume;
      enhancedItem['weight_kg'] = weight;
      enhancedItem['density'] = density;

      grouped[groupKey]!.add(enhancedItem);
    }

    // Sortiere die Gruppen nach Zolltarifnummer
    final sortedGrouped = Map<String, List<Map<String, dynamic>>>.fromEntries(
        grouped.entries.toList()..sort((a, b) {
          final tariffA = a.key.split(' - ')[0];
          final tariffB = b.key.split(' - ')[0];
          return tariffA.compareTo(tariffB);
        })
    );

    return sortedGrouped;
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
              language == 'EN' ? 'Qty' : 'Anz.', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Unit' : 'Einh', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: pw.TextAlign.right),
          // BasePdfGenerator.buildHeaderCell(language == 'EN' ? 'Curr' : 'Wä', 8),
          // BasePdfGenerator.buildHeaderCell(
          //     language == 'EN' ? 'Total' : 'Betrag', 8, align: pw.TextAlign.right),
          // BasePdfGenerator.buildHeaderCell(
          //     language == 'EN' ? 'Disc.' : 'Rab.', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right),
        ],
      ),
    );

    double totalAmount = 0.0;

    // Dienstleistungen hinzufügen
    for (final service in serviceItems) {
      final quantity = (service['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = (service['custom_price_per_unit'] as num?) != null
          ? (service['custom_price_per_unit'] as num).toDouble()
          : (service['price_per_unit'] as num? ?? 0).toDouble();

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
      totalAmount += total;

      rows.add(
        pw.TableRow(
          children: [
            BasePdfGenerator.buildContentCell(
              pw.Text(
                language == 'EN'
                    ? (service['name_en']?.isNotEmpty == true ? service['name_en'] : service['name'] ?? 'Unnamed Service')
                    : (service['name'] ?? 'Unbenannte Dienstleistung'),
                style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                language == 'EN'
                    ? (service['description_en']?.isNotEmpty == true ? service['description_en'] : service['description'] ?? '')
                    : (service['description'] ?? ''),
                style: const pw.TextStyle(fontSize: 6),
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                quantity.toStringAsFixed(0),
                style: const pw.TextStyle(fontSize: 6),

              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text( language == 'EN' ? 'pcs' : 'Stk', style: const pw.TextStyle(fontSize: 6)),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatCurrency(pricePerUnit, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
            // BasePdfGenerator.buildContentCell(
            //   pw.Text(currency, style: const pw.TextStyle(fontSize: 6)),
            // ),
            // Gesamtpreis vor Rabatt
//             BasePdfGenerator.buildContentCell(
//               pw.Text(
//                 BasePdfGenerator.formatCurrency(totalBeforeDiscount, currency, exchangeRates),
//                 style: const pw.TextStyle(fontSize: 6),
//                 textAlign: pw.TextAlign.right,
//               ),
//             ),
// // Rabatt-Spalte
//             BasePdfGenerator.buildContentCell(
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.end,
//                 children: [
//                   if (discount != null && (discount['percentage'] as num? ?? 0) > 0)
//                     pw.Text(
//                       '${discount['percentage'].toStringAsFixed(2)}%',
//                       style: const pw.TextStyle(fontSize: 6),
//                       textAlign: pw.TextAlign.right,
//                     ),
//                   if (discount != null && (discount['absolute'] as num? ?? 0) > 0)
//                     pw.Text(
//                       BasePdfGenerator.formatCurrency(
//                           (discount['absolute'] as num).toDouble(),
//                           currency,
//                           exchangeRates
//                       ),
//                       style: const pw.TextStyle(fontSize: 6),
//                       textAlign: pw.TextAlign.right,
//                     ),
//                 ],
//               ),
//             ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatCurrency(total, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    // Gesamtsumme für Dienstleistungen
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey100,
          border: pw.Border(top: pw.BorderSide(width: 2, color: PdfColors.blueGrey700)),
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN' ? 'Services Total' : 'Dienstleistungen Gesamt',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
            ),
          ),
          ...List.generate(4, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              BasePdfGenerator.formatCurrency(totalAmount, currency, exchangeRates),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Text(
          language == 'EN' ? 'Services' : 'Dienstleistungen',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),    // Dienstleistung
            1: const pw.FlexColumnWidth(4),    // Beschreibung
            2: const pw.FlexColumnWidth(1),    // Anzahl
            3: const pw.FlexColumnWidth(1),    // Einheit
            4: const pw.FlexColumnWidth(2),    // Preis/E
           // 5: const pw.FlexColumnWidth(1),    // Währung
            5: const pw.FlexColumnWidth(2),    // Betrag
            6: const pw.FlexColumnWidth(1.5),  // Rabatt (NEU)
            7: const pw.FlexColumnWidth(2),    // Netto Gesamt (NEU)
          },
          children: rows,
        ),
      ],
    );
  }
// 2. ERSETZE die bestehende _buildProductTable Methode mit dieser:
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      Map<String, dynamic>? taraSettings) {

    final List<pw.TableRow> rows = [];
    double totalVolume = 0.0;
    double totalWeight = 0.0;

    // Header-Zeile mit m³ statt Masse
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Tariff No.' : 'Zolltarif', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Product' : 'Produkt', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Instrument' : 'Instrument', 8),
          // BasePdfGenerator.buildHeaderCell(
          //     language == 'EN' ? 'Type' : 'Typ', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Quality' : 'Qualität', 8),
          BasePdfGenerator.buildHeaderCell('FSC®', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Orig' : 'Urs', 8),
          BasePdfGenerator.buildHeaderCell('m³', 8), // NEU: m³ statt Masse
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Menge', 8,),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Unit' : 'Einh', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: pw.TextAlign.right),
          // BasePdfGenerator.buildHeaderCell(language == 'EN' ? 'Curr' : 'Wä', 8),
          // BasePdfGenerator.buildHeaderCell(
          //     language == 'EN' ? 'Total' : 'Betrag', 8, align: pw.TextAlign.right),
          // BasePdfGenerator.buildHeaderCell(
          //     language == 'EN' ? 'Disc.' : 'Rab.', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: pw.TextAlign.right),
        ],
      ),
    );

    // Für jede Zolltarifnummer-Gruppe
    groupedItems.forEach((groupKey, items) {
      // Extrahiere Zolltarifnummer und Holzart aus dem Schlüssel
      final parts = groupKey.split(' - ');
      final tariffNumber = parts[0];
      final woodDescription = parts.length > 1 ? parts[1] : '';

      // Berechne Zwischensumme m³ für diese Gruppe
      double groupVolume = 0.0;
      double groupWeight = 0.0;
      for (final item in items) {

        print("weight:${item['weight_kg']}");
        groupVolume += (item['volume_m3'] as num?)?.toDouble() ?? 0.0;
        groupWeight += (item['weight_kg'] as num?)?.toDouble() ?? 0.0;
      }
      totalVolume += groupVolume;
      totalWeight += groupWeight;

      // Zolltarifnummer-Header mit Zwischensumme
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            // Zolltarifnummer in erster Spalte
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(
                tariffNumber,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            // Holzart-Beschreibung über mehrere Spalten
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(
                woodDescription,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7,
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            // Leere Zellen
            ...List.generate(4, (index) => pw.SizedBox(height: 16)),
            // Zwischensumme m³
            // Im Zolltarifnummer-Header:
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(
                groupVolume > 0
                    ? (language == 'EN'
                    ? '${groupVolume.toStringAsFixed(5)}'
                    : '${groupVolume.toStringAsFixed(5)}')
                    : '', // Leer wenn 0
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7,
                  color: PdfColors.blueGrey800,
                ),

              ),
            ),
            // Restliche leere Zellen
            ...List.generate(5, (index) => pw.SizedBox(height: 16)),
          ],
        ),
      );

      // Items der Gruppe
      for (final item in items) {
        // NEU: Gratisartikel-Check
        final isGratisartikel = item['is_gratisartikel'] == true;
        final proformaValue = item['proforma_value'] as num?;

        final quantity = (item['quantity'] as num? ?? 0).toDouble();

        // ÄNDERUNG: Bei Gratisartikeln den Pro-forma-Wert verwenden
        final pricePerUnit = isGratisartikel && proformaValue != null
            ? proformaValue.toDouble()
            : (item['custom_price_per_unit'] as num?) != null
            ? (item['custom_price_per_unit'] as num).toDouble()
            : (item['price_per_unit'] as num? ?? 0).toDouble();

        // Rabatt-Berechnung
        final discount = item['discount'] as Map<String, dynamic>?;
        final totalBeforeDiscount = quantity * pricePerUnit;

        double discountAmount = 0.0;
        if (discount != null && !isGratisartikel) { // Kein Rabatt auf Gratisartikel
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();

          if (percentage > 0) {
            discountAmount = totalBeforeDiscount * (percentage / 100);
          } else if (absolute > 0) {
            discountAmount = absolute;
          }
        }

        final itemTotal = totalBeforeDiscount - discountAmount;
        final volumeM3 = (item['volume_m3'] as double? ?? 0.0);

        String unit = item['unit'] ?? '';
        if (unit.toLowerCase() == 'stück') {
          unit = language == 'EN' ? 'pcs' : 'Stk';
        }

        rows.add(
          pw.TableRow(
            children: [
              BasePdfGenerator.buildContentCell(
                pw.Text('', style: const pw.TextStyle(fontSize: 6)), // Zolltarifnummer nur im Header
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(  language == 'EN' ?item['part_name_en']:item['part_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
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
                pw.Text(
                  volumeM3 > 0 ? volumeM3.toStringAsFixed(5) : '', // Leer wenn 0
                  style: const pw.TextStyle(fontSize: 6),

                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  quantity.toStringAsFixed(3),
                  style: const pw.TextStyle(fontSize: 6),

                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(unit, style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              // // BasePdfGenerator.buildContentCell(pw.Text(currency, style: const pw.TextStyle(fontSize: 6)),),
              // BasePdfGenerator.buildContentCell(
              //   pw.Text(
              //     BasePdfGenerator.formatCurrency(totalBeforeDiscount, currency, exchangeRates),
              //     style: const pw.TextStyle(fontSize: 6),
              //     textAlign: pw.TextAlign.right,
              //   ),
              // ),
              // // NEU: Rabatt-Spalte
              // BasePdfGenerator.buildContentCell(
              //   pw.Column(
              //     crossAxisAlignment: pw.CrossAxisAlignment.end,
              //     children: [
              //       if (discount != null && (discount['percentage'] as num? ?? 0) > 0)
              //         pw.Text(
              //           '${discount['percentage'].toStringAsFixed(2)}%',
              //           style: const pw.TextStyle(fontSize: 6),
              //           textAlign: pw.TextAlign.right,
              //         ),
              //       if (discount != null && (discount['absolute'] as num? ?? 0) > 0)
              //         pw.Text(
              //           BasePdfGenerator.formatCurrency(
              //               (discount['absolute'] as num).toDouble(),
              //               currency,
              //               exchangeRates
              //           ),
              //           style: const pw.TextStyle(fontSize: 6),
              //           textAlign: pw.TextAlign.right,
              //         ),
              //     ],
              //   ),
              // ),
              // NEU: Netto Gesamtpreis
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

    // Gesamtsummen-Zeile
    final numberOfPackages = taraSettings?['number_of_packages'] ?? 1;
    final packagingWeight = (taraSettings?['packaging_weight'] ?? 0.0) as double;
    final totalGrossWeight = totalWeight + packagingWeight;

    // Berechne Gesamtbetrag
    double totalAmount = 0.0;
    groupedItems.forEach((key, items) {
      for (final item in items) {
        final isGratisartikel = item['is_gratisartikel'] == true;
        final proformaValue = item['proforma_value'] as num?;

        final quantity = (item['quantity'] as num? ?? 0).toDouble();

        // Bei Gratisartikeln Pro-forma-Wert verwenden
        final pricePerUnit = isGratisartikel && proformaValue != null
            ? proformaValue.toDouble()
            : (item['custom_price_per_unit'] as num?) != null
            ? (item['custom_price_per_unit'] as num).toDouble()
            : (item['price_per_unit'] as num? ?? 0).toDouble();
        // Rabatt-Berechnung
        final discount = item['discount'] as Map<String, dynamic>?;
        final totalBeforeDiscount = quantity * pricePerUnit;

        double discountAmount = 0.0;
        if (discount != null && !isGratisartikel) {
          final percentage = (discount['percentage'] as num? ?? 0).toDouble();
          final absolute = (discount['absolute'] as num? ?? 0).toDouble();

          if (percentage > 0) {
            discountAmount = totalBeforeDiscount * (percentage / 100);
          } else if (absolute > 0) {
            discountAmount = absolute;
          }
        }

        totalAmount += totalBeforeDiscount - discountAmount;
      }
    });

    // Total Netto-Zeile
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey100,
          border: pw.Border(top: pw.BorderSide(width: 2, color: PdfColors.blueGrey700)),
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN'
                  ? 'Net Volume'
                  : 'Netto-Kubatur',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
          // Total m³
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              totalVolume.toStringAsFixed(5),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),

            ),
          ),
          ...List.generate(1, (index) => pw.SizedBox()),
          // Total Gewicht

          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${totalWeight.toStringAsFixed(2)} kg',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),

            ),
          ),
          ...List.generate(1, (index) => pw.SizedBox()),
          // Gesamtbetrag
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              BasePdfGenerator.formatCurrency(totalAmount, currency, exchangeRates),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );

    // Tara-Zeile
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.amber50),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN'
                  ? 'Tare'
                  : 'Tara',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN'
                  ? 'Packaging: $numberOfPackages'
                  : 'Packungen: $numberOfPackages',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
          ...List.generate(6, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${packagingWeight.toStringAsFixed(2)} kg',
              style: const pw.TextStyle(fontSize: 7),

            ),
          ),
          ...List.generate(4, (index) => pw.SizedBox()),
        ],
      ),
    );

    // Brutto-Zeile
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey200,
          border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.blueGrey700)),
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN'
                  ? 'Gross Volume'
                  : 'Brutto-Kubatur',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              totalVolume.toStringAsFixed(5),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),

            ),
          ),
          ...List.generate(1, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${totalGrossWeight.toStringAsFixed(2)} kg',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),

            ),
          ),
          ...List.generate(3, (index) => pw.SizedBox()),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),    // Zolltarif
        1: const pw.FlexColumnWidth(2.8),      // Produkt
        2: const pw.FlexColumnWidth(2.1),    // Instr.
        3: const pw.FlexColumnWidth(1.5),    // Qual.
        4: const pw.FlexColumnWidth(1.5),    // FSC
        5: const pw.FlexColumnWidth(1.1),    // Urs
        6: const pw.FlexColumnWidth(1.5),    // m³
        7: const pw.FlexColumnWidth(1.5),    // Menge
        8: const pw.FlexColumnWidth(1.5),    // Einh
        9: const pw.FlexColumnWidth(2.0),   // Preis/E
      //  10: const pw.FlexColumnWidth(1.0),   // Wä
       // 10: const pw.FlexColumnWidth(2.0),   // Betrag
       // 11: const pw.FlexColumnWidth(1.5),   // Rabatt (NEU)
        10: const pw.FlexColumnWidth(2.0),   // Netto Gesamt (NEU)
      },
      children: rows,
    );
  }


  static pw.Widget _buildTotalsSection(
      List<Map<String, dynamic>> items,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      Map<String, dynamic>? calculations) {

    double subtotal = 0.0;
    double actualItemDiscounts = 0.0;

    // Separate Produkte und Dienstleistungen
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final serviceItems = items.where((item) => item['is_service'] == true).toList();

    // Berechne Subtotal und Einzelrabatte
    for (final item in items) {
      final isGratisartikel = item['is_gratisartikel'] == true;
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = isGratisartikel
          ? 0.0
          : (item['custom_price_per_unit'] as num?) != null
          ? (item['custom_price_per_unit'] as num).toDouble()
          : (item['price_per_unit'] as num? ?? 0).toDouble();

      subtotal += quantity * pricePerUnit;

      if (!isGratisartikel) {
        final itemDiscountAmount = (item['discount_amount'] as num? ?? 0).toDouble();
        actualItemDiscounts += itemDiscountAmount;
      }
    }

    final itemDiscounts = actualItemDiscounts > 0 ? actualItemDiscounts : (calculations?['item_discounts'] ?? 0.0);
    final totalDiscountAmount = calculations?['total_discount_amount'] ?? 0.0;
    final afterDiscounts = subtotal - itemDiscounts - totalDiscountAmount;

    // Anzeigen wenn: Gesamtrabatt vorhanden ODER sowohl Produkte als auch Dienstleistungen
    final hasProducts = productItems.isNotEmpty;
    final hasServices = serviceItems.isNotEmpty;
    final hasTotalDiscount = totalDiscountAmount > 0;

    if (!hasTotalDiscount && !(hasProducts && hasServices)) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
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
            // Subtotal
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    language == 'EN' ? 'Subtotal' : 'Subtotal',
                    style: const pw.TextStyle(fontSize: 9)
                ),
                pw.Text(
                    BasePdfGenerator.formatCurrency(subtotal - itemDiscounts, currency, exchangeRates),
                    style: const pw.TextStyle(fontSize: 9)
                ),
              ],
            ),

            // Gesamtrabatt (nur wenn vorhanden)
            if (totalDiscountAmount > 0) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                          language == 'EN' ? 'Total discount' : 'Gesamtrabatt',
                          style: const pw.TextStyle(fontSize: 9)
                      ),
                      pw.Text(
                          ' (${(totalDiscountAmount/subtotal*100).toStringAsFixed(2)}%)',
                          style: const pw.TextStyle(fontSize: 9)
                      ),
                    ],
                  ),
                  pw.Text(
                      '- ${BasePdfGenerator.formatCurrency(totalDiscountAmount, currency, exchangeRates)}',
                      style: const pw.TextStyle(fontSize: 9)
                  ),
                ],
              ),
            ],

            pw.Divider(color: PdfColors.blueGrey300),

            // Total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    language == 'EN' ? 'Total' : 'Gesamt',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)
                ),
                pw.Text(
                    BasePdfGenerator.formatCurrency(afterDiscounts, currency, exchangeRates),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Kopiere _addInlineAdditionalTexts aus QuoteGenerator
  static Future<pw.Widget> _addInlineAdditionalTexts(String language) async {
    // Gleicher Code wie in QuoteGenerator
    try {
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();
      final List<pw.Widget> textWidgets = [];

      if (additionalTexts['legend']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['legend'],
                  'legend',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (additionalTexts['fsc']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['fsc'],
                  'fsc',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

      if (additionalTexts['natural_product']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['natural_product'],
                  'natural_product',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }


      //Bankverbindung wird in Handelsrechnung nicht angezeigt
      // if (additionalTexts['bank_info']?['selected'] == true) {
      //   textWidgets.add(
      //     pw.Container(
      //       alignment: pw.Alignment.centerLeft,
      //       margin: const pw.EdgeInsets.only(bottom: 3),
      //       child: pw.Text(
      //         AdditionalTextsManager.getTextContent(
      //             additionalTexts['bank_info'],
      //             'bank_info',
      //             language: language
      //         ),
      //         style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
      //         textAlign: pw.TextAlign.left,
      //       ),
      //     ),
      //   );
      // }

      if (additionalTexts['free_text']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['free_text'],
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
}