// lib/analytics/production/widgets/volume_info_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String chVolume(double value) {
  final formatted = value.toStringAsFixed(3);
  final parts = formatted.split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('\'');
    buffer.write(intPart[i]);
  }
  return "${buffer.toString()}.$decPart";
}

class VolumeInfoSheet extends StatelessWidget {
  final Map<String, dynamic> summary;

  const VolumeInfoSheet({super.key, required this.summary});

  static void show(BuildContext context, Map<String, dynamic> summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VolumeInfoSheet(summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final volumeFromDirectM3 =
        (summary['volume_from_direct_m3'] as num?)?.toDouble() ?? 0.0;
    final volumeFromPieces =
        (summary['volume_from_pieces'] as num?)?.toDouble() ?? 0.0;
    final totalVolumeM3 =
        (summary['total_volume_m3'] as num?)?.toDouble() ?? 0.0;
    final pieceBatchesTotal =
        (summary['piece_batches_total'] as num?)?.toInt() ?? 0;
    final pieceBatchesWithVolume =
        (summary['piece_batches_with_volume'] as num?)?.toInt() ?? 0;
    final piecesWithoutVolume =
        (summary['pieces_without_volume'] as num?)?.toDouble() ?? 0.0;
    final missingProducts = (summary['missing_volume_products'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ??
        [];

    final coveragePercent = pieceBatchesTotal > 0
        ? (pieceBatchesWithVolume / pieceBatchesTotal * 100)
        : 100.0;

    final coverageColor = coveragePercent >= 90
        ? Colors.green
        : coveragePercent >= 70
        ? Colors.orange
        : Colors.red;

    final numberFormat = NumberFormat('#,##0', 'de_CH');

    return DraggableScrollableSheet(
      initialChildSize: missingProducts.isEmpty ? 0.45 : 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag-Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.straighten,
                        size: 22, color: Colors.teal),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'm³ Berechnung',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // ── Aufschlüsselung ──────────────────────────────
                  _SectionLabel(label: 'Aufschlüsselung'),
                  const SizedBox(height: 10),

                  if (volumeFromDirectM3 > 0)
                    _VolumeRow(
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      label: 'Direkt als m³ gebucht',
                      value: '${chVolume(volumeFromDirectM3)} m³',
                    ),

                  if (volumeFromDirectM3 > 0 && volumeFromPieces > 0)
                    const SizedBox(height: 10),

                  if (volumeFromPieces > 0)
                    _VolumeRow(
                      icon: Icons.calculate_outlined,
                      color: Colors.blue,
                      label: 'Aus Stück umgerechnet',
                      value: '${chVolume(volumeFromPieces)} m³',
                    ),

                  const Divider(height: 28),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('m³ gesamt',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '${chVolume(totalVolumeM3)} m³',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal),
                      ),
                    ],
                  ),

                  // ── Abdeckung (nur wenn Stück-Buchungen) ────────
                  if (pieceBatchesTotal > 0) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'Abdeckung Stück-Buchungen'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fortschrittsbalken
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: coveragePercent / 100,
                              minHeight: 10,
                              backgroundColor:
                              Colors.red.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  coverageColor),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$pieceBatchesWithVolume / $pieceBatchesTotal Buchungen mit Volumen',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600]),
                              ),
                              Text(
                                '${coveragePercent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: coverageColor),
                              ),
                            ],
                          ),
                          if (piecesWithoutVolume > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${numberFormat.format(piecesWithoutVolume)} Stk ohne Standardprodukt-Zuordnung',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── Fehlende Produkte ────────────────────────────
                  if (missingProducts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(
                      label: 'Ohne Standardprodukt-Zuordnung',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${missingProducts.length}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Diese Produkte haben kein Standardprodukt hinterlegt – ihr Volumen kann nicht berechnet werden.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),
                    ...missingProducts.map((p) => _MissingProductTile(
                      product: p,
                      numberFormat: numberFormat,
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hilfwidgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _SectionLabel({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _VolumeRow(
      {required this.icon,
        required this.color,
        required this.label,
        required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style:
                TextStyle(fontSize: 14, color: Colors.grey[700]))),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

class _MissingProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final NumberFormat numberFormat;
  const _MissingProductTile(
      {required this.product, required this.numberFormat});

  @override
  Widget build(BuildContext context) {
    final instrName = product['instrument_name'] as String? ?? '';
    final partName = product['part_name'] as String? ?? '';
    final articleNumber = product['article_number'] as String? ?? '';
    final totalQty =
        (product['total_quantity'] as num?)?.toDouble() ?? 0.0;
    final batchCount = (product['batch_count'] as num?)?.toInt() ?? 0;
    final woodName = product['wood_name'] as String? ?? '';
    final qualityName = product['quality_name'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$instrName · $partName',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$woodName · $qualityName · Art. $articleNumber',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${numberFormat.format(totalQty)} Stk',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '$batchCount ${batchCount == 1 ? 'Buchung' : 'Buchungen'}',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}