import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tonewood/analytics/production/services/production_service.dart';

import '../../services/icon_helper.dart';
import 'models/production_filter.dart';

class ProductionBatches extends StatelessWidget {
  final ProductionService service;
  final ProductionFilter filter;

  const ProductionBatches({
    super.key,
    required this.service,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: service.getFilteredBatches(filter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Fehler beim Laden der Chargen'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final batches = snapshot.data!;
        if (batches.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 getAdaptiveIcon(iconName: 'inbox',defaultIcon:Icons.inbox, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Keine Chargen gefunden',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header mit Statistiken
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard2(
                      context,
                      'Chargen',
                      batches.length.toString(),
                      Icons.layers,
                      Colors.blue,
                    ),
                  ),
                  // const SizedBox(width: 16),
                  // Expanded(
                  //   child: _buildStatCard(
                  //     context,
                  //     'Gesamtmenge',
                  //     NumberFormat('#,##0').format(
                  //       batches.fold<int>(0, (sum, b) => sum + (b['quantity'] as double)),
                  //     ),
                  //     Icons.inventory,
                  //     Colors.green,
                  //   ),
                  // ),
                  // const SizedBox(width: 16),
                  // Expanded(
                  //   child: _buildStatCard(
                  //     context,
                  //     'Gesamtwert',
                  //     NumberFormat.currency(locale: 'de_CH', symbol: 'CHF').format(
                  //       batches.fold<double>(0, (sum, b) => sum + (b['value'] as double)),
                  //     ),
                  //     Icons.payments,
                  //     Colors.amber,
                  //   ),
                  // ),
                ],
              ),
            ),

            // Chargen Liste
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: batches.length,
                itemBuilder: (context, index) {
                  final batch = batches[index];
                  return _buildBatchCard(context, batch);
                },
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildStatCard2(
      BuildContext context,
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                //  const SizedBox(width: 8),


            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text(
      title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
    )
    ],
        ),
      ),
    );
  }
  Widget _buildStatCard(
      BuildContext context,
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
              //  const SizedBox(width: 8),
                // Text(
                //   title,
                //   style: Theme.of(context).textTheme.bodySmall,
                // ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(BuildContext context, Map<String, dynamic> batch) {
    final specialTags = <Widget>[];
    if (batch['moonwood'] == true) {
      specialTags.add(_buildTag('Mondholz', Colors.purple));
    }
    if (batch['haselfichte'] == true) {
      specialTags.add(_buildTag('Haselfichte', Colors.teal));
    }
    if (batch['thermally_treated'] == true) {
      specialTags.add(_buildTag('Therm. behandelt', Colors.orange));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showBatchDetails(context, batch),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header mit Datum und Chargennummer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd.MM.yyyy').format(batch['stock_entry_date'] as DateTime),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Charge ${batch['batch_number']}',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Produktname
              Text(
                batch['product_name'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Holzart und Qualität
              Row(
                children: [
                  getAdaptiveIcon(iconName: 'forest',defaultIcon:Icons.forest, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(batch['wood_name'] as String),
                  const SizedBox(width: 16),
                   getAdaptiveIcon(iconName: 'stars',defaultIcon:Icons.stars, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(batch['quality_name'] as String),
                ],
              ),
              const SizedBox(height: 12),

              // Spezialholz Tags
              if (specialTags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: specialTags,
                ),
                const SizedBox(height: 12),
              ],

              // Menge und Wert
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                       getAdaptiveIcon(iconName: 'inventory',defaultIcon:Icons.inventory, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${NumberFormat('#,##0').format(batch['quantity'])} ${batch['unit']}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Text(
                    NumberFormat.currency(locale: 'de_CH', symbol: 'CHF')
                        .format(batch['value']),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showBatchDetails(BuildContext context, Map<String, dynamic> batch) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F4A29).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.layers,
                        color: Color(0xFF0F4A29),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Charge ${batch['batch_number']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F4A29),
                            ),
                          ),
                          Text(
                            DateFormat('dd.MM.yyyy').format(batch['stock_entry_date'] as DateTime),
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                      onPressed: () => Navigator.of(context).pop(),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barcode Section als erstes
                      _buildDetailSection(
                        'Artikelnummer',
                        Icons.qr_code,
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                'Barcode',
                                batch['barcode'] ?? '-',
                                Icons.tag,
                              ),
                              _buildDetailRow(
                                'Kurzform',
                                batch['short_barcode'] ?? '-',
                                Icons.short_text,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildDetailSection(
                        'Produktinformationen',
                        Icons.info,
                        Column(
                          children: [
                            _buildDetailRow('Instrument', batch['instrument_name'], Icons.piano),
                            _buildDetailRow('Bauteil', batch['part_name'], Icons.construction),
                            _buildDetailRow('Holzart', batch['wood_name'], Icons.forest),
                            _buildDetailRow('Qualität', batch['quality_name'], Icons.stars),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailSection(
                        'Mengen & Werte',
                        Icons.analytics,
                        Column(
                          children: [
                            _buildDetailRow(
                              'Menge',
                              '${NumberFormat('#,##0').format(batch['quantity'])} ${batch['unit']}',
                              Icons.inventory,
                            ),
                            _buildDetailRow(
                              'Preis pro ${batch['unit']}',
                              NumberFormat.currency(
                                  locale: 'de_DE',
                                  symbol: 'CHF',
                                  decimalDigits: 2
                              ).format(batch['price_CHF']),
                              Icons.attach_money,
                            ),
                            _buildDetailRow(
                              'Gesamtwert',
                              NumberFormat.currency(
                                  locale: 'de_DE',
                                  symbol: 'CHF',
                                  decimalDigits: 2
                              ).format(batch['value']),
                              Icons.payments,
                            ),
                          ],
                        ),
                      ),
                      if (batch['moonwood'] == true ||
                          batch['haselfichte'] == true ||
                          batch['thermally_treated'] == true) ...[
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          'Spezialholz',
                          Icons.star,
                          Column(
                            children: [
                              if (batch['moonwood'] == true)
                                _buildDetailRow('Mondholz', 'Ja', Icons.nightlight),
                              if (batch['haselfichte'] == true)
                                _buildDetailRow('Haselfichte', 'Ja', Icons.nature),
                              if (batch['thermally_treated'] == true)
                                _buildDetailRow('Thermisch behandelt', 'Ja', Icons.whatshot),
                            ],
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

  Widget _buildDetailSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            flex: 3, // Gibt dem Label mehr Platz
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Expanded(
            flex: 5, // Gibt dem Value weniger Platz
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}