// lib/analytics/sales/services/customer_stats_migration.dart
//
// Einmalig ausführen um die Stats für alle bestehenden Kunden zu berechnen.
// Kann z.B. über einen Admin-Button oder in den Settings aufgerufen werden.

import 'package:flutter/material.dart';
import 'customer_stats_service.dart';

class CustomerStatsMigration {
  /// Zeigt einen Dialog mit Fortschrittsanzeige für die Migration
  static Future<void> showMigrationDialog(BuildContext context) async {
    int processed = 0;
    int total = 0;
    bool isRunning = false;
    bool isDone = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Kunden-Stats Migration'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isRunning && !isDone) ...[
                  const Text(
                    'Diese Migration berechnet die Verkaufsstatistiken '
                    'für alle bestehenden Kunden basierend auf allen '
                    'versendeten Aufträgen.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dies muss nur einmalig ausgeführt werden. '
                            'Danach werden die Stats automatisch bei '
                            'jeder Statusänderung aktualisiert.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isRunning) ...[
                  const Text('Migration läuft...'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: total > 0 ? processed / total : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    total > 0
                        ? '$processed / $total Kunden verarbeitet'
                        : 'Daten werden geladen...',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (isDone && error == null) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 12),
                  Text('Migration abgeschlossen! $processed Kunden verarbeitet.'),
                ],
                if (error != null) ...[
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text('Fehler: $error'),
                ],
              ],
            ),
            actions: [
              if (!isRunning && !isDone)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
              if (!isRunning && !isDone)
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      isRunning = true;
                    });

                    try {
                      final count = await CustomerStatsService.rebuildAllCustomerStats(
                        onProgress: (p, t) {
                          setState(() {
                            processed = p;
                            total = t;
                          });
                        },
                      );

                      setState(() {
                        processed = count;
                        isRunning = false;
                        isDone = true;
                      });
                    } catch (e) {
                      setState(() {
                        isRunning = false;
                        isDone = true;
                        error = e.toString();
                      });
                    }
                  },
                  child: const Text('Migration starten'),
                ),
              if (isDone)
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fertig'),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Prüft ob Jahresrotation nötig ist und führt sie ggf. aus
  static Future<void> checkAndRotateYearIfNeeded() async {
    if (await CustomerStatsService.needsYearRotation()) {
      await CustomerStatsService.rotateYearStats();
    }
  }
}
