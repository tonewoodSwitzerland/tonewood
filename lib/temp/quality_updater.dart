import 'package:cloud_firestore/cloud_firestore.dart';

class QualityUpdater {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateQualities() async {
    try {
      // Mapping für die Quality Updates
      final Map<String, Map<String, String>> qualityUpdates = {
        '20': {
          'quality_name': 'I thermo',
          'quality_name_en': 'I thermo',
        },
        '21': {
          'quality_name': 'II thermo',
          'quality_name_en': 'II thermo',
        },
        '22': {
          'quality_name': 'III thermo',
          'quality_name_en': 'III thermo',
        },
        '23': {
          'quality_name': 'IV thermo',
          'quality_name_en': 'IV thermo',
        },
        '24': {
          'quality_name': 'B',
          'quality_name_en': 'B',
        },
      };

      // Alle Dokumente in der inventory Collection abrufen
      QuerySnapshot inventorySnapshot = await _firestore
          .collection('inventory')
          .get();

      int updatedCount = 0;

      for (var doc in inventorySnapshot.docs) {
        String? qualityCode = doc.get('quality_code');

        if (qualityCode != null && qualityUpdates.containsKey(qualityCode)) {
          await doc.reference.update(qualityUpdates[qualityCode]!);
          updatedCount++;
          print('Updated: ${doc.id} - Quality Code: $qualityCode');
        }
      }

      print('✅ Update abgeschlossen! $updatedCount Dokumente aktualisiert.');
    } catch (e) {
      print('❌ Fehler beim Update: $e');
    }
  }
}

// Verwendung:
// final updater = QualityUpdater();
// await updater.updateQualities();