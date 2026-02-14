// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
//
// /// Migration-Service zum Übertragen bestehender Batches
// /// in die neue flache production_batches Collection
// class ProductionBatchMigration {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   /// Führt die Migration durch
//   /// Gibt einen Stream mit Fortschrittsupdates zurück
//   Stream<MigrationProgress> migrate() async* {
//     int totalProducts = 0;
//     int processedProducts = 0;
//     int totalBatches = 0;
//     int migratedBatches = 0;
//     int skippedBatches = 0;
//     final errors = <String>[];
//
//     try {
//       // 1. Zähle alle Produkte
//       final productsSnapshot = await _firestore.collection('production').get();
//       totalProducts = productsSnapshot.docs.length;
//
//       yield MigrationProgress(
//         status: MigrationStatus.counting,
//         message: 'Gefunden: $totalProducts Produkte',
//         totalProducts: totalProducts,
//         processedProducts: 0,
//         totalBatches: 0,
//         migratedBatches: 0,
//       );
//
//       // 2. Iteriere über alle Produkte
//       for (final productDoc in productsSnapshot.docs) {
//         try {
//           final productData = productDoc.data();
//           final productId = productDoc.id;
//
//           // Hole alle Batches für dieses Produkt
//           final batchesSnapshot = await productDoc.reference
//               .collection('batch')
//               .get();
//
//           totalBatches += batchesSnapshot.docs.length;
//
//           for (final batchDoc in batchesSnapshot.docs) {
//             try {
//               final batchData = batchDoc.data();
//
//               // Prüfe ob bereits migriert
//               final existingQuery = await _firestore
//                   .collection('production_batches')
//                   .where('product_id', isEqualTo: productId)
//                   .where('batch_number', isEqualTo: batchData['batch_number'])
//                   .limit(1)
//                   .get();
//
//               if (existingQuery.docs.isNotEmpty) {
//                 skippedBatches++;
//                 continue;
//               }
//
//               // Berechne Wert
//               final quantity = (batchData['quantity'] as num?)?.toDouble() ?? 0.0;
//               final price = (productData['price_CHF'] as num?)?.toDouble() ?? 0.0;
//               final value = quantity * price;
//
//               // Erstelle den flachen Batch-Eintrag
//               final flatBatchData = {
//                 // Referenzen
//                 'product_id': productId,
//                 'batch_number': batchData['batch_number'],
//                 'roundwood_id': null, // Wird später nachgetragen
//                 'roundwood_internal_number': null,
//                 'roundwood_year': null,
//
//                 // Zeitdaten - verwende stock_entry_date aus Batch oder created_at
//                 'stock_entry_date': batchData['stock_entry_date'] ??
//                     productData['created_at'] ??
//                     FieldValue.serverTimestamp(),
//                 'year': productData['year'] ?? _extractYearFromId(productId),
//
//                 // Mengen
//                 'quantity': quantity,
//                 'value': value,
//                 'unit': productData['unit'] ?? 'Stk',
//                 'price_CHF': price,
//
//                 // Produkt-Details (denormalisiert)
//                 'instrument_code': productData['instrument_code'],
//                 'instrument_name': productData['instrument_name'],
//                 'part_code': productData['part_code'],
//                 'part_name': productData['part_name'],
//                 'wood_code': productData['wood_code'],
//                 'wood_name': productData['wood_name'],
//                 'quality_code': productData['quality_code'],
//                 'quality_name': productData['quality_name'],
//
//                 // Spezial-Flags
//                 'moonwood': productData['moonwood'] ?? false,
//                 'haselfichte': productData['haselfichte'] ?? false,
//                 'thermally_treated': productData['thermally_treated'] ?? false,
//                 'FSC_100': productData['FSC_100'] ?? false,
//
//                 // Migration-Metadaten
//                 'migrated_at': FieldValue.serverTimestamp(),
//                 'migrated_from': 'production/$productId/batch/${batchDoc.id}',
//               };
//
//               await _firestore.collection('production_batches').add(flatBatchData);
//               migratedBatches++;
//
//             } catch (e) {
//               errors.add('Batch ${batchDoc.id} in $productId: $e');
//             }
//           }
//
//           processedProducts++;
//
//           // Yield Fortschritt alle 10 Produkte oder am Ende
//           if (processedProducts % 10 == 0 || processedProducts == totalProducts) {
//             yield MigrationProgress(
//               status: MigrationStatus.migrating,
//               message: 'Verarbeite Produkt $processedProducts von $totalProducts',
//               totalProducts: totalProducts,
//               processedProducts: processedProducts,
//               totalBatches: totalBatches,
//               migratedBatches: migratedBatches,
//               skippedBatches: skippedBatches,
//               progress: processedProducts / totalProducts,
//             );
//           }
//
//         } catch (e) {
//           errors.add('Produkt ${productDoc.id}: $e');
//           processedProducts++;
//         }
//       }
//
//       // 3. Fertig
//       yield MigrationProgress(
//         status: errors.isEmpty ? MigrationStatus.completed : MigrationStatus.completedWithErrors,
//         message: errors.isEmpty
//             ? 'Migration abgeschlossen!'
//             : 'Migration abgeschlossen mit ${errors.length} Fehlern',
//         totalProducts: totalProducts,
//         processedProducts: processedProducts,
//         totalBatches: totalBatches,
//         migratedBatches: migratedBatches,
//         skippedBatches: skippedBatches,
//         progress: 1.0,
//         errors: errors,
//       );
//
//     } catch (e) {
//       yield MigrationProgress(
//         status: MigrationStatus.error,
//         message: 'Kritischer Fehler: $e',
//         totalProducts: totalProducts,
//         processedProducts: processedProducts,
//         totalBatches: totalBatches,
//         migratedBatches: migratedBatches,
//         errors: [...errors, e.toString()],
//       );
//     }
//   }
//
//   /// Extrahiert das Jahr aus der Produkt-ID
//   /// Format: IIPP.HHQQ.ThHaMoFs.JJ -> JJ = Jahr
//   int _extractYearFromId(String productId) {
//     try {
//       final parts = productId.split('.');
//       if (parts.length >= 4) {
//         final yearPart = parts[3];
//         if (yearPart.length == 2) {
//           final year = int.parse(yearPart);
//           return year < 50 ? 2000 + year : 1900 + year;
//         }
//       }
//     } catch (e) {
//       // Fallback
//     }
//     return DateTime.now().year;
//   }
//
//   /// Prüft den Migrations-Status
//   Future<MigrationStatus> checkStatus() async {
//     final productionCount = await _firestore.collection('production').count().get();
//     final batchesCount = await _firestore.collection('production_batches').count().get();
//
//     // Grobe Schätzung: Wenn production_batches leer ist, wurde noch nicht migriert
//     if (batchesCount.count == 0 && productionCount.count! > 0) {
//       return MigrationStatus.notStarted;
//     }
//
//     return MigrationStatus.completed;
//   }
//
//   /// Löscht alle migrierten Daten (für Neustart)
//   Future<void> resetMigration() async {
//     final batches = await _firestore.collection('production_batches').get();
//
//     final batch = _firestore.batch();
//     for (final doc in batches.docs) {
//       batch.delete(doc.reference);
//     }
//
//     await batch.commit();
//   }
// }
//
// enum MigrationStatus {
//   notStarted,
//   counting,
//   migrating,
//   completed,
//   completedWithErrors,
//   error,
// }
//
// class MigrationProgress {
//   final MigrationStatus status;
//   final String message;
//   final int totalProducts;
//   final int processedProducts;
//   final int totalBatches;
//   final int migratedBatches;
//   final int skippedBatches;
//   final double progress;
//   final List<String> errors;
//
//   MigrationProgress({
//     required this.status,
//     required this.message,
//     this.totalProducts = 0,
//     this.processedProducts = 0,
//     this.totalBatches = 0,
//     this.migratedBatches = 0,
//     this.skippedBatches = 0,
//     this.progress = 0.0,
//     this.errors = const [],
//   });
// }
//
// // ===========================================
// // MIGRATION UI WIDGET
// // ===========================================
//
// class MigrationScreen extends StatefulWidget {
//   const MigrationScreen({Key? key}) : super(key: key);
//
//   @override
//   State<MigrationScreen> createState() => _MigrationScreenState();
// }
//
// class _MigrationScreenState extends State<MigrationScreen> {
//   final _migration = ProductionBatchMigration();
//   MigrationProgress? _progress;
//   bool _isRunning = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Batch-Migration'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Info Card
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(Icons.info, color: Colors.blue),
//                         SizedBox(width: 8),
//                         Text(
//                           'Was macht diese Migration?',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       'Diese Migration kopiert alle bestehenden Batches aus den '
//                           'Subcollections (production/{id}/batch) in eine neue flache '
//                           'Collection (production_batches). Dies ermöglicht deutlich '
//                           'schnellere Auswertungen.',
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       '• Die originalen Daten bleiben erhalten\n'
//                           '• Bereits migrierte Batches werden übersprungen\n'
//                           '• Stamm-Zuordnungen können später nachgetragen werden',
//                       style: TextStyle(fontSize: 13),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             SizedBox(height: 24),
//
//             // Progress
//             if (_progress != null) ...[
//               Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Status: ${_progress!.message}',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       SizedBox(height: 16),
//                       LinearProgressIndicator(
//                         value: _progress!.progress,
//                         backgroundColor: Colors.grey[200],
//                       ),
//                       SizedBox(height: 16),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           _buildStatItem('Produkte',
//                               '${_progress!.processedProducts}/${_progress!.totalProducts}'),
//                           _buildStatItem('Batches migriert',
//                               '${_progress!.migratedBatches}'),
//                           _buildStatItem('Übersprungen',
//                               '${_progress!.skippedBatches}'),
//                         ],
//                       ),
//                       if (_progress!.errors.isNotEmpty) ...[
//                         SizedBox(height: 16),
//                         ExpansionTile(
//                           title: Text(
//                             '${_progress!.errors.length} Fehler',
//                             style: TextStyle(color: Colors.red),
//                           ),
//                           children: _progress!.errors
//                               .map((e) => ListTile(
//                             dense: true,
//                             title: Text(e, style: TextStyle(fontSize: 12)),
//                           ))
//                               .toList(),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//
//             Spacer(),
//
//             // Buttons
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: _isRunning ? null : _startMigration,
//                     icon: Icon(_isRunning ? Icons.hourglass_empty : Icons.play_arrow),
//                     label: Text(_isRunning ? 'Läuft...' : 'Migration starten'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFF0F4A29),
//                       foregroundColor: Colors.white,
//                       padding: EdgeInsets.symmetric(vertical: 16),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildStatItem(String label, String value) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//             color: const Color(0xFF0F4A29),
//           ),
//         ),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey[600],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Future<void> _startMigration() async {
//     setState(() {
//       _isRunning = true;
//       _progress = null;
//     });
//
//     await for (final progress in _migration.migrate()) {
//       if (mounted) {
//         setState(() {
//           _progress = progress;
//         });
//       }
//     }
//
//     if (mounted) {
//       setState(() {
//         _isRunning = false;
//       });
//     }
//   }
// }