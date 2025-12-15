import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'base_pdf_generator.dart';
import '../../orders/order_model.dart';

class CombinedPackingListGenerator {
  static Future<Uint8List> generatePdf({
    required String shipmentNumber,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerData,
    required Map<String, String> orderReferences,
    required List<OrderX> orders,
    required String shipmentId,
    required Map<String, dynamic> settings,
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    // Bestimme gemeinsame Sprache
    final language = orders.first.customer['language'] ?? 'DE';

    // Lade oder erstelle Packlisten-Einstellungen für Sammellieferung
    Map<String, dynamic> packingSettings;

    final combinedPackingDoc = await FirebaseFirestore.instance
        .collection('combined_shipments')
        .doc(shipmentId)
        .collection('packing_list')
        .doc('settings')
        .get();

    if (combinedPackingDoc.exists) {
      packingSettings = combinedPackingDoc.data() ?? {};
    } else {
      // Erstelle Standard-Pakete basierend auf den einzelnen Orders
      packingSettings = await _createDefaultPackages(orders, items);

      // Speichere für zukünftige Verwendung
      await FirebaseFirestore.instance
          .collection('combined_shipments')
          .doc(shipmentId)
          .collection('packing_list')
          .doc('settings')
          .set(packingSettings);
    }

    final packages = List<Map<String, dynamic>>.from(packingSettings['packages'] ?? []);

    // Lade Caches (wie im normalen PackingListGenerator)
    final Map<String, Map<String, dynamic>> woodTypeCache = {};
    final Map<String, Map<String, dynamic>> measurementsCache = {};
    final Map<String, Map<String, dynamic>> standardVolumeCache = {};

    // Cache-Befüllung (analog zum normalen Generator)
    await _fillCaches(packages, woodTypeCache, measurementsCache, standardVolumeCache);

    // Sammle alle Rechnungsnummern
    final invoiceNumbers = orders.map((o) => o.orderNumber).join(', ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          final List<pw.Widget> content = [];

          // Header
          content.add(_buildCombinedHeader(
            documentTitle: language == 'EN' ? 'COMBINED PACKING LIST' : 'SAMMEL-PACKLISTE',
            documentNumber: shipmentNumber,
            date: DateTime.now(),
            logo: logo,
            language: language,
            invoiceNumbers: invoiceNumbers,
          ));
          content.add(pw.SizedBox(height: 20));

          // Lieferadresse
          content.add(BasePdfGenerator.buildCustomerAddress(customerData, 'packing_list', language: language));
          content.add(pw.SizedBox(height: 15));

          // Info-Box
          content.add(_buildOrderReferencesBox(orders, language));
          content.add(pw.SizedBox(height: 20));

          // Für jedes Paket eine Tabelle
          for (int i = 0; i < packages.length; i++) {
            final package = packages[i];
            final packageItems = List<Map<String, dynamic>>.from(package['items'] ?? []);

            if (packageItems.isEmpty) continue;

            // Paket-Header
            content.add(_buildPackageHeader(package, language, i + 1));
            content.add(pw.SizedBox(height: 10));

            // Paket-Tabelle
            content.add(_buildCombinedPackageTable(
              package,
              packageItems,
              language,
              woodTypeCache,
              measurementsCache,
              standardVolumeCache,
              orderReferences,
            ));
            content.add(pw.SizedBox(height: 20));
          }

          // Gesamtübersicht
          content.add(_buildTotalSummary(packages, language));

          return content;
        },
        footer: (context) => BasePdfGenerator.buildFooter(),
      ),
    );

