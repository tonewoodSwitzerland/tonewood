// File: services/pdf_generators/commercial_invoice_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../pdf_settings_screen.dart';
import '../product_sorting_manager.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';

class CommercialInvoiceGenerator extends BasePdfGenerator {

  // ═══════════════════════════════════════════════════════════════════════════
  // NEU: Helper-Funktion für Spaltenausrichtung
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.TextAlign _getTextAlign(String alignment) {
    switch (alignment) {
      case 'left':
        return pw.TextAlign.left;
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
  }

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

    print("invoiceDate:$invoiceDate");


    // Generiere Handelsrechnungs-Nummer falls nicht übergeben
    final invoiceNum = invoiceNumber ?? await getNextCommercialInvoiceNumber();

    // NEU: Lade Adress-Anzeigemodus
    final addressMode = await PdfSettingsHelper.getAddressDisplayMode('commercial_invoice');

    // NEU: Lade Spaltenausrichtungen
    final columnAlignments = await PdfSettingsHelper.getColumnAlignments('commercial_invoice');

    // Gruppiere Items nach Zolltarifnummer
    // Ersetzen durch:
// Items nach Typ trennen
    // NACHHER:
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final serviceItems = items.where((item) => item['is_service'] == true).toList();
    final consolidatedItems = _consolidateItems(productItems);  // NEU
    final groupedProductItems = await _groupItemsByTariffNumber(consolidatedItems, language);

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
                costCenter: null,
                language: language,
                // additionalReference:  invoiceNumber != null ? 'invoice_nr:$invoiceNumber' : null,
                // secondaryReference: quoteNumber != null ? 'quote_nr:$quoteNumber' : null,

              ),
              pw.SizedBox(height: 20),

              // Kundenadresse
              BasePdfGenerator.buildCustomerAddress(customerData, 'commercial_invoice', language: language, addressDisplayMode: addressMode),
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
                    BasePdfGenerator.buildCurrencyHint(currency, language),

                    // Produkttabelle nur wenn Produkte vorhanden
                    if (productItems.isNotEmpty)
                      _buildProductTable(groupedProductItems, currency, exchangeRates, language, taraSettings, columnAlignments),

