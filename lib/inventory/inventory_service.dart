import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

/// Model für eine Inventur-Differenz
class InventoryDifference {
  final String shortBarcode;
  final String productName;
  final String unit;
  final double oldQuantity;
  final double newQuantity;
  final double difference;
  final double differencePercent;
  final bool hasWarning; // >10% Abweichung
  String? comment;

  InventoryDifference({
    required this.shortBarcode,
    required this.productName,
    required this.unit,
    required this.oldQuantity,
    required this.newQuantity,
    required this.difference,
    required this.differencePercent,
    required this.hasWarning,
    this.comment,
  });

  Map<String, dynamic> toMap() {
    return {
      'short_barcode': shortBarcode,
      'product_name': productName,
      'unit': unit,
      'old_quantity': oldQuantity,
      'new_quantity': newQuantity,
      'difference': difference,
      'difference_percent': differencePercent,
      'has_warning': hasWarning,
      'comment': comment,
    };
  }
}

/// Model für Import-Ergebnis
class InventoryImportResult {
  final bool success;
  final String? errorMessage;
  final int totalItems;
  final int changedItems;
  final int warningItems;
  final List<InventoryDifference> differences;
  final String? snapshotId;

  InventoryImportResult({
    required this.success,
    this.errorMessage,
    this.totalItems = 0,
    this.changedItems = 0,
    this.warningItems = 0,
    this.differences = const [],
    this.snapshotId,
  });
}

