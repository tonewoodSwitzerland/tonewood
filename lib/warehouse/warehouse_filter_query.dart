import 'package:cloud_firestore/cloud_firestore.dart';
import 'warehouse_filter.dart';

/// Baut die Firestore-Query und übernimmt die clientseitige Nachfilterung.
///
/// Server-seitig laufen: Collection-Auswahl (inventory/onlineshop), Shop-Status,
/// die vier Code-Filter (instrument/part/wood/quality), unit und die Sortierung.
///
/// Client-seitig laufen: die Textsuche und der Von-Bis-Datumsfilter (jeweils
/// Lager + Shop) sowie – NUR im Shop – die fünf Eigenschaften
/// (thermo/hasel/mondholz/fsc + is_acts) und der Jahrgang.
/// Diese bewusst clientseitig, weil:
///  - `features.*` und `is_acts`/`year` nur bei manuellen Shop-Artikeln existieren;
///    eine serverseitige Query würde Standard-Artikel ohne diese Felder ausschließen,
///  - zusätzliche `where`-Klauseln neue Composite-Indizes erzwingen und die
///    Firestore-Grenze für disjunktive Filter (max. 30 im Produkt) belasten,
///  - ein Jahrgangs-Bereich mit der bestehenden orderBy-Sortierung kollidieren würde.
///  - ein Range-Filter auf `created_at` müsste zudem das erste orderBy-Feld sein
///    und würde mit dem `sold`-Zweig (orderBy `sold_at`) sowie den `whereIn`-
///    Code-Filtern neue Composite-Indizes erzwingen.
class WarehouseFilterQuery {
  /// Server-seitige Query.
  static Query<Map<String, dynamic>> build(WarehouseFilter f) {
    Query<Map<String, dynamic>> query;

    if (f.isOnlineShopView) {
      query = FirebaseFirestore.instance.collection('onlineshop');

      if (f.shopFilter == 'sold') {
        query = query.where('sold', isEqualTo: true);
      } else if (f.shopFilter == 'available') {
        query = query.where('sold', isEqualTo: false);
      } else if (f.shopFilter == 'discounted') {
        query = query.where('discounted', isEqualTo: true);
      }

      if (f.instrumentCodes.isNotEmpty) {
        query = query.where('instrument_code', whereIn: f.instrumentCodes);
      }
      if (f.partCodes.isNotEmpty) {
        query = query.where('part_code', whereIn: f.partCodes);
      }
      if (f.woodCodes.isNotEmpty) {
        query = query.where('wood_code', whereIn: f.woodCodes);
      }
      if (f.qualityCodes.isNotEmpty) {
        query = query.where('quality_code', whereIn: f.qualityCodes);
      }

      query = (f.shopFilter == 'sold')
          ? query.orderBy('sold_at', descending: true)
          : query.orderBy('created_at', descending: true);
    } else {
      query = FirebaseFirestore.instance.collection('inventory');

      if (f.instrumentCodes.isNotEmpty) {
        query = query.where('instrument_code', whereIn: f.instrumentCodes);
      }
      if (f.partCodes.isNotEmpty) {
        query = query.where('part_code', whereIn: f.partCodes);
      }
      if (f.woodCodes.isNotEmpty) {
        query = query.where('wood_code', whereIn: f.woodCodes);
      }
      if (f.qualityCodes.isNotEmpty) {
        query = query.where('quality_code', whereIn: f.qualityCodes);
      }
      if (f.unit != null) {
        query = query.where('unit', isEqualTo: f.unit);
      }
    }

    return query;
  }

  /// Clientseitige Nachfilterung.
  /// - Textsuche: Lager UND Shop
  /// - Von-Bis-Datum (`created_at`): Lager UND Shop
  /// - Eigenschaften/Jahrgang: NUR Shop
  static List<QueryDocumentSnapshot> applyClientFilters(
      List<QueryDocumentSnapshot> docs,
      WarehouseFilter f,
      ) {
    Iterable<QueryDocumentSnapshot> result = docs;

    // 1) Textsuche – gilt für Lager UND Shop
    if (f.hasSearch) {
      final terms = f.searchText
          .toLowerCase()
          .split(' ')
          .where((t) => t.isNotEmpty)
          .toList();

      result = result.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final haystack = [
          data['product_name'] ?? '',
          data['product_name_en'] ?? '',
          f.isOnlineShopView
              ? (data['barcode'] ?? '')
              : (data['short_barcode'] ?? ''),
          data['instrument_name'] ?? '',
          data['instrument_name_en'] ?? '',
          data['part_name'] ?? '',
          data['part_name_en'] ?? '',
          data['wood_name'] ?? '',
          data['wood_name_en'] ?? '',
          data['quality_name'] ?? '',
          data['quality_name_en'] ?? '',
          data['instrument_code'] ?? '',
          data['part_code'] ?? '',
          data['wood_code'] ?? '',
          data['quality_code'] ?? '',
        ].join(' ').toLowerCase();
        return terms.every((t) => haystack.contains(t));
      });
    }

    // 2) Von-Bis-Datum auf `created_at` – gilt für Lager UND Shop.
    //    Die Grenzen werden tagesgenau interpretiert: `createdFrom` ab 00:00:00,
    //    `createdTo` inklusive bis 23:59:59.999. Dokumente ohne (lesbares)
    //    `created_at` fallen heraus, sobald eine Grenze gesetzt ist.
    if (f.hasDateFilter) {
      final from = f.createdFrom == null ? null : _startOfDay(f.createdFrom!);
      final to = f.createdTo == null ? null : _endOfDay(f.createdTo!);

      result = result.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final created = _readCreatedAt(data['created_at']);
        if (created == null) return false;
        if (from != null && created.isBefore(from)) return false;
        if (to != null && created.isAfter(to)) return false;
        return true;
      });
    }

    // 3) Shop-Eigenschaften + Jahrgang – NUR in der Shop-Ansicht
    if (f.isOnlineShopView && f.hasShopPropertyFilters) {
      result = result.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // `features`-Map kann bei Standard-Artikeln komplett fehlen.
        final features = (data['features'] as Map?)?.cast<String, dynamic>();

        // a) Vier Boolean-Merkmale (UND): jedes gewählte muss true sein.
        for (final key in f.features) {
          if (features == null || features[key] != true) return false;
        }

        // b) is_acts (Top-Level-Feld).
        if (f.isActs != null) {
          final value = data['is_acts'] == true;
          if (value != f.isActs) return false;
        }

        // c) Jahrgang (year ist ein String, z. B. "07").
        if (f.years.isNotEmpty) {
          final year = normalizeYear(data['year']);
          if (!f.years.contains(year)) return false;
        }
        return true;
      });
    }

    return result.toList();
  }

  /// Liest `created_at` defensiv als lokale DateTime.
  /// Unterstützt Firestore-Timestamp, DateTime und millisecondsSinceEpoch (int).
  static DateTime? _readCreatedAt(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// Vereinheitlicht uneinheitliche Jahrgänge: "14" -> "2014", "2014" bleibt.
  /// (Annahme: zweistellige Jahre sind 20xx – für ältere Bestände ggf. anpassen.)
  static String normalizeYear(Object? raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (s.length == 2) return '20$s';
    return s;
  }

  static List<String> availableYears(List<QueryDocumentSnapshot> docs) {
    final years = docs
        .map((d) => normalizeYear((d.data() as Map<String, dynamic>)['year']))
        .where((y) => y.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return years;
  }
}