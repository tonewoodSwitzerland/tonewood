import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_pdf_generator.dart';
import '../additional_text_manager.dart';
import '../../components/order_model.dart';

class CombinedCommercialInvoiceGenerator {
  static Future<Uint8List> generatePdf({
    required String shipmentNumber,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, String> orderReferences,
    required List<OrderX> orders,
    required Map<String, dynamic> settings,
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    // Bestimme gemeinsame Sprache und Währung
    final language = orders.first.customer['language'] ?? 'DE';
    final currency = orders.first.metadata?['currency'] ?? 'CHF';
    final exchangeRates = Map<String, double>.from(orders.first.metadata?['exchangeRates'] ?? {'CHF': 1.0});

    // Gruppiere Items nach Zolltarifnummer
    final productItems = items.where((item) => item['is_service'] != true).toList();
    final groupedProductItems = await _groupItemsByTariffNumberAndOrder(productItems, language);

    // Lade Zusatztexte
    final additionalTextsWidget = await _addInlineAdditionalTexts(language);
    final standardTextsWidget = await _addCommercialInvoiceStandardTexts(language, taraSettings: settings);

    // Sammle alle Rechnungsnummern
    final invoiceNumbers = orders.map((o) => o.orderNumber).join(', ');

    // Berechne Gesamtwert
    double totalAmount = 0.0;
    for (final order in orders) {
      totalAmount += (order.calculations['total'] as num? ?? 0).toDouble();
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Header
          _buildCombinedHeader(
            documentTitle: language == 'EN' ? 'COMBINED COMMERCIAL INVOICE' : 'SAMMEL-HANDELSRECHNUNG',
            documentNumber: shipmentNumber,
            date: DateTime.now(),
            logo: logo,
            language: language,
            invoiceNumbers: invoiceNumbers,
          ),
          pw.SizedBox(height: 20),

          // Lieferadresse
          BasePdfGenerator.buildCustomerAddress(customerData, 'commercial_invoice', language: language),

          pw.SizedBox(height: 15),

          // Info-Box mit Aufträgen und Währungshinweis
          _buildCombinedInfoBox(orders, language, currency, exchangeRates),

          pw.SizedBox(height: 15),

          // Produkttabelle mit Zolltarifnummer-Gruppierung
          _buildCombinedProductTable(
            groupedProductItems,
            currency,
            exchangeRates,
            language,
            settings,
            orderReferences,
          ),

          // Dienstleistungen (falls vorhanden)
          if (items.any((item) => item['is_service'] == true)) ...[
            pw.SizedBox(height: 20),
            _buildServicesSummary(items, orders, currency, exchangeRates, language),
          ],

          // Gesamtsumme
          _buildTotalSection(totalAmount, currency, exchangeRates, language),

          pw.SizedBox(height: 10),

          // Zusatztexte
          additionalTextsWidget,
          standardTextsWidget,

          // Footer
          BasePdfGenerator.buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  // Angepasster Header
  static pw.Widget _buildCombinedHeader({
    required String documentTitle,
    required String documentNumber,
    required DateTime date,
    required pw.MemoryImage? logo,
    required String language,
    required String invoiceNumbers,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Logo
        if (logo != null)
          pw.Container(
            width: 150,
            height: 80,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),

        // Dokumentinfo
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                documentTitle,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                language == 'EN' ? 'Number: $documentNumber' : 'Nummer: $documentNumber',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                language == 'EN' ? 'Date: ${DateFormat('dd.MM.yyyy').format(date)}' : 'Datum: ${DateFormat('dd.MM.yyyy').format(date)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      language == 'EN' ? 'Invoice Numbers:' : 'Rechnungsnummern:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                    pw.Text(
                      invoiceNumbers,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.amber900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Info-Box mit Details
  static pw.Widget _buildCombinedInfoBox(
      List<OrderX> orders,
      String language,
      String currency,
      Map<String, double> exchangeRates,
      ) {
    return pw.Column(
      children: [
        // Währungshinweis (falls nicht CHF)
        if (currency != 'CHF')
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
            ),
            child: pw.Text(
              language == 'EN'
                  ? 'All prices in $currency (Exchange rate: 1 CHF = ${exchangeRates[currency]?.toStringAsFixed(4) ?? "1.0000"} $currency)'
                  : 'Alle Preise in $currency (Umrechnungskurs: 1 CHF = ${exchangeRates[currency]?.toStringAsFixed(4) ?? "1.0000"} $currency)',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.amber900),
            ),
          ),

        // Auftragsübersicht
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                language == 'EN'
                    ? 'This commercial invoice covers the following invoices:'
                    : 'Diese Handelsrechnung umfasst folgende Rechnungen:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(80),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(80),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          language == 'EN' ? 'Invoice No.' : 'Rechnung Nr.',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          language == 'EN' ? 'Customer' : 'Kunde',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          language == 'EN' ? 'Amount' : 'Betrag',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Daten
                  ...orders.map((order) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          order.orderNumber,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          order.customer['company'] ?? order.customer['fullName'] ?? '',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          '$currency ${_convertPrice((order.calculations['total'] as num).toDouble(), currency, exchangeRates).toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  )).toList(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Gruppiere Items nach Zolltarifnummer und Order
  static Future<Map<String, List<Map<String, dynamic>>>> _groupItemsByTariffNumberAndOrder(
      List<Map<String, dynamic>> items,
      String language
      ) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    for (final item in items) {
      final woodCode = item['wood_code'] as String? ?? '';

      // Lade Holzart-Info
      if (!woodTypeCache.containsKey(woodCode) && woodCode.isNotEmpty) {
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

      final woodInfo = woodTypeCache[woodCode] ?? {};

      // Hole Dichte
      final density = (woodInfo['density'] as num?)?.toDouble() ?? 0;

      // Bestimme Zolltarifnummer
      final thickness = (item['custom_thickness'] as num?)?.toDouble() ?? 0.0;
      String tariffNumber = '';

      if (thickness <= 6.0) {
        tariffNumber = woodInfo['z_tares_1'] ?? '4408.1000';
      } else {
        tariffNumber = woodInfo['z_tares_2'] ?? '4407.1200';
      }

      // Berechne Volumen und Gewicht
      final length = (item['custom_length'] as num?)?.toDouble() ?? 0.0;
      final width = (item['custom_width'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;

      double totalVolume = 0.0;
      if (length > 0 && width > 0 && thickness > 0) {
        final volumePerPiece = (length / 1000) * (width / 1000) * (thickness / 1000);
        totalVolume = volumePerPiece * quantity;
      }

      double weight = 0.0;
      if (item['unit']?.toString().toLowerCase() == 'kg') {
        weight = quantity;
      } else if (totalVolume > 0) {
        weight = totalVolume * density;
      }

      final woodName = language == 'EN'
          ? (woodInfo['name_english'] ?? woodInfo['name'] ?? item['wood_name'] ?? 'Unknown wood type')
          : (woodInfo['name'] ?? item['wood_name'] ?? 'Unbekannte Holzart');
      final woodNameLatin = woodInfo['name_latin'] ?? '';

      final groupKey = '$tariffNumber - $woodName ($woodNameLatin)';

      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }

      // Füge erweiterte Infos hinzu
      final enhancedItem = Map<String, dynamic>.from(item);
      enhancedItem['tariff_number'] = tariffNumber;
      enhancedItem['wood_display_name'] = '$woodName ($woodNameLatin)';
      enhancedItem['wood_name_latin'] = woodNameLatin;
      enhancedItem['volume_m3'] = totalVolume;
      enhancedItem['weight_kg'] = weight;
      enhancedItem['density'] = density;

      grouped[groupKey]!.add(enhancedItem);
    }

    return grouped;
  }

  // Produkttabelle mit Rechnungsnummer-Spalte
  static pw.Widget _buildCombinedProductTable(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      Map<String, dynamic>? taraSettings,
      Map<String, String> orderReferences,
      ) {
    final List<pw.TableRow> rows = [];
    double totalVolume = 0.0;
    double totalWeight = 0.0;
    double totalAmount = 0.0;

    // Header
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Invoice' : 'Rechnung', 7),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Tariff No.' : 'Zolltarif', 7),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Product' : 'Produkt', 7),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Instrument' : 'Instrument', 7),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qual.' : 'Qual.', 7),
          BasePdfGenerator.buildHeaderCell('FSC®', 7),
          BasePdfGenerator.buildHeaderCell('m³', 7),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Qty' : 'Menge', 7, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Unit' : 'Einh', 7),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Price/U' : 'Preis/E', 7, align: pw.TextAlign.right),
          BasePdfGenerator.buildHeaderCell(
              language == 'EN' ? 'Total' : 'Betrag', 7, align: pw.TextAlign.right),
        ],
      ),
    );

    // Für jede Zolltarifnummer-Gruppe
    groupedItems.forEach((groupKey, items) {
      final parts = groupKey.split(' - ');
      final tariffNumber = parts[0];
      final woodDescription = parts.length > 1 ? parts[1] : '';

      // Berechne Zwischensummen für diese Gruppe
      double groupVolume = 0.0;
      double groupWeight = 0.0;
      for (final item in items) {
        groupVolume += (item['volume_m3'] as num?)?.toDouble() ?? 0.0;
        groupWeight += (item['weight_kg'] as num?)?.toDouble() ?? 0.0;
      }
      totalVolume += groupVolume;
      totalWeight += groupWeight;

      // Zolltarifnummer-Header
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.SizedBox(),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(
                tariffNumber,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7,
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(
                woodDescription,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 6,
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            ...List.generate(3, (index) => pw.SizedBox()),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(
                groupVolume > 0 ? groupVolume.toStringAsFixed(5) : '',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 6,
                  color: PdfColors.blueGrey800,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            ...List.generate(4, (index) => pw.SizedBox()),
          ],
        ),
      );

      // Items sortiert nach Rechnungsnummer
      items.sort((a, b) => (a['_invoice_number'] ?? '').compareTo(b['_invoice_number'] ?? ''));

      for (final item in items) {
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        final pricePerUnit = (item['price_per_unit'] as num? ?? 0).toDouble();
        final itemTotal = quantity * pricePerUnit;
        totalAmount += itemTotal;

        final volumeM3 = (item['volume_m3'] as double? ?? 0.0);
        String unit = item['unit'] ?? '';
        if (unit.toLowerCase() == 'stück') unit = 'Stk';

        rows.add(
          pw.TableRow(
            children: [
              // Rechnungsnummer
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  item['_invoice_number'] ?? '',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text('', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(language == 'EN' ? item['part_name_en'] : item['part_name'] ?? '',
                    style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(language == 'EN' ? item['instrument_name_en'] : item['instrument_name'] ?? '',
                    style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['quality_name'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(item['fsc_status'] ?? '', style: const pw.TextStyle(fontSize: 6)),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  volumeM3 > 0 ? volumeM3.toStringAsFixed(5) : '',
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
                  _formatCurrency(pricePerUnit, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              BasePdfGenerator.buildContentCell(
                pw.Text(
                  _formatCurrency(itemTotal, currency, exchangeRates),
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }
    });

    // Netto-Zeile
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
              language == 'EN' ? 'Net Volume' : 'Netto-Kubatur',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
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
              '${totalWeight.toStringAsFixed(2)} kg',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
              textAlign: pw.TextAlign.center,
            ),
          ),
          ...List.generate(2, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              _formatCurrency(totalAmount, currency, exchangeRates),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );

    // Tara und Brutto
    final numberOfPackages = taraSettings?['number_of_packages'] ?? 1;
    final packagingWeight = (taraSettings?['packaging_weight'] ?? 0.0) as double;
    final totalGrossWeight = totalWeight + packagingWeight;

    // Tara-Zeile
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.amber50),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN' ? 'Tare' : 'Tara',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              language == 'EN' ? 'Packaging: $numberOfPackages' : 'Packungen: $numberOfPackages',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '${packagingWeight.toStringAsFixed(2)} kg',
              style: const pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
          ),
          ...List.generate(3, (index) => pw.SizedBox()),
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
              language == 'EN' ? 'Gross Volume' : 'Brutto-Kubatur',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          ...List.generate(5, (index) => pw.SizedBox()),
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
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
              textAlign: pw.TextAlign.center,
            ),
          ),
          ...List.generate(3, (index) => pw.SizedBox()),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),      // Rechnung
        1: const pw.FlexColumnWidth(2),      // Zolltarif
        2: const pw.FlexColumnWidth(2.5),    // Produkt
        3: const pw.FlexColumnWidth(2),      // Instr.
        4: const pw.FlexColumnWidth(1.5),    // Qual.
        5: const pw.FlexColumnWidth(1),      // FSC
        6: const pw.FlexColumnWidth(1.5),    // m³
        7: const pw.FlexColumnWidth(1.5),    // Menge
        8: const pw.FlexColumnWidth(1),      // Einh
        9: const pw.FlexColumnWidth(2),      // Preis/E
        10: const pw.FlexColumnWidth(2),     // Betrag
      },
      children: rows,
    );
  }

  // Dienstleistungs-Zusammenfassung
  static pw.Widget _buildServicesSummary(
      List<Map<String, dynamic>> allItems,
      List<OrderX> orders,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      ) {
    final serviceItems = allItems.where((item) => item['is_service'] == true).toList();
    if (serviceItems.isEmpty) return pw.SizedBox.shrink();

    // Gruppiere Dienstleistungen nach Rechnung
    final Map<String, List<Map<String, dynamic>>> servicesByInvoice = {};
    for (final service in serviceItems) {
      final invoiceNumber = service['_invoice_number'] ?? '';
      if (!servicesByInvoice.containsKey(invoiceNumber)) {
        servicesByInvoice[invoiceNumber] = [];
      }
      servicesByInvoice[invoiceNumber]!.add(service);
    }

    double totalServices = 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          language == 'EN' ? 'Services' : 'Dienstleistungen',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ...servicesByInvoice.entries.map((entry) {
                final invoiceNumber = entry.key;
                final services = entry.value;
                double invoiceServiceTotal = 0.0;

                for (final service in services) {
                  final quantity = (service['quantity'] as num? ?? 0).toDouble();
                  final pricePerUnit = (service['price_per_unit'] as num? ?? 0).toDouble();
                  invoiceServiceTotal += quantity * pricePerUnit;
                }
                totalServices += invoiceServiceTotal;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${language == 'EN' ? 'Invoice' : 'Rechnung'} $invoiceNumber - ${services.length} ${language == 'EN' ? 'Service(s)' : 'Dienstleistung(en)'}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        '$currency ${_convertPrice(invoiceServiceTotal, currency, exchangeRates).toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    language == 'EN' ? 'Services Total' : 'Dienstleistungen Gesamt',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '$currency ${_convertPrice(totalServices, currency, exchangeRates).toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Gesamtsummen-Sektion
  static pw.Widget _buildTotalSection(
      double totalAmount,
      String currency,
      Map<String, double> exchangeRates,
      String language,
      ) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Container(
        width: 300,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.green50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColors.green200, width: 1),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              language == 'EN' ? 'TOTAL AMOUNT' : 'GESAMTBETRAG',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.Text(
              '$currency ${_convertPrice(totalAmount, currency, exchangeRates).toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hilfsfunktionen
  static double _convertPrice(double priceInCHF, String currency, Map<String, double> exchangeRates) {
    if (currency == 'CHF') return priceInCHF;
    final rate = exchangeRates[currency] ?? 1.0;
    return priceInCHF * rate;
  }

  static String _formatCurrency(double amount, String currency, Map<String, double> exchangeRates) {
    final converted = _convertPrice(amount, currency, exchangeRates);
    return converted.toStringAsFixed(2);
  }

  // Kopiere die Zusatztext-Methoden aus dem normalen Generator
  static Future<pw.Widget> _addInlineAdditionalTexts(String language) async {
    // Gleicher Code wie im normalen CommercialInvoiceGenerator
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

      // Weitere Texte analog...

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

  static Future<pw.Widget> _addCommercialInvoiceStandardTexts(
      String language,
      {Map<String, dynamic>? taraSettings}
      ) async {
    // Gleicher Code wie im normalen CommercialInvoiceGenerator
    // aber ohne orderId Parameter
    try {
      await AdditionalTextsManager.loadDefaultTextsFromFirebase();

      Map<String, dynamic> settings = taraSettings ?? {};
      final List<pw.Widget> textWidgets = [];

      // Standardtexte verarbeiten...

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
      print('Fehler beim Laden der Standardtexte: $e');
      return pw.SizedBox.shrink();
    }
  }
}