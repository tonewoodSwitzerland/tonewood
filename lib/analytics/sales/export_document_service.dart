import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../services/download_helper_web.dart';

class ExportDocumentsService {
  // Constants
  static const double _pageMargin = 40.0;

  // Templates for various documents
  static Future<Uint8List> generateCommercialInvoice(String receiptId) async {
    final pdf = pw.Document();
    final receiptDoc = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .doc(receiptId)
        .get();

    if (!receiptDoc.exists) {
      throw Exception('Receipt not found');
    }

    final receiptData = receiptDoc.data()!;
    final customerData = receiptData['customer'] as Map<String, dynamic>;
    final items = (receiptData['items'] as List).cast<Map<String, dynamic>>();
    final calculations = receiptData['calculations'] as Map<String, dynamic>;
    final receiptNumber = receiptData['receiptNumber'] as String;
    final timestamp = receiptData['metadata']['timestamp'] as Timestamp? ?? Timestamp.now();

    // Lade das Firmenlogo
    final logoImage = await rootBundle.load('images/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Group items by customs tariff number for the invoice
    final Map<String, List<Map<String, dynamic>>> itemsByTariff = {};

    for (final item in items) {
      final tariffNumber = _determineTariffNumber(item);
      if (!itemsByTariff.containsKey(tariffNumber)) {
        itemsByTariff[tariffNumber] = [];
      }
      itemsByTariff[tariffNumber]!.add(item);
    }

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(_pageMargin),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with company and customer information
              _buildInvoiceHeader(logo, receiptNumber, timestamp.toDate(), customerData),
              pw.SizedBox(height: 20),

              // Document title
              pw.Center(
                child: pw.Text(
                  'COMMERCIAL INVOICE',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 15),

              // Items table grouped by tariff number
              _buildCommercialInvoiceTable(itemsByTariff),
              pw.SizedBox(height: 20),

              // Totals section
              _buildInvoiceTotals(calculations),
              pw.SizedBox(height: 20),

              // Additional declaration texts
              _buildDeclarationTexts(),

              // Footer with signature
              pw.Expanded(child: pw.SizedBox()),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generatePackingList(String receiptId, {String? containerInfo}) async {
    final pdf = pw.Document();
    final receiptDoc = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .doc(receiptId)
        .get();

    if (!receiptDoc.exists) {
      throw Exception('Receipt not found');
    }

    final receiptData = receiptDoc.data()!;
    final customerData = receiptData['customer'] as Map<String, dynamic>;
    final items = (receiptData['items'] as List).cast<Map<String, dynamic>>();
    final receiptNumber = receiptData['receiptNumber'] as String;
    final timestamp = receiptData['metadata']['timestamp'] as Timestamp? ?? Timestamp.now();

    // Lade das Firmenlogo
    final logoImage = await rootBundle.load('images/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Simulate packages for demonstration purposes
    // In a real implementation, this data would come from the database
    final packages = _simulatePackages(items);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(_pageMargin),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with company and customer information
              _buildPackingListHeader(logo, receiptNumber, timestamp.toDate(), customerData),
              pw.SizedBox(height: 20),

              // Document title
              pw.Center(
                child: pw.Text(
                  'PACKING LIST',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),

              // Container information
              if (containerInfo != null && containerInfo.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Text(
                    'Container no. $containerInfo',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),

              // Packages
              _buildPackingListDetails(packages),
              pw.SizedBox(height: 20),

              // Totals
              _buildPackingListTotals(packages),
              pw.SizedBox(height: 15),

              // FSC certification note
              pw.Text(
                'Only products identified as FSC® are FSC® certified: TUVDC-COC-101112.',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Origin of all goods: Switzerland.',
                style: const pw.TextStyle(fontSize: 9),
              ),

              // Footer with contact info
              pw.Expanded(child: pw.SizedBox()),
              pw.Text(
                'FLORINETT AG, Tonewood Switzerland, Veja Zinols 6, CH-7482 Bergün, info@tonewood.ch, www.tonewood.ch',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Helper methods for document generation

  static pw.Widget _buildInvoiceHeader(pw.MemoryImage logo, String invoiceNumber, DateTime date, Map<String, dynamic> customer) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('sender:', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Florinett AG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Tonewood Switzerland'),
            pw.Text('Veja Zinols 6'),
            pw.Text('7482 Bergün'),
            pw.Text('Switzerland'),
            pw.SizedBox(height: 10),
            pw.Text('phone: +41 81 407 21 34', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('e-mail: info@tonewood.ch', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('VAT: CHE-102.853.600 MWST', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Image(logo, width: 150),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('consignee:', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(customer['company'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(customer['fullName'] ?? ''),
            pw.Text('${customer['street'] ?? ''} ${customer['houseNumber'] ?? ''}'),
            pw.Text('${customer['zipCode'] ?? ''} ${customer['city'] ?? ''}'),
            pw.Text(customer['country'] ?? ''),
            pw.SizedBox(height: 10),
            pw.Text('phone: ${customer['phone'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('e-mail: ${customer['email'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('VAT/EORI: ${customer['vatNumber'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPackingListHeader(pw.MemoryImage logo, String documentNumber, DateTime date, Map<String, dynamic> customer) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('sender:', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Florinett AG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Tonewood Switzerland'),
            pw.Text('Veja Zinols 6'),
            pw.Text('7482 Bergün'),
            pw.Text('Switzerland'),
            pw.SizedBox(height: 10),
            pw.Text('phone: +41 81 407 21 34', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('e-mail: info@tonewood.ch', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('VAT: CHE-102.853.600 MWST', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Image(logo, width: 150),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('consignee:', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(customer['company'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(customer['fullName'] ?? ''),
            pw.Text('${customer['street'] ?? ''} ${customer['houseNumber'] ?? ''}'),
            pw.Text('${customer['zipCode'] ?? ''} ${customer['city'] ?? ''}'),
            pw.Text(customer['country'] ?? ''),
            pw.SizedBox(height: 10),
            pw.Text('phone: ${customer['phone'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('e-mail: ${customer['email'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCommercialInvoiceTable(Map<String, List<Map<String, dynamic>>> itemsByTariff) {
    final List<pw.Widget> sections = [];

    itemsByTariff.forEach((tariffNumber, tariffItems) {
      // Add tariff header
      final tariffDescription = _getTariffDescription(tariffNumber);
      sections.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            '$tariffDescription, customs tariff $tariffNumber',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ),
      );

      // Add items table for this tariff
      sections.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(4), // Product
            1: const pw.FlexColumnWidth(1), // Quality
            2: const pw.FlexColumnWidth(1), // FSC
            3: const pw.FlexColumnWidth(1), // Quantity
            4: const pw.FlexColumnWidth(1), // Unit
            5: const pw.FlexColumnWidth(1.5), // Price/Unit
            6: const pw.FlexColumnWidth(1.5), // Total
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Product', isHeader: true),
                _buildTableCell('Quality', isHeader: true),
                _buildTableCell('FSC', isHeader: true),
                _buildTableCell('Quantity', isHeader: true),
                _buildTableCell('Unit', isHeader: true),
                _buildTableCell('Price/Unit CHF', isHeader: true, align: pw.TextAlign.right),
                _buildTableCell('Total CHF', isHeader: true, align: pw.TextAlign.right),
              ],
            ),

            // Item rows
            ...tariffItems.map((item) {
              final quantity = item['quantity'] as double;
              final pricePerUnit = _getPricePerUnit(item);
              final total = quantity * pricePerUnit;

              return pw.TableRow(
                children: [
                  _buildTableCell('${item['product_name'] ?? ''}'),
                  _buildTableCell('${item['quality_name'] ?? ''}'),
                  _buildTableCell('100%'), // FSC status - could be dynamic
                  _buildTableCell('$quantity'),
                  _buildTableCell('${item['unit'] ?? ''}'),
                  _buildTableCell('${pricePerUnit.toStringAsFixed(2)}', align: pw.TextAlign.right),
                  _buildTableCell('${total.toStringAsFixed(2)}', align: pw.TextAlign.right),
                ],
              );
            }).toList(),
          ],
        ),
      );

      // Add tariff summary
      double tariffTotal = 0;
      double tariffVolume = 0;
      double tariffWeight = 0;

      for (final item in tariffItems) {
        final quantity = item['quantity'] as double;
        final pricePerUnit = _getPricePerUnit(item);
        tariffTotal += quantity * pricePerUnit;

        // These would need proper calculation from your data model
        tariffVolume += 0.001817 * quantity; // Example volume calculation
        tariffWeight += 0.5 * quantity; // Example weight calculation
      }

      sections.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10, top: 5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Net volume: ${tariffVolume.toStringAsFixed(3)} m³', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 15),
              pw.Text('Net weight: ${tariffWeight.toStringAsFixed(1)} kg', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 15),
              pw.Text('Tariff total: ${tariffTotal.toStringAsFixed(2)} CHF',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ],
          ),
        ),
      );
    });

    return pw.Column(children: sections);
  }

  static pw.Widget _buildInvoiceTotals(Map<String, dynamic> calculations) {
    final subtotal = calculations['subtotal'] as double;
    final itemDiscounts = calculations['item_discounts'] as double? ?? 0.0;
    final totalDiscountAmount = calculations['total_discount_amount'] as double? ?? 0.0;
    final netAmount = calculations['net_amount'] as double;
    final vatRate = calculations['vat_rate'] as double? ?? 8.1;
    final vatAmount = calculations['vat_amount'] as double? ?? 0.0;
    final total = calculations['total'] as double;

    // These would come from actual goods weight/volume calculation
    final double netVolume = 0.85; // Example
    final double netWeight = 350.0; // Example
    final double grossVolume = 1.1; // Example
    final double grossWeight = 375.0; // Example

    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${subtotal.toStringAsFixed(2)} CHF', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),

              if (itemDiscounts > 0 || totalDiscountAmount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total discounts:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('-${(itemDiscounts + totalDiscountAmount).toStringAsFixed(2)} CHF',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.red)),
                  ],
                ),
              ],

              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Net amount:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${netAmount.toStringAsFixed(2)} CHF', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VAT ($vatRate%):', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${vatAmount.toStringAsFixed(2)} CHF', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),

              pw.Divider(color: PdfColors.grey400),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('${total.toStringAsFixed(2)} CHF',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 15),

        // Volume and weight information
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Net volume: ${netVolume.toStringAsFixed(3)} m³', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Net weight: ${netWeight.toStringAsFixed(1)} kg', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Gross volume: ${grossVolume.toStringAsFixed(3)} m³', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Gross weight: ${grossWeight.toStringAsFixed(1)} kg', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPackingListDetails(List<Map<String, dynamic>> packages) {
    final List<pw.Widget> packageWidgets = [];

    for (int i = 0; i < packages.length; i++) {
      final package = packages[i];
      final packageItems = package['items'] as List<Map<String, dynamic>>;

      packageWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 15),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Package header
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'package ${i+1}: packed in ${package['packagingType']}, ${package['stackable'] ? 'stackable' : 'not stackable'}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  pw.Text(
                    '${package['dimensions']}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Text(
                    '${package['grossVolume'].toStringAsFixed(3)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Text(
                    '${package['tareWeight'].toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),

              // Tariff description
              pw.Text(
                '${package['tariffDescription']}, customs tariff ${package['tariffNumber']}',
                style: const pw.TextStyle(fontSize: 10),
              ),

              // Package items table
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(1), // Product
                  1: const pw.FlexColumnWidth(1), // Instrument
                  2: const pw.FlexColumnWidth(1), // Type
                  3: const pw.FlexColumnWidth(1), // Quality
                  4: const pw.FlexColumnWidth(1), // FSC
                  5: const pw.FlexColumnWidth(2), // Measurements
                  6: const pw.FlexColumnWidth(0.8), // cbm''/pc
                  7: const pw.FlexColumnWidth(0.8), // Quantity
                  8: const pw.FlexColumnWidth(0.5), // Unit
                  9: const pw.FlexColumnWidth(0.8), // cbm
                  10: const pw.FlexColumnWidth(0.8), // kg
                },
                children: [
                  // Item rows
                  ...packageItems.map((item) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell('${item['product'] ?? ''}', fontSize: 9),
                        _buildTableCell('${item['instrument'] ?? ''}', fontSize: 9),
                        _buildTableCell('${item['type'] ?? ''}', fontSize: 9),
                        _buildTableCell('${item['quality'] ?? ''}', fontSize: 9),
                        _buildTableCell('${item['fsc'] ?? ''}', fontSize: 9),
                        _buildTableCell('${item['measurements'] ?? ''}', fontSize: 9),
                        _buildTableCell('${item['volumePerPiece'] ?? ''}', fontSize: 9, align: pw.TextAlign.right),
                        _buildTableCell('${item['quantity'] ?? ''}', fontSize: 9, align: pw.TextAlign.right),
                        _buildTableCell('${item['unit'] ?? ''}', fontSize: 9),
                        _buildTableCell('${item['totalVolume'] ?? ''}', fontSize: 9, align: pw.TextAlign.right),
                        _buildTableCell('${item['totalWeight'] ?? ''}', fontSize: 9, align: pw.TextAlign.right),
                      ],
                    );
                  }).toList(),
                ],
              ),

              // Package summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('sum net cubature/weight package ${i+1} (products)', style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(width: 15),
                  pw.Text('${package['netVolume'].toStringAsFixed(3)}', style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(width: 15),
                  pw.Text('${package['netWeight'].toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('sum gross cubature/weight package ${i+1} (products & packing)', style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(width: 15),
                  pw.Text('${package['grossVolume'].toStringAsFixed(3)}', style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(width: 15),
                  pw.Text('${package['grossWeight'].toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return pw.Column(children: packageWidgets);
  }

  static pw.Widget _buildPackingListTotals(List<Map<String, dynamic>> packages) {
    double totalNetVolume = 0;
    double totalNetWeight = 0;
    double totalTareWeight = 0;
    double totalGrossVolume = 0;
    double totalGrossWeight = 0;

    for (final package in packages) {
      totalNetVolume += package['netVolume'] as double;
      totalNetWeight += package['netWeight'] as double;
      totalTareWeight += package['tareWeight'] as double;
      totalGrossVolume += package['grossVolume'] as double;
      totalGrossWeight += package['grossWeight'] as double;
    }

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('total net cubature/weight (products)', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 15),
            pw.Text('${totalNetVolume.toStringAsFixed(3)}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 15),
            pw.Text('${totalNetWeight.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('total tara (packing)', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 15),
            pw.Text('', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 15),
            pw.Text('${totalTareWeight.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('total gross cubature/weight (products & packing)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(width: 15),
            pw.Text('${totalGrossVolume.toStringAsFixed(3)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(width: 15),
            pw.Text('${totalGrossWeight.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDeclarationTexts() {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
        pw.Text('FSC® declaration:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    pw.Text('Products identified as FSC® are FSC® certified: TUVDC-COC-101112.', style: const pw.TextStyle(fontSize: 9)),
    pw.SizedBox(height: 5),

    pw.Text('Origin declaration:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    pw.Text('All goods originate from Switzerland.', style: const pw.TextStyle(fontSize: 9)),
    pw.SizedBox(height: 5),

    pw.Text('CITES declaration:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    pw.Text('None of the goods are subject to CITES regulation.', style: const pw.TextStyle(fontSize: 9)),
    pw.SizedBox(height: 5),

    pw.Text('Purpose of export: Commercial Goods', style: const pw.TextStyle(fontSize: 9)),
    pw.Text('Incoterm 2020: EXW Bergün, Switzerland', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Delivery date: ${DateFormat('dd.MM.yyyy').format(DateTime.now().add(const Duration(days: 14)))}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Transport: Strassentransport / DHL Express', style: const pw.TextStyle(fontSize: 9)),
        ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 40),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Place, Date:', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 5),
                pw.Text('Bergün, ${DateFormat('dd.MM.yyyy').format(DateTime.now())}')
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Signature:', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 25),
                pw.Container(
                  width: 150,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: isHeader
            ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize)
            : pw.TextStyle(fontSize: fontSize),
        textAlign: align,
      ),
    );
  }

// Helper methods for document generation

  static String _determineTariffNumber(Map<String, dynamic> item) {
    // In a real implementation, this would determine the correct tariff number based on product type
    // For the example, we'll use hardcoded values from the sample
    final String productName = (item['product_name'] ?? '').toLowerCase();

    if (productName.contains('spruce') || productName.contains('fichte')) {
      return '4407.1200'; // For Swiss alpine spruce (Picea abies), thicker than 6mm
    } else if (productName.contains('maple') || productName.contains('ahorn')) {
      return '4407.9300'; // For sycamore maple (Acer pseudoplatanus), thicker than 6mm
    } else {
      return '4407.1200'; // Default to spruce
    }
  }

  static String _getTariffDescription(String tariffNumber) {
    final Map<String, String> descriptions = {
      '4407.1200': 'Swiss alpine spruce (Picea abies), thicker than 6mm',
      '4407.9300': 'Sycamore maple (Acer pseudoplatanus), thicker than 6mm',
      '4408.1000': 'Swiss alpine spruce (Picea abies), up to 6mm thickness',
      '4408.9000': 'Sycamore maple (Acer pseudoplatanus), up to 6mm thickness',
    };

    return descriptions[tariffNumber] ?? 'Wood';
  }

  static double _getPricePerUnit(Map<String, dynamic> item) {
    // Use custom price if available, otherwise use the standard price
    final customPrice = item['custom_price_per_unit'];
    final standardPrice = item['price_per_unit'];

    if (customPrice != null) {
      return (customPrice as num).toDouble();
    } else if (standardPrice != null) {
      return (standardPrice as num).toDouble();
    } else {
      return 0.0;
    }
  }

// Helper method to simulate packages for demo purposes
// In a real implementation, this would come from database/user input
  static List<Map<String, dynamic>> _simulatePackages(List<Map<String, dynamic>> items) {
    // Group items by similar types
    final Map<String, List<Map<String, dynamic>>> groupedItems = {};

    for (final item in items) {
      final key = _getGroupingKey(item);
      if (!groupedItems.containsKey(key)) {
        groupedItems[key] = [];
      }
      groupedItems[key]!.add(item);
    }

    // Create packages based on groups
    final List<Map<String, dynamic>> packages = [];
    int packageCount = 0;

    groupedItems.forEach((key, packageItems) {
      // Calculate approximate volume and weight
      double netVolume = 0;
      double netWeight = 0;

      for (final item in packageItems) {
        final quantity = item['quantity'] as double;
        netVolume += 0.001817 * quantity; // Example calculation
        netWeight += 0.75 * quantity; // Example calculation
      }

      // Package info based on sample document
      packageCount++;
      final isLargePackage = netVolume > 0.5 || netWeight > 200;
      final dimensions = isLargePackage ? '1250×800×1220' : '1150×780×1100';
      final grossVolume = isLargePackage ? 1.22 : 0.987;
      final tareWeight = 21.0; // Packaging weight
      final grossWeight = netWeight + tareWeight;

      // Create simulated items with detailed measurements
      final simulatedItems = packageItems.map((item) {
        final quantity = item['quantity'] as double;
        return {
          'product': 'top',
          'instrument': item['instrument_name'] ?? 'violin',
          'type': 'standard',
          'quality': item['quality_name'] ?? 'A',
          'fsc': '100%',
          'measurements': '430×130×50/15',
          'volumePerPiece': '0.001817',
          'quantity': quantity,
          'unit': item['unit'] ?? 'pc',
          'totalVolume': (0.001817 * quantity).toStringAsFixed(3),
          'totalWeight': (0.75 * quantity).toStringAsFixed(2),
        };
      }).toList();

      packages.add({
        'packagingType': 'cardboard box, INKA-pallet',
        'stackable': true,
        'dimensions': dimensions,
        'grossVolume': grossVolume,
        'netVolume': netVolume,
        'netWeight': netWeight,
        'tareWeight': tareWeight,
        'grossWeight': grossWeight,
        'tariffNumber': '4407.1200',
        'tariffDescription': 'Swiss alpine spruce (Picea abies), thicker than 6mm',
        'items': simulatedItems,
      });
    });

    return packages;
  }

  static String _getGroupingKey(Map<String, dynamic> item) {
    // Group items by instrument and quality type
    return '${item['instrument_name'] ?? 'violin'}_${item['quality_name'] ?? 'standard'}';
  }

// Method to share the documents
  static Future<void> shareDocuments(BuildContext context, String receiptId, {bool isWeb = kIsWeb}) async {
    try {
      final pdfBytes = await generateCommercialInvoice(receiptId);
      final packingListBytes = await generatePackingList(receiptId, containerInfo: 'BSIU 245144-3, seal 051219');

      if (isWeb) {
        // For web, use direct download
        await _downloadDocuments(receiptId, pdfBytes, packingListBytes);
      } else {
        // For mobile, use share functionality
        await _shareDocuments(receiptId, pdfBytes, packingListBytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Erstellen der Dokumente: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Download helper for web
  static Future<void> _downloadDocuments(String receiptId, Uint8List invoiceBytes, Uint8List packingListBytes) async {
    // Implementation depends on your DownloadHelper class
    // This is a placeholder - actual implementation would use your existing download helper
    try {
      // Download invoice
      final invoiceFileName = 'CommercialInvoice_$receiptId.pdf';
      await downloadSingleFile(invoiceBytes, invoiceFileName);

      // Download packing list
      final packingListFileName = 'PackingList_$receiptId.pdf';
      await downloadSingleFile(packingListBytes, packingListFileName);
    } catch (e) {
      print('Error downloading documents: $e');
      rethrow;
    }
  }

// Helper method for web downloads
  static Future<void> downloadSingleFile(Uint8List bytes, String fileName) async {
    // This is a placeholder - implementation depends on your DownloadHelper
    // Using a hypothetical DownloadHelper class
    await DownloadHelper.downloadFile(bytes, fileName);
  }

// Share helper for mobile
  static Future<void> _shareDocuments(String receiptId, Uint8List invoiceBytes, Uint8List packingListBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();

      // Save invoice to temp file
      final invoiceFile = File('${tempDir.path}/CommercialInvoice_$receiptId.pdf');
      await invoiceFile.writeAsBytes(invoiceBytes);

      // Save packing list to temp file
      final packingListFile = File('${tempDir.path}/PackingList_$receiptId.pdf');
      await packingListFile.writeAsBytes(packingListBytes);

      // Share both files
      await Share.shareXFiles(
        [
          XFile(invoiceFile.path),
          XFile(packingListFile.path),
        ],
        subject: 'Export Documents for Order $receiptId',
      );

      // Optional: Delete temporary files after a delay
      Future.delayed(const Duration(minutes: 5), () async {
        try {
          if (await invoiceFile.exists()) await invoiceFile.delete();
          if (await packingListFile.exists()) await packingListFile.delete();
        } catch (e) {
          print('Error deleting temporary files: $e');
        }
      });
    } catch (e) {
      print('Error sharing documents: $e');
      rethrow;
    }
  } }