
import 'dart:ffi';
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/pdf.dart';
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
style: const pw.TextStyle(
fontSize: 12,
color: PdfColors.blueGrey600
),
),
],
),
pw.Image(logo, width: 180),
],
);
}

static pw.Widget _buildSummarySection(List<RoundwoodItem> items) {
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
_buildSummaryItem(
'Anzahl Stämme',
items.length.toString(),
'Stück'
),
_buildSummaryItem(
'Gesamtvolumen',
items.fold<double>(0, (sum, item) => sum + item.volume)
    .toStringAsFixed(2),
'm³'
),
_buildSummaryItem(
'Mondholz',
items.where((item) => item.isMoonwood).length.toString(),
'Stück'
),
],
),
);
}

static pw.Widget _buildMainTable(List<RoundwoodItem> items) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(0.8), // Nr.
      1: const pw.FlexColumnWidth(1), // Original Nr.
      2: const pw.FlexColumnWidth(1.5), // Holzart
      3: const pw.FlexColumnWidth(1), // Qualität
      4: const pw.FlexColumnWidth(0.8), // Vol
      5: const pw.FlexColumnWidth(1), // Farbe
      6: const pw.FlexColumnWidth(1.5), // Schlagdatum
      7: const pw.FlexColumnWidth(1.5), // Herkunft
      8: const pw.FlexColumnWidth(1.5), // Zweck
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          _buildHeaderCell('Nr.', 11),
          _buildHeaderCell('Orig. Nr.', 11),
          _buildHeaderCell('Holzart', 11),
          _buildHeaderCell('Q', 11),
          _buildHeaderCell('Vol.', 11),
          _buildHeaderCell('Farbe', 11),
          _buildHeaderCell('Einschnitt',9),
          _buildHeaderCell('Herkunft', 11),
          _buildHeaderCell('Zweck', 11),
        ],
      ),
      ...items.map((item) => pw.TableRow(
        children: [
          _buildContentCell(item.internalNumber, 8),
          _buildContentCell(item.originalNumber ?? '-', 8),
          _buildContentCell(item.woodName, 8),
          _buildContentCell(item.qualityName, 8),
          _buildContentCell('${item.volume.toStringAsFixed(2)} m³', 8),
          _buildContentCell(item.color ?? '-', 8),
          _buildContentCell(
              item.cuttingDate != null
                  ? DateFormat('dd.MM.yy').format(item.cuttingDate!)
                  : '-',
              8
          ),
          _buildContentCell(item.origin ?? '-', 8),
          _buildContentCell(item.purpose ?? '-', 8),
        ],
      )),
    ],
  );
}

static pw.Widget _buildFooter() {
return pw.Container(
padding: const pw.EdgeInsets.only(top: 20),
decoration: const pw.BoxDecoration(
border: pw.Border(
top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.5),
),
),
child: pw.Row(
mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
children: [
pw.Column(
crossAxisAlignment: pw.CrossAxisAlignment.start,
children: [
pw.Text('Florinett AG',
style: pw.TextStyle(
fontWeight: pw.FontWeight.bold,
color: PdfColors.blueGrey800
),
),
...['Tonewood Switzerland', 'Veja Zinols 6', '7482 Bergün', 'Switzerland']
    .map((text) => pw.Text(
text,
style: const pw.TextStyle(color: PdfColors.blueGrey600),
)),
],
),
pw.Column(
crossAxisAlignment: pw.CrossAxisAlignment.end,
children: [
pw.Text('phone: +41 81 407 21 34',
style: const pw.TextStyle(color: PdfColors.blueGrey600),
),
pw.Text('e-mail: info@tonewood.ch',
style: const pw.TextStyle(color: PdfColors.blueGrey600),
),
],
),
],
),
);
}

static pw.Widget _buildSummaryItem(String title, String value, String unit) {
return pw.Column(
children: [
pw.Text(
title,
style: const pw.TextStyle(
color: PdfColors.blueGrey600,
fontSize: 10,
),
),
pw.SizedBox(height: 4),
pw.Text(
'$value $unit',
style: pw.TextStyle(
fontWeight: pw.FontWeight.bold,
fontSize: 12,
),
),
],
);
}

static pw.Widget _buildHeaderCell(String text, double fontSize) {
return pw.Padding(
padding: const pw.EdgeInsets.all(8),
child: pw.Text(
text,
style: pw.TextStyle(
fontSize: fontSize,
fontWeight: pw.FontWeight.bold,
color: PdfColors.blueGrey800,
),
),
);
}