                    // Dienstleistungstabelle nur wenn Dienstleistungen vorhanden
                    if (serviceItems.isNotEmpty)
                      _buildServiceTable(serviceItems, currency, exchangeRates, language, columnAlignments),

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
      {Map<String, dynamic>? taraSettings, String? orderId}
      ) async {
    try {
      await AdditionalTextsManager.loadDefaultTextsFromFirebase();

      Map<String, dynamic> settings = {};

      if (taraSettings != null) {
        settings = taraSettings;

        print("taraSettings:$settings");
      } else if (orderId != null && orderId.isNotEmpty) {
        final orderSettingsDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .collection('settings')
            .doc('tara_settings')
            .get();

        if (orderSettingsDoc.exists) {
          settings = orderSettingsDoc.data()!;

          print("settings:$settings");
        } else {
          final tempSettingsDoc = await FirebaseFirestore.instance
              .collection('temporary_document_settings')
              .doc('tara_settings')
              .get();

          if (tempSettingsDoc.exists) {
            settings = tempSettingsDoc.data()!;
          } else {
            return pw.SizedBox.shrink();
          }
        }
      } else {
        final tempSettingsDoc = await FirebaseFirestore.instance
            .collection('temporary_document_settings')
            .doc('tara_settings')
            .get();

        if (!tempSettingsDoc.exists) return pw.SizedBox.shrink();
        settings = tempSettingsDoc.data()!;
      }

      final List<pw.Widget> textWidgets = [];

      // CITES
      if (settings['commercial_invoice_cites'] == true ||
          settings['cites'] == true) {
        final citesText = AdditionalTextsManager.getTextContent(
            {'selected': true, 'type': 'standard'},
            'cites',
            language: language
        );

        if (citesText.isNotEmpty) {
          textWidgets.add(
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                citesText,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
              ),
            ),
          );
        }
      }

      // Export Reason
      if (settings['commercial_invoice_export_reason'] == true) {
        final exportReasonText = settings['commercial_invoice_export_reason_text'] as String? ?? 'Ware';
        final displayText = (exportReasonText == 'Ware' && language == 'EN') ? 'goods' : exportReasonText;

        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: language == 'EN' ? 'Export Reason: ' : 'Grund des Exports: ',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.TextSpan(
                    text: displayText,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Incoterms
      if (settings['commercial_invoice_incoterms'] == true &&
          settings['commercial_invoice_selected_incoterms'] != null) {

        final incotermIds = List<String>.from(settings['commercial_invoice_selected_incoterms']);
        final freeTexts = Map<String, String>.from(settings['commercial_invoice_incoterms_freetexts'] ?? {});

        if (incotermIds.isNotEmpty) {
          List<pw.InlineSpan> incotermSpans = [
            pw.TextSpan(
              text: 'Incoterm 2020: ',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ];

          for (int i = 0; i < incotermIds.length; i++) {
            final incotermDoc = await FirebaseFirestore.instance
                .collection('incoterms')
                .doc(incotermIds[i])
                .get();

            if (incotermDoc.exists) {
              final incotermData = incotermDoc.data()!;
              final incotermName = incotermData['name'] as String;
              final freeText = freeTexts[incotermIds[i]] ?? '';

              String lineText = incotermName;
              if (freeText.isNotEmpty) {
                lineText += ', $freeText';
              }

              incotermSpans.add(
                pw.TextSpan(
                  text: lineText + (i < incotermIds.length - 1 ? '\n' : ''),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                ),
              );
            }
          }

          textWidgets.add(
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(bottom: 6),
              child: pw.RichText(
                text: pw.TextSpan(children: incotermSpans),
              ),
            ),
          );
        }
      }

      print("check:${settings['commercial_invoice_delivery_date']}");

      // Delivery Date
      if (settings['commercial_invoice_delivery_date'] == true) {
        String dateValue = 'XXX';

        if (settings['commercial_invoice_delivery_date_value'] != null) {
          final rawValue = settings['commercial_invoice_delivery_date_value'];
          final monthOnly = settings['commercial_invoice_delivery_date_month_only'] ?? false;

          DateTime? date;

          // Prüfe, welcher Typ vorliegt und konvertiere falls nötig
          if (rawValue is Timestamp) {
            date = rawValue.toDate();
          } else if (rawValue is DateTime) {
            date = rawValue;
          }

          if (date != null) {
            print("Verarbeitetes Datum: $date");
            if (monthOnly) {
              final months = language == 'EN'
                  ? ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
                  : ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];
              dateValue = '${months[date.month - 1]} ${date.year}';
            } else {
              dateValue = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
            }
          }
        }

        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: language == 'EN' ? 'Delivery Date: ' : 'Lieferdatum: ',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.TextSpan(
                    text: dateValue,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Carrier
      if (settings['commercial_invoice_carrier'] == true) {
        final carrierText = settings['commercial_invoice_carrier_text'] as String? ?? 'Swiss Post';

        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: language == 'EN' ? 'Carrier: ' : 'Transporteur: ',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.TextSpan(
                    text: carrierText,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Origin Declaration (bleibt hervorgehoben)
      if (settings['commercial_invoice_origin_declaration'] == true ||
          settings['origin_declaration'] == true) {
        final originText = AdditionalTextsManager.getTextContent(
            {'selected': true, 'type': 'standard'},
            'origin_declaration',
            language: language
        );

        if (originText.isNotEmpty) {
          textWidgets.add(
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(top: 8, bottom: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(

                border: pw.Border.all(color: PdfColors.blueGrey700, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                originText,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
        }
      }

      // Signature
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
              margin: const pw.EdgeInsets.only(top: 16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    language == 'EN' ? 'Signature:' : 'Signatur:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    signerName,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                  ),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    width: 200,
                    height: 1,
                    color: PdfColors.blueGrey400,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Florinett AG, Tonewood Switzerland',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600),
                  ),
                  pw.SizedBox(height: 8),
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
        margin: const pw.EdgeInsets.only(top: 8),
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
    final sortedItems = await ProductSortingManager.sortProducts(items);

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    for (final item in sortedItems) {
      String tariffNumber = '';

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
      final density = (woodInfo['density'] as num?)?.toDouble() ?? 0;

      // PRIORITÄT 1: Individuelle Zolltarifnummer
      if (item['custom_tariff_number'] != null &&
          (item['custom_tariff_number'] as String).isNotEmpty) {
        tariffNumber = item['custom_tariff_number'] as String;
      } else {
        // PRIORITÄT 2: Standard-Zolltarifnummer aus Datenbank
        final thickness = (item['custom_thickness'] != null)
            ? (item['custom_thickness'] is int
            ? (item['custom_thickness'] as int).toDouble()
            : item['custom_thickness'] as double)
            : 0.0;

        if (thickness <= 6.0) {
          tariffNumber = woodInfo['z_tares_1'] ?? '4408.1000';
        } else {
          tariffNumber = woodInfo['z_tares_2'] ?? '4407.1200';
        }
      }

      // Hole Maße
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
      final unit = item['unit']?.toString().toLowerCase() ?? '';

      // ============ VOLUMEN BERECHNUNG (gleiche Logik wie Packing List) ============
      double totalVolume = 0.0;
      double volumePerPiece = 0.0;

      // 1. Priorität: volume_per_unit aus Item (bereits pro Einheit inkl. aller Teile)
      final volumeFromItem = item['volume_per_unit'];
      if (volumeFromItem != null && (volumeFromItem as num) > 0) {
        volumePerPiece = (volumeFromItem as num).toDouble();
        totalVolume = volumePerPiece * quantity;
      }
      // 2. Priorität: Manuell eingegebenes Volumen
      else if (item['custom_volume'] != null && (item['custom_volume'] as num) > 0) {
        volumePerPiece = (item['custom_volume'] as num).toDouble();
        totalVolume = volumePerPiece * quantity;
      }
      // 3. Priorität: Berechnetes Volumen aus Maßen
      else if (length > 0 && width > 0 && thicknessValue > 0) {
        volumePerPiece = (length / 1000) * (width / 1000) * (thicknessValue / 1000);
        totalVolume = volumePerPiece * quantity;
      }
      // 4. Priorität: Standardvolumen aus der Datenbank
      else {
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
              final mm3Volume = standardProduct['volume_per_unit']?['mm3_standard'];
              final dm3Volume = standardProduct['volume_per_unit']?['dm3_standard'];

              if (mm3Volume != null && mm3Volume > 0) {
                volumePerPiece = (mm3Volume / 1000000000.0); // mm³ zu m³
              } else if (dm3Volume != null && dm3Volume > 0) {
                volumePerPiece = (dm3Volume / 1000.0); // dm³ zu m³
              }

              totalVolume = volumePerPiece * quantity;
            }
          } catch (e) {
            print('Fehler beim Laden des Standard-Volumens: $e');
          }
        }
      }

      // ============ GEWICHT BERECHNUNG (gleiche Logik wie Packing List) ============
      double weight = 0.0;

      if (unit == 'kg') {
        // Wenn Einheit kg ist, ist quantity bereits das Gesamtgewicht
        weight = quantity;
        // Volumen aus Gewicht und Dichte berechnen (falls noch nicht gesetzt)
        if (totalVolume == 0 && density > 0) {
          totalVolume = weight / density;
        }
      } else {
        // Standard-Berechnung: Gewicht = Volumen × Dichte
        if (totalVolume > 0 && density > 0) {
          weight = totalVolume * density;
        } else {
          // Fallback auf custom_weight
          weight = (item['custom_weight'] as num?)?.toDouble() ?? 0.0;
        }
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
      enhancedItem['wood_display_name'] = '$woodName\n($woodNameLatin)';
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

  /// Fasst Items mit gleicher product_id zusammen (addiert Mengen)
  static List<Map<String, dynamic>> _consolidateItems(List<Map<String, dynamic>> items) {
    final Map<String, Map<String, dynamic>> consolidated = {};

    for (final item in items) {
      final productId = item['product_id']?.toString() ?? '';

      if (productId.isEmpty) {
        // Ohne product_id: als einzelnes Item behalten
        consolidated[DateTime.now().microsecondsSinceEpoch.toString()] = Map<String, dynamic>.from(item);
        continue;
      }

      if (consolidated.containsKey(productId)) {
        // Existiert bereits: Menge addieren
        final existing = consolidated[productId]!;
        final existingQty = (existing['quantity'] as num? ?? 0).toDouble();
        final newQty = (item['quantity'] as num? ?? 0).toDouble();
        existing['quantity'] = existingQty + newQty;
      } else {
        // Neues Item
        consolidated[productId] = Map<String, dynamic>.from(item);
      }
    }

    return consolidated.values.toList();
  }


  /// Berechnet optimale Spaltenbreiten basierend auf Inhalt
  static Map<int, pw.FlexColumnWidth> _calculateOptimalColumnWidths(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String language,
      ) {
    const double charWidth = 0.18;

    int maxTariffLen = language == 'EN' ? 10 : 9;
    int maxProductLen = language == 'EN' ? 7 : 7;
    int maxInstrLen = 10;
    int maxQualLen = language == 'EN' ? 8 : 10;
    int maxFscLen = 4;

    groupedItems.forEach((groupKey, items) {
      // Zolltarifnummer aus groupKey extrahieren
      final parts = groupKey.split(' - ');
      final tariffNumber = parts[0];
      if (tariffNumber.length > maxTariffLen) maxTariffLen = tariffNumber.length;

      for (final item in items) {
        String productText = language == 'EN'
            ? (item['part_name_en'] ?? item['part_name'] ?? '')
            : (item['part_name'] ?? '');
        if (item['is_gratisartikel'] == true) productText += '  GRATIS';
        if (item['is_online_shop_item'] == true) productText += '  #0000';
        if (productText.length > maxProductLen) maxProductLen = productText.length;

        String instrText = language == 'EN'
            ? (item['instrument_name_en'] ?? item['instrument_name'] ?? '')
            : (item['instrument_name'] ?? '');
        if (instrText.length > maxInstrLen) maxInstrLen = instrText.length;

        String qualText = item['quality_name'] ?? '';
        if (qualText.length > maxQualLen) maxQualLen = qualText.length;

        String fscText = item['fsc_status'] ?? '';
        if (fscText.length > maxFscLen) maxFscLen = fscText.length;
      }
    });

    double tariffWidth = (maxTariffLen * charWidth).clamp(1.8, 2.5);
    double productWidth = (maxProductLen * charWidth).clamp(2.0, 3.5);
    double instrWidth = (maxInstrLen * charWidth).clamp(1.8, 2.5);
    double qualWidth = (maxQualLen * charWidth).clamp(1.5, 2.0);
    double fscWidth = (maxFscLen * charWidth).clamp(1.2, 1.8);

    return {
      0: pw.FlexColumnWidth(tariffWidth),   // Zolltarif
      1: pw.FlexColumnWidth(productWidth),  // Produkt
      2: pw.FlexColumnWidth(instrWidth),    // Instr.
      3: pw.FlexColumnWidth(qualWidth),     // Qual.
      4: pw.FlexColumnWidth(fscWidth),      // FSC
      5: const pw.FlexColumnWidth(1.1),     // Urs
      6: const pw.FlexColumnWidth(1.5),     // m³
      7: const pw.FlexColumnWidth(1.5),     // Menge
      8: const pw.FlexColumnWidth(1.8),     // Einh
      9: const pw.FlexColumnWidth(2.0),     // Preis/E
      10: const pw.FlexColumnWidth(2.0),    // Netto Gesamt
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NEU: Service-Tabelle mit variablen Spaltenausrichtungen
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildServiceTable(
      List<Map<String, dynamic>> serviceItems,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      Map<String, String> columnAlignments) {

    if (serviceItems.isEmpty) return pw.SizedBox.shrink();

    final List<pw.TableRow> rows = [];

    // NEU: Ausrichtungen holen
    final tariffAlign = _getTextAlign(columnAlignments['tariff'] ?? 'left');
    final productAlign = _getTextAlign(columnAlignments['product'] ?? 'left');
    final descriptionAlign = _getTextAlign(columnAlignments['description'] ?? 'left');
    final qtyAlign = _getTextAlign(columnAlignments['quantity'] ?? 'right');
    final unitAlign = _getTextAlign(columnAlignments['unit'] ?? 'center');
    final priceAlign = _getTextAlign(columnAlignments['price_per_unit'] ?? 'right');
    final netTotalAlign = _getTextAlign(columnAlignments['net_total'] ?? 'right');

    // Header für Dienstleistungen
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Tariff No.' : 'Zolltarif', 8, align: tariffAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Service' : 'Dienstleistung', 8, align: productAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Description' : 'Beschreibung', 8, align: descriptionAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Anz.', 8, align: qtyAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Unit' : 'Einh', 8, align: unitAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: priceAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: netTotalAlign),
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

      // Zolltarifnummer holen
      final tariffNumber = service['custom_tariff_number'] as String? ?? '-';

      rows.add(
        pw.TableRow(
          children: [
            // Zolltarifnummer in erster Spalte
            BasePdfGenerator.buildContentCell(
              pw.Text(
                tariffNumber,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: tariffAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                language == 'EN'
                    ? (service['name_en']?.isNotEmpty == true ? service['name_en'] : service['name'] ?? 'Unnamed Service')
                    : (service['name'] ?? 'Unbenannte Dienstleistung'),
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: productAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                language == 'EN'
                    ? (service['description_en']?.isNotEmpty == true ? service['description_en'] : service['description'] ?? '')
                    : (service['description'] ?? ''),
                style: const pw.TextStyle(fontSize: 8),
                textAlign: descriptionAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                quantity.toStringAsFixed(0),
                style: const pw.TextStyle(fontSize: 8),
                textAlign: qtyAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                language == 'EN' ? 'pcs' : 'Stk',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: unitAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatAmountOnly(pricePerUnit, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 8),
                textAlign: priceAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                BasePdfGenerator.formatAmountOnly(total, currency, exchangeRates),
                style: const pw.TextStyle(fontSize: 8),
                textAlign: netTotalAlign,
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
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              BasePdfGenerator.formatAmountOnly(totalAmount, currency, exchangeRates),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: netTotalAlign,
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
            0: const pw.FlexColumnWidth(2),    // Zolltarif (erste Spalte)
            1: const pw.FlexColumnWidth(3),    // Dienstleistung
            2: const pw.FlexColumnWidth(4),    // Beschreibung
            3: const pw.FlexColumnWidth(1),    // Anzahl
            4: const pw.FlexColumnWidth(1),    // Einheit
            5: const pw.FlexColumnWidth(2),    // Preis/E
            6: const pw.FlexColumnWidth(2),    // Netto Gesamt
          },
          children: rows,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NEU: Produkt-Tabelle mit variablen Spaltenausrichtungen
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _buildProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      Map<String, dynamic>? taraSettings,
      Map<String, String> columnAlignments) {

    final List<pw.TableRow> rows = [];
    double totalVolume = 0.0;
    double totalWeight = 0.0;

    // NEU: Ausrichtungen holen
    final tariffAlign = _getTextAlign(columnAlignments['tariff'] ?? 'left');
    final productAlign = _getTextAlign(columnAlignments['product'] ?? 'left');
    final instrumentAlign = _getTextAlign(columnAlignments['instrument'] ?? 'left');
    final qualityAlign = _getTextAlign(columnAlignments['quality'] ?? 'left');
    final fscAlign = _getTextAlign(columnAlignments['fsc'] ?? 'left');
    final originAlign = _getTextAlign(columnAlignments['origin'] ?? 'left');
    final volumeAlign = _getTextAlign(columnAlignments['volume'] ?? 'right');
    final qtyAlign = _getTextAlign(columnAlignments['quantity'] ?? 'right');
    final unitAlign = _getTextAlign(columnAlignments['unit'] ?? 'center');
    final priceAlign = _getTextAlign(columnAlignments['price_per_unit'] ?? 'right');
    final netTotalAlign = _getTextAlign(columnAlignments['net_total'] ?? 'right');

    // Header-Zeile mit m³ statt Masse
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Tariff No.' : 'Zolltarif', 8, align: tariffAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Product' : 'Produkt', 8, align: productAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Instrument' : 'Instrument', 8, align: instrumentAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Quality' : 'Qualität', 8, align: qualityAlign),
          BasePdfGenerator.buildHeaderCell('FSC®', 8, align: fscAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Orig' : 'Urs', 8, align: originAlign),
          BasePdfGenerator.buildHeaderCell('m³', 8, align: volumeAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Menge', 8, align: qtyAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Unit' : 'Einh', 8, align: unitAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 8, align: priceAlign),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Net Total' : 'Netto Gesamt', 8, align: netTotalAlign),
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
                textAlign: tariffAlign,
              ),
            ),
            // Holzart-Beschreibung über mehrere Spalten
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(
                woodDescription,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            // Leere Zellen
            ...List.generate(4, (index) => pw.SizedBox(height: 16)),
            // Zwischensumme m³
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
                  fontSize: 8,
                  color: PdfColors.blueGrey800,
                ),
                textAlign: volumeAlign,
              ),
            ),
            // Restliche leere Zellen
            ...List.generate(4, (index) => pw.SizedBox(height: 16)),
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
                pw.Text('', style: const pw.TextStyle(fontSize: 8)), // Zolltarifnummer nur im Header
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: productAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  language == 'EN' ? item['instrument_name_en'] : item['instrument_name'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: instrumentAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  item['quality_name'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: qualityAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  item['fsc_status'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: fscAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  'CH',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: originAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  volumeM3 > 0 ? volumeM3.toStringAsFixed(5) : '', // Leer wenn 0
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: volumeAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  quantity.toStringAsFixed(3),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: qtyAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  unit,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: unitAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatAmountOnly(pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: priceAlign,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  BasePdfGenerator.formatAmountOnly(itemTotal, currency, exchangeRates),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: discountAmount > 0 ? pw.FontWeight.bold : null,
                  ),
                  textAlign: netTotalAlign,
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
    final packagingVolume= (taraSettings?['packaging_volume'] ?? 0.0) as double;
    final totalGrossWeight = totalWeight + packagingWeight;
    final totalGrossVolume = totalVolume + packagingVolume;

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
                  ? 'Net\nVolume'
                  : 'Netto-\nKubatur',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
          // Total m³
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              totalVolume.toStringAsFixed(5),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: volumeAlign,
            ),
          ),
          ...List.generate(1, (index) => pw.SizedBox()),
          // Total Gewicht
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${totalWeight.toStringAsFixed(2)} kg',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: unitAlign,
            ),
          ),
          ...List.generate(1, (index) => pw.SizedBox()),
          // Gesamtbetrag
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              BasePdfGenerator.formatAmountOnly(totalAmount, currency, exchangeRates),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: netTotalAlign,
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
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN'
                  ? 'Packaging: $numberOfPackages'
                  : 'Packungen: $numberOfPackages',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          ...List.generate(4, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${packagingVolume.toStringAsFixed(5)}',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: volumeAlign,
            ),
          ),
          ...List.generate(1, (index) => pw.SizedBox()),

          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${packagingWeight.toStringAsFixed(2)} kg',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: unitAlign,
            ),
          ),
          ...List.generate(2, (index) => pw.SizedBox()),
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
                  ? 'Gross\nVolume'
                  : 'Brutto-\nKubatur',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              totalGrossVolume.toStringAsFixed(5),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: volumeAlign,
            ),
          ),
          ...List.generate(1, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${totalGrossWeight.toStringAsFixed(2)} kg',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: unitAlign,
            ),
          ),
          ...List.generate(2, (index) => pw.SizedBox()),
        ],
      ),
    );

    // Optimierte Spaltenbreiten basierend auf Inhalt
    final columnWidths = _calculateOptimalColumnWidths(
      groupedItems,
      language,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: columnWidths,
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

  static Future<pw.Widget> _addInlineAdditionalTexts(String language) async {
    try {
      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();
      final List<pw.Widget> textWidgets = [];

      // Legend
      if (additionalTexts['legend']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['legend'],
                  'legend',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
            ),
          ),
        );
      }

      // FSC
      if (additionalTexts['fsc']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['fsc'],
                  'fsc',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
            ),
          ),
        );
      }

      // Natural Product
      if (additionalTexts['natural_product']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['natural_product'],
                  'natural_product',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
            ),
          ),
        );
      }

      // Free Text
      if (additionalTexts['free_text']?['selected'] == true) {
        textWidgets.add(
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              AdditionalTextsManager.getTextContent(
                  additionalTexts['free_text'],
                  'free_text',
                  language: language
              ),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
            ),
          ),
        );
      }

      if (textWidgets.isEmpty) {
        return pw.SizedBox.shrink();
      }

      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        margin: const pw.EdgeInsets.only(top: 12, bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
        ),
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