/// Service für alle Inventur-bezogenen Operationen
class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const double WARNING_THRESHOLD_PERCENT = 10.0;

  // ============================================================
  // SNAPSHOT ERSTELLEN (Archivierung des aktuellen Bestands)
  // ============================================================

  /// Erstellt einen Snapshot des aktuellen Lagerbestands
  /// Gibt die Snapshot-ID zurück
  Future<String> createInventorySnapshot({
    String? description,
  }) async {
    final user = _auth.currentUser;
    final snapshotId = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());

    // Alle Inventory-Dokumente laden
    final inventorySnapshot = await _firestore.collection('inventory').get();
    final docs = inventorySnapshot.docs;

    // Gesamtwert berechnen
    double totalValue = 0;
   double  totalQuantityItems = 0;

    for (var doc in docs) {
      final data = doc.data();
      final quantity = (data['quantity'] ?? 0).toDouble();
      final price = (data['price_CHF'] ?? 0).toDouble();
      totalValue += quantity * price;
      totalQuantityItems += quantity.round();
    }

    // Snapshot-Dokument erstellen
    final snapshotRef = _firestore.collection('inventory_snapshots').doc(snapshotId);

    await snapshotRef.set({
      'created_at': FieldValue.serverTimestamp(),
      'created_by': user?.uid,
      'created_by_email': user?.email,
      'type': 'inventory',
      'description': description ?? 'Inventur vom ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
      'total_items': docs.length,
      'total_quantity': totalQuantityItems,
      'total_value': totalValue,
      'status': 'created', // created -> counting -> imported -> applied
    });

    // Batch für Items (max 450 pro Batch wegen Firestore-Limit)
    final batches = <WriteBatch>[];
    var currentBatch = _firestore.batch();
    var operationCount = 0;

    for (var doc in docs) {
      final itemRef = snapshotRef.collection('items').doc(doc.id);
      currentBatch.set(itemRef, {
        ...doc.data(),
        'snapshot_quantity': doc.data()['quantity'],
        'short_barcode': doc.id,
      });

      operationCount++;
      if (operationCount >= 450) {
        batches.add(currentBatch);
        currentBatch = _firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      batches.add(currentBatch);
    }

    // Alle Batches ausführen
    for (var batch in batches) {
      await batch.commit();
    }

    return snapshotId;
  }

  // ============================================================
  // INVENTUR-EXPORT (CSV für Zählung)
  // ============================================================

  /// Exportiert eine Inventur-CSV mit leerer "Gezählt"-Spalte
  /// Gibt das File zurück, das dann geteilt werden kann
  Future<File> exportInventoryForCounting(String snapshotId) async {
    // Snapshot-Items laden
    final snapshotItems = await _firestore
        .collection('inventory_snapshots')
        .doc(snapshotId)
        .collection('items')
        .orderBy('product_name')
        .get();

    final items = snapshotItems.docs.map((doc) => doc.data()).toList();

    // CSV erstellen
    final StringBuffer csvContent = StringBuffer();

    // BOM für Excel UTF-8 Erkennung
    csvContent.write('\uFEFF');

    // Header
    csvContent.writeln([
      'Artikelnummer',
      'Produkt',
      'Instrument',
      'Bauteil',
      'Holzart',
      'Qualität',
      'Einheit',
      'IST-Bestand',
      'Gezählt',
      'Bemerkung',
    ].join(';'));

    // Datenzeilen
    for (final item in items) {
      final row = [
        item['short_barcode'] ?? '',
        item['product_name'] ?? '',
        '${item['instrument_name'] ?? ''} (${item['instrument_code'] ?? ''})',
        '${item['part_name'] ?? ''} (${item['part_code'] ?? ''})',
        '${item['wood_name'] ?? ''} (${item['wood_code'] ?? ''})',
        '${item['quality_name'] ?? ''} (${item['quality_code'] ?? ''})',
        item['unit'] ?? 'Stück',
        _formatQuantity(item['snapshot_quantity'] ?? 0, item['unit'] ?? 'Stück'),
        '', // Gezählt - leer für User
        '', // Bemerkung - leer für User
      ];

      // Escape semicolons in values
      final escapedRow = row.map((value) {
        final str = value.toString();
        if (str.contains(';') || str.contains('"') || str.contains('\n')) {
          return '"${str.replaceAll('"', '""')}"';
        }
        return str;
      }).toList();

      csvContent.writeln(escapedRow.join(';'));
    }

    // Datei speichern
    final tempDir = await getTemporaryDirectory();
    final fileName = 'Inventur_${snapshotId}.csv';
    final file = File('${tempDir.path}/$fileName');

    await file.writeAsString(csvContent.toString());

    // Snapshot-Status aktualisieren
    await _firestore.collection('inventory_snapshots').doc(snapshotId).update({
      'status': 'counting',
      'exported_at': FieldValue.serverTimestamp(),
    });

    return file;
  }

  /// Teilt die Inventur-Datei
  Future<void> shareInventoryFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Inventur Export',
    );
  }

  // ============================================================
  // INVENTUR-IMPORT (CSV mit gezählten Werten)
  // ============================================================

  /// Importiert eine ausgefüllte Inventur-CSV und berechnet Differenzen
  Future<InventoryImportResult> importInventoryCsv(
      String csvContent,
      String snapshotId,
      ) async {
    try {
      final lines = csvContent.split('\n');

      if (lines.length < 2) {
        return InventoryImportResult(
          success: false,
          errorMessage: 'Die CSV-Datei enthält keine Daten.',
        );
      }

      // Header prüfen
      final header = lines[0].trim();
      if (!header.contains('Artikelnummer') || !header.contains('Gezählt')) {
        return InventoryImportResult(
          success: false,
          errorMessage: 'Ungültiges CSV-Format. Bitte verwende die exportierte Inventur-Datei.',
        );
      }

      // Snapshot-Items laden für Vergleich
      final snapshotItemsQuery = await _firestore
          .collection('inventory_snapshots')
          .doc(snapshotId)
          .collection('items')
          .get();

      final snapshotItems = <String, Map<String, dynamic>>{};
      for (var doc in snapshotItemsQuery.docs) {
        snapshotItems[doc.id] = doc.data();
      }

      // CSV parsen
      final differences = <InventoryDifference>[];
      int changedItems = 0;
      int warningItems = 0;

      // Header-Indizes finden
      final headerParts = _parseCsvLine(header);
      final artikelIndex = headerParts.indexOf('Artikelnummer');
      final gezaehltIndex = headerParts.indexOf('Gezählt');
      final bemerkungIndex = headerParts.indexOf('Bemerkung');

      if (artikelIndex == -1 || gezaehltIndex == -1) {
        return InventoryImportResult(
          success: false,
          errorMessage: 'Spalten "Artikelnummer" oder "Gezählt" nicht gefunden.',
        );
      }

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = _parseCsvLine(line);
        if (parts.length <= gezaehltIndex) continue;

        final shortBarcode = parts[artikelIndex].replaceAll("'", "").trim();
        final gezaehltStr = parts[gezaehltIndex].trim();
        final bemerkung = bemerkungIndex != -1 && parts.length > bemerkungIndex
            ? parts[bemerkungIndex].trim()
            : '';

        // Wenn "Gezählt" leer ist, überspringen (nicht gezählt)
        if (gezaehltStr.isEmpty) continue;

        // Gezählte Menge parsen
        final newQuantity = double.tryParse(
          gezaehltStr.replaceAll(',', '.'),
        );

        if (newQuantity == null) {
          return InventoryImportResult(
            success: false,
            errorMessage: 'Ungültige Menge in Zeile ${i + 1}: "$gezaehltStr"',
          );
        }

        // Snapshot-Item finden
        final snapshotItem = snapshotItems[shortBarcode];
        if (snapshotItem == null) {
          // Neuer Artikel, der nicht im Snapshot war
          differences.add(InventoryDifference(
            shortBarcode: shortBarcode,
            productName: 'Unbekannter Artikel',
            unit: 'Stück',
            oldQuantity: 0,
            newQuantity: newQuantity,
            difference: newQuantity,
            differencePercent: 100,
            hasWarning: true,
            comment: bemerkung.isNotEmpty ? bemerkung : 'Neuer Artikel',
          ));
          changedItems++;
          warningItems++;
          continue;
        }

        final oldQuantity = (snapshotItem['snapshot_quantity'] ?? 0).toDouble();
        final difference = newQuantity - oldQuantity;

        // Nur wenn es eine Änderung gibt
        if (difference.abs() > 0.001) {
          // Prozentuale Abweichung berechnen
          double differencePercent = 0;
          if (oldQuantity > 0) {
            differencePercent = (difference.abs() / oldQuantity) * 100;
          } else if (newQuantity > 0) {
            differencePercent = 100; // Von 0 auf etwas = 100% Änderung
          }

          final hasWarning = differencePercent >= WARNING_THRESHOLD_PERCENT;

          differences.add(InventoryDifference(
            shortBarcode: shortBarcode,
            productName: snapshotItem['product_name'] ?? 'Unbekannt',
            unit: snapshotItem['unit'] ?? 'Stück',
            oldQuantity: oldQuantity,
            newQuantity: newQuantity,
            difference: difference,
            differencePercent: differencePercent,
            hasWarning: hasWarning,
            comment: bemerkung.isNotEmpty ? bemerkung : null,
          ));

          changedItems++;
          if (hasWarning) warningItems++;
        }
      }

      // Differenzen sortieren: Warnungen zuerst, dann nach Differenz
      differences.sort((a, b) {
        if (a.hasWarning && !b.hasWarning) return -1;
        if (!a.hasWarning && b.hasWarning) return 1;
        return b.difference.abs().compareTo(a.difference.abs());
      });

      return InventoryImportResult(
        success: true,
        totalItems: snapshotItems.length,
        changedItems: changedItems,
        warningItems: warningItems,
        differences: differences,
        snapshotId: snapshotId,
      );
    } catch (e) {
      return InventoryImportResult(
        success: false,
        errorMessage: 'Fehler beim Import: $e',
      );
    }
  }

  /// Parst eine CSV-Zeile und berücksichtigt Anführungszeichen
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ';' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(buffer.toString());
    return result;
  }

  // ============================================================
  // INVENTUR ANWENDEN (Bestände aktualisieren)
  // ============================================================

  /// Wendet die Inventur-Differenzen an und aktualisiert die Bestände
  Future<bool> applyInventoryChanges(
      String snapshotId,
      List<InventoryDifference> differences,
      ) async {
    final user = _auth.currentUser;

    try {
      // Adjustment-Dokument erstellen
      final adjustmentId = DateTime.now().millisecondsSinceEpoch.toString();
      final adjustmentRef =
      _firestore.collection('inventory_adjustments').doc(adjustmentId);

      await adjustmentRef.set({
        'created_at': FieldValue.serverTimestamp(),
        'created_by': user?.uid,
        'created_by_email': user?.email,
        'snapshot_id': snapshotId,
        'total_changes': differences.length,
        'status': 'applied',
      });

      // Batches für Änderungen
      final batches = <WriteBatch>[];
      var currentBatch = _firestore.batch();
      var operationCount = 0;

      for (final diff in differences) {
        // 1. Inventory aktualisieren
        final inventoryRef =
        _firestore.collection('inventory').doc(diff.shortBarcode);

        currentBatch.update(inventoryRef, {
          'quantity': diff.newQuantity,
          'last_modified': FieldValue.serverTimestamp(),
          'last_inventory_adjustment': adjustmentId,
        });
        operationCount++;

        // 2. Stock Entry erstellen (für Historie)
        final stockEntryRef = _firestore.collection('stock_entries').doc();
        currentBatch.set(stockEntryRef, {
          'product_id': diff.shortBarcode,
          'quantity_change': diff.difference,
          'old_quantity': diff.oldQuantity,
          'new_quantity': diff.newQuantity,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'inventory_adjustment',
          'entry_type': diff.difference > 0 ? 'increase' : 'decrease',
          'adjustment_id': adjustmentId,
          'snapshot_id': snapshotId,
          'comment': diff.comment,
          'created_by': user?.uid,
        });
        operationCount++;

        // 3. Adjustment-Item speichern
        final adjustmentItemRef =
        adjustmentRef.collection('items').doc(diff.shortBarcode);
        currentBatch.set(adjustmentItemRef, diff.toMap());
        operationCount++;

        // Batch-Limit prüfen
        if (operationCount >= 450) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      // Alle Batches ausführen
      for (var batch in batches) {
        await batch.commit();
      }

      // Snapshot-Status aktualisieren
      await _firestore.collection('inventory_snapshots').doc(snapshotId).update({
        'status': 'applied',
        'applied_at': FieldValue.serverTimestamp(),
        'applied_by': user?.uid,
        'adjustment_id': adjustmentId,
        'total_changes': differences.length,
      });

      return true;
    } catch (e) {
      print('Fehler beim Anwenden der Inventur: $e');
      return false;
    }
  }

  // ============================================================
  // SNAPSHOT VERWALTUNG
  // ============================================================

  /// Lädt alle Snapshots
  Stream<QuerySnapshot<Map<String, dynamic>>> getSnapshots() {
    return _firestore
        .collection('inventory_snapshots')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Lädt einen einzelnen Snapshot
  Future<DocumentSnapshot<Map<String, dynamic>>> getSnapshot(String snapshotId) {
    return _firestore.collection('inventory_snapshots').doc(snapshotId).get();
  }

  /// Lädt die Items eines Snapshots
  Future<QuerySnapshot<Map<String, dynamic>>> getSnapshotItems(String snapshotId) {
    return _firestore
        .collection('inventory_snapshots')
        .doc(snapshotId)
        .collection('items')
        .get();
  }

  /// Löscht einen Snapshot (nur wenn nicht angewendet)
  Future<bool> deleteSnapshot(String snapshotId) async {
    try {
      final snapshot = await getSnapshot(snapshotId);
      final data = snapshot.data();

      if (data?['status'] == 'applied') {
        return false; // Angewendete Snapshots nicht löschen
      }

      // Items löschen
      final items = await getSnapshotItems(snapshotId);
      final batch = _firestore.batch();

      for (var doc in items.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Snapshot löschen
      await _firestore.collection('inventory_snapshots').doc(snapshotId).delete();

      return true;
    } catch (e) {
      print('Fehler beim Löschen des Snapshots: $e');
      return false;
    }
  }

  // ============================================================
  // HILFSMETHODEN
  // ============================================================

  String _formatQuantity(dynamic quantity, String unit) {
    final qty = (quantity ?? 0).toDouble();
    if (unit == 'Stück') {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(3);
  }

  /// Generiert einen Differenz-Report als CSV
  Future<File> exportDifferenceReport(
      String snapshotId,
      List<InventoryDifference> differences,
      ) async {
    final StringBuffer csvContent = StringBuffer();

    // BOM für Excel
    csvContent.write('\uFEFF');

    // Header
    csvContent.writeln([
      'Artikelnummer',
      'Produkt',
      'Einheit',
      'Alter Bestand',
      'Neuer Bestand',
      'Differenz',
      'Abweichung %',
      'Warnung',
      'Bemerkung',
    ].join(';'));

    // Daten
    for (final diff in differences) {
      csvContent.writeln([
        diff.shortBarcode,
        diff.productName,
        diff.unit,
        _formatQuantity(diff.oldQuantity, diff.unit),
        _formatQuantity(diff.newQuantity, diff.unit),
        _formatQuantity(diff.difference, diff.unit),
        '${diff.differencePercent.toStringAsFixed(1)}%',
        diff.hasWarning ? 'JA' : '',
        diff.comment ?? '',
      ].join(';'));
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'Inventur_Differenzen_$snapshotId.csv';
    final file = File('${tempDir.path}/$fileName');

    await file.writeAsString(csvContent.toString());

    return file;
  }
}