import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseUploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload der gesamten Stammdaten
  Future<void> uploadAllMasterData() async {
   // await uploadInstruments();
    // await uploadParts();
    // await uploadWoodTypes();
    // await uploadQualities();
     await uploadYears();
   //  await uploadSequenceNumbers();
  }

  // Upload Instrumente
  Future<void> uploadInstruments() async {
    final instruments = [
      {'code': '10', 'name': 'Steelstring Gitarre'},
      {'code': '11', 'name': 'Klassische Gitarre'},
      {'code': '12', 'name': 'Parlor Gitarre'},
      {'code': '13', 'name': 'Archtop Gitarre'},
      {'code': '14', 'name': 'E-Gitarre'},
      {'code': '15', 'name': 'Laute'},
      {'code': '16', 'name': 'Bouzouki'},
      {'code': '17', 'name': 'Mandoline'},
      {'code': '18', 'name': 'Ukulele'},
      {'code': '19', 'name': 'Gitarrenhals'},
      {'code': '20', 'name': 'Violine'},
      {'code': '21', 'name': 'Viola'},
      {'code': '22', 'name': 'Cello'},
      {'code': '23', 'name': 'Kontrabass'},
      {'code': '24', 'name': 'Klavier'},
      {'code': '25', 'name': 'Harfe'},
      {'code': '26', 'name': 'Leistenholz'},
      {'code': '27', 'name': 'Schindeln'},
      {'code': '28', 'name': 'Abschnitte'},
      {'code': '99', 'name': 'Spezial'},
    ];

    final batch = _firestore.batch();
    for (var instrument in instruments) {
      final docRef = _firestore.collection('instruments').doc(instrument['code']);
      batch.set(docRef, {
        ...instrument,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Upload Teile
  Future<void> uploadParts() async {
    final parts = [
      {'code': '10', 'name': 'Decke'},
      {'code': '11', 'name': 'Boden'},
      {'code': '12', 'name': 'Zargen'},
      {'code': '13', 'name': 'Hals'},
      {'code': '14', 'name': 'Set (Bo/Ha/Za)'},
      {'code': '15', 'name': 'Set (Bo/Za)'},
      {'code': '16', 'name': 'Resonanzholz'},
      {'code': '17', 'name': 'Leistenholz kurz'},
      {'code': '18', 'name': 'Leistenholz lang'},
      {'code': '19', 'name': 'Rippenholz'},
      {'code': '20', 'name': 'Balken'},
      {'code': '21', 'name': 'Bassbalken'},
      {'code': '22', 'name': 'Stimmstock'},
      {'code': '23', 'name': 'Block'},
      {'code': '24', 'name': 'Kopfplatte'},
      {'code': '25', 'name': 'Body 1-teilig'},
      {'code': '26', 'name': 'Body 2-teilig'},
      {'code': '27', 'name': 'Body 3-teilig'},
      {'code': '28', 'name': '700 x 80 x 27'},
      {'code': '29', 'name': '700 x 100 x 27'},
      {'code': '30', 'name': '700 x 100 x 50'},
      {'code': '31', 'name': '900 x 100 x 27'},
      {'code': '32', 'name': '900 x 100 x 50'},
      {'code': '33', 'name': '1100 x 135 x 50'},
      {'code': '34', 'name': 'Carved top'},
      {'code': '35', 'name': 'Drop top'},
      {'code': '36', 'name': 'Klotz'},
      {'code': '99', 'name': 'Spezial'},
    ];

    final batch = _firestore.batch();
    for (var part in parts) {
      final docRef = _firestore.collection('parts').doc(part['code']);
      batch.set(docRef, {
        ...part,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Upload Holzarten
  Future<void> uploadWoodTypes() async {
    final woodTypes = [
      {'code': '10', 'name': 'Fichte'},
      {'code': '11', 'name': 'Weisstanne'},
      {'code': '12', 'name': 'Bergahorn'},
      {'code': '13', 'name': 'Kirsche'},
      {'code': '14', 'name': 'Zwetschge'},
      {'code': '15', 'name': 'Birnbaum'},
      {'code': '16', 'name': 'Apfelbaum'},
      {'code': '17', 'name': 'Elsbeere'},
      {'code': '18', 'name': 'Nussbaum'},
      {'code': '19', 'name': 'Schwarznuss'},
      {'code': '20', 'name': 'Lärche'},
      {'code': '21', 'name': 'Föhre'},
      {'code': '22', 'name': 'Arve'},
      {'code': '23', 'name': 'Eibe'},
      {'code': '24', 'name': 'Scheinzypresse'},
      {'code': '25', 'name': 'Buche'},
      {'code': '26', 'name': 'Esche'},
      {'code': '27', 'name': 'Erle'},
      {'code': '28', 'name': 'Hagebuche'},
      {'code': '29', 'name': 'Ulme'},
      {'code': '30', 'name': 'Eiche'},
      {'code': '31', 'name': 'Roteiche'},
      {'code': '32', 'name': 'Platane'},
      {'code': '33', 'name': 'Gleditschie'},
      {'code': '99', 'name': 'undefiniert'},
    ];

    final batch = _firestore.batch();
    for (var wood in woodTypes) {
      final docRef = _firestore.collection('wood_types').doc(wood['code']);
      batch.set(docRef, {
        ...wood,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Upload Qualitäten
  Future<void> uploadQualities() async {
    final qualities = [
      {'code': '10', 'name': 'Master'},
      {'code': '11', 'name': 'AAAA'},
      {'code': '12', 'name': 'AAA'},
      {'code': '13', 'name': 'AA'},
      {'code': '14', 'name': 'A'},
      {'code': '15', 'name': 'AB'},
      {'code': '16', 'name': 'O'},
      {'code': '17', 'name': '1'},
      {'code': '18', 'name': '2'},
      {'code': '20', 'name': 'I'},
      {'code': '21', 'name': 'II'},
      {'code': '22', 'name': 'III'},
      {'code': '23', 'name': 'IV'},
      {'code': '99', 'name': 'undefiniert'},
    ];

    final batch = _firestore.batch();
    for (var quality in qualities) {
      final docRef = _firestore.collection('qualities').doc(quality['code']);
      batch.set(docRef, {
        ...quality,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Upload Jahre
  Future<void> uploadYears() async {
    final years = List.generate(25, (index) => {
      'code': index.toString().padLeft(2, '0'),
      'name': index == 0 ? 'Jahrgang' : '',
    });

    final batch = _firestore.batch();
    for (var year in years) {
      final docRef = _firestore.collection('years').doc(year['code']);
      batch.set(docRef, {
        ...year,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Upload Sequenznummern
  Future<void> uploadSequenceNumbers() async {
    final sequences = List.generate(28, (index) => {
      'code': (index + 1).toString().padLeft(4, '0'),
      'name': index == 0 ? 'eindeutige Produktzuordnungsnummer/Laufnummer' : '',
      'used': false,
    });

    final batch = _firestore.batch();
    for (var sequence in sequences) {
      // Explizite Typumwandlung zu String
      String sequenceCode = sequence['code'] as String;

      final docRef = _firestore.collection('sequences').doc(sequenceCode);
      batch.set(docRef, {
        'code': sequenceCode,
        'name': sequence['name'] as String,
        'used': sequence['used'] as bool,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Hilfsmethode zum Testen der Artikelnummergenerierung
  String generateArticleNumber({
    required String instrumentCode,
    required String partCode,
    required String woodCode,
    required String qualityCode,
    required String year,
    required String sequence,
  }) {
    return '$instrumentCode$partCode.$woodCode$qualityCode.$year.$sequence';
  }
}

