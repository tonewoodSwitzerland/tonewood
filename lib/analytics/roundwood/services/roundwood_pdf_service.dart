import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/roundwood_models.dart';

class RoundwoodPdfService {
  static Future<Uint8List> generatePdf(
      List<RoundwoodItem> items, {
        bool includeAnalytics = false,
      }) async {
    final pdf = pw.Document();

    // Lade das Firmenlogo
    final logoImage = await rootBundle.load('images/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Sortiere nach interner Nummer
    items.sort((a, b) => a.internalNumber.compareTo(b.internalNumber));

    // Erste Seite mit Liste
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(logo),
              pw.SizedBox(height: 20),
              _buildSummarySection(items),
              pw.SizedBox(height: 20),
              _buildMainTable(items),
              pw.Expanded(child: pw.SizedBox()),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    // Optional: Analyse-Seiten
    if (includeAnalytics) {
      pdf.addPage(
        pw.Page(
          build: (context) => _buildAnalyticsPage(items),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildHeader(pw.MemoryImage logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Rundholz Übersicht',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Datum: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
            ),
          ],
        ),
        pw.Image(logo, width: 180),
      ],
    );
  }

  static pw.Widget _buildSummarySection(List<RoundwoodItem> items) {
    final totalVolume = items.fold<double>(0, (sum, item) => sum + item.volume);
    final moonwoodCount = items.where((item) => item.isMoonwood).length;
    final fscCount = items.where((item) => item.isFSC).length; // NEU

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: PdfColors.grey50,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Anzahl Stämme', items.length.toString(), 'Stück'),
          _buildSummaryItem('Gesamtvolumen', totalVolume.toStringAsFixed(2), 'm³'),
          _buildSummaryItem('Mondholz', moonwoodCount.toString(), 'Stück'),
          _buildSummaryItem('FSC', fscCount.toString(), 'Stück'), // NEU
        ],
      ),
    );
  }

  static pw.Widget _buildMainTable(List<RoundwoodItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.7), // Nr.
        1: const pw.FlexColumnWidth(0.5), // Jahr - NEU
        2: const pw.FlexColumnWidth(0.8), // Original Nr.
        3: const pw.FlexColumnWidth(1.2), // Holzart
        4: const pw.FlexColumnWidth(0.5), // Q
        5: const pw.FlexColumnWidth(0.8), // Vol
        6: const pw.FlexColumnWidth(0.6), // Spray
        7: const pw.FlexColumnWidth(1.0), // Einschnitt
        8: const pw.FlexColumnWidth(1.2), // Zweck
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          children: [
            _buildHeaderCell('Nr.', 9),
            _buildHeaderCell('Jahr', 9), // NEU
            _buildHeaderCell('Orig.', 9),
            _buildHeaderCell('Holzart', 9),
            _buildHeaderCell('Q', 9),
            _buildHeaderCell('Vol.', 9),
            _buildHeaderCell('Spray', 9),
            _buildHeaderCell('Einschn.', 9),
            _buildHeaderCell('Zweck', 9),
          ],
        ),
        ...items.map((item) => pw.TableRow(
          children: [
            _buildContentCell(item.internalNumber, 8),
            _buildContentCell(item.year.toString(), 8), // NEU
            _buildContentCell(item.originalNumber ?? '-', 8),
            _buildContentCell(item.woodName, 8),
            _buildContentCell(item.qualityName, 8),
            _buildContentCell('${item.volume.toStringAsFixed(2)}', 8),
            _buildContentCell(item.sprayColor ?? '-', 8), // UMBENANNT
            _buildContentCell(
              item.cuttingDate != null
                  ? DateFormat('dd.MM.yy').format(item.cuttingDate!)
                  : '-',
              8,
            ),
            _buildContentCell(item.purposesDisplay, 8), // VEREINFACHT
          ],
        )),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Florinett AG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              ...['Tonewood Switzerland', 'Veja Zinols 6', '7482 Bergün', 'Switzerland']
                  .map((text) => pw.Text(text, style: const pw.TextStyle(color: PdfColors.blueGrey600))),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('phone: +41 81 407 21 34', style: const pw.TextStyle(color: PdfColors.blueGrey600)),
              pw.Text('e-mail: info@tonewood.ch', style: const pw.TextStyle(color: PdfColors.blueGrey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String title, String value, String unit) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text('$value $unit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String text, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
    );
  }

  static pw.Widget _buildContentCell(String text, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize, color: PdfColors.blueGrey800)),
    );
  }

  static pw.Widget _buildAnalyticsPage(List<RoundwoodItem> items) {
    final woodTypeCount = <String, int>{};
    final qualityCount = <String, int>{};
    final woodTypeVolume = <String, double>{};
    final qualityVolume = <String, double>{};
    final yearCount = <int, int>{}; // NEU: Jahr-Statistik

    final woodTypes = items.map((item) => item.woodName).toSet();

    final woodTypeColors = <String, PdfColor>{};
    final baseShades = [
      PdfColors.green900,
      PdfColors.green800,
      PdfColors.green700,
      PdfColors.green600,
      PdfColors.green500,
    ];

    int colorIndex = 0;
    for (var woodType in woodTypes) {
      woodTypeColors[woodType] = baseShades[colorIndex % baseShades.length];
      colorIndex++;
    }

    for (var item in items) {
      woodTypeCount[item.woodName] = (woodTypeCount[item.woodName] ?? 0) + 1;
      qualityCount[item.qualityName] = (qualityCount[item.qualityName] ?? 0) + 1;
      woodTypeVolume[item.woodName] = (woodTypeVolume[item.woodName] ?? 0) + item.volume;
      qualityVolume[item.qualityName] = (qualityVolume[item.qualityName] ?? 0) + item.volume;
      yearCount[item.year] = (yearCount[item.year] ?? 0) + 1; // NEU
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Rundholz Analyse',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          _buildVolumeAnalysis(items),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildDistributionChart(
                  'Holzartenverteilung',
                  woodTypeCount,
                  items.length,
                  woodTypeVolume,
                  woodTypeColors,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildDistributionChart(
                  'Qualitätsverteilung',
                  qualityCount,
                  items.length,
                  qualityVolume,
                  woodTypeColors,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // NEU: Jahresübersicht
          _buildYearOverview(yearCount, items.length),
        ],
      ),
    );
  }

  // NEU: Jahresübersicht
  static pw.Widget _buildYearOverview(Map<int, int> yearCount, int totalItems) {
    final sortedYears = yearCount.keys.toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Jahrgänge', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: sortedYears.map((year) {
            final count = yearCount[year]!;
            final percentage = (count / totalItems * 100).toStringAsFixed(1);
            return pw.Container(
              margin: const pw.EdgeInsets.only(right: 16),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                children: [
                  pw.Text('$year', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('$count ($percentage%)', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildVolumeAnalysis(List<RoundwoodItem> items) {
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final woodTypes = items.map((item) => item.woodName).toSet().toList();

    final volumeByMonth = <String, Map<String, double>>{};
    var maxTotalVolume = 0.0;

    if (items.isNotEmpty) {
      var currentDate = DateTime(items.first.timestamp.year, items.first.timestamp.month);
      final lastDate = DateTime(items.last.timestamp.year, items.last.timestamp.month);

      while (!currentDate.isAfter(lastDate)) {
        final monthKey = DateFormat('MM.yy').format(currentDate);
        volumeByMonth[monthKey] = Map.fromIterable(woodTypes, key: (item) => item as String, value: (item) => 0.0);
        currentDate = DateTime(currentDate.year, currentDate.month + 1);
      }
    }

    for (var item in items) {
      final monthKey = DateFormat('MM.yy').format(item.timestamp);
      volumeByMonth[monthKey]![item.woodName] = (volumeByMonth[monthKey]![item.woodName] ?? 0) + item.volume;
      final monthTotal = volumeByMonth[monthKey]!.values.reduce((a, b) => a + b);
      if (monthTotal > maxTotalVolume) maxTotalVolume = monthTotal;
    }

    maxTotalVolume = (maxTotalVolume / 10).ceil() * 10.0;

    final woodTypeColors = <String, PdfColor>{};
    final baseShades = [PdfColors.green900, PdfColors.green800, PdfColors.green700, PdfColors.green600, PdfColors.green500];

    for (var i = 0; i < woodTypes.length; i++) {
      woodTypeColors[woodTypes[i]] = baseShades[i % baseShades.length];
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Volumenentwicklung nach Holzart', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: woodTypes.map((woodType) => pw.Container(
                margin: const pw.EdgeInsets.only(left: 10),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(width: 8, height: 8, color: woodTypeColors[woodType]),
                    pw.SizedBox(width: 4),
                    pw.Text(woodType, style: const pw.TextStyle(fontSize: 6)),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 200,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.SizedBox(
                width: 40,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: List.generate(6, (index) {
                    final value = (maxTotalVolume * (5 - index) / 5).toStringAsFixed(0);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 8),
                      child: pw.Text('$value m³', style: const pw.TextStyle(fontSize: 8)),
                    );
                  }),
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Expanded(
                      child: pw.Stack(
                        children: [
                          pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) => pw.Container(height: 0.5, color: PdfColors.grey300)),
                          ),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: volumeByMonth.entries.map((entry) {
                              return pw.Expanded(
                                child: pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                                  child: pw.Column(
                                    mainAxisAlignment: pw.MainAxisAlignment.end,
                                    children: [
                                      pw.Column(
                                        children: woodTypes.map((woodType) {
                                          final volume = entry.value[woodType] ?? 0.0;
                                          final height = (volume / maxTotalVolume) * 180;
                                          return volume > 0
                                              ? pw.Container(height: height, decoration: pw.BoxDecoration(color: woodTypeColors[woodType]))
                                              : pw.Container();
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(
                      height: 20,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: volumeByMonth.keys.map((month) => pw.Transform.rotate(
                          angle: -0.785398,
                          child: pw.Container(
                            width: 30,
                            child: pw.Text(month, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                          ),
                        )).toList(),
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

  static pw.Widget _buildDistributionChart(
      String title,
      Map<String, int> data,
      int totalItems,
      Map<String, double> volumeData,
      Map<String, PdfColor> woodTypeColors,
      ) {
    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 16),
        ...sortedEntries.asMap().entries.map((mapEntry) {
          final entry = mapEntry.value;
          final percentage = entry.value / totalItems;
          final volume = volumeData[entry.key] ?? 0.0;

          return pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(width: 12, height: 12, decoration: pw.BoxDecoration(color: woodTypeColors[entry.key] ?? PdfColors.grey)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: pw.Text('${entry.key} (${volume.toStringAsFixed(1)} m³)', style: const pw.TextStyle(fontSize: 10))),
                    pw.Text('${(percentage * 100).toStringAsFixed(1)}% (${entry.value})', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: percentage * 200,
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: woodTypeColors[entry.key] ?? PdfColors.grey,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}