// File: services/pdf_generators/packing_list_generator.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../document_selection_manager.dart';
import '../pdf_settings_screen.dart';
import 'base_pdf_generator.dart';

class PackingListGenerator extends BasePdfGenerator {

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

  // Erstelle eine neue Packliste-Nummer
  static Future<String> getNextPackingListNumber() async {
    try {
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('packing_list_counters');

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

        return 'PL-$year-$currentNumber';
      });
    } catch (e) {
      print('Fehler beim Erstellen der Packliste-Nummer: $e');
      return 'PL-${DateTime.now().year}-1000';
    }
  }

  static Future<Uint8List> generatePackingListPdf({
    required String language,
    String? packingListNumber,
    String? orderId,
    String? invoiceNumber, // NEU
    String? quoteNumber, // NEU
    required Map<String, dynamic> customerData,
    Map<String, dynamic>? fairData,
    required String costCenterCode,
  }) async {
    final pdf = pw.Document();
    final logo = await BasePdfGenerator.loadLogo();

    // Generiere Packliste-Nummer falls nicht übergeben
    final packingNum = packingListNumber ?? await getNextPackingListNumber();

    // NEU: Lade Adress-Anzeigemodus
    final addressMode = await PdfSettingsHelper.getAddressDisplayMode('packing_list');

    // NEU: Lade Spaltenausrichtungen
    final columnAlignments = await PdfSettingsHelper.getColumnAlignments('packing_list');

    // Lade Packliste-Einstellungen
    Map<String, dynamic> packingSettings;

// Prüfe zuerst ob es eine gespeicherte Packliste für diesen Auftrag gibt
    if (orderId != null && orderId.isNotEmpty) {
      final orderPackingListDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('packing_list')
          .doc('settings')
          .get();

      if (orderPackingListDoc.exists) {
        // Verwende die gespeicherten Daten aus dem Auftrag
        packingSettings = orderPackingListDoc.data() ?? {};
      } else {
        // Fallback auf die globalen Einstellungen
        packingSettings = await DocumentSelectionManager.loadPackingListSettings();
      }
    } else {
      // Kein Auftrag vorhanden, verwende globale Einstellungen
      packingSettings = await DocumentSelectionManager.loadPackingListSettings();
    }

    final packages = List<Map<String, dynamic>>.from(packingSettings['packages'] ?? []);

    // Lade alle Holzart-Daten vorher
    final Map<String, Map<String, dynamic>> woodTypeCache = {};

    // NEU: Lade auch alle Maße aus temporary_basket vorher
    final Map<String, Map<String, dynamic>> measurementsCache = {};

    final Map<String, Map<String, dynamic>> standardVolumeCache = {}; // NEU


    for (final package in packages) {
      final packageItems = List<Map<String, dynamic>>.from(package['items'] ?? []);
      for (final item in packageItems) {
        // Holzart-Cache (bleibt gleich)
        final woodCode = item['wood_code'] as String? ?? '';
        if (woodCode.isNotEmpty && !woodTypeCache.containsKey(woodCode)) {
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

        // Maße-Cache (bleibt gleich)
        final productId = item['product_id'] as String? ?? '';
        if (productId.isNotEmpty && !measurementsCache.containsKey(productId)) {
          try {
            final basketQuery = await FirebaseFirestore.instance
                .collection('temporary_basket')
                .where('product_id', isEqualTo: productId)
                .limit(1)
                .get();

            if (basketQuery.docs.isNotEmpty) {
              final basketData = basketQuery.docs.first.data();
              measurementsCache[productId] = {
                'custom_length': basketData['custom_length'] ?? 0.0,
                'custom_width': basketData['custom_width'] ?? 0.0,
                'custom_thickness': basketData['custom_thickness'] ?? 0.0,
                'custom_volume': basketData['custom_volume']?? 0.0,
              };
            } else {
              measurementsCache[productId] = {
                'custom_length': 0.0,
                'custom_width': 0.0,
                'custom_thickness': 0.0,
                'custom_volume': 0.0,
              };
            }
          } catch (e) {
            print('Fehler beim Laden der Maße für $productId: $e');
            measurementsCache[productId] = {
              'custom_length': 0.0,
              'custom_width': 0.0,
              'custom_thickness': 0.0,
              'custom_volume': 0.0,
            };
          }
        }

        // NEU: Standard-Volumen Cache
        final instrumentCode = item['instrument_code'] as String?;
        final partCode = item['part_code'] as String?;

        if (instrumentCode != null && partCode != null) {
          final articleNumber = instrumentCode + partCode;

          if (!standardVolumeCache.containsKey(articleNumber)) {
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
                  standardVolumeCache[articleNumber] = {
                    'volume_per_unit': mm3Volume,
                    'type': 'mm3'
                  };
                } else if (dm3Volume != null && dm3Volume > 0) {
                  standardVolumeCache[articleNumber] = {
                    'volume_per_unit': dm3Volume,
                    'type': 'dm3'
                  };
                } else {
                  standardVolumeCache[articleNumber] = {
                    'volume_per_unit': 0,
                    'type': 'mm3'
                  };
                }
              } else {
                standardVolumeCache[articleNumber] = {
                  'volume_per_unit': 0,
                  'type': 'mm3'
                };
              }
            } catch (e) {
              print('Fehler beim Laden des Standard-Volumens für $articleNumber: $e');
              standardVolumeCache[articleNumber] = {
                'volume_per_unit': 0,
                'type': 'mm3'
              };
            }
          }
        }
      }
    }

    // Debug output bleibt gleich...
    print('=== DEBUG: Package Items ===');
    for (final package in packages) {
      print('Package: ${package['name']}');
      final items = package['items'] as List<dynamic>;
      for (final item in items) {
        print('  Item: ${item['product_name']}');
        print('  custom_length: ${item['custom_length']}');
        print('  custom_width: ${item['custom_width']}');
        print('  custom_thickness: ${item['custom_thickness']}');
        print('  custom_volume: ${item['custom_volume']}');
      }
    }

    // Übersetzungsfunktion
    String getTranslation(String key) {
      final translations = {
        'DE': {
          'packing_list': 'PACKLISTE',
          'package': 'Packung',
          'packaging': 'Verpackungsart',
          'dimensions': 'Abmessungen',
          'tare_weight': 'Tara-Gewicht',
          'gross_volume': 'Bruttovolumen',
          'net_weight': 'Nettogewicht',
          'gross_weight': 'Bruttogewicht',
          'total_summary': 'GESAMTÜBERSICHT',
          'product': 'Produkt',
          'qty': 'Menge',
          'quality': 'Qual.',
          'unit': 'Einh.',
          'weight_pc': 'Gewicht/Stk',
          'volume_pc': 'Volumen/Stk',
          'total_weight': 'Gesamt Gewicht',
          'total_volume': 'Gesamt Volumen',
          'package_total_net': 'Paket Gewicht (Netto)',
          'package_total_gross': 'Paket Gewicht (Brutto)',
        },
        'EN': {
          'packing_list': 'PACKING LIST',
          'package': 'Package',
          'packaging': 'Packaging',
          'dimensions': 'Dimensions',
          'tare_weight': 'Tare Weight',
          'gross_volume': 'Gross Volume',
          'net_weight': 'Net Weight',
          'gross_weight': 'Gross Weight',
          'total_summary': 'TOTAL SUMMARY',
          'product': 'Product',
          'unit': 'unit',
          'quality': 'qual.',
          'qty': 'Qty',
          'weight_pc': 'Weight/pc',
          'volume_pc': 'Volume/pc',
          'total_weight': 'Total Weight',
          'total_volume': 'Total Volume',
          'package_total_net': 'Package weight (Net)',
          'package_total_gross': 'Package weight (Gross)',
        }
      };
      return translations[language]?[key] ?? translations['DE']?[key] ?? '';
    }

    if (packages.isEmpty) {
      // Fallback wenn keine Pakete konfiguriert
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                BasePdfGenerator.buildHeader(
                  documentTitle: getTranslation('packing_list'),
                  documentNumber: packingNum,
                  date: DateTime.now(),
                  logo: logo,
                  costCenter: null,
                  language: language,
                ),
                pw.SizedBox(height: 20),

                // Kundenadresse
                BasePdfGenerator.buildCustomerAddress(customerData, 'packing_list', language: language, addressDisplayMode: addressMode),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Text(
                      language == 'EN' ? 'No packages configured' : 'Keine Pakete konfiguriert',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
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


    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          if (context.pageNumber == 1) return pw.SizedBox.shrink();
          return pw.Column(
            children: [
              BasePdfGenerator.buildCompactHeader(
                documentTitle: getTranslation('packing_list'),
                documentNumber: packingNum,
                logo: logo,
                pageNumber: context.pageNumber,
                totalPages: context.pagesCount,
                language: language,
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) => BasePdfGenerator.buildFooter(
          pageNumber: context.pageNumber,
          totalPages: context.pagesCount,
          language: language,
        ),
        build: (pw.Context context) { // Async entfernt
          final List<pw.Widget> content = [];

          // Header
          content.add(BasePdfGenerator.buildHeader(
            documentTitle: getTranslation('packing_list'),
            documentNumber: packingNum,
            date: DateTime.now(),
            logo: logo,
            costCenter: costCenterCode,
            language: language,
            additionalReference: invoiceNumber != null ? 'invoice_nr:$invoiceNumber' : null,
            secondaryReference: quoteNumber != null ? 'quote_nr:$quoteNumber' : null,
          ));
          content.add(pw.SizedBox(height: 20));

          // Kundenadresse
          content.add(BasePdfGenerator.buildCustomerAddress(customerData,'packing_list', language: language));
          content.add(pw.SizedBox(height: 20));

          // Für jedes Paket eine Tabelle
          for (int i = 0; i < packages.length; i++) {
            final package = packages[i];
            final packageItems = List<Map<String, dynamic>>.from(package['items'] ?? []);

            if (packageItems.isEmpty) continue;

            // Paket-Header
            content.add(_buildPackageHeader(package, language, i + 1, getTranslation));
            content.add(pw.SizedBox(height: 10));

            // Paket-Tabelle - NEU: columnAlignments hinzugefügt
            content.add(_buildPackageTable(package, packageItems, language, getTranslation, woodTypeCache, measurementsCache, standardVolumeCache, columnAlignments));
            content.add(pw.SizedBox(height: 20));
          }

          return content;
        },

      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildPackageHeader(
      Map<String, dynamic> package,
      String language,
      int packageNumber,
      String Function(String) getTranslation,

      ) {
    final length = (package['length'] as num?)?.toDouble() ?? 0.0;
    final width = (package['width'] as num?)?.toDouble() ?? 0.0;
    final height = (package['height'] as num?)?.toDouble() ?? 0.0;
    final tareWeight = (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
    final packagingType = language == 'EN'
        ? (package['packaging_type_en'] as String? ?? package['packaging_type'] as String? ?? '')
        : (package['packaging_type'] as String? ?? '');

    // Berechne Bruttovolumen in m³
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
            '${getTranslation('package')} $packageNumber',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${getTranslation('packaging')}: $packagingType',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                ),
              ),
              pw.Text(
                '${getTranslation('dimensions')}: ${length.toStringAsFixed(1)} × ${width.toStringAsFixed(1)} × ${height.toStringAsFixed(1)} cm',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${getTranslation('tare_weight')}: ${tareWeight.toStringAsFixed(2)} kg',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                ),
              ),
              pw.Text(
                '${getTranslation('gross_volume')}: ${grossVolume.toStringAsFixed(4)} m³',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
              ),
            ],
          ),
        ],
      ),
    );
  }



  // Ersetze die _buildPackageTable Methode in packing_list_generator.dart

  // Ersetze die _buildPackageTable Methode in packing_list_generator.dart

  static pw.Widget _buildPackageTable(
      Map<String, dynamic> package,
      List<Map<String, dynamic>> packageItems,
      String language,
      String Function(String) getTranslation,
      Map<String, Map<String, dynamic>> woodTypeCache,
      Map<String, Map<String, dynamic>> measurementsCache,
      Map<String, Map<String, dynamic>> standardVolumeCache,
      Map<String, String> columnAlignments, // NEU: columnAlignments Parameter
      ) {
    double packageNetWeight = 0.0;
    double packageNetVolume = 0.0;
    final tareWeight = (package['tare_weight'] as num?)?.toDouble() ?? 0.0;

    // Berechne Bruttovolumen
    final length = (package['length'] as num?)?.toDouble() ?? 0.0;
    final width = (package['width'] as num?)?.toDouble() ?? 0.0;
    final height = (package['height'] as num?)?.toDouble() ?? 0.0;
    final grossVolume = (length * width * height) / 1000000; // cm³ zu m³

    final List<pw.TableRow> rows = [];

    // NEU: Ausrichtungen holen (Packing List hat eigene Spalten)
    final productAlign = _getTextAlign(columnAlignments['product'] ?? 'left');
    final qualityAlign = _getTextAlign(columnAlignments['quality'] ?? 'left');
    final qtyAlign = _getTextAlign(columnAlignments['quantity'] ?? 'right');
    final unitAlign = _getTextAlign(columnAlignments['unit'] ?? 'center');
    // Packing List spezifische Spalten - verwende Standard-Defaults
    final weightPcAlign = _getTextAlign(columnAlignments['weight_pc'] ?? 'right');
    final volumePcAlign = _getTextAlign(columnAlignments['volume_pc'] ?? 'right');
    final totalWeightAlign = _getTextAlign(columnAlignments['total_weight'] ?? 'right');
    final totalVolumeAlign = _getTextAlign(columnAlignments['total_volume'] ?? 'right');

    // Header-Zeile - NEU: mit align Parameter
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          BasePdfGenerator.buildHeaderCell(getTranslation('product'), 8, align: productAlign),
          BasePdfGenerator.buildHeaderCell(getTranslation('quality'), 8, align: qualityAlign),
          BasePdfGenerator.buildHeaderCell(getTranslation('qty'), 8, align: qtyAlign),
          BasePdfGenerator.buildHeaderCell(getTranslation('unit'), 8, align: unitAlign),
          BasePdfGenerator.buildHeaderCell(getTranslation('weight_pc'), 8, align: weightPcAlign),
          BasePdfGenerator.buildHeaderCell(getTranslation('volume_pc'), 8, align: volumePcAlign),
          BasePdfGenerator.buildHeaderCell(getTranslation('total_weight'), 8, align: totalWeightAlign),
          BasePdfGenerator.buildHeaderCell(getTranslation('total_volume'), 8, align: totalVolumeAlign),
        ],
      ),
    );

    // Produktzeilen
    for (final item in packageItems) {
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final productId = item['product_id'] as String? ?? '';
      final quality = item['quality_name'] as String? ?? '';

      // Einheit normalisieren




      String unit = item['unit'] ?? 'Stk';
      if (unit.toLowerCase() == 'stück') {
        unit = language == 'EN' ? 'pcs' : 'Stk';
      }

      // Hole die Maße aus dem Cache
      final measurements = measurementsCache[productId] ?? {
        'custom_length': 0.0,
        'custom_width': 0.0,
        'custom_thickness': 0.0,
        'custom_volume': 0.0
      };

      final itemLength = (measurements['custom_length'] as num).toDouble();
      final itemWidth = (measurements['custom_width'] as num).toDouble();
      final thickness = (measurements['custom_thickness'] as num).toDouble();

      // Holzart-Info für Dichte
      final woodCode = item['wood_code'] as String? ?? '';
      final woodInfo = woodTypeCache[woodCode] ?? {};
      final density = (woodInfo['density'] as num?)?.toDouble() ?? 0.0;

      // Volumen berechnen
      double volumePerPiece = 0.0;

      final volumeFromItem = item['volume_per_unit'];
      if (volumeFromItem != null && (volumeFromItem as num) > 0) {
        volumePerPiece = (volumeFromItem as num).toDouble();
        print("Verwende volume_per_unit aus Item: $volumePerPiece");
      }
// 2. Priorität: Manuell eingegebenes Volumen
      else if  (measurements['custom_volume'] != null && (measurements['custom_volume'] as num) > 0) {
        volumePerPiece = (measurements['custom_volume'] as num).toDouble();
      }
      // 2. Priorität: Berechnetes Volumen aus Maßen
      else if (itemLength > 0 && itemWidth > 0 && thickness > 0) {
        volumePerPiece = (itemLength / 1000) * (itemWidth / 1000) * (thickness / 1000);
      }
      // 3. Priorität: Standard-Volumen aus Cache
      else {
        final instrumentCode = item['instrument_code'] as String?;
        final partCode = item['part_code'] as String?;

        if (instrumentCode != null && partCode != null) {
          final articleNumber = instrumentCode + partCode;
          final standardVolumeData = standardVolumeCache[articleNumber];

          print("standardVolumeData:$standardVolumeData");
          if (standardVolumeData != null) {
            final standardVolume = standardVolumeData['volume_per_unit'] ?? 0;
            final volumeType = standardVolumeData['type'] ?? 'mm3';

            if (standardVolume > 0) {
              if (volumeType == 'mm3') {
                volumePerPiece = (standardVolume / 1000000000.0); // mm³ zu m³
              } else {
                volumePerPiece = (standardVolume / 1000.0); // dm³ zu m³
              }
            }
          }
        }
      }

      // NEU: Gewichtsberechnung basierend auf Einheit
      double weightPerPiece = 0.0;
      double totalWeight = 0.0;
      double totalVolume = 0.0;
      print("Item: ${item['product_name']}");
      print("  Unit: $unit");
      print("  Quantity: $quantity");
      print("  Density: $density");
      print("  Volume per piece: $volumePerPiece");
      print("  Total weight: $totalWeight");
      print("  Total volume: $totalVolume");
      if (unit.toLowerCase() == 'kg') {
        // Wenn Einheit kg ist, ist quantity bereits das Gesamtgewicht
        totalWeight = quantity;
        // Volumen berechnen aus Gewicht und Dichte
        if (density > 0) {
          totalVolume = totalWeight / density;
        } else {
          totalVolume = 0.0; // oder Standardwert
        }  totalVolume = totalWeight / density;
        // weightPerPiece bleibt 0, da es bei kg keinen Sinn macht
      } else {
        // Standard-Berechnung für andere Einheiten
        totalVolume = volumePerPiece * quantity;
        weightPerPiece = volumePerPiece * density;
        totalWeight = weightPerPiece * quantity;
      }

      packageNetWeight += totalWeight;
      packageNetVolume += totalVolume;

      // Maße-String nur erstellen wenn Werte > 0 vorhanden sind
      String dimensionsText = '';
      if (itemLength > 0 || itemWidth > 0 || thickness > 0) {
        dimensionsText = '${itemLength.toStringAsFixed(0)}×${itemWidth.toStringAsFixed(0)}×${thickness.toStringAsFixed(1)}';
      }

      // NEU: Gewicht/Stk und Volumen/Stk nur anzeigen wenn Einheit Stk ist
      String weightPerPieceText = '';
      String volumePerPieceText = '';

      if (unit == 'Stk') {
        weightPerPieceText = '${weightPerPiece.toStringAsFixed(3)} kg';
        volumePerPieceText = '${volumePerPiece.toStringAsFixed(5)} m³';
      }

      print("item:$item");

      // NEU: Alle Zellen mit textAlign
      rows.add(
        pw.TableRow(
          children: [
            BasePdfGenerator.buildContentCell(
              pw.Text(
                (language == 'EN' ? item['product_name_en'] : item['product_name']) ??
                    (language == 'EN' ? item['part_name_en'] : item['part_name']) ??
                    '',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: productAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(quality, style: const pw.TextStyle(fontSize: 8), textAlign: qualityAlign),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                unit != "Stk"
                    ? quantity.toStringAsFixed(3)
                    : quantity.toStringAsFixed(quantity == quantity.round() ? 0 : 3),
                style: const pw.TextStyle(fontSize: 8),
                textAlign: qtyAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(unit, style: const pw.TextStyle(fontSize: 8), textAlign: unitAlign),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                weightPerPieceText,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: weightPcAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                volumePerPieceText,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: volumePcAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                '${totalWeight.toStringAsFixed(2)} kg',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: totalWeightAlign,
              ),
            ),
            BasePdfGenerator.buildContentCell(
              pw.Text(
                '${totalVolume.toStringAsFixed(4)} m³',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: totalVolumeAlign,
              ),
            ),
          ],
        ),
      );
    }

    // Rest der Methode bleibt gleich...
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
        children: [
          BasePdfGenerator.buildContentCell(
            pw.Text(getTranslation('package_total_net'),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          ),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(
            pw.Text('${packageNetWeight.toStringAsFixed(2)} kg',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                textAlign: totalWeightAlign),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text('${packageNetVolume.toStringAsFixed(4)} m³',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                textAlign: totalVolumeAlign),
          ),
        ],
      ),
    );

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey200),
        children: [
          BasePdfGenerator.buildContentCell(
            pw.Text(getTranslation('package_total_gross'),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          ),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(pw.Text('', style: const pw.TextStyle(fontSize: 8))),
          BasePdfGenerator.buildContentCell(
            pw.Text('${(packageNetWeight + tareWeight).toStringAsFixed(2)} kg',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                textAlign: totalWeightAlign),
          ),
          BasePdfGenerator.buildContentCell(
            pw.Text('${(packageNetVolume+grossVolume).toStringAsFixed(4)} m³',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                textAlign: totalVolumeAlign),
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3.0),    // Produkt
        1: const pw.FlexColumnWidth(2.0),    // Abmessungen
        2: const pw.FlexColumnWidth(1.5),    // Menge
        3: const pw.FlexColumnWidth(1.0),    // Einheit
        4: const pw.FlexColumnWidth(1.8),    // Gewicht/Stk
        5: const pw.FlexColumnWidth(1.8),    // Volumen/Stk
        6: const pw.FlexColumnWidth(1.8),    // Gesamt Gewicht
        7: const pw.FlexColumnWidth(1.8),    // Gesamt Volumen
      },
      children: rows,
    );
  }
}