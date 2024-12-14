import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models/roundwood_models.dart';
import 'services/roundwood_service.dart';
import 'widgets/roundwood_chart_card.dart';
import 'widgets/roundwood_stats_card.dart';
import 'constants/roundwood_constants.dart';

class RoundwoodAnalysis extends StatefulWidget {
  final RoundwoodFilter filter;
  final RoundwoodService service;
  final bool isDesktopLayout;

  const RoundwoodAnalysis({
    Key? key,
    required this.filter,
    required this.service,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  RoundwoodAnalysisState createState() => RoundwoodAnalysisState();
}

class RoundwoodAnalysisState extends State<RoundwoodAnalysis> {
  final ValueNotifier<Map<String, String>> selectedFilters = ValueNotifier({});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.service.getRoundwoodStream(widget.filter),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs
            .map((doc) => RoundwoodItem.fromFirestore(doc))
            .toList();

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Keine Daten für die Analyse verfügbar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return Container(
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
        child: Column(
        children: [
        SizedBox(
        width: double.infinity,
        child: _buildSummaryStats(items),
        ),
        const SizedBox(height: 24),
        SizedBox(
        width: double.infinity,
        height: 400,
        child: _buildVolumeChart(items),
        ),
        const SizedBox(height: 24),
        SizedBox(
        width: double.infinity,
        height: 400,
        child: _buildQualityDistribution(items),
        ),
        const SizedBox(height: 24),
        SizedBox(
        width: double.infinity,
        height: 400,
        child: _buildWoodTypeDistribution(items),
        ),
        ],
        )));
      },
    );
  }

  Widget _buildVolumeChart(List<RoundwoodItem> items) {
    // Sortiere Items chronologisch
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Gruppiere nach Datum und summiere Volumen
    final volumeByDate = <DateTime, double>{};
    var maxVolume = 0.0;
    var runningTotal = 0.0;

    // Stelle sicher, dass wir alle Tage zwischen Start und Ende haben
    if (items.isNotEmpty) {
      final startDate = DateTime(
        items.first.timestamp.year,
        items.first.timestamp.month,
        items.first.timestamp.day,
      );
      final endDate = DateTime(
        items.last.timestamp.year,
        items.last.timestamp.month,
        items.last.timestamp.day,
      );

      // Initialisiere alle Tage mit 0
      for (var d = startDate;
      d.isBefore(endDate.add(const Duration(days: 1)));
      d = d.add(const Duration(days: 1))) {
        volumeByDate[d] = 0;
      }

      // Addiere die tatsächlichen Volumina
      for (var item in items) {
        final date = DateTime(
          item.timestamp.year,
          item.timestamp.month,
          item.timestamp.day,
        );
        volumeByDate[date] = (volumeByDate[date] ?? 0) + item.volume;
      }

      // Berechne kumulative Summe
      var previousTotal = 0.0;
      final sortedDates = volumeByDate.keys.toList()..sort();
      for (var date in sortedDates) {
        volumeByDate[date] = previousTotal + volumeByDate[date]!;
        previousTotal = volumeByDate[date]!;
        maxVolume = maxVolume < volumeByDate[date]! ? volumeByDate[date]! : maxVolume;
      }
    }

    final yAxisInterval = _calculateYAxisInterval(maxVolume);
    final adjustedMaxVolume = (maxVolume / yAxisInterval).ceil() * yAxisInterval;

    return Padding(
      padding: const EdgeInsets.only(
        right: 16,
        left: 4,
        top: 16,
        bottom: 24,
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: yAxisInterval,
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 0.8,
              );
            },
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 0.8,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 30 * 24 * 60 * 60 * 1000,
                reservedSize: 36,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Transform.rotate(
                    angle: -45 * pi / 180,
                    child: Text(
                      DateFormat('MM.yy').format(date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yAxisInterval,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${value.toInt()} m³',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 0.8,
            ),
          ),
          minY: 0,
          maxY: adjustedMaxVolume,
          lineBarsData: [
            LineChartBarData(
              spots: volumeByDate.entries.map((e) => FlSpot(
                e.key.millisecondsSinceEpoch.toDouble(),
                e.value,
              )).toList()..sort((a, b) => a.x.compareTo(b.x)), // Sortiere die Punkte nach X
              isCurved: false,
              color: Theme.of(context).colorScheme.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
  double _calculateYAxisInterval(double maxValue) {
    final magnitude = (log(maxValue) / ln10).floor();
    final factor = pow(10, magnitude).toDouble();
    final normalized = maxValue / factor;

    if (normalized <= 2) return factor / 4;
    if (normalized <= 5) return factor / 2;
    return factor;
  }
  Widget _buildSummaryStats(List<RoundwoodItem> items) {
    final totalVolume = items.fold<double>(
      0,
          (sum, item) => sum + item.volume,
    );

    final moonwoodCount = items.where((item) => item.isMoonwood).length;

    return Row(
      children: [
        Expanded(
          child: RoundwoodStatsCard(

            value: '${totalVolume.toStringAsFixed(2)} m³',
            icon: Icons.straighten,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: RoundwoodStatsCard(

            value: items.length.toString(),
            icon: Icons.forest,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: RoundwoodStatsCard(

            value: '${(moonwoodCount / items.length * 100).toStringAsFixed(1)}%',
            icon: Icons.nightlight,
          ),
        ),
      ],
    );
  }

// Hilfsfunktion für sichere Farben
  Color getSafeColor(int index, int totalItems) {
    // Basis-Farbe
    const baseColor = Color(0xFF0F4A29);

    // Berechne einen sicheren Opacity-Wert zwischen 0.3 und 0.9
    double opacity = 0.3 + (index / (totalItems > 1 ? totalItems - 1 : 1) * 0.6);
    opacity = opacity.clamp(0.3, 0.9); // Stelle sicher, dass wir im gültigen Bereich bleiben

    return baseColor.withOpacity(opacity);
  }

  Widget _buildDistributionChart({
    required Map<String, int> data,
    required String title,
    required Function(String) onFilterSelected,
    required bool hasFilter,
    required VoidCallback onClearFilter,
    required bool smoothEdges,
  }) {
    // Bereinige die Daten: Entferne leere/null Einträge
    final cleanData = Map<String, int>.fromEntries(
        data.entries.where((entry) =>
        entry.key.isNotEmpty &&
            entry.key != 'null' &&
            entry.value > 0
        )
    );

    // Debug-Ausgabe
    print('Chart data entries: ${cleanData.length}');
    cleanData.forEach((key, value) {
      print('Key: $key, Value: $value');
    });

    final totalItems = cleanData.values.fold(0, (sum, value) => sum + value);
    final totalTypes = cleanData.length;

    // Sortiere die Daten nach Wert (absteigend)
    final sortedData = Map<String, int>.fromEntries(
        cleanData.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
    );

    return RoundwoodChartCard(
      title: title,
      child: SizedBox(
        height: 300,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pie Chart
              Expanded(
                flex: 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: sortedData.entries.map((entry) {
                            final percentage = entry.value / totalItems * 100;
                            final index = sortedData.keys.toList().indexOf(entry.key);
                            return PieChartSectionData(
                              value: entry.value.toDouble(),
                              title: percentage >= 5
                                  ? '${percentage.toStringAsFixed(0)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              radius: 80,
                              color: getSafeColor(index, totalTypes),
                              borderSide: BorderSide(
                                width: smoothEdges ? 0.5 : 1,
                                color: Colors.white.withOpacity(smoothEdges ? 0.5 : 1),
                              ),
                            );
                          }).toList(),
                          sectionsSpace: smoothEdges ? 0 : 1,
                          centerSpaceRadius: 30,
                          pieTouchData: PieTouchData(
                            enabled: !kIsWeb, // Deaktiviert Touch/Mouse-Interaktion im Web
                            touchCallback: (event, response) {
                              if (!kIsWeb) { // Nur für nicht-Web-Plattformen
                                if (!event.isInterestedForInteractions ||
                                    response == null ||
                                    response.touchedSection == null) {
                                  return;
                                }
                                final touchedIndex = response.touchedSection!.touchedSectionIndex;
                                final entry = sortedData.entries.elementAt(touchedIndex);
                                onFilterSelected(entry.key);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    // Center Info
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              totalItems.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F4A29),
                              ),
                            ),
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Text(
                      //   title,
                      //   style: const TextStyle(
                      //     fontWeight: FontWeight.bold,
                      //     fontSize: 14,
                      //     color: Color(0xFF0F4A29),
                      //   ),
                      // ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: sortedData.entries.map((entry) {
                            final percentage = entry.value / totalItems * 100;
                            final index = sortedData.keys.toList().indexOf(entry.key);
                            return InkWell(
                              onTap: () => onFilterSelected(entry.key),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: getSafeColor(index, totalTypes),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${percentage.toStringAsFixed(1)}% (${entry.value})',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (hasFilter) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 32,
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onClearFilter,
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text(
                              'Filter zurücksetzen',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeDistribution(List<RoundwoodItem> items) {
    final purposeCount = <String, int>{};

    for (var item in items) {
      if (item.purposeNames != null) {
        for (var purpose in item.purposeNames!) {
          if (purpose.isNotEmpty) {
            purposeCount[purpose] = (purposeCount[purpose] ?? 0) + 1;
          }
        }
      }
    }


    return _buildDistributionChart(
      data: purposeCount,
      title: 'Verwendungszwecke',
      onFilterSelected: (purpose) {
        if (selectedFilters != null && selectedFilters is ValueNotifier<Map<String, dynamic>>) {
          selectedFilters.value = {'purpose': purpose};
        }
      },
      hasFilter: selectedFilters?.value.containsKey('purpose') ?? false,
      onClearFilter: () {
        if (selectedFilters != null && selectedFilters is ValueNotifier<Map<String, dynamic>>) {
          selectedFilters.value = {};
        }
      },
      smoothEdges: true,
    );
  }
      // Verwendung in den Widgets:
  Widget _buildQualityDistribution(List<RoundwoodItem> items) {
    final qualityCount = <String, int>{};
    for (var item in items) {
      qualityCount[item.qualityName] = (qualityCount[item.qualityName] ?? 0) + 1;
    }

    return _buildDistributionChart(
      data: qualityCount,
      title: RoundwoodStrings.qualityDistributionLabel,
      onFilterSelected: (quality) => selectedFilters.value = {'quality': quality},
      hasFilter: selectedFilters.value.containsKey('quality'),
      onClearFilter: () => selectedFilters.value = {},
      smoothEdges: true,
    );
  }

  Widget _buildWoodTypeDistribution(List<RoundwoodItem> items) {
    final woodTypeCount = <String, int>{};
    for (var item in items) {
      woodTypeCount[item.woodName] = (woodTypeCount[item.woodName] ?? 0) + 1;
    }

    return _buildDistributionChart(
      data: woodTypeCount,
      title: RoundwoodStrings.woodTypeDistributionLabel,
      onFilterSelected: (woodType) => selectedFilters.value = {'wood_type': woodType},
      hasFilter: selectedFilters.value.containsKey('wood_type'),
      onClearFilter: () => selectedFilters.value = {},
      smoothEdges: true,
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}