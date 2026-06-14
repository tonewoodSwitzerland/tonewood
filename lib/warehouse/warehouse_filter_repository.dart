import 'package:cloud_firestore/cloud_firestore.dart';
import 'warehouse_filter.dart';

/// Kapselt die gesamte Firestore-Persistenz rund um [WarehouseFilter]:
///  - den zuletzt aktiven Filter eines Nutzers (`users/{uid}/settings/filter_settings`),
///  - die geteilten Filter-Favoriten (`general_data/filter_settings/favorites`).
///
/// Der Screen kennt damit keine Collection-Pfade mehr und arbeitet nur noch
/// mit [WarehouseFilter]-Objekten. Serialisierung lebt im Modell
/// ([WarehouseFilter.toMap] / [WarehouseFilter.fromMap]).
class WarehouseFilterRepository {
  WarehouseFilterRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _filterDoc => _db
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('filter_settings');

  CollectionReference<Map<String, dynamic>> get _favoritesCol => _db
      .collection('general_data')
      .doc('filter_settings')
      .collection('favorites');

  /// Live-Stream des gespeicherten Filters. Liefert `null`, wenn noch nichts
  /// gespeichert wurde (Erststart).
  Stream<WarehouseFilter?> watch() {
    return _filterDoc.snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return WarehouseFilter.fromMap(data);
    });
  }

  /// Speichert den aktuellen Filter (überschreibt den vorherigen).
  Future<void> save(WarehouseFilter filter) {
    return _filterDoc.set({
      ...filter.toMap(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Legt einen benannten Favoriten ab. Schema bleibt kompatibel zur
  /// bestehenden FilterFavoritesSheet: bei aktiver Suche nur `searchText`,
  /// sonst die manuellen Felder. `unit` wird nur bei Bedarf geschrieben.
  Future<void> saveFavorite({
    required String name,
    required WarehouseFilter filter,
  }) {
    final isSearch = filter.hasSearch;
    final data = <String, dynamic>{
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'isSearch': isSearch,
    };

    if (isSearch) {
      data['searchText'] = filter.searchText;
    } else {
      data['instrumentCodes'] = filter.instrumentCodes;
      data['partCodes'] = filter.partCodes;
      data['woodCodes'] = filter.woodCodes;
      data['qualityCodes'] = filter.qualityCodes;
      data['features'] = filter.features.toList();
      data['isActs'] = filter.isActs;
      data['years'] = filter.years;
      data['createdFrom'] = filter.createdFrom?.millisecondsSinceEpoch;
      data['createdTo'] = filter.createdTo?.millisecondsSinceEpoch;
      if (filter.unit != null) {
        data['unit'] = filter.unit;
      }
    }

    return _favoritesCol.add(data);
  }
}