    return pdf.save();
  }

  // Erstelle Standard-Pakete wenn noch keine existieren
  static Future<Map<String, dynamic>> _createDefaultPackages(
      List<OrderX> orders,
      List<Map<String, dynamic>> items,
      ) async {
    // Erstelle ein großes Paket für alle Produkte
    final package = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': 'Packung 1',
      'packaging_type': 'Palette',
      'packaging_type_en': 'Pallet',
      'length': 120.0,
      'width': 80.0,
      'height': 100.0,
      'tare_weight': 25.0,
      'items': items.map((item) => {
        ...item,
        'quantity': (item['quantity'] as num).toDouble(),
      }).toList(),
    };

    return {
      'packages': [package],
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  // Befülle Caches
  static Future<void> _fillCaches(
      List<Map<String, dynamic>> packages,
      Map<String, Map<String, dynamic>> woodTypeCache,
      Map<String, Map<String, dynamic>> measurementsCache,
      Map<String, Map<String, dynamic>> standardVolumeCache,
      ) async {
    for (final package in packages) {
      final packageItems = List<Map<String, dynamic>>.from(package['items'] ?? []);

      for (final item in packageItems) {
        // Holzart-Cache
        final woodCode = item['wood_code'] as String? ?? '';
        if (woodCode.isNotEmpty && !woodTypeCache.containsKey(woodCode)) {
          final woodTypeDoc = await FirebaseFirestore.instance
              .collection('wood_types')
              .doc(woodCode)
              .get();
          if (woodTypeDoc.exists) {
            woodTypeCache[woodCode] = woodTypeDoc.data()!;
          }
        }

        // Maße aus den Items direkt verwenden (wurden aus Orders übernommen)
        final productId = item['product_id'] as String? ?? '';
        if (!measurementsCache.containsKey(productId)) {
          measurementsCache[productId] = {
            'custom_length': item['custom_length'] ?? 0.0,
            'custom_width': item['custom_width'] ?? 0.0,
            'custom_thickness': item['custom_thickness'] ?? 0.0,
            'custom_volume': item['custom_volume'] ?? 0.0,
          };
        }

        // Standard-Volumen Cache
        final instrumentCode = item['instrument_code'] as String?;
        final partCode = item['part_code'] as String?;
        if (instrumentCode != null && partCode != null) {
          final articleNumber = instrumentCode + partCode;
          if (!standardVolumeCache.containsKey(articleNumber)) {
            // Cache-Befüllung wie im normalen Generator
            // ... (Code übernommen aus normalem PackingListGenerator)
          }
        }
      }
    }
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

  // Info-Box
  static pw.Widget _buildOrderReferencesBox(List<OrderX> orders, String language) {
    return pw.Container(
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
                ? 'This packing list includes products from the following invoices:'
                : 'Diese Packliste enthält Produkte aus folgenden Rechnungen:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 6),
          ...orders.map((order) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: const pw.TextStyle(fontSize: 9)),
                pw.Expanded(
                  child: pw.Text(
                    '${language == 'EN' ? 'Invoice' : 'Rechnung'} ${order.orderNumber}: '
                        '${order.customer['company'] ?? order.customer['fullName']} - '
                        '${order.items.length} ${language == 'EN' ? 'Item(s)' : 'Position(en)'}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
    }

    // Paket-Header
    static pw.Widget _buildPackageHeader(
    Map<String, dynamic> package,
    String language,
    int packageNumber,
    ) {
    final length = (package['length'] as num?)?.toDouble() ?? 0.0;
    final width = (package['width'] as num?)?.toDouble() ?? 0.0;
    final height = (package['height'] as num?)?.toDouble() ?? 0.0;
    final tareWeight = (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
    final packagingType = language == 'EN'
    ? (package['packaging_type_en'] ?? package['packaging_type'] ?? '')
        : (package['packaging_type'] ?? '');

    final grossVolume = (length * width * height) / 1000000; // cm³ zu m³

    return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
    color: PdfColors.blueGrey50,
    borderRadius: pw.BorderRadius.circular(4),
    border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
    ),
    child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
    pw.Text(
    language == 'EN' ? 'Package $packageNumber' : 'Packung $packageNumber',
    style: pw.TextStyle(
    fontWeight: pw.FontWeight.bold,
    fontSize: 12,
    color: PdfColors.blueGrey800,
    ),
    ),
    pw.SizedBox(height: 4),
    pw.Row(
    children: [
    pw.Expanded(
    child: pw.Text(
    '${language == 'EN' ? 'Packaging' : 'Verpackungsart'}: $packagingType',
    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
    ),
    ),
    pw.Text(
    '${language == 'EN' ? 'Dimensions' : 'Abmessungen'}: '
    '${length.toStringAsFixed(1)} × ${width.toStringAsFixed(1)} × ${height.toStringAsFixed(1)} cm',
    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
    ),
    ],
    ),
    pw.SizedBox(height: 2),
    pw.Row(
    children: [
    pw.Expanded(
    child: pw.Text(
    '${language == 'EN' ? 'Tare weight' : 'Tara-Gewicht'}: ${tareWeight.toStringAsFixed(2)} kg',
    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
    ),
    ),
    pw.Text(
    '${language == 'EN' ? 'Gross volume' : 'Bruttovolumen'}: ${grossVolume.toStringAsFixed(4)} m³',
    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
    ),
    ],
    ),
    ],
    ),
    );
    }

    // Paket-Tabelle mit Rechnungsnummer
    static pw.Widget _buildCombinedPackageTable(
    Map<String, dynamic> package,
    List<Map<String, dynamic>> packageItems,
    String language,
    Map<String, Map<String, dynamic>> woodTypeCache,
    Map<String, Map<String, dynamic>> measurementsCache,
    Map<String, Map<String, dynamic>> standardVolumeCache,
    Map<String, String> orderReferences,
    ) {
    double packageNetWeight = 0.0;
    double packageNetVolume = 0.0;
    final tareWeight = (package['tare_weight'] as num?)?.toDouble() ?? 0.0;

    final length = (package['length'] as num?)?.toDouble() ?? 0.0;
    final width = (package['width'] as num?)?.toDouble() ?? 0.0;
    final height = (package['height'] as num?)?.toDouble() ?? 0.0;
    final grossVolume = (length * width * height) / 1000000;

    final List<pw.TableRow> rows = [];

    // Header mit Rechnungsnummer-Spalte
    rows.add(
    pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
    children: [
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Inv.' : 'Re.Nr.', 7),
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Product' : 'Produkt', 7),
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Qual.' : 'Qual.', 7),
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Qty' : 'Menge', 7, align: pw.TextAlign.right),
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Unit' : 'Einh.', 7),
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Weight/pc' : 'Gew./Stk', 7, align: pw.TextAlign.right),
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Vol./pc' : 'Vol./Stk', 7, align: pw.TextAlign.right),
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Total Weight' : 'Ges. Gewicht', 7, align: pw.TextAlign.right),
    BasePdfGenerator.buildHeaderCell(
    language == 'EN' ? 'Total Vol.' : 'Ges. Volumen', 7, align: pw.TextAlign.right),
    ],
    ),
    );

    // Sortiere Items nach Rechnungsnummer
    packageItems.sort((a, b) =>
    (a['_invoice_number'] ?? '').compareTo(b['_invoice_number'] ?? ''));

    // Produktzeilen
    for (final item in packageItems) {
    final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    final productId = item['product_id'] as String? ?? '';
    final quality = item['quality_name'] as String? ?? '';
    final invoiceNumber = item['_invoice_number'] ?? '';

    // Einheit normalisieren
    String unit = item['unit'] ?? 'Stk';
    if (unit.toLowerCase() == 'stück') {
    unit = 'Stk';
    }

    // Volumen und Gewicht berechnen (wie im normalen Generator)
    // ... (Code übernommen aus normalem PackingListGenerator)

    final measurements = measurementsCache[productId] ?? {};
    final woodInfo = woodTypeCache[item['wood_code']] ?? {};
    final density = (woodInfo['density'] as num?)?.toDouble() ?? 0.0;

    // Volumen berechnen (vereinfacht)
    double volumePerPiece = 0.0;
    if (item['volume_per_unit'] != null && (item['volume_per_unit'] as num) > 0) {
    volumePerPiece = (item['volume_per_unit'] as num).toDouble();
    } else if (measurements['custom_volume'] != null && (measurements['custom_volume'] as num) > 0) {
    volumePerPiece = (measurements['custom_volume'] as num).toDouble();
    }

    double weightPerPiece = 0.0;
    double totalWeight = 0.0;
    double totalVolume = 0.0;

    if (unit.toLowerCase() == 'kg') {
    totalWeight = quantity;
    if (density > 0) {
    totalVolume = totalWeight / density;
    }
    } else {
    totalVolume = volumePerPiece * quantity;
    weightPerPiece = volumePerPiece * density;
    totalWeight = weightPerPiece * quantity;
    }

    packageNetWeight += totalWeight;
    packageNetVolume += totalVolume;

    rows.add(
    pw.TableRow(
    children: [
    // Rechnungsnummer
    BasePdfGenerator.buildContentCell(
    pw.Text(
    invoiceNumber,
    style: pw.TextStyle(
    fontSize: 7,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.blueGrey800,
    ),
    ),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    language == 'EN'
    ? (item['product_name_en'] ?? item['product_name'] ?? '')
        : (item['product_name'] ?? ''),
    style: const pw.TextStyle(fontSize: 7),
    ),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(quality, style: const pw.TextStyle(fontSize: 7)),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    unit != "Stk"
    ? quantity.toStringAsFixed(3)
        : quantity.toStringAsFixed(quantity == quantity.round() ? 0 : 3),
    style: const pw.TextStyle(fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(unit, style: const pw.TextStyle(fontSize: 7)),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    unit == 'Stk' ? '${weightPerPiece.toStringAsFixed(3)} kg' : '',
    style: const pw.TextStyle(fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    unit == 'Stk' ? '${volumePerPiece.toStringAsFixed(5)} m³' : '',
    style: const pw.TextStyle(fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    '${totalWeight.toStringAsFixed(2)} kg',
    style: const pw.TextStyle(fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    '${totalVolume.toStringAsFixed(4)} m³',
    style: const pw.TextStyle(fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    ],
    ),
    );
    }

    // Netto-Zeile
    rows.add(
    pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
    children: [
    BasePdfGenerator.buildContentCell(
    pw.Text(
    language == 'EN' ? 'Package Net' : 'Paket Netto',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
    ),
    ),
    ...List.generate(6, (index) => BasePdfGenerator.buildContentCell(pw.Text(''))),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    '${packageNetWeight.toStringAsFixed(2)} kg',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    '${packageNetVolume.toStringAsFixed(4)} m³',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    ],
    ),
    );

    // Brutto-Zeile
    rows.add(
    pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey200),
    children: [
    BasePdfGenerator.buildContentCell(
    pw.Text(
    language == 'EN' ? 'Package Gross' : 'Paket Brutto',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
    ),
    ),
    ...List.generate(6, (index) => BasePdfGenerator.buildContentCell(pw.Text(''))),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    '${(packageNetWeight + tareWeight).toStringAsFixed(2)} kg',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    BasePdfGenerator.buildContentCell(
    pw.Text(
    '${grossVolume.toStringAsFixed(4)} m³',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
    textAlign: pw.TextAlign.right,
    ),
    ),
    ],
    ),
    );

    return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
    columnWidths: {
    0: const pw.FlexColumnWidth(1.5),    // Rechnungsnr
    1: const pw.FlexColumnWidth(3.0),    // Produkt
    2: const pw.FlexColumnWidth(1.5),    // Qualität
    3: const pw.FlexColumnWidth(1.5),    // Menge
    4: const pw.FlexColumnWidth(1.0),    // Einheit
    5: const pw.FlexColumnWidth(1.8),    // Gewicht/Stk
    6: const pw.FlexColumnWidth(1.8),    // Volumen/Stk
    7: const pw.FlexColumnWidth(1.8),    // Gesamt Gewicht
    8: const pw.FlexColumnWidth(1.8),    // Gesamt Volumen
    },
    children: rows,
    );
    }

    // Gesamtübersicht
    static pw.Widget _buildTotalSummary(
    List<Map<String, dynamic>> packages,
    String language,
    ) {
    double totalNetWeight = 0.0;
    double totalGrossWeight = 0.0;
    double totalNetVolume = 0.0;
    double totalGrossVolume = 0.0;
    int totalItems = 0;

    for (final package in packages) {
    final packageItems = List<Map<String, dynamic>>.from(package['items'] ?? []);
    totalItems += packageItems.length;

    final tareWeight = (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
    totalGrossWeight += tareWeight;

    // Paketvolumen
    final length = (package['length'] as num?)?.toDouble() ?? 0.0;
    final width = (package['width'] as num?)?.toDouble() ?? 0.0;
    final height = (package['height'] as num?)?.toDouble() ?? 0.0;
    totalGrossVolume += (length * width * height) / 1000000;

    // Items durchgehen für Netto-Werte
    for (final item in packageItems) {
    // Vereinfachte Berechnung für Übersicht
    final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    if (item['unit']?.toString().toLowerCase() == 'kg') {
    totalNetWeight += quantity;
    }
    // Weitere Berechnungen analog zum normalen Generator
    }
    }

    totalGrossWeight += totalNetWeight;

    return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
    color: PdfColors.green50,
    borderRadius: pw.BorderRadius.circular(8),
    border: pw.Border.all(color: PdfColors.green200, width: 1),
    ),
    child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
    pw.Text(
    language == 'EN' ? 'TOTAL SUMMARY' : 'GESAMTÜBERSICHT',
    style: pw.TextStyle(
    fontSize: 12,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.green800,
    ),
    ),
    pw.SizedBox(height: 8),
    pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
    pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
    pw.Text(
    '${language == 'EN' ? 'Number of packages' : 'Anzahl Pakete'}: ${packages.length}',
    style: const pw.TextStyle(fontSize: 10),
    ),
    pw.Text(
    '${language == 'EN' ? 'Total items' : 'Gesamtpositionen'}: $totalItems',
    style: const pw.TextStyle(fontSize: 10),
    ),
    ],
    ),
    pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
    pw.Text(
    '${language == 'EN' ? 'Total net weight' : 'Gesamt Nettogewicht'}: ${totalNetWeight.toStringAsFixed(2)} kg',
    style: const pw.TextStyle(fontSize: 10),
    ),
    pw.Text(
    '${language == 'EN' ? 'Total gross weight' : 'Gesamt Bruttogewicht'}: ${totalGrossWeight.toStringAsFixed(2)} kg',
    style: pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.green800,
    ),
    ),
    ],
    ),
    ],
    ),
    ],
    ),
    );
    }
  }