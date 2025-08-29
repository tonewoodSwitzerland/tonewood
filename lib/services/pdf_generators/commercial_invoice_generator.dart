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
    final groupedItems = await _groupItemsByTariffNumber(items, language);
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
                  additionalReference: invoiceNumber != null ? 'Rechnungsnummer: $invoiceNumber' : null,
                   secondaryReference: quoteNumber != null ? 'Angebotsnummer: $quoteNumber' : null,

              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
             BasePdfGenerator.buildCustomerAddress(customerData, language: language),

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

              // Produkttabelle mit Zolltarifnummer-Gruppierung
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildProductTable(groupedItems, currency, exchangeRates, language,taraSettings),
                    pw.SizedBox(height: 10),


                    additionalTextsWidget,
                    standardTextsWidget
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
              margin: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                originText,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              ),
            ),
          );
        }
      }

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
      if (settings['commercial_invoice_export_reason'] == true) {
        final exportReasonText = settings['commercial_invoice_export_reason_text'] as String? ?? 'Ware';

        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              language == 'EN' ? 'Export Reason: $exportReasonText' : 'Grund des Exports: $exportReasonText',
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
              margin: const pw.EdgeInsets.only(top: 20, bottom: 3),
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
      final density = (woodInfo['density'] as num?)?.toDouble() ?? 450.0; // Default 450 kg/m³

      // Bestimme Zolltarifnummer basierend auf der Dicke
      final thickness = (item['custom_thickness'] ?? 0.0) as double;
      String tariffNumber = '';

      if (thickness <= 6.0) {
        tariffNumber = woodInfo['z_tares_1'] ?? '4408.1000';
      } else {
        tariffNumber = woodInfo['z_tares_2'] ?? '4407.1200';
      }

      // Berechne m³
      final length = (item['custom_length'] ?? 0.0) as double;
      final width = (item['custom_width'] ?? 0.0) as double;
      final thicknessValue = (item['custom_thickness'] ?? 0.0) as double;
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
              language == 'EN' ? 'Instr.' : 'Instr.', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Type' : 'Typ', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qual.' : 'Qual.', 8),
          BasePdfGenerator.buildHeaderCell('FSC®', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Orig' : 'Urs', 8),
          BasePdfGenerator.buildHeaderCell('m³', 8), // NEU: m³ statt Masse
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Menge', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Unit' : 'Einh', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Curr' : 'Wä', 8),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Total' : 'Betrag', 8, align: pw.TextAlign.right),
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
            ...List.generate(5, (index) => pw.SizedBox(height: 16)),
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
                textAlign: pw.TextAlign.right,
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
            : (item['price_per_unit'] as num? ?? 0).toDouble();

        final itemTotal = quantity * pricePerUnit;
        final volumeM3 = (item['volume_m3'] as double? ?? 0.0);

        String unit = item['unit'] ?? '';
        if (unit.toLowerCase() == 'stück') {
          unit = 'Stk';
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
              BasePdfGenerator.buildContentCell(
                pw.Text(  language == 'EN' ?item['part_name_en']:item['part_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
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
                  textAlign: pw.TextAlign.right,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  quantity.toStringAsFixed(3),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
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
              BasePdfGenerator.buildContentCell(
                pw.Text(currency, style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatCurrency(itemTotal, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 6),
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
            : (item['price_per_unit'] as num? ?? 0).toDouble();

        totalAmount += quantity * pricePerUnit;
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
          ...List.generate(6, (index) => pw.SizedBox()),
          // Total m³
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              totalVolume.toStringAsFixed(5),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
              textAlign: pw.TextAlign.right,
            ),
          ),
          // Total Gewicht
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${totalWeight.toStringAsFixed(2)} kg',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
              textAlign: pw.TextAlign.right,
            ),
          ),
          ...List.generate(3, (index) => pw.SizedBox()),
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
              textAlign: pw.TextAlign.right,
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
          ...List.generate(6, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              totalVolume.toStringAsFixed(5),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${totalGrossWeight.toStringAsFixed(2)} kg',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
              textAlign: pw.TextAlign.right,
            ),
          ),
          ...List.generate(4, (index) => pw.SizedBox()),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),    // Zolltarif
        1: const pw.FlexColumnWidth(2.5),      // Produkt
        2: const pw.FlexColumnWidth(2.0),    // Instr.
        3: const pw.FlexColumnWidth(1.5),    // Typ
        4: const pw.FlexColumnWidth(1.5),    // Qual.
        5: const pw.FlexColumnWidth(1.5),    // FSC
        6: const pw.FlexColumnWidth(1.0),    // Urs
        7: const pw.FlexColumnWidth(1.5),    // m³
        8: const pw.FlexColumnWidth(1.5),    // Menge
        9: const pw.FlexColumnWidth(1.0),    // Einh
        10: const pw.FlexColumnWidth(2.0),   // Preis/E
        11: const pw.FlexColumnWidth(1.0),   // Wä
        12: const pw.FlexColumnWidth(2.0),   // Betrag
      },
      children: rows,
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

      if (additionalTexts['bank_info']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['bank_info'],
                  'bank_info',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600),
              textAlign: pw.TextAlign.left,
            ),
          ),
        );
      }

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