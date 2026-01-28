import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/icon_helper.dart';
import 'models/roundwood_models.dart';
import 'services/roundwood_service.dart';
import 'widgets/roundwood_chart_card.dart';
import 'widgets/roundwood_stats_card.dart';

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

        final items = snapshot.data!.docs.map((doc) => RoundwoodItem.fromFirestore(doc)).toList();

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                getAdaptiveIcon(
                  iconName: 'analytics',
                  defaultIcon: Icons.analytics,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text('Keine Daten für die Analyse verfügbar', style: Theme.of(context).textTheme.titleLarge),
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
                SizedBox(width: double.infinity, child: _buildSummaryStats(items)),
                const SizedBox(height: 24),
                // NEU: Jahres-Übersicht
                SizedBox(width: double.infinity, child: _buildYearOverview(items)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 400, child: _buildVolumeChart(items)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 400, child: _buildQualityDistribution(items)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 400, child: _buildWoodTypeDistribution(items)),
                const SizedBox(height: 24),
                // NEU: Verwendungszweck-Verteilung
                SizedBox(width: double.infinity, height: 400, child: _buildPurposeDistribution(items)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryStats(List<RoundwoodItem> items) {
    final totalVolume = items.fold<double>(0, (sum, item) => sum + item.volume);
    final moonwoodItems = items.where((item) => item.isMoonwood).toList();
    final moonwoodVolume = moonwoodItems.fold<double>(0, (sum, item) => sum + item.volume);
    final fscItems = items.where((item) => item.isFSC).toList();
    final fscVolume = fscItems.fold<double>(0, (sum, item) => sum + item.volume);

    final cards = [
      RoundwoodStatsCard(
        value: '${totalVolume.toStringAsFixed(2)} m³',
        iconName: 'straighten',
        icon: Icons.straighten,
      ),
      RoundwoodStatsCard(
        value: items.length.toString(),
        iconName: 'forest',
        icon: Icons.forest,
      ),
      RoundwoodStatsCard(
        value: '${(moonwoodItems.length / items.length * 100).toStringAsFixed(1)}%',
        subtitle: '${moonwoodVolume.toStringAsFixed(1)} m³',
        iconName: 'nightlight',
        icon: Icons.nightlight,
      ),
      RoundwoodStatsCard(
        value: '${(fscItems.length / items.length * 100).toStringAsFixed(1)}%',
        subtitle: '${fscVolume.toStringAsFixed(1)} m³',
        iconName: 'eco',
        icon: Icons.eco,
      ),
    ];

    // Mobile: 2x2 Grid, Desktop: Row
    if (!widget.isDesktopLayout) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: cards,
      );
    }

    return Row(
      children: cards
          .expand((card) => [Expanded(child: card), const SizedBox(width: 16)])
          .toList()
        ..removeLast(),
    );
  }
  // NEU: Jahres-Übersicht
  Widget _buildYearOverview(List<RoundwoodItem> items) {
    final yearCount = <int, int>{};
    final yearVolume = <int, double>{};

    for (var item in items) {
      yearCount[item.year] = (yearCount[item.year] ?? 0) + 1;
      yearVolume[item.year] = (yearVolume[item.year] ?? 0) + item.volume;
    }

    final sortedYears = yearCount.keys.toList()..sort((a, b) => b.compareTo(a));

    return RoundwoodChartCard(
      title: 'Jahrgänge',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: sortedYears.map((year) {
          final count = yearCount[year]!;
          final volume = yearVolume[year]!;
          final percentage = (count / items.length * 100).toStringAsFixed(1);

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4A29).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0F4A29).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text('$year', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F4A29))),
                const SizedBox(height: 8),
                Text('$count Stämme', style: TextStyle(color: Colors.grey[700])),
                Text('${volume.toStringAsFixed(2)} m³', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text('$percentage%', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVolumeChart(List<RoundwoodItem> items) {
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final volumeByDate = <DateTime, double>{};
    var maxVolume = 0.0;

    if (items.isNotEmpty) {
      final startDate = DateTime(items.first.timestamp.year, items.first.timestamp.month, items.first.timestamp.day);
      final endDate = DateTime(items.last.timestamp.year, items.last.timestamp.month, items.last.timestamp.day);

      for (var d = startDate; d.isBefore(endDate.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
        volumeByDate[d] = 0;
      }

      for (var item in items) {
        final date = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
        volumeByDate[date] = (volumeByDate[date] ?? 0) + item.volume;
      }

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
      padding: const EdgeInsets.only(right: 16, left: 4, top: 16, bottom: 24),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: yAxisInterval,
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 0.8),
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 0.8),
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
                    child: Text(DateFormat('MM.yy').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                    child: Text('${value.toInt()} m³', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2), width: 0.8)),
          minY: 0,
          maxY: adjustedMaxVolume,
          lineBarsData: [
            LineChartBarData(
              spots: volumeByDate.entries.map((e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value)).toList()
                ..sort((a, b) => a.x.compareTo(b.x)),
              isCurved: false,
              color: Theme.of(context).colorScheme.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateYAxisInterval(double maxValue) {
    if (maxValue <= 0) return 1;
    final magnitude = (log(maxValue) / ln10).floor();
    final factor = pow(10, magnitude).toDouble();
    final normalized = maxValue / factor;
    if (normalized <= 2) return factor / 4;
    if (normalized <= 5) return factor / 2;
    return factor;
  }

  Color getSafeColor(int index, int totalItems) {
    // Professionelle Business-Palette - satt aber elegant
    const colors = [
      Color(0xFF0F4A29), // Dunkelgrün (Brand)
      Color(0xFF1565C0), // Königsblau
      Color(0xFFC62828), // Tiefrot
      Color(0xFF6A1B9A), // Violett
      Color(0xFFEF6C00), // Orange
      Color(0xFF00838F), // Cyan/Teal
      Color(0xFF2E7D32), // Grün
      Color(0xFF4527A0), // Indigo
      Color(0xFFAD1457), // Magenta
      Color(0xFF00695C), // Dunkles Teal
      Color(0xFF558B2F), // Olivgrün
      Color(0xFF5D4037), // Braun
      Color(0xFF37474F), // Blaugrau
      Color(0xFFD84315), // Terrakotta
      Color(0xFF1976D2), // Hellblau
      Color(0xFF7B1FA2), // Lila
    ];

    return colors[index % colors.length];
  }

  Widget _buildDistributionChart({
    required Map<String, int> data,
    required String title,
    required Function(String) onFilterSelected,
    required bool hasFilter,
    required VoidCallback onClearFilter,
    required bool smoothEdges,
  })
  {
    final cleanData = Map<String, int>.fromEntries(
      data.entries.where((entry) => entry.key.isNotEmpty && entry.key != 'null' && entry.value > 0),
    );

    final totalItems = cleanData.values.fold(0, (sum, value) => sum + value);
    final totalTypes = cleanData.length;

    final sortedData = Map<String, int>.fromEntries(cleanData.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    return RoundwoodChartCard(
      title: title,
      child: SizedBox(
        height: 300,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                              title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              radius: 80,
                              color: getSafeColor(index, totalTypes),
                              borderSide: BorderSide(width: smoothEdges ? 0.5 : 1, color: Colors.white.withOpacity(smoothEdges ? 0.5 : 1)),
                            );
                          }).toList(),
                          sectionsSpace: smoothEdges ? 0 : 1,
                          centerSpaceRadius: 30,
                          pieTouchData: PieTouchData(
                            enabled: !kIsWeb,
                            touchCallback: (event, response) {
                              if (!kIsWeb && event.isInterestedForInteractions && response?.touchedSection != null) {
                                final touchedIndex = response!.touchedSection!.touchedSectionIndex;
                                final entry = sortedData.entries.elementAt(touchedIndex);
                                onFilterSelected(entry.key);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(totalItems.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F4A29))),
                            Text('Total', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 2)],
                  ),
                  child: Column(
                    children: [
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
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: getSafeColor(index, totalTypes), borderRadius: BorderRadius.circular(2)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12), overflow: TextOverflow.ellipsis),
                                          Text('${percentage.toStringAsFixed(1)}% (${entry.value})', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
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
                            icon: getAdaptiveIcon(iconName: 'clear_all', defaultIcon: Icons.clear),
                            label: const Text('Filter zurücksetzen', style: TextStyle(fontSize: 12)),
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

  // NEU: Verwendungszweck-Verteilung
  Widget _buildPurposeDistribution(List<RoundwoodItem> items) {
    final purposeCount = <String, int>{};

    for (var item in items) {
      for (var purpose in item.purposes) {
        if (purpose.isNotEmpty) {
          purposeCount[purpose] = (purposeCount[purpose] ?? 0) + 1;
        }
      }
      // Auch "andere" Verwendungszwecke zählen
      if (item.otherPurpose != null && item.otherPurpose!.isNotEmpty) {
        purposeCount['Andere: ${item.otherPurpose}'] = (purposeCount['Andere: ${item.otherPurpose}'] ?? 0) + 1;
      }
    }

    return _buildDistributionChart(
      data: purposeCount,
      title: 'Verwendungszwecke',
      onFilterSelected: (purpose) => selectedFilters.value = {'purpose': purpose},
      hasFilter: selectedFilters.value.containsKey('purpose'),
      onClearFilter: () => selectedFilters.value = {},
      smoothEdges: true,
    );
  }

  Widget _buildQualityDistribution(List<RoundwoodItem> items) {
    final qualityCount = <String, int>{};
    for (var item in items) {
      qualityCount[item.qualityName] = (qualityCount[item.qualityName] ?? 0) + 1;
    }

    return _buildDistributionChart(
      data: qualityCount,
      title: 'Qualitätsverteilung',
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
      title: 'Holzartenverteilung',
      onFilterSelected: (woodType) => selectedFilters.value = {'wood_type': woodType},
      hasFilter: selectedFilters.value.containsKey('wood_type'),
      onClearFilter: () => selectedFilters.value = {},
      smoothEdges: true,
    );
  }
}