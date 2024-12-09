import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/analytics/production/services/production_service.dart';

import 'models/production_filter.dart';


class ProductionOverview extends StatelessWidget {
  final ProductionService service;
  final ProductionFilter filter;

  const ProductionOverview({
    super.key,
    required this.service,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: service.getProductionTotals(filter),
      builder: (context, totalsSnapshot) {
        try {
          if (totalsSnapshot.hasError) {
            print('Error in ProductionOverview: ${totalsSnapshot.error}');
            print('StackTrace: ${totalsSnapshot.stackTrace}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ein Fehler ist aufgetreten'),
                    const SizedBox(height: 8),
                    if (kDebugMode)
                      Text(
                        totalsSnapshot.error.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            );
          }

          if (!totalsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final totals = totalsSnapshot.data!;
          final quantities = totals['quantities'] as Map<String, int>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Mengenübersicht nach Einheiten
                _buildKpiSection(context, quantities),

                const SizedBox(height: 32),

                // 2. Produktionsübersicht nach Instrumenten
                _buildInstrumentSection(context),
                const SizedBox(height: 32),
              // 2. Produktionsübersicht nach Teilen
                _buildPartsSection(context),
                const SizedBox(height: 32),
                // 2. Produktionsübersicht nach Holzart
                _buildWoodTypeSection(context),

                const SizedBox(height: 32),

                // 3. Qualitätsverteilung
                _buildQualitySection(context),

                const SizedBox(height: 32),

                // 4. Spezialholz und Wertübersicht
                _buildSpecialAndValueSection(
                  context,
                  totals['special_wood'] as Map<String, int>,
                  totals['total_value'] as double,
                  totals['batch_count'] as int,
                ),
              ],
            ),
          );
        } catch (e, stackTrace) {
          print('Error building ProductionOverview: $e');
          print('StackTrace: $stackTrace');
          return const Center(child: Text('Ein Fehler ist aufgetreten'));
        }
      },
    );
  }

  Widget _buildKpiSection(BuildContext context, Map<String, int> quantities) {
    try {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produktionsmengen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildQuantityGrid(context, quantities),
        ],
      );
    } catch (e, stackTrace) {
      print('Error building KPI section: $e');
      print('StackTrace: $stackTrace');
      return const SizedBox.shrink();
    }
  }
  Widget _buildInstrumentSection(BuildContext context) {
    try {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produktion nach Instrumenten',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildInstrumentTable(context),
        ],
      );
    } catch (e, stackTrace) {
      print('Error building wood type section: $e');
      print('StackTrace: $stackTrace');
      return const SizedBox.shrink();
    }
  }
  Widget _buildPartsSection(BuildContext context) {
    try {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produktion nach Bauteil',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildPartsTable(context),
        ],
      );
    } catch (e, stackTrace) {
      print('Error building wood type section: $e');
      print('StackTrace: $stackTrace');
      return const SizedBox.shrink();
    }
  }
  Widget _buildWoodTypeSection(BuildContext context) {
    try {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produktion nach Holzart',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildWoodTypeTable(context),
        ],
      );
    } catch (e, stackTrace) {
      print('Error building wood type section: $e');
      print('StackTrace: $stackTrace');
      return const SizedBox.shrink();
    }
  }

  Widget _buildQualitySection(BuildContext context) {
    try {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produktion nach Qualität',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildQualityTable(context),
        ],
      );
    } catch (e, stackTrace) {
      print('Error building quality section: $e');
      print('StackTrace: $stackTrace');
      return const SizedBox.shrink();
    }
  }

  Widget _buildSpecialAndValueSection(
      BuildContext context,
      Map<String, int> specialWood,
      double totalValue,
      int batchCount,
      ) {
    try {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildSpecialWoodCard(context, specialWood),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTotalValueCard(context, totalValue, batchCount),
          ),
        ],
      );
    } catch (e, stackTrace) {
      print('Error building special and value section: $e');
      print('StackTrace: $stackTrace');
      return const SizedBox.shrink();
    }
  }

  Widget _buildQuantityGrid(BuildContext context, Map<String, int> quantities) {
    final units = {
      'Stk': (Icons.inventory_2, Colors.blue),
      'PAL': (Icons.grid_view, Colors.green),
      'KG': (Icons.scale, Colors.orange),
      'M3': (Icons.view_in_ar, Colors.purple),
    };

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: units.entries.map((unit) {
        final quantity = quantities[unit.key] ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: unit.value.$2.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(unit.value.$1, size: 20, color: unit.value.$2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        unit.key,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                Text(
                  NumberFormat('#,##0').format(quantity),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInstrumentTable(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: service.getProductionByInstrument(filter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error loading wood type stats: ${snapshot.error}');
          return const Text('Fehler beim Laden der Daten');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        if (stats.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Keine Daten für den ausgewählten Zeitraum'),
            ),
          );
        }

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Holzart')),
                DataColumn(label: Text('Stück'), numeric: true),
                DataColumn(label: Text('Paletten'), numeric: true),
                DataColumn(label: Text('Kilogramm'), numeric: true),
                DataColumn(label: Text('Kubikmeter'), numeric: true),
                DataColumn(label: Text('Wert CHF'), numeric: true),
              ],
              rows: stats.entries.map((entry) {
                final quantities = entry.value['quantities'] as Map<String, int>;
                print('Building row for ${entry.value['name']}: $quantities');
                return DataRow(cells: [
                  DataCell(Text(entry.value['name'] as String)),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['Stk'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['PAL'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['KG'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0.##').format(quantities['M3'] ?? 0))),
                  DataCell(Text(
                    NumberFormat.currency(locale: 'de_CH', symbol: 'CHF')
                        .format(entry.value['total_value'] ?? 0),
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
  Widget _buildPartsTable(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: service.getProductionByPart(filter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error loading part stats: ${snapshot.error}');
          return const Text('Fehler beim Laden der Daten');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        if (stats.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Keine Daten für den ausgewählten Zeitraum'),
            ),
          );
        }

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Holzart')),
                DataColumn(label: Text('Stück'), numeric: true),
                DataColumn(label: Text('Paletten'), numeric: true),
                DataColumn(label: Text('Kilogramm'), numeric: true),
                DataColumn(label: Text('Kubikmeter'), numeric: true),
                DataColumn(label: Text('Wert CHF'), numeric: true),
              ],
              rows: stats.entries.map((entry) {
                final quantities = entry.value['quantities'] as Map<String, int>;
                print('Building row for ${entry.value['name']}: $quantities');
                return DataRow(cells: [
                  DataCell(Text(entry.value['name'] as String)),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['Stk'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['PAL'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['KG'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0.##').format(quantities['M3'] ?? 0))),
                  DataCell(Text(
                    NumberFormat.currency(locale: 'de_CH', symbol: 'CHF')
                        .format(entry.value['total_value'] ?? 0),
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
  Widget _buildWoodTypeTable(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: service.getProductionByWoodType(filter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error loading wood type stats: ${snapshot.error}');
          return const Text('Fehler beim Laden der Daten');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        if (stats.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Keine Daten für den ausgewählten Zeitraum'),
            ),
          );
        }

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Holzart')),
                DataColumn(label: Text('Stück'), numeric: true),
                DataColumn(label: Text('Paletten'), numeric: true),
                DataColumn(label: Text('Kilogramm'), numeric: true),
                DataColumn(label: Text('Kubikmeter'), numeric: true),
                DataColumn(label: Text('Wert CHF'), numeric: true),
              ],
              rows: stats.entries.map((entry) {
                final quantities = entry.value['quantities'] as Map<String, int>;
                print('Building row for ${entry.value['name']}: $quantities');
                return DataRow(cells: [
                  DataCell(Text(entry.value['name'] as String)),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['Stk'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['PAL'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['KG'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0.##').format(quantities['M3'] ?? 0))),
                  DataCell(Text(
                    NumberFormat.currency(locale: 'de_CH', symbol: 'CHF')
                        .format(entry.value['total_value'] ?? 0),
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualityTable(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: service.getProductionByQuality(filter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error loading quality stats: ${snapshot.error}');
          return const Text('Fehler beim Laden der Daten');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        if (stats.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Keine Daten für den ausgewählten Zeitraum'),
            ),
          );
        }

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Qualität')),
                DataColumn(label: Text('Stück'), numeric: true),
                DataColumn(label: Text('Paletten'), numeric: true),
                DataColumn(label: Text('Kilogramm'), numeric: true),
                DataColumn(label: Text('Kubikmeter'), numeric: true),
                DataColumn(label: Text('Wert CHF'), numeric: true),
              ],
              rows: stats.entries.map((entry) {
                final quantities = entry.value['quantities'] as Map<String, int>;
                print('Building row for ${entry.value['name']}: $quantities');
                return DataRow(cells: [
                  DataCell(Text(entry.value['name'] as String)),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['Stk'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['PAL'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0').format(quantities['KG'] ?? 0))),
                  DataCell(Text(NumberFormat('#,##0.##').format(quantities['M3'] ?? 0))),
                  DataCell(Text(
                    NumberFormat.currency(locale: 'de_CH', symbol: 'CHF')
                        .format(entry.value['total_value'] ?? 0),
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpecialWoodCard(BuildContext context, Map<String, dynamic> specialWood) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.star, color: Colors.amber.shade800),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Spezialholz',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSpecialWoodRow('Mondholz', specialWood['moonwood'] as int),
            const SizedBox(height: 8),
            _buildSpecialWoodRow('Haselfichte', specialWood['haselfichte'] as int),
            const SizedBox(height: 8),
            _buildSpecialWoodRow('Th. behandelt', specialWood['thermally_treated'] as int),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialWoodRow(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          NumberFormat('#,##0').format(value),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTotalValueCard(BuildContext context, double totalValue, int batchCount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.payments, color: Colors.green.shade700),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Gesamtwert',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              NumberFormat.currency(locale: 'de_CH', symbol: 'CHF').format(totalValue),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$batchCount Chargen',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}