static pw.Widget _buildContentCell(String text, double fontSize) {
return pw.Padding(
padding: const pw.EdgeInsets.all(8),
child: pw.Text(
text,
style: pw.TextStyle(
fontSize: fontSize,
color: PdfColors.blueGrey800,
),
),
);
}

  static pw.Widget _buildVolumeAnalysis(List<RoundwoodItem> items) {
    // 1. Datenaufbereitung
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final woodTypes = items.map((item) => item.woodName).toSet().toList();

    // Erstelle Map für jeden Monat mit Volumen pro Holzart
    final volumeByMonth = <String, Map<String, double>>{};
    var maxTotalVolume = 0.0;

    // Erstelle alle Monate zwischen Start und Ende
    if (items.isNotEmpty) {
      var currentDate = DateTime(items.first.timestamp.year, items.first.timestamp.month);
      final lastDate = DateTime(items.last.timestamp.year, items.last.timestamp.month);

      while (!currentDate.isAfter(lastDate)) {
        final monthKey = DateFormat('MM.yy').format(currentDate);
        volumeByMonth[monthKey] = Map.fromIterable(
          woodTypes,
          key: (item) => item as String,
          value: (item) => 0.0,
        );
        currentDate = DateTime(currentDate.year, currentDate.month + 1);
      }
    }

    // Fülle die Daten
    for (var item in items) {
      final monthKey = DateFormat('MM.yy').format(item.timestamp);
      volumeByMonth[monthKey]![item.woodName] =
          (volumeByMonth[monthKey]![item.woodName] ?? 0) + item.volume;

      // Berechne das maximale Gesamtvolumen pro Monat
      final monthTotal = volumeByMonth[monthKey]!.values.reduce((a, b) => a + b);
      if (monthTotal > maxTotalVolume) maxTotalVolume = monthTotal;
    }

    // Runde maxTotalVolume auf die nächste "schöne" Zahl
    maxTotalVolume = (maxTotalVolume / 10).ceil() * 10.0;

    // 2. Farben generieren
    final woodTypeColors = <String, PdfColor>{};
    final baseShades = [
      PdfColors.green900,
      PdfColors.green800,
      PdfColors.green700,
      PdfColors.green600,
      PdfColors.green500,
    ];

    for (var i = 0; i < woodTypes.length; i++) {
      woodTypeColors[woodTypes[i]] = baseShades[i % baseShades.length];
    }

    // 3. Chart bauen
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Titel und Legende
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Volumenentwicklung nach Holzart',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: woodTypes.map((woodType) => pw.Container(
                margin: const pw.EdgeInsets.only(left: 10),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 8,
                      height: 8,
                      color: woodTypeColors[woodType],
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      woodType,
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
        pw.SizedBox(height: 8),

        // Chart
        pw.Container(
          height: 200,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Y-Achse
              pw.SizedBox(
                width: 40,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: List.generate(6, (index) {
                    final value = (maxTotalVolume * (5 - index) / 5).toStringAsFixed(0);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 8),
                      child: pw.Text(
                        '$value m³',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    );
                  }),
                ),
              ),

              // Chart Area
              pw.Expanded(
                child: pw.Column(
                  children: [
                    // Grid und Bars
                    pw.Expanded(
                      child: pw.Stack(
                        children: [
                          // Horizontale Grid Lines
                          pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) => pw.Container(
                              height: 0.5,
                              color: PdfColors.grey300,
                            )),
                          ),

                          // Bars
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

                                          return volume > 0 ? pw.Container(
                                            height: height,
                                            decoration: pw.BoxDecoration(
                                              color: woodTypeColors[woodType],
                                            ),
                                          ) : pw.Container();
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

                    // X-Achse Labels
                    pw.SizedBox(
                      height: 20,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: volumeByMonth.keys.map((month) => pw.Transform.rotate(
                          angle: -0.785398,
                          child: pw.Container(
                            width: 30,
                            child: pw.Text(
                              month,
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center,
                            ),
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
      Map<String, double> volumeData, // Neuer Parameter für Volumen
      Map<String, PdfColor> woodTypeColors, // Farben aus dem Volumenchart
      ) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
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
                    pw.Container(
                      width: 12,
                      height: 12,
                      decoration: pw.BoxDecoration(
                        color: woodTypeColors[entry.key] ?? PdfColors.grey, // Verwende die gleiche Farbe
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        '${entry.key} (${volume.toStringAsFixed(1)} m³)',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Text(
                      '${(percentage * 100).toStringAsFixed(1)}% (${entry.value})',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: percentage * 200,
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: woodTypeColors[entry.key] ?? PdfColors.grey, // Verwende die gleiche Farbe
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

// Modifiziere die _buildAnalyticsPage Methode:
  static pw.Widget _buildAnalyticsPage(List<RoundwoodItem> items) {
    final woodTypeCount = <String, int>{};
    final qualityCount = <String, int>{};
    final woodTypeVolume = <String, double>{};
    final qualityVolume = <String, double>{};

    // Sammle alle Holzarten für die Farben
    final woodTypes = items.map((item) => item.woodName).toSet();

    // Generiere Farben für die Holzarten
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

    // Sammle Daten
    for (var item in items) {
      // Zähle Vorkommen
      woodTypeCount[item.woodName] = (woodTypeCount[item.woodName] ?? 0) + 1;
      qualityCount[item.qualityName] = (qualityCount[item.qualityName] ?? 0) + 1;

      // Summiere Volumen
      woodTypeVolume[item.woodName] = (woodTypeVolume[item.woodName] ?? 0) + item.volume;
      qualityVolume[item.qualityName] = (qualityVolume[item.qualityName] ?? 0) + item.volume;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Rundholz Analyse',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
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
                  woodTypeColors, // Hier könnten wir auch andere Farben verwenden
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildQualityAnalysis(List<RoundwoodItem> items) {
    final qualityData = items.fold<Map<String, int>>({}, (map, item) {
      map[item.qualityName] = (map[item.qualityName] ?? 0) + 1;
      return map;
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Qualitätsverteilung',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 10),
        ...qualityData.entries.map((entry) {
          final percentage = (entry.value / items.length * 100).toStringAsFixed(1);
          return pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 12,
                  height: 12,
                  color: PdfColors.green700,
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.Text('$percentage% (${entry.value})', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildWoodTypeAnalysis(List<RoundwoodItem> items) {
    final woodTypeData = items.fold<Map<String, int>>({}, (map, item) {
      map[item.woodName] = (map[item.woodName] ?? 0) + 1;
      return map;
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Holzartenverteilung',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 10),
        ...woodTypeData.entries.map((entry) {
          final percentage = (entry.value / items.length * 100).toStringAsFixed(1);
          return pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 12,
                  height: 12,
                  color: PdfColors.green700,
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.Text('$percentage% (${entry.value})', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          );
        }),
      ],
    );
  }